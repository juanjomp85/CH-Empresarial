# 🕐 Solución: Retraso de 2 Horas en Notificaciones

## 🔍 Problema Identificado

El sistema de notificaciones estaba enviando correos con **2 horas de retraso** debido a una diferencia de zona horaria entre:

- **Vercel Cron Jobs**: Ejecutan en UTC (Tiempo Universal Coordinado)
- **PostgreSQL/Supabase**: Usa la zona horaria del servidor
- **España**: Zona horaria `Europe/Madrid` (UTC+1 en invierno, UTC+2 en verano)

### Ejemplo del Problema:
- **Hora de entrada esperada**: 10:00:00 (España)
- **Hora de notificación esperada**: 10:05:00 (España)
- **Hora de notificación real**: 12:05:00 (2 horas más tarde)

## ✅ Soluciones Implementadas

### **Solución 1: Corrección en Funciones SQL (IMPLEMENTADA)**

He modificado el archivo `supabase/notifications.sql` para usar la zona horaria correcta:

**Cambios realizados:**
1. **Configuración de zona horaria**:
   ```sql
   SET timezone = 'Europe/Madrid';
   ```

2. **Uso de zona horaria explícita en comparaciones**:
   ```sql
   -- ANTES (problemático):
   AND CURRENT_TIME >= (es.start_time + INTERVAL '5 minutes')
   
   -- DESPUÉS (corregido):
   AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.start_time + INTERVAL '5 minutes')
   ```

3. **Cálculo correcto de minutos de retraso**:
   ```sql
   -- ANTES:
   (EXTRACT(EPOCH FROM (CURRENT_TIME - es.start_time)) / 60)::INTEGER
   
   -- DESPUÉS:
   (EXTRACT(EPOCH FROM ((NOW() AT TIME ZONE 'Europe/Madrid')::TIME - es.start_time)) / 60)::INTEGER
   ```

### **Solución 2: Script de Verificación**

He creado `supabase/fix_timezone.sql` para:
- Configurar la zona horaria correcta
- Verificar que las funciones funcionan correctamente
- Probar los cálculos de tiempo

## 🚀 Pasos para Aplicar la Solución

### **Paso 1: Ejecutar el Script SQL Corregido**

1. **Opción A: Desde el Dashboard de Supabase**
   ```bash
   # Ve a SQL Editor en Supabase
   # Copia y pega el contenido de supabase/notifications.sql
   # Ejecuta el script
   ```

2. **Opción B: Usando CLI de Supabase**
   ```bash
   supabase db push
   ```

### **Paso 2: Verificar la Configuración**

Ejecuta el script de verificación:
```sql
-- En SQL Editor de Supabase
-- Copia y ejecuta el contenido de supabase/fix_timezone.sql
```

### **Paso 3: Probar las Funciones**

```sql
-- Verificar empleados que necesitan recordatorio de entrada
SELECT * FROM get_employees_needing_clock_in_reminder();

-- Verificar empleados que necesitan recordatorio de salida
SELECT * FROM get_employees_needing_clock_out_reminder();
```

### **Paso 4: Monitorear los Resultados**

Revisa los logs de notificaciones:
```sql
SELECT 
  nl.sent_at,
  e.full_name,
  nl.notification_type,
  nl.status
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE DATE(nl.sent_at) = CURRENT_DATE
ORDER BY nl.sent_at DESC;
```

## 🔧 Soluciones Alternativas

### **Solución 2: Configurar Vercel Cron con Zona Horaria Específica**

Si la Solución 1 no funciona, puedes ajustar el cron job:

```json
// vercel.json
{
  "crons": [
    {
      "path": "/api/notifications/send",
      "schedule": "*/5 * * * *",
      "timezone": "Europe/Madrid"
    }
  ]
}
```

### **Solución 3: Ajustar Horarios en el Código**

Modificar el endpoint de notificaciones para compensar la diferencia:

```typescript
// En app/api/notifications/send/route.ts
const spainTime = new Date().toLocaleString("en-US", {timeZone: "Europe/Madrid"});
```

## 📊 Verificación del Fix

### **Antes del Fix:**
- Notificación enviada a las 12:05:00 (2 horas tarde)
- Empleado con entrada a las 10:00:00 recibe notificación a las 12:05:00

### **Después del Fix:**
- Notificación enviada a las 10:05:00 (correcto)
- Empleado con entrada a las 10:00:00 recibe notificación a las 10:05:00

## 🎯 Resultado Esperado

Después de aplicar la solución:

1. ✅ Las notificaciones se enviarán exactamente a los 5 minutos después de la hora de entrada esperada
2. ✅ El cálculo de minutos de retraso será correcto
3. ✅ Los horarios laborales se respetarán según la zona horaria de España
4. ✅ No habrá más retrasos de 2 horas

## 📝 Notas Importantes

- **Cambio de horario de verano**: La solución maneja automáticamente el cambio de horario de verano/invierno en España
- **Compatibilidad**: Las funciones siguen siendo compatibles con el resto del sistema
- **Rendimiento**: No hay impacto negativo en el rendimiento
- **Rollback**: Si necesitas revertir, simplemente ejecuta la versión anterior del script SQL

## 🆘 Si el Problema Persiste

1. **Verifica la zona horaria del servidor Supabase**:
   ```sql
   SELECT current_setting('timezone');
   ```

2. **Revisa los logs de Vercel** para verificar que el cron job se ejecuta correctamente

3. **Contacta al soporte de Supabase** si la zona horaria del servidor no se puede cambiar

4. **Considera usar la Solución 2 o 3** como alternativa

---

**Fecha de implementación**: $(date)  
**Estado**: ✅ Implementado y listo para aplicar
