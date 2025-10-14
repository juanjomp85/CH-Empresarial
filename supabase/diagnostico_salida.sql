-- =====================================================
-- DIAGNÓSTICO: ¿Por qué no se envían correos de salida?
-- =====================================================

-- 1️⃣ Ver la hora actual del servidor
SELECT 
    CURRENT_DATE as fecha_hoy,
    CURRENT_TIME as hora_actual,
    EXTRACT(DOW FROM CURRENT_DATE) as dia_semana_numero;

-- 2️⃣ Ver empleados que ficharon entrada hoy pero no salida
SELECT 
    e.full_name as nombre,
    e.email,
    e.department_id,
    te.clock_in as entrada,
    te.clock_out as salida,
    te.date as fecha
FROM employees e
INNER JOIN time_entries te ON e.id = te.employee_id
WHERE te.date = CURRENT_DATE
AND te.clock_in IS NOT NULL
AND te.clock_out IS NULL
ORDER BY te.clock_in;

-- 3️⃣ Ver horarios de salida configurados para HOY
SELECT 
    d.name as departamento,
    ds.end_time as hora_salida_esperada,
    ds.day_of_week as dia_semana,
    ds.is_working_day as es_dia_laboral,
    COUNT(e.id) as num_empleados
FROM department_schedules ds
INNER JOIN departments d ON ds.department_id = d.id
LEFT JOIN employees e ON e.department_id = d.id AND e.is_active = true
WHERE ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
AND ds.is_working_day = true
GROUP BY d.name, ds.end_time, ds.day_of_week, ds.is_working_day
ORDER BY ds.end_time;

-- 4️⃣ Ver si ya pasaron 5 minutos de la hora de salida
SELECT 
    d.name as departamento,
    ds.end_time as hora_salida,
    CURRENT_TIME as hora_actual,
    (ds.end_time + INTERVAL '5 minutes') as hora_limite,
    CASE 
        WHEN CURRENT_TIME > (ds.end_time + INTERVAL '5 minutes') THEN '✅ Ya pasaron 5 min'
        ELSE '❌ Aún no pasan 5 min'
    END as deberia_enviar
FROM department_schedules ds
INNER JOIN departments d ON ds.department_id = d.id
WHERE ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
AND ds.is_working_day = true
ORDER BY ds.end_time;

-- 5️⃣ Ver empleados que deberían recibir recordatorio AHORA
-- (Esta es la query que usa el sistema)
SELECT * FROM get_employees_needing_clock_out_reminder();

-- 6️⃣ Ver notificaciones de salida enviadas HOY
SELECT 
    e.full_name as nombre,
    nl.email_sent_to as email,
    nl.notification_type as tipo,
    nl.sent_at as enviado_a_las,
    nl.status as estado,
    nl.error_message as error
FROM notification_logs nl
LEFT JOIN employees e ON nl.employee_id = e.id
WHERE nl.notification_type = 'clock_out_reminder'
AND DATE(nl.sent_at) = CURRENT_DATE
ORDER BY nl.sent_at DESC;

-- 7️⃣ Ver empleados activos SIN departamento asignado
-- (No pueden recibir notificaciones si no tienen horario)
SELECT 
    e.full_name as nombre,
    e.email,
    e.department_id,
    e.is_active
FROM employees e
WHERE e.is_active = true
AND e.department_id IS NULL;

-- =====================================================
-- RESUMEN DE POSIBLES PROBLEMAS
-- =====================================================
/*
❌ PROBLEMA 1: Hora de salida no ha pasado
   - Mira la Query 4: "deberia_enviar"
   - Si dice "Aún no pasan 5 min", espera a que pase la hora

❌ PROBLEMA 2: Empleados sin departamento
   - Query 7 muestra empleados sin departamento
   - Solución: Asignar departamento a cada empleado

❌ PROBLEMA 3: No hay horario configurado para hoy
   - Query 3 muestra horarios por departamento
   - Si está vacía, no hay horarios configurados

❌ PROBLEMA 4: Empleado ya fichó salida
   - Query 2 muestra solo quienes NO ficharon salida
   - Si está vacía, todos ya ficharon

❌ PROBLEMA 5: Cron job no se está ejecutando
   - Query 6 muestra las últimas notificaciones
   - Si nunca ha habido ninguna, el cron no funciona

✅ TODO OK: Query 5 debería mostrar empleados
   - Si Query 5 muestra empleados, el sistema funcionará
   - El cron job enviará el correo en los próximos 5 minutos
*/

