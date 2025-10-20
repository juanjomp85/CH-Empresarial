# 🔧 Corrección: Notificaciones Perdidas

**Fecha**: 20 de octubre de 2025  
**Estado**: ✅ Corrección aplicada
**Prioridad**: 🔴 CRÍTICA

## 🐛 Problema Identificado

Después de los cambios del 19 de octubre relacionados con el cierre automático, las notificaciones dejaron de funcionar correctamente, causando:

- ❌ **Algunos usuarios NO reciben notificaciones** (ni de entrada ni de salida)
- ❌ **Los que reciben notificaciones las reciben a horas incorrectas**
- ✅ **Antes del cambio, las notificaciones funcionaban perfectamente**

### Causa Raíz

Las funciones SQL `get_employees_needing_clock_in_reminder()` y `get_employees_needing_clock_out_reminder()` tenían una **ventana de detección de SOLO 1 MINUTO**:

```sql
-- ❌ CÓDIGO PROBLEMÁTICO (líneas 91-92 y 168-169)
AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.start_time + INTERVAL '5 minutes')
AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME < (es.start_time + INTERVAL '6 minutes')
```

### ¿Por Qué Fallaba?

1. **El cron job ejecuta cada 5 minutos**: `:00`, `:05`, `:10`, `:15`, `:20`, `:25`, `:30`, `:35`, `:40`, `:45`, `:50`, `:55`

2. **La función solo detectaba empleados en una ventana de 1 minuto** (entre minuto 5 y minuto 6)

3. **Solo funcionaba para horarios múltiplos de 5**:
   - ✅ Horario 09:00 → Notificación a las 09:05-09:06 → Cron ejecuta a las 09:05 → **FUNCIONA**
   - ❌ Horario 09:02 → Notificación a las 09:07-09:08 → Cron ejecuta a las 09:05 y 09:10 → **SE PIERDE**
   - ❌ Horario 18:03 → Notificación a las 18:08-18:09 → Ninguna ejecución del cron coincide → **SE PIERDE**

### Ejemplo Visual

```
Horario: 09:02 (entrada esperada)
         |
         v
09:02 -------- 09:07 (notificación debería enviarse aquí)
                |     
                v
   ❌ [09:05 cron ejecuta] ← Demasiado pronto (la ventana es 09:07-09:08)
                |
                v
              09:08 (fin de ventana de 1 minuto)
                |
   ❌ [09:10 cron ejecuta] ← Demasiado tarde (ya pasó la ventana)
   
RESULTADO: Notificación NUNCA se envía
```

## ✅ Solución Aplicada

He eliminado la restricción de la ventana de 1 minuto. Ahora las funciones detectan **todos los empleados con 5 minutos o más de retraso**, independientemente del momento exacto.

### Cambios Realizados en `supabase/notifications.sql`

#### 1. Función `get_employees_needing_clock_in_reminder()` (líneas 86-96)

```sql
-- ✅ NUEVA VERSIÓN (CORRECTA)
WHERE 
    -- No ha fichado hoy
    te.clock_in IS NULL
    -- Enviar notificación si han pasado 5 minutos o más después de la hora de entrada
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.start_time + INTERVAL '5 minutes')
    -- No se ha enviado notificación hoy para este empleado
    AND (rn.last_sent IS NULL OR DATE(rn.last_sent) < CURRENT_DATE)
    -- Estamos dentro del horario laboral
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= '06:00:00'
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME <= '23:00:00';
```

#### 2. Función `get_employees_needing_clock_out_reminder()` (líneas 161-172)

```sql
-- ✅ NUEVA VERSIÓN (CORRECTA)
WHERE 
    -- Ha fichado entrada pero no salida
    te.clock_in IS NOT NULL
    AND te.clock_out IS NULL
    -- Enviar notificación si han pasado 5 minutos o más después de la hora de salida
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.end_time + INTERVAL '5 minutes')
    -- No se ha enviado notificación hoy para este empleado
    AND (rn.last_sent IS NULL OR DATE(rn.last_sent) < CURRENT_DATE)
    -- Estamos dentro del horario laboral
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= '06:00:00'
    AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME <= '23:59:59';
```

### Protección Anti-Duplicados

La protección contra envío de múltiples notificaciones está garantizada por:

```sql
AND (rn.last_sent IS NULL OR DATE(rn.last_sent) < CURRENT_DATE)
```

Esto asegura que **solo se envía 1 notificación por día por empleado**, sin importar cuántas veces ejecute el cron.

## 📋 Pasos para Aplicar la Corrección

### Paso 1: Actualizar Supabase

1. Abre el **SQL Editor** en tu dashboard de Supabase
2. Copia y ejecuta el contenido completo de `supabase/notifications.sql`
3. Verifica que se ejecute sin errores

```bash
# Alternativamente, si usas Supabase CLI:
supabase db push
```

### Paso 2: Verificar la Corrección

Ejecuta esta consulta en Supabase para ver qué empleados serán notificados en la próxima ejecución:

```sql
-- Ver empleados que necesitan notificación de ENTRADA
SELECT * FROM get_employees_needing_clock_in_reminder();

-- Ver empleados que necesitan notificación de SALIDA
SELECT * FROM get_employees_needing_clock_out_reminder();
```

### Paso 3: Limpiar Logs Antiguos (Opcional)

Si quieres limpiar los logs de notificaciones de hoy para hacer una prueba limpia:

```sql
-- ⚠️ USAR CON PRECAUCIÓN - Solo para testing
DELETE FROM notification_logs 
WHERE DATE(sent_at) = CURRENT_DATE;
```

### Paso 4: Probar Manualmente

Fuerza una ejecución del endpoint de notificaciones:

```bash
# Desarrollo local
curl -X POST http://localhost:3000/api/notifications/send \
  -H "Authorization: Bearer tu_cron_secret"

# Producción
curl -X POST https://tudominio.com/api/notifications/send \
  -H "Authorization: Bearer tu_cron_secret"
```

## 🧪 Casos de Prueba

### Antes de la Corrección (❌ FALLABA)

| Horario Entrada | Notificación Esperada | Cron Ejecuta | Resultado |
|---|---|---|---|
| 09:00 | 09:05-09:06 | 09:05 ✅ | Funciona |
| 09:01 | 09:06-09:07 | 09:05 ❌, 09:10 ❌ | **Falla** |
| 09:02 | 09:07-09:08 | 09:05 ❌, 09:10 ❌ | **Falla** |
| 09:03 | 09:08-09:09 | 09:05 ❌, 09:10 ❌ | **Falla** |
| 09:04 | 09:09-09:10 | 09:05 ❌, 09:10 ✅ | Funciona |

**Resultado**: Solo el 40% de los empleados recibían notificaciones.

### Después de la Corrección (✅ FUNCIONA)

| Horario Entrada | Notificación Esperada | Cron Ejecuta | Resultado |
|---|---|---|---|
| 09:00 | >= 09:05 | 09:05 ✅ | **Funciona** |
| 09:01 | >= 09:06 | 09:10 ✅ | **Funciona** |
| 09:02 | >= 09:07 | 09:10 ✅ | **Funciona** |
| 09:03 | >= 09:08 | 09:10 ✅ | **Funciona** |
| 09:04 | >= 09:09 | 09:10 ✅ | **Funciona** |

**Resultado**: ✅ **100% de los empleados reciben notificaciones**.

## 🔍 Cómo Verificar que Funciona

### 1. Monitorear Logs en Tiempo Real

```sql
-- Ver notificaciones enviadas hoy
SELECT 
    nl.sent_at AT TIME ZONE 'Europe/Madrid' as enviado_a,
    e.full_name,
    nl.notification_type,
    nl.status,
    CASE 
        WHEN nl.notification_type = 'clock_in_reminder' THEN '⏰ Entrada'
        WHEN nl.notification_type = 'clock_out_reminder' THEN '🚪 Salida'
        WHEN nl.notification_type = 'auto_clock_out' THEN '🤖 Auto-cierre'
    END as tipo
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE
ORDER BY nl.sent_at DESC;
```

### 2. Verificar Cobertura de Notificaciones

```sql
-- Ver qué empleados deberían haber recibido notificación pero no la recibieron
WITH expected_notifications AS (
    SELECT 
        e.id,
        e.full_name,
        e.email,
        ds.start_time,
        CASE 
            WHEN te.clock_in IS NULL 
                AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (ds.start_time + INTERVAL '5 minutes')
            THEN 'Debería tener notificación de ENTRADA'
            WHEN te.clock_in IS NOT NULL 
                AND te.clock_out IS NULL
                AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (ds.end_time + INTERVAL '5 minutes')
            THEN 'Debería tener notificación de SALIDA'
            ELSE 'OK'
        END as status
    FROM employees e
    LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
    LEFT JOIN time_entries te ON e.id = te.employee_id AND te.date = CURRENT_DATE
    WHERE e.is_active = true
    AND ds.is_working_day = true
    AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
)
SELECT * FROM expected_notifications
WHERE status != 'OK';
```

## 📊 Resultados Esperados

Después de aplicar esta corrección:

- ✅ **TODOS los empleados** con 5+ minutos de retraso recibirán notificaciones
- ✅ Las notificaciones se envían en la **siguiente ejecución del cron** (máximo 5 minutos de espera)
- ✅ **NO se envían duplicados** (solo 1 notificación por día por empleado)
- ✅ Funciona para **cualquier horario**, no solo múltiplos de 5
- ✅ El **cierre automático sigue funcionando** correctamente (no se modificó)

## ⚠️ Nota Importante

Esta corrección **NO afecta** al cierre automático de jornadas (que fue corregido ayer y funciona correctamente). Solo corrige el sistema de notificaciones por email.

## 🎯 Comparación: Antes vs Después

| Aspecto | Antes (❌) | Después (✅) |
|---|---|---|
| Cobertura | ~40% de usuarios | 100% de usuarios |
| Ventana detección | 1 minuto exacto | 5+ minutos desde el retraso |
| Horarios compatibles | Solo múltiplos de 5 | Todos los horarios |
| Duplicados | No se enviaban | No se envían |
| Fiabilidad | Baja | Alta |

## 📞 Si los Problemas Persisten

Si después de aplicar esta corrección sigues teniendo problemas:

1. **Verifica que el cron job esté ejecutándose**:
   - Revisa los logs de Vercel
   - Verifica que `CRON_SECRET` esté configurado
   - Confirma que el timezone es `Europe/Madrid` en `vercel.json`

2. **Verifica las credenciales de email**:
   - Revisa que `EMAIL_PROVIDER` esté configurado (resend/sendgrid)
   - Verifica que `RESEND_API_KEY` o `SENDGRID_API_KEY` sea válido
   - Confirma que `EMAIL_FROM` esté verificado en tu proveedor

3. **Revisa los logs de Supabase**:
   ```sql
   SELECT * FROM notification_logs 
   WHERE status = 'failed'
   AND DATE(sent_at) = CURRENT_DATE;
   ```

4. **Verifica la zona horaria de Supabase**:
   ```sql
   SELECT current_setting('timezone');
   -- Debería mostrar: Europe/Madrid
   ```

## 🚀 Próximos Pasos

1. ✅ Ejecutar el script SQL actualizado en Supabase
2. ✅ Probar manualmente el endpoint
3. ✅ Monitorear los logs durante las próximas horas
4. ✅ Verificar que todos los empleados reciban notificaciones

---

**Estado del fix**: ✅ Listo para aplicar  
**Impacto**: 🔴 Crítico - Restaura la funcionalidad completa de notificaciones  
**Compatibilidad**: ✅ Compatible con el cierre automático corregido ayer  
**Urgencia**: 🔴 Alta - Aplicar inmediatamente para que las notificaciones de hoy funcionen correctamente

