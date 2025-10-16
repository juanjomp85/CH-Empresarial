-- =====================================================
-- SISTEMA DE NOTIFICACIONES POR CORREO ELECTRÓNICO
-- =====================================================
-- Este script crea el sistema de notificaciones automáticas
-- para recordar a los empleados fichar entrada/salida

-- Configurar zona horaria para las funciones de notificaciones
-- Esto asegura que CURRENT_TIME use la zona horaria de España
SET timezone = 'Europe/Madrid';

-- Tabla para registrar notificaciones enviadas
CREATE TABLE IF NOT EXISTS notification_logs (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    notification_type VARCHAR(50) NOT NULL, -- 'clock_in_reminder', 'clock_out_reminder'
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    email_sent_to VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'sent', -- 'sent', 'failed'
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_notification_logs_employee ON notification_logs(employee_id);
CREATE INDEX IF NOT EXISTS idx_notification_logs_sent_at ON notification_logs(sent_at);
CREATE INDEX IF NOT EXISTS idx_notification_logs_type ON notification_logs(notification_type);

-- =====================================================
-- FUNCIÓN: Detectar empleados que necesitan recordatorios de entrada
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
        AND DATE(nl.sent_at) = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.start_time,
        (EXTRACT(EPOCH FROM ((NOW() AT TIME ZONE 'Europe/Madrid')::TIME - es.start_time)) / 60)::INTEGER AS minutes_late,
        es.dept_name
    FROM employee_schedules es
    LEFT JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        -- No ha fichado hoy
        te.clock_in IS NULL
        -- Enviar notificación exactamente a las 5 minutos después de la hora de entrada
        -- Usar NOW() AT TIME ZONE 'Europe/Madrid' para asegurar zona horaria correcta
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.start_time + INTERVAL '5 minutes')
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME < (es.start_time + INTERVAL '6 minutes')
        -- No se ha enviado notificación hoy para este empleado
        AND (rn.last_sent IS NULL OR DATE(rn.last_sent) < CURRENT_DATE)
        -- Estamos dentro del horario laboral (no enviar notificaciones de madrugada)
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= '06:00:00'
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME <= '23:00:00';
END;
$$;

-- =====================================================
-- FUNCIÓN: Detectar empleados que necesitan recordatorios de salida
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
        AND DATE(nl.sent_at) = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.end_time,
        (EXTRACT(EPOCH FROM ((NOW() AT TIME ZONE 'Europe/Madrid')::TIME - es.end_time)) / 60)::INTEGER AS minutes_late,
        te.clock_in,
        es.dept_name
    FROM employee_schedules es
    INNER JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        -- Ha fichado entrada pero no salida
        te.clock_in IS NOT NULL
        AND te.clock_out IS NULL
        -- Enviar notificación exactamente a las 5 minutos después de la hora de salida
        -- Usar NOW() AT TIME ZONE 'Europe/Madrid' para asegurar zona horaria correcta
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.end_time + INTERVAL '5 minutes')
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME < (es.end_time + INTERVAL '6 minutes')
        -- No se ha enviado notificación hoy para este empleado
        AND (rn.last_sent IS NULL OR DATE(rn.last_sent) < CURRENT_DATE)
        -- Estamos dentro del horario laboral
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= '06:00:00'
        AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME <= '23:59:59';
END;
$$;

-- =====================================================
-- FUNCIÓN: Registrar notificación enviada
-- =====================================================
CREATE OR REPLACE FUNCTION log_notification(
    p_employee_id UUID,
    p_notification_type VARCHAR(50),
    p_email VARCHAR(255),
    p_status VARCHAR(20) DEFAULT 'sent',
    p_error_message TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
AS $$
DECLARE
    v_log_id UUID;
BEGIN
    INSERT INTO notification_logs (
        employee_id,
        notification_type,
        email_sent_to,
        status,
        error_message
    ) VALUES (
        p_employee_id,
        p_notification_type,
        p_email,
        p_status,
        p_error_message
    )
    RETURNING id INTO v_log_id;
    
    RETURN v_log_id;
END;
$$;

-- =====================================================
-- POLÍTICA DE SEGURIDAD (RLS)
-- =====================================================
ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;

-- Eliminar políticas existentes si existen
DROP POLICY IF EXISTS "Admins can view all notification logs" ON notification_logs;
DROP POLICY IF EXISTS "Employees can view own notification logs" ON notification_logs;

-- Los administradores pueden ver todos los logs
CREATE POLICY "Admins can view all notification logs"
    ON notification_logs FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM employees
            WHERE employees.user_id = auth.uid()
            AND employees.role = 'admin'
        )
    );

-- Los empleados solo pueden ver sus propios logs
CREATE POLICY "Employees can view own notification logs"
    ON notification_logs FOR SELECT
    USING (
        employee_id IN (
            SELECT id FROM employees
            WHERE user_id = auth.uid()
        )
    );

-- =====================================================
-- FUNCIÓN: Generar automáticamente registro de salida
-- =====================================================
CREATE OR REPLACE FUNCTION auto_generate_clock_out()
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
DECLARE
    auto_clock_outs_count INTEGER := 0;
    employee_record RECORD;
BEGIN
    -- Obtener empleados que necesitan auto-registro de salida
    -- (2 horas después de su hora de salida programada, sin haber fichado salida)
    FOR employee_record IN
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
        )
        SELECT 
            es.emp_id as employee_id,
            es.full_name,
            es.end_time as expected_clock_out,
            te.clock_in
        FROM employee_schedules es
        INNER JOIN todays_entries te ON es.emp_id = te.employee_id
        WHERE 
            -- Ha fichado entrada pero no salida
            te.clock_in IS NOT NULL
            AND te.clock_out IS NULL
            -- Han pasado 2 horas desde la hora de salida programada
            AND (NOW() AT TIME ZONE 'Europe/Madrid')::TIME >= (es.end_time + INTERVAL '2 hours')
    LOOP
        -- Generar automáticamente el registro de salida
        UPDATE time_entries 
        SET 
            clock_out = CURRENT_DATE + employee_record.expected_clock_out + INTERVAL '2 hours',
            updated_at = NOW()
        WHERE 
            employee_id = employee_record.employee_id 
            AND date = CURRENT_DATE
            AND clock_out IS NULL;
            
        -- Registrar en el log de notificaciones
        INSERT INTO notification_logs (
            employee_id,
            notification_type,
            email_sent_to,
            status
        ) VALUES (
            employee_record.employee_id,
            'auto_clock_out',
            employee_record.full_name,
            'generated'
        );
        
        auto_clock_outs_count := auto_clock_outs_count + 1;
    END LOOP;
    
    RETURN auto_clock_outs_count;
END;
$$;

-- =====================================================
-- COMENTARIOS
-- =====================================================
COMMENT ON TABLE notification_logs IS 'Registro de notificaciones enviadas a empleados';
COMMENT ON FUNCTION get_employees_needing_clock_in_reminder() IS 'Obtiene la lista de empleados que necesitan recordatorio de entrada';
COMMENT ON FUNCTION get_employees_needing_clock_out_reminder() IS 'Obtiene la lista de empleados que necesitan recordatorio de salida';
COMMENT ON FUNCTION log_notification IS 'Registra una notificación enviada en el log';
COMMENT ON FUNCTION auto_generate_clock_out IS 'Genera automáticamente registros de salida 2 horas después de la hora programada';

