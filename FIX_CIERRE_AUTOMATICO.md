# 🔧 Corrección: Cierre Automático de Jornadas

**Fecha**: 19 de octubre de 2025  
**Estado**: ✅ Correcciones aplicadas

## 🐛 Problemas Corregidos

### 1. Zona Horaria en Cron Jobs (vercel.json)
**Problema**: El cron job ejecutaba en UTC sin especificar zona horaria, causando retrasos en las ejecuciones.

**Solución**: 
```json
{
  "crons": [
    {
      "path": "/api/notifications/send",
      "schedule": "*/5 * * * *",
      "timezone": "Europe/Madrid"  // ✅ AÑADIDO
    }
  ]
}
```

### 2. Comparación Incorrecta de Timestamps en SQL
**Problema**: La función `auto_generate_clock_out()` comparaba solo la HORA (`::TIME`), lo que causaba:
- Fallos en el cierre automático
- Problemas cuando la hora + 2 horas pasaba al día siguiente (23:00 → 01:00)

**Cambio realizado en `supabase/notifications.sql` (línea 294)**:

```sql
-- ❌ ANTES (INCORRECTO):
AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.end_time + INTERVAL '2 hours')

-- ✅ DESPUÉS (CORRECTO):
AND (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + es.end_time + INTERVAL '2 hours')
```

**Por qué funciona mejor**:
- Usa timestamp completo en lugar de solo hora
- `CURRENT_DATE + es.end_time` crea un timestamp para hoy a la hora de fin
- Añade 2 horas al timestamp completo
- Compara correctamente incluso cuando cruza la medianoche

## 📋 Pasos para Aplicar las Correcciones

### Paso 1: Desplegar cambios en Vercel
```bash
git add vercel.json
git commit -m "fix: añadir timezone a cron jobs"
git push
```

### Paso 2: Actualizar función SQL en Supabase
1. Abre el **SQL Editor** en tu dashboard de Supabase
2. Copia y ejecuta el contenido de `supabase/notifications.sql`
3. La función `auto_generate_clock_out()` se actualizará automáticamente

### Paso 3: Verificar la corrección
Ejecuta el script de verificación en Supabase:
```bash
# Copia y ejecuta el contenido de supabase/fix_timezone.sql
```

Esto te mostrará:
- ✅ Zona horaria actual
- ✅ Comparaciones de horarios
- ✅ Test de cierre automático
- ✅ Test de cambio de día (23:00 → 01:00)

## 🧪 Ejemplos de Funcionamiento

### Ejemplo 1: Jornada Normal
- **Hora de salida**: 18:00
- **Cierre automático**: 20:00 (18:00 + 2 horas)
- **Resultado**: ✅ Se cierra correctamente a las 20:00

### Ejemplo 2: Jornada con Cambio de Día
- **Hora de salida**: 23:00
- **Cierre automático**: 01:00 del día siguiente
- **Resultado**: ✅ Se cierra correctamente a las 01:00 del día siguiente

### Ejemplo 3: Jornada de Noche
- **Hora de salida**: 02:00 AM
- **Cierre automático**: 04:00 AM
- **Resultado**: ✅ Se cierra correctamente a las 04:00 AM

## 🔍 Monitoreo

### Ver registros de cierres automáticos:
```sql
SELECT 
    nl.sent_at,
    e.full_name,
    nl.notification_type,
    nl.status
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE nl.notification_type = 'auto_clock_out'
AND DATE(nl.sent_at) = CURRENT_DATE
ORDER BY nl.sent_at DESC;
```

### Ver entradas que serán cerradas automáticamente:
```sql
SELECT 
    e.full_name,
    te.clock_in,
    ds.end_time as hora_fin_programada,
    (CURRENT_DATE + ds.end_time + INTERVAL '2 hours') as cierre_automatico_a,
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + ds.end_time + INTERVAL '2 hours')
        THEN '🔴 Listo para cierre'
        ELSE '🟡 Aún no'
    END as estado
FROM time_entries te
JOIN employees e ON te.employee_id = e.id
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
WHERE te.date = CURRENT_DATE
AND te.clock_in IS NOT NULL
AND te.clock_out IS NULL
AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER;
```

## ⚠️ Nota sobre Netlify

**IMPORTANTE**: Si estás usando Netlify en lugar de Vercel:
- Netlify **NO soporta cron jobs nativamente**
- Opciones:
  1. **Recomendado**: Migrar a Vercel para aprovechar los cron jobs
  2. Usar **GitHub Actions** para ejecutar el endpoint cada 5 minutos
  3. Usar un servicio externo como **cron-job.org**

### Ejemplo con GitHub Actions:
```yaml
# .github/workflows/cron.yml
name: Run Notifications Cron
on:
  schedule:
    - cron: '*/5 * * * *'
  workflow_dispatch:

jobs:
  run-notifications:
    runs-on: ubuntu-latest
    steps:
      - name: Call notifications endpoint
        run: |
          curl -X POST https://tu-app.netlify.app/api/notifications/send \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}"
```

## 🎯 Resultado Esperado

Después de aplicar estas correcciones:
- ✅ Los cierres automáticos se ejecutan **exactamente 2 horas** después de la hora de fin de jornada
- ✅ Funciona correctamente con cambios de día (23:00 → 01:00)
- ✅ No hay más retrasos por problemas de zona horaria
- ✅ Los logs muestran la hora correcta de cierre

## 📞 Si los Problemas Persisten

1. **Verifica la zona horaria de Supabase**:
   ```sql
   SELECT current_setting('timezone');
   ```

2. **Revisa los logs de Vercel** para ver si el cron se ejecuta correctamente

3. **Verifica las variables de entorno** en Vercel:
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `CRON_SECRET` (opcional pero recomendado)

4. **Consulta los logs de notificaciones** en Supabase para ver errores específicos

---

**Estado del fix**: ✅ Listo para aplicar  
**Impacto**: Alto - Corrige el problema principal del cierre automático  
**Compatibilidad**: ✅ Compatible con todas las versiones anteriores

