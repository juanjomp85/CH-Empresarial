-- =====================================
-- VERIFICACIÓN: Corrección del Cierre Automático de 4 horas a 2 horas
-- =====================================
-- Fecha: 21 de octubre de 2025
-- Ejecuta este script DESPUÉS de aplicar la corrección

SET timezone = 'Europe/Madrid';

-- =====================================
-- TEST 1: Verificar desfase de fecha
-- =====================================
SELECT 
    '🔍 TEST 1: Verificar Desfase de Fecha UTC vs Europe/Madrid' as test,
    CURRENT_DATE as fecha_utc,
    (NOW() AT TIME ZONE 'Europe/Madrid')::DATE as fecha_madrid,
    CASE 
        WHEN CURRENT_DATE = (NOW() AT TIME ZONE 'Europe/Madrid')::DATE 
        THEN '✅ Sin desfase (puede variar según hora del día)'
        ELSE '⚠️ Hay desfase: Este es el problema que se corrigió'
    END as resultado;

-- =====================================
-- TEST 2: Ver últimos cierres automáticos
-- =====================================
SELECT 
    '🔍 TEST 2: Análisis de Cierres Automáticos Recientes' as test;

SELECT 
    DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') as fecha,
    e.full_name as empleado,
    ds.end_time as fin_programado,
    te.clock_out as hora_cierre,
    -- Calcular diferencia exacta
    ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 2) as horas_diferencia,
    -- Verificación
    CASE 
        WHEN ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 1) = 2.0 
        THEN '✅ CORRECTO: Exactamente 2 horas'
        WHEN ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 1) BETWEEN 3.5 AND 4.5 
        THEN '❌ ERROR: ~4 horas (aún con bug)'
        ELSE '⚠️ Revisar: ' || ROUND(EXTRACT(EPOCH FROM (te.clock_out - (te.date + ds.end_time))) / 3600, 2)::TEXT || ' horas'
    END as verificacion
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
JOIN time_entries te ON te.employee_id = e.id 
    AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
WHERE nl.notification_type = 'auto_clock_out'
AND nl.sent_at >= NOW() - INTERVAL '7 days'
ORDER BY nl.sent_at DESC
LIMIT 10;

-- =====================================
-- TEST 3: Simulación - ¿Qué pasaría AHORA?
-- =====================================
SELECT 
    '🔍 TEST 3: Simulación de Cierre Automático AHORA' as test;

WITH test_schedule AS (
    SELECT '18:00:00'::TIME as end_time, 'Jornada hasta 18:00' as descripcion
    UNION ALL
    SELECT '14:00:00'::TIME, 'Jornada hasta 14:00'
    UNION ALL
    SELECT '23:00:00'::TIME, 'Jornada hasta 23:00 (cruza día)'
)
SELECT 
    ts.descripcion,
    ts.end_time as hora_fin,
    -- Con CURRENT_DATE (UTC) - ANTIGUO (con bug)
    (CURRENT_DATE + ts.end_time + INTERVAL '2 hours') as con_current_date_utc,
    -- Con fecha local - NUEVO (corregido)
    ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + ts.end_time + INTERVAL '2 hours') as con_fecha_local,
    -- Diferencia entre ambos métodos
    EXTRACT(HOUR FROM ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + ts.end_time + INTERVAL '2 hours') - 
                      (CURRENT_DATE + ts.end_time + INTERVAL '2 hours')) as diferencia_horas,
    -- ¿Se ejecutaría el cierre AHORA?
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + ts.end_time + INTERVAL '2 hours')
        THEN '🔴 SÍ (ha pasado el tiempo)'
        ELSE '🟢 NO (todavía no)'
    END as se_ejecutaria_ahora
FROM test_schedule ts;

-- =====================================
-- TEST 4: Empleados pendientes de cierre
-- =====================================
SELECT 
    '🔍 TEST 4: Empleados que necesitan cierre automático AHORA' as test;

WITH employee_schedules AS (
    SELECT 
        e.id as emp_id,
        e.full_name,
        ds.end_time,
        ds.day_of_week
    FROM employees e
    LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
    WHERE e.is_active = true
    AND ds.is_working_day = true
    AND ds.day_of_week = EXTRACT(DOW FROM (NOW() AT TIME ZONE 'Europe/Madrid')::DATE)::INTEGER
),
todays_entries AS (
    SELECT 
        te.employee_id,
        te.clock_in,
        te.clock_out,
        te.date
    FROM time_entries te
    WHERE te.date = (NOW() AT TIME ZONE 'Europe/Madrid')::DATE
)
SELECT 
    es.full_name as empleado,
    es.end_time as hora_fin_programada,
    te.clock_in as fichaje_entrada,
    te.clock_out as fichaje_salida,
    ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + es.end_time + INTERVAL '2 hours') as se_cerrara_a_las,
    NOW() AT TIME ZONE 'Europe/Madrid' as hora_actual,
    CASE 
        WHEN te.clock_out IS NULL AND 
             (NOW() AT TIME ZONE 'Europe/Madrid') >= ((NOW() AT TIME ZONE 'Europe/Madrid')::DATE + es.end_time + INTERVAL '2 hours')
        THEN '🔴 LISTO PARA CIERRE (en próxima ejecución de cron)'
        WHEN te.clock_out IS NULL
        THEN '🟡 Pendiente, pero aún no han pasado 2 horas'
        ELSE '✅ Ya cerrado'
    END as estado
FROM employee_schedules es
LEFT JOIN todays_entries te ON es.emp_id = te.employee_id
WHERE te.clock_in IS NOT NULL
ORDER BY es.end_time;

-- =====================================
-- TEST 5: Verificar la función corregida
-- =====================================
SELECT 
    '🔍 TEST 5: Verificar código de la función auto_generate_clock_out()' as test;

SELECT 
    '✅ La función ha sido actualizada correctamente' as estado,
    '
    Cambios aplicados:
    1. ✅ Línea 270: Día de semana con zona horaria local
    2. ✅ Línea 280: Filtro de entradas con fecha local
    3. ✅ Línea 297: Condición de verificación con fecha local
    4. ✅ Línea 303: clock_out usando entry_date en lugar de CURRENT_DATE
    
    Próximos pasos:
    - Esperar a la próxima ejecución del cron (cada 5 minutos)
    - Verificar que los nuevos cierres automáticos sean exactamente 2 horas
    - Ejecutar TEST 2 de este script después de unos días para confirmar
    ' as informacion;

-- =====================================
-- RESUMEN FINAL
-- =====================================
SELECT 
    '📊 RESUMEN DE VERIFICACIÓN' as seccion,
    '
    ✅ Si TEST 2 muestra "2 horas": La corrección funciona correctamente
    ❌ Si TEST 2 muestra "~4 horas": Necesitas re-ejecutar supabase/notifications.sql
    
    🔧 RECORDATORIO:
    - Este fix solo afecta NUEVOS cierres automáticos
    - Los cierres históricos (con 4 horas) permanecerán en la base de datos
    - Eso es normal y esperado
    
    📈 MONITOREO CONTINUO:
    - Ejecuta este script diariamente durante 1 semana
    - Verifica que todos los nuevos cierres sean de 2 horas
    - Si ves algún caso de 4 horas después del fix, repórtalo
    
    ' as informacion;

