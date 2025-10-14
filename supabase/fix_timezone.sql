-- =====================================================
-- FIX: CORREGIR TIMEZONE EN NOTIFICACIONES
-- =====================================================
-- Problema: Las funciones usan CURRENT_TIME en UTC
-- Solución: Usar timezone de Europa/Madrid
-- =====================================================

-- =====================================================
-- 1. FUNCIÓN CORREGIDA: Recordatorios de ENTRADA
-- =====================================================

CREATE OR REPLACE FUNCTION get_employees_needing_clock_in_reminder()
RETURNS TABLE (
    employee_id UUID,
    employee_name VARCHAR(255),
    employee_email VARCHAR(255),
    expected_clock_in TIME,
    minutes_late INTEGER,
    department_name VARCHAR(100)
) 
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    RETURN QUERY
    WITH employee_schedules AS (
        SELECT 
            e.id as emp_id,
            e.full_name,
            e.email,
            d.name as dept_name,
            ds.start_time,
            ds.day_of_week,
            ds.is_working_day
        FROM employees e
        LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
        LEFT JOIN departments d ON e.department_id = d.id
        WHERE e.is_active = true
        AND ds.is_working_day = true
        AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
    ),
    todays_entries AS (
        SELECT 
            te.employee_id,
            te.clock_in
        FROM time_entries te
        WHERE te.date = CURRENT_DATE
    ),
    recent_notifications AS (
        SELECT 
            nl.employee_id,
            MAX(nl.sent_at) as last_sent
        FROM notification_logs nl
        WHERE nl.notification_type = 'clock_in_reminder'
        AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.start_time,
        (EXTRACT(EPOCH FROM ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time - es.start_time)) / 60)::INTEGER AS minutes_late,
        es.dept_name
    FROM employee_schedules es
    LEFT JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        -- No ha fichado hoy
        te.clock_in IS NULL
        -- Han pasado más de 5 minutos desde la hora esperada (en hora de Madrid)
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time > (es.start_time + INTERVAL '5 minutes')
        -- No se ha enviado notificación en las últimas 2 horas (evitar spam)
        AND (rn.last_sent IS NULL OR rn.last_sent < (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid') - INTERVAL '2 hours')
        -- Estamos dentro del horario laboral (hora de Madrid)
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time >= '06:00:00'
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time <= '23:00:00';
END;
$$;

-- =====================================================
-- 2. FUNCIÓN CORREGIDA: Recordatorios de SALIDA
-- =====================================================

CREATE OR REPLACE FUNCTION get_employees_needing_clock_out_reminder()
RETURNS TABLE (
    employee_id UUID,
    employee_name VARCHAR(255),
    employee_email VARCHAR(255),
    expected_clock_out TIME,
    minutes_late INTEGER,
    clock_in_time TIMESTAMP WITH TIME ZONE,
    department_name VARCHAR(100)
) 
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    RETURN QUERY
    WITH employee_schedules AS (
        SELECT 
            e.id as emp_id,
            e.full_name,
            e.email,
            d.name as dept_name,
            ds.end_time,
            ds.day_of_week,
            ds.is_working_day
        FROM employees e
        LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
        LEFT JOIN departments d ON e.department_id = d.id
        WHERE e.is_active = true
        AND ds.is_working_day = true
        AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
    ),
    todays_entries AS (
        SELECT 
            te.employee_id,
            te.clock_in,
            te.clock_out
        FROM time_entries te
        WHERE te.date = CURRENT_DATE
    ),
    recent_notifications AS (
        SELECT 
            nl.employee_id,
            MAX(nl.sent_at) as last_sent
        FROM notification_logs nl
        WHERE nl.notification_type = 'clock_out_reminder'
        AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.end_time,
        (EXTRACT(EPOCH FROM ((CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time - es.end_time)) / 60)::INTEGER AS minutes_late,
        te.clock_in,
        es.dept_name
    FROM employee_schedules es
    INNER JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        -- Ha fichado entrada pero no salida
        te.clock_in IS NOT NULL
        AND te.clock_out IS NULL
        -- Han pasado más de 5 minutos desde la hora esperada de salida (en hora de Madrid)
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time > (es.end_time + INTERVAL '5 minutes')
        -- No se ha enviado notificación en las últimas 2 horas (evitar spam)
        AND (rn.last_sent IS NULL OR rn.last_sent < (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid') - INTERVAL '2 hours')
        -- Estamos dentro del horario laboral (hora de Madrid)
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time >= '06:00:00'
        AND (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time <= '23:59:59';
END;
$$;

-- =====================================================
-- 3. VERIFICAR TIMEZONE
-- =====================================================

-- Ver la hora actual en diferentes zonas horarias
SELECT 
    CURRENT_TIMESTAMP as utc_timestamp,
    CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid' as madrid_timestamp,
    (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time as madrid_time_only,
    CURRENT_DATE as fecha_actual;

-- Ver configuración de timezone en company_settings
SELECT 
    company_name,
    timezone,
    created_at
FROM company_settings;

-- =====================================================
-- 4. PROBAR FUNCIÓN DE SALIDA AHORA
-- =====================================================

-- Esta query debería mostrar empleados si:
-- - Es después de las 18:05 hora de Madrid
-- - Han fichado entrada pero no salida
SELECT 
    employee_name,
    employee_email,
    expected_clock_out,
    minutes_late,
    department_name
FROM get_employees_needing_clock_out_reminder();

-- =====================================================
-- 5. PROBAR FUNCIÓN DE ENTRADA
-- =====================================================

SELECT 
    employee_name,
    employee_email,
    expected_clock_in,
    minutes_late,
    department_name
FROM get_employees_needing_clock_in_reminder();

-- =====================================================
-- COMENTARIOS
-- =====================================================

COMMENT ON FUNCTION get_employees_needing_clock_in_reminder() IS 
'Detecta empleados que necesitan recordatorio de entrada - USA TIMEZONE Europe/Madrid';

COMMENT ON FUNCTION get_employees_needing_clock_out_reminder() IS 
'Detecta empleados que necesitan recordatorio de salida - USA TIMEZONE Europe/Madrid';

-- =====================================================
-- RESUMEN DE CAMBIOS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Funciones actualizadas para usar timezone Europe/Madrid';
    RAISE NOTICE '✅ Ahora las notificaciones se enviarán en la hora correcta';
    RAISE NOTICE '⏰ Hora UTC en servidor:    %', CURRENT_TIME;
    RAISE NOTICE '⏰ Hora Madrid (España):    %', (CURRENT_TIMESTAMP AT TIME ZONE 'Europe/Madrid')::time;
    RAISE NOTICE '';
    RAISE NOTICE '📧 Las notificaciones de SALIDA se enviarán a las 18:05 hora de Madrid';
    RAISE NOTICE '📧 Las notificaciones de ENTRADA se enviarán según horario de cada departamento + 5 min';
END $$;

