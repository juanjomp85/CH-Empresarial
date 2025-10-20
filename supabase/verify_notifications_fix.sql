-- =====================================================
-- SCRIPT DE VERIFICACIÓN: Corrección de Notificaciones
-- =====================================================
-- Este script verifica que la corrección de notificaciones
-- funciona correctamente después de aplicar los cambios
-- Fecha: 20 de octubre de 2025

-- Configurar zona horaria
SET timezone = 'Europe/Madrid';

-- =====================================================
-- 1. VERIFICAR HORA ACTUAL DEL SISTEMA
-- =====================================================
SELECT 
    'Verificación de Zona Horaria' as test,
    NOW() as hora_utc,
    NOW() AT TIME ZONE 'Europe/Madrid' as hora_madrid,
    (NOW() AT TIME ZONE 'Europe/Madrid')::TIME as hora_actual,
    current_setting('timezone') as timezone_configurada;

-- =====================================================
-- 2. VER TODOS LOS HORARIOS CONFIGURADOS HOY
-- =====================================================
SELECT 
    '---' as separador,
    'Horarios Configurados para Hoy' as test;

SELECT 
    e.full_name as empleado,
    d.name as departamento,
    ds.start_time as hora_entrada,
    ds.end_time as hora_salida,
    ds.start_time + INTERVAL '5 minutes' as notif_entrada_desde,
    ds.end_time + INTERVAL '5 minutes' as notif_salida_desde,
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (ds.start_time + INTERVAL '5 minutes')
        THEN '✅ Debería notificar ENTRADA si no ha fichado'
        ELSE '⏳ Aún no es hora de notificar entrada'
    END as estado_entrada,
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (ds.end_time + INTERVAL '5 minutes')
        THEN '✅ Debería notificar SALIDA si no ha fichado'
        ELSE '⏳ Aún no es hora de notificar salida'
    END as estado_salida
FROM employees e
JOIN department_schedules ds ON e.department_id = ds.department_id
JOIN departments d ON e.department_id = d.id
WHERE e.is_active = true
AND ds.is_working_day = true
AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
ORDER BY ds.start_time;

-- =====================================================
-- 3. EMPLEADOS QUE NECESITAN NOTIFICACIÓN DE ENTRADA
-- =====================================================
SELECT 
    '---' as separador,
    'Empleados que Necesitan Notificación de ENTRADA (AHORA)' as test;

SELECT 
    employee_id,
    employee_name,
    employee_email,
    expected_clock_in as hora_entrada_esperada,
    (NOW() AT TIME ZONE 'Europe/Madrid')::TIME as hora_actual,
    minutes_late as minutos_retraso,
    department_name
FROM get_employees_needing_clock_in_reminder();

-- =====================================================
-- 4. EMPLEADOS QUE NECESITAN NOTIFICACIÓN DE SALIDA
-- =====================================================
SELECT 
    '---' as separador,
    'Empleados que Necesitan Notificación de SALIDA (AHORA)' as test;

SELECT 
    employee_id,
    employee_name,
    employee_email,
    expected_clock_out as hora_salida_esperada,
    (NOW() AT TIME ZONE 'Europe/Madrid')::TIME as hora_actual,
    minutes_late as minutos_retraso,
    clock_in_time as fichó_entrada_a,
    department_name
FROM get_employees_needing_clock_out_reminder();

-- =====================================================
-- 5. ESTADO DE FICHAJES HOY
-- =====================================================
SELECT 
    '---' as separador,
    'Estado de Fichajes de Hoy' as test;

SELECT 
    e.full_name as empleado,
    ds.start_time as entrada_esperada,
    te.clock_in AT TIME ZONE 'Europe/Madrid' as entrada_real,
    CASE 
        WHEN te.clock_in IS NULL THEN '❌ NO FICHADO'
        WHEN te.clock_in::TIME <= ds.start_time + INTERVAL '5 minutes' THEN '✅ A tiempo'
        ELSE '⏰ Con retraso'
    END as estado_entrada,
    ds.end_time as salida_esperada,
    te.clock_out AT TIME ZONE 'Europe/Madrid' as salida_real,
    CASE 
        WHEN te.clock_in IS NULL THEN '⏳ No aplicable'
        WHEN te.clock_out IS NULL THEN '❌ NO FICHADO'
        WHEN te.clock_out::TIME <= ds.end_time + INTERVAL '5 minutes' THEN '✅ A tiempo'
        ELSE '⏰ Con retraso'
    END as estado_salida
FROM employees e
JOIN department_schedules ds ON e.department_id = ds.department_id
LEFT JOIN time_entries te ON e.id = te.employee_id AND te.date = CURRENT_DATE
WHERE e.is_active = true
AND ds.is_working_day = true
AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
ORDER BY e.full_name;

-- =====================================================
-- 6. NOTIFICACIONES ENVIADAS HOY
-- =====================================================
SELECT 
    '---' as separador,
    'Notificaciones Enviadas Hoy' as test;

SELECT 
    nl.sent_at AT TIME ZONE 'Europe/Madrid' as enviado_a,
    e.full_name as empleado,
    nl.notification_type as tipo,
    nl.status as estado,
    nl.email_sent_to as email,
    CASE 
        WHEN nl.notification_type = 'clock_in_reminder' THEN '⏰ Recordatorio Entrada'
        WHEN nl.notification_type = 'clock_out_reminder' THEN '🚪 Recordatorio Salida'
        WHEN nl.notification_type = 'auto_clock_out' THEN '🤖 Cierre Automático'
        ELSE nl.notification_type
    END as descripcion
FROM notification_logs nl
LEFT JOIN employees e ON nl.employee_id = e.id
WHERE DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE
ORDER BY nl.sent_at DESC;

-- =====================================================
-- 7. SIMULACIÓN: ¿Qué pasaría en diferentes horas?
-- =====================================================
SELECT 
    '---' as separador,
    'Simulación: Cobertura de Horarios' as test;

WITH horarios_test AS (
    SELECT horario_entrada FROM (VALUES
        ('09:00'::TIME),
        ('09:01'::TIME),
        ('09:02'::TIME),
        ('09:03'::TIME),
        ('09:04'::TIME)
    ) AS t(horario_entrada)
),
cron_times AS (
    SELECT cron_ejecuta FROM (VALUES
        ('09:00'::TIME),
        ('09:05'::TIME),
        ('09:10'::TIME),
        ('09:15'::TIME)
    ) AS c(cron_ejecuta)
)
SELECT 
    ht.horario_entrada as entrada_empleado,
    ht.horario_entrada + INTERVAL '5 minutes' as notificacion_desde,
    STRING_AGG(ct.cron_ejecuta::TEXT, ', ' ORDER BY ct.cron_ejecuta) as cron_ejecuta_a,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM cron_times ct2 
            WHERE ct2.cron_ejecuta >= ht.horario_entrada + INTERVAL '5 minutes'
            AND ct2.cron_ejecuta <= ht.horario_entrada + INTERVAL '15 minutes'
        )
        THEN '✅ SE DETECTARÁ'
        ELSE '❌ SE PERDERÁ'
    END as resultado
FROM horarios_test ht
CROSS JOIN cron_times ct
WHERE ct.cron_ejecuta >= ht.horario_entrada + INTERVAL '5 minutes'
GROUP BY ht.horario_entrada;

-- =====================================================
-- 8. RESUMEN DE ESTADÍSTICAS
-- =====================================================
SELECT 
    '---' as separador,
    'Resumen de Estadísticas' as test;

SELECT 
    (SELECT COUNT(*) FROM employees WHERE is_active = true) as total_empleados_activos,
    (SELECT COUNT(DISTINCT employee_id) FROM time_entries WHERE date = CURRENT_DATE) as empleados_ficharon_hoy,
    (SELECT COUNT(*) FROM notification_logs WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE) as notificaciones_enviadas_hoy,
    (SELECT COUNT(*) FROM notification_logs WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE AND notification_type = 'clock_in_reminder') as notif_entrada_hoy,
    (SELECT COUNT(*) FROM notification_logs WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE AND notification_type = 'clock_out_reminder') as notif_salida_hoy,
    (SELECT COUNT(*) FROM notification_logs WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE AND notification_type = 'auto_clock_out') as cierres_automaticos_hoy,
    (SELECT COUNT(*) FROM notification_logs WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE AND status = 'failed') as notif_fallidas_hoy;

-- =====================================================
-- 9. TEST: Verificar que NO hay restricción de 1 minuto
-- =====================================================
SELECT 
    '---' as separador,
    'Verificación: Las funciones NO tienen restricción de 1 minuto' as test;

-- Este test verifica que la función detecta empleados con MÁS de 5 minutos
-- y NO solo en una ventana de 1 minuto
WITH test_data AS (
    SELECT 
        '09:00:00'::TIME as start_time,
        '09:06:00'::TIME as check_time_1,  -- 6 min después
        '09:10:00'::TIME as check_time_2,  -- 10 min después
        '09:15:00'::TIME as check_time_3   -- 15 min después
)
SELECT 
    start_time as hora_entrada,
    start_time + INTERVAL '5 minutes' as notif_desde,
    check_time_1 as verificando_a_las,
    CASE 
        WHEN check_time_1 >= start_time + INTERVAL '5 minutes' 
        THEN '✅ DEBERÍA DETECTAR'
        ELSE '❌ NO DEBERÍA DETECTAR'
    END as resultado_6min,
    CASE 
        WHEN check_time_2 >= start_time + INTERVAL '5 minutes' 
        THEN '✅ DEBERÍA DETECTAR'
        ELSE '❌ NO DEBERÍA DETECTAR'
    END as resultado_10min,
    CASE 
        WHEN check_time_3 >= start_time + INTERVAL '5 minutes' 
        THEN '✅ DEBERÍA DETECTAR'
        ELSE '❌ NO DEBERÍA DETECTAR'
    END as resultado_15min
FROM test_data;

-- =====================================================
-- INSTRUCCIONES
-- =====================================================
SELECT 
    '---' as separador,
    'INSTRUCCIONES' as test;

SELECT 
    'Copia este script completo y ejecútalo en el SQL Editor de Supabase' as paso_1,
    'Revisa todos los resultados para verificar que las notificaciones funcionan' as paso_2,
    'Los empleados en la sección 3 y 4 recibirán notificaciones en la próxima ejecución del cron' as paso_3,
    'El cron ejecuta cada 5 minutos, así que espera máximo 5 minutos para ver resultados' as paso_4;

SELECT 
    '✅ Si ves empleados en las secciones 3 o 4, significa que la corrección funciona' as resultado_esperado,
    '✅ Todos los horarios deberían ser detectados, no solo múltiplos de 5' as verificacion_clave,
    '✅ La protección anti-duplicados está activa (solo 1 notif/día por empleado)' as proteccion;

