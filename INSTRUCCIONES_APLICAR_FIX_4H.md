# 🚀 Instrucciones para Aplicar el Fix de Cierre Automático 4 Horas

## 📋 Pasos a Seguir

### ✅ Paso 1: Aplicar la corrección en Supabase

1. **Abre tu dashboard de Supabase**: https://app.supabase.com
2. Navega a tu proyecto
3. Ve a **SQL Editor** (icono de base de datos en el menú lateral)
4. Crea una nueva query
5. **Copia y pega TODO el contenido** del archivo: `supabase/notifications.sql`
6. Haz clic en **RUN** o presiona `Ctrl+Enter` (o `Cmd+Enter` en Mac)
7. Espera a que se complete (debería decir "Success. No rows returned")

### ✅ Paso 2: Verificar la corrección (OPCIONAL)

1. En el mismo **SQL Editor**, crea otra nueva query
2. Copia y pega el contenido de: `supabase/verify_fix_4_horas.sql`
3. Ejecuta el script
4. Revisa los resultados de los 5 tests:
   - **TEST 1**: Debe mostrar si hay desfase de fecha
   - **TEST 2**: Debe mostrar los últimos cierres (busca "2 horas" o "4 horas")
   - **TEST 3**: Simulación de qué pasaría ahora
   - **TEST 4**: Empleados pendientes de cierre
   - **TEST 5**: Confirmación de que la función fue actualizada

### ✅ Paso 3: Monitorear el comportamiento

**Importante**: Los cambios solo afectarán a **nuevos** cierres automáticos, no a los históricos.

Después de aplicar el fix:
1. Espera al menos **1 día** para que se generen nuevos cierres automáticos
2. Ejecuta esta query en Supabase para verificar:

```sql
-- Ver últimos cierres y verificar si son de 2 o 4 horas
SELECT 
    DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') as fecha,
    e.full_name as empleado,
    ds.end_time as fin_programado,
    te.clock_out as hora_cierre,
    ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 2) as horas_diferencia,
    CASE 
        WHEN ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 1) = 2.0 
        THEN '✅ CORRECTO: 2 horas'
        WHEN ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 1) BETWEEN 3.5 AND 4.5 
        THEN '❌ ERROR: 4 horas'
        ELSE '⚠️ Otro valor'
    END as verificacion
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
JOIN time_entries te ON te.employee_id = e.id 
    AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
WHERE nl.notification_type = 'auto_clock_out'
AND nl.sent_at >= NOW() - INTERVAL '3 days'
ORDER BY nl.sent_at DESC
LIMIT 20;
```

## 🎯 Resultado Esperado

Después de aplicar el fix, los **NUEVOS** cierres automáticos deben:
- ✅ Ejecutarse **exactamente 2 horas** después de la hora de fin programada
- ✅ Mostrar "✅ CORRECTO: 2 horas" en la columna `verificacion`

Los cierres **históricos** (anteriores al fix):
- Permanecerán con ~4 horas de diferencia
- Esto es **normal** y no afecta al funcionamiento actual

## ❓ Preguntas Frecuentes

### ¿Necesito reiniciar algo?
❌ **No**. Los cambios se aplican inmediatamente en Supabase. El próximo cron job (que se ejecuta cada 5 minutos) ya usará la función corregida.

### ¿Afectará a los datos históricos?
❌ **No**. Los registros ya cerrados permanecen sin cambios. Solo los **nuevos** cierres automáticos usarán la lógica corregida.

### ¿Cómo sé si funcionó?
✅ Espera 1-2 días y ejecuta la query de monitoreo del Paso 3. Los nuevos registros deben mostrar "2 horas" de diferencia.

### ¿Y si sigo viendo 4 horas después del fix?
⚠️ Asegúrate de:
1. Haber ejecutado **TODO** el contenido de `supabase/notifications.sql`
2. Que la ejecución haya sido **exitosa** (sin errores)
3. Que estás viendo registros **NUEVOS** (posteriores a aplicar el fix)

Si el problema persiste, ejecuta `supabase/diagnostic_auto_close.sql` y comparte los resultados.

## 📚 Documentación Relacionada

- **Resumen ejecutivo**: [RESUMEN_FIX_4_HORAS.md](./RESUMEN_FIX_4_HORAS.md)
- **Documentación completa**: [FIX_CIERRE_4_HORAS.md](./FIX_CIERRE_4_HORAS.md)
- **Script de diagnóstico**: [supabase/diagnostic_auto_close.sql](./supabase/diagnostic_auto_close.sql)
- **Script de verificación**: [supabase/verify_fix_4_horas.sql](./supabase/verify_fix_4_horas.sql)

## 🆘 Soporte

Si encuentras algún problema:
1. Ejecuta `supabase/diagnostic_auto_close.sql`
2. Ejecuta `supabase/verify_fix_4_horas.sql`
3. Captura los resultados y compártelos

---

**Última actualización**: 21 de octubre de 2025  
**Estado**: ✅ Fix probado y listo para aplicar

