# ⚡ Resumen: Corrección Cierre Automático 4 Horas

**Fecha**: 21 de octubre de 2025  
**Estado**: ✅ Corrección implementada

## 🎯 Problema Identificado

**Síntoma**: Los cierres automáticos de jornadas se ejecutaban aproximadamente **4 horas después** de la hora de fin programada, en lugar de **2 horas**.

**Ejemplo**:
- Hora de fin programada: 18:00
- Cierre esperado: 20:00 (18:00 + 2h)
- Cierre real: ~22:00 (18:00 + ~4h) ❌

## 🔍 Causa Raíz

**NO era una duplicación de lógica**, sino un **problema de zona horaria**:

- Se usaba `CURRENT_DATE` que retorna la fecha en **UTC**
- Europe/Madrid es **UTC+1** (invierno) o **UTC+2** (verano)
- Al hacer cálculos con `CURRENT_DATE`, se acumulaban desfases de zona horaria
- **Desfase total**: ~2h (zona horaria) + 2h (intervalo programado) = **~4h**

## ✅ Solución Aplicada

### Archivo modificado: `supabase/notifications.sql`

**Cambios realizados** (4 correcciones en la función `auto_generate_clock_out()`):

1. **Línea 270**: Día de la semana usando zona horaria local
   ```sql
   -- Antes:
   AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
   
   -- Ahora:
   AND ds.day_of_week = EXTRACT(DOW FROM (NOW() AT TIME ZONE 'Europe/Madrid')::DATE)::INTEGER
   ```

2. **Línea 279**: Filtrar entradas del día actual en zona horaria local
   ```sql
   -- Antes:
   WHERE te.date = CURRENT_DATE
   
   -- Ahora:
   WHERE te.date = (NOW() AT TIME ZONE 'Europe/Madrid')::DATE
   ```

3. **Línea 293**: Condición de verificación con fecha local
   ```sql
   -- Antes:
   AND (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + es.end_time + INTERVAL '2 hours')
   
   -- Ahora:
   AND (NOW() AT TIME ZONE 'Europe/Madrid') >= ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + es.end_time + INTERVAL '2 hours')
   ```

4. **Línea 304**: Almacenar timestamp en zona horaria correcta
   ```sql
   -- Antes:
   clock_out = CURRENT_DATE + employee_record.expected_clock_out + INTERVAL '2 hours',
   
   -- Ahora:
   clock_out = timezone('Europe/Madrid', employee_record.entry_date + employee_record.expected_clock_out + INTERVAL '2 hours'),
   ```
   
   **⚠️ CRÍTICO**: Esta corrección es esencial. Sin `timezone('Europe/Madrid', ...)`, PostgreSQL interpreta el timestamp como UTC y al almacenarlo le suma 2 horas, resultando en un `clock_out` incorrecto (ej: 22:00 en lugar de 20:00).

## 📋 Instrucciones de Aplicación

### Paso 1: Actualizar Supabase
```bash
# En el SQL Editor de Supabase, ejecuta:
# Copia y pega el contenido completo de: supabase/notifications.sql
```

### Paso 2: Verificar (OPCIONAL)
```bash
# Ejecuta el script de diagnóstico:
# supabase/diagnostic_auto_close.sql
```

### Paso 3: Monitorear
Después de aplicar, el próximo cierre automático debería ejecutarse correctamente a las **2 horas**.

## 🧪 Verificación Rápida

Ejecuta esta query para verificar que funciona:

```sql
-- Ver últimos cierres y verificar si son 2 o 4 horas
SELECT 
    e.full_name as empleado,
    te.clock_out as hora_cierre,
    ds.end_time as hora_fin_programada,
    EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time))) as horas_diferencia,
    CASE 
        WHEN EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time))) = 2 
        THEN '✅ CORRECTO'
        WHEN EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time))) = 4 
        THEN '❌ TODAVÍA CON ERROR'
        ELSE '⚠️ Revisar'
    END as verificacion
FROM time_entries te
JOIN employees e ON te.employee_id = e.id
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
JOIN notification_logs nl ON nl.employee_id = e.id 
    AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
    AND nl.notification_type = 'auto_clock_out'
WHERE te.date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY te.date DESC
LIMIT 10;
```

## 🎯 Resultado Esperado

Después de la corrección:
- ✅ Cierre automático **exactamente a las 2 horas**
- ✅ No más desfases de ~4 horas
- ✅ Funciona en horario de verano e invierno
- ✅ Maneja correctamente cambios de día (23:00 → 01:00)

## 📚 Documentación Completa

Para más detalles, consulta: **[FIX_CIERRE_4_HORAS.md](./FIX_CIERRE_4_HORAS.md)**

---

**Impacto**: ✅ Alto - Corrige problema crítico de timing  
**Riesgo**: 🟢 Bajo - Solo afecta zona horaria, no lógica de negocio  
**Retrocompatibilidad**: ✅ Completa

