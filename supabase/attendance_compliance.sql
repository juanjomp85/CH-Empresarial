-- ============================================
-- SISTEMA DE CUMPLIMIENTO DE HORARIOS
-- ============================================
-- Este script crea funciones y vistas para analizar el cumplimiento
-- de los horarios establecidos por departamento

-- ============================================
-- FUNCIÓN: Obtener horario esperado para un empleado en una fecha
-- ============================================
CREATE OR REPLACE FUNCTION get_expected_schedule(
    p_employee_id UUID,
    p_date DATE
)
RETURNS TABLE (
    day_of_week INTEGER,
    start_time TIME,
    end_time TIME,
    is_working_day BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ds.day_of_week,
        ds.start_time,
        ds.end_time,
        ds.is_working_day
    FROM employees e
    INNER JOIN department_schedules ds ON ds.department_id = e.department_id
    WHERE e.id = p_employee_id
    AND ds.day_of_week = EXTRACT(DOW FROM p_date)::INTEGER;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCIÓN: Calcular minutos de retraso/adelanto
-- ============================================
CREATE OR REPLACE FUNCTION calculate_time_difference_minutes(
    actual_time TIMESTAMP WITH TIME ZONE,
    expected_time TIME
)
RETURNS INTEGER AS $$
DECLARE
    actual_time_only TIME;
    diff_interval INTERVAL;
BEGIN
    actual_time_only := actual_time::TIME;
    diff_interval := actual_time_only - expected_time;
    RETURN EXTRACT(EPOCH FROM diff_interval)::INTEGER / 60;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- VISTA: Análisis de cumplimiento de horarios
-- ============================================
CREATE OR REPLACE VIEW attendance_compliance AS
SELECT 
    e.id AS employee_id,
    e.full_name AS employee_name,
    e.department_id,
    d.name AS department_name,
    te.date,
    te.clock_in,
    te.clock_out,
    te.total_hours,
    ds.start_time AS expected_start_time,
    ds.end_time AS expected_end_time,
    ds.is_working_day,
    
    -- Calcular si llegó tarde (en minutos)
    CASE 
        WHEN te.clock_in IS NOT NULL AND ds.is_working_day THEN
            EXTRACT(EPOCH FROM (te.clock_in::TIME - ds.start_time)) / 60
        ELSE NULL
    END AS arrival_delay_minutes,
    
    -- Calcular si salió temprano (en minutos negativos si salió antes)
    CASE 
        WHEN te.clock_out IS NOT NULL AND ds.is_working_day THEN
            EXTRACT(EPOCH FROM (te.clock_out::TIME - ds.end_time)) / 60
        ELSE NULL
    END AS departure_difference_minutes,
    
    -- Estado de puntualidad en entrada
    CASE 
        WHEN te.clock_in IS NULL AND ds.is_working_day THEN 'AUSENTE'
        WHEN NOT ds.is_working_day THEN 'DIA_NO_LABORAL'
        WHEN te.clock_in IS NOT NULL AND ds.is_working_day THEN
            CASE 
                WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - ds.start_time)) / 60 <= 0 THEN 'PUNTUAL'
                WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - ds.start_time)) / 60 <= 15 THEN 'RETRASO_LEVE'
                WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - ds.start_time)) / 60 <= 30 THEN 'RETRASO_MODERADO'
                ELSE 'RETRASO_GRAVE'
            END
        ELSE 'DESCONOCIDO'
    END AS arrival_status,
    
    -- Estado de cumplimiento en salida
    CASE 
        WHEN te.clock_out IS NULL AND ds.is_working_day AND te.clock_in IS NOT NULL THEN 'SIN_SALIDA_REGISTRADA'
        WHEN NOT ds.is_working_day THEN 'DIA_NO_LABORAL'
        WHEN te.clock_out IS NOT NULL AND ds.is_working_day THEN
            CASE 
                WHEN EXTRACT(EPOCH FROM (te.clock_out::TIME - ds.end_time)) / 60 < -30 THEN 'SALIDA_ANTICIPADA'
                WHEN EXTRACT(EPOCH FROM (te.clock_out::TIME - ds.end_time)) / 60 >= -30 AND 
                     EXTRACT(EPOCH FROM (te.clock_out::TIME - ds.end_time)) / 60 <= 30 THEN 'SALIDA_NORMAL'
                ELSE 'SALIDA_TARDIA'
            END
        ELSE 'DESCONOCIDO'
    END AS departure_status,
    
    -- Horas esperadas vs. horas trabajadas
    CASE 
        WHEN ds.is_working_day THEN
            EXTRACT(EPOCH FROM (ds.end_time - ds.start_time)) / 3600
        ELSE 0
    END AS expected_hours,
    
    -- Diferencia entre horas trabajadas y esperadas
    CASE 
        WHEN ds.is_working_day AND te.total_hours IS NOT NULL THEN
            te.total_hours - (EXTRACT(EPOCH FROM (ds.end_time - ds.start_time)) / 3600)
        ELSE NULL
    END AS hours_difference,
    
    te.created_at,
    te.updated_at

FROM employees e
INNER JOIN departments d ON d.id = e.department_id
INNER JOIN department_schedules ds ON ds.department_id = e.department_id
LEFT JOIN time_entries te ON te.employee_id = e.id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
WHERE e.is_active = true;

-- ============================================
-- VISTA: Resumen de cumplimiento por empleado
-- ============================================
CREATE OR REPLACE VIEW employee_compliance_summary AS
SELECT 
    employee_id,
    employee_name,
    department_id,
    department_name,
    COUNT(CASE WHEN arrival_status = 'PUNTUAL' THEN 1 END) AS punctual_days,
    COUNT(CASE WHEN arrival_status IN ('RETRASO_LEVE', 'RETRASO_MODERADO', 'RETRASO_GRAVE') THEN 1 END) AS late_days,
    COUNT(CASE WHEN arrival_status = 'AUSENTE' THEN 1 END) AS absent_days,
    COUNT(CASE WHEN is_working_day = true THEN 1 END) AS total_working_days,
    
    -- Porcentajes
    ROUND(
        (COUNT(CASE WHEN arrival_status = 'PUNTUAL' THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(CASE WHEN is_working_day = true THEN 1 END), 0) * 100), 2
    ) AS punctuality_percentage,
    
    ROUND(
        (COUNT(CASE WHEN arrival_status = 'AUSENTE' THEN 1 END)::NUMERIC / 
        NULLIF(COUNT(CASE WHEN is_working_day = true THEN 1 END), 0) * 100), 2
    ) AS absenteeism_percentage,
    
    -- Promedios
    ROUND(AVG(CASE WHEN arrival_delay_minutes > 0 THEN arrival_delay_minutes END), 2) AS avg_delay_minutes,
    ROUND(AVG(CASE WHEN is_working_day = true THEN total_hours END), 2) AS avg_hours_worked,
    ROUND(AVG(CASE WHEN is_working_day = true THEN expected_hours END), 2) AS avg_expected_hours,
    
    -- Totales
    SUM(CASE WHEN is_working_day = true THEN total_hours END) AS total_hours_worked,
    SUM(CASE WHEN is_working_day = true THEN expected_hours END) AS total_expected_hours

FROM attendance_compliance
GROUP BY employee_id, employee_name, department_id, department_name;

-- ============================================
-- FUNCIÓN: Obtener cumplimiento de un empleado en rango de fechas
-- ============================================
CREATE OR REPLACE FUNCTION get_employee_compliance(
    p_employee_id UUID,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS TABLE (
    date DATE,
    day_name TEXT,
    is_working_day BOOLEAN,
    expected_start_time TIME,
    expected_end_time TIME,
    clock_in TIMESTAMP WITH TIME ZONE,
    clock_out TIMESTAMP WITH TIME ZONE,
    total_hours NUMERIC,
    arrival_delay_minutes NUMERIC,
    arrival_status TEXT,
    departure_status TEXT,
    expected_hours NUMERIC,
    hours_difference NUMERIC
) AS $$
DECLARE
    v_end_date DATE;
BEGIN
    -- Limitar la fecha final a ayer (no incluir el día actual)
    -- Esto evita contar como ausencias días que aún están en curso
    v_end_date := LEAST(p_end_date, CURRENT_DATE - INTERVAL '1 day');
    
    RETURN QUERY
    WITH date_range AS (
        -- Generar todas las fechas del rango (hasta ayer como máximo)
        SELECT generate_series(
            p_start_date,
            v_end_date,
            '1 day'::INTERVAL
        )::DATE AS date_val
    ),
    employee_info AS (
        -- Obtener información del empleado
        SELECT 
            e.id,
            e.full_name,
            e.department_id
        FROM employees e
        WHERE e.id = p_employee_id
        AND e.is_active = true
    ),
    daily_schedule AS (
        -- Para cada fecha, obtener el horario esperado
        SELECT 
            dr.date_val AS date,
            ds.start_time,
            ds.end_time,
            ds.is_working_day,
            ds.day_of_week
        FROM date_range dr
        CROSS JOIN employee_info ei
        LEFT JOIN department_schedules ds 
            ON ds.department_id = ei.department_id
            AND ds.day_of_week = EXTRACT(DOW FROM dr.date_val)::INTEGER
    )
    SELECT 
        dsch.date,
        TO_CHAR(dsch.date, 'Day') AS day_name,
        COALESCE(dsch.is_working_day, false) AS is_working_day,
        dsch.start_time AS expected_start_time,
        dsch.end_time AS expected_end_time,
        te.clock_in,
        te.clock_out,
        te.total_hours,
        
        -- Calcular minutos de retraso
        CASE 
            WHEN te.clock_in IS NOT NULL AND dsch.is_working_day THEN
                EXTRACT(EPOCH FROM (te.clock_in::TIME - dsch.start_time)) / 60
            ELSE NULL
        END AS arrival_delay_minutes,
        
        -- Estado de llegada
        CASE 
            WHEN te.clock_in IS NULL AND dsch.is_working_day THEN 'AUSENTE'
            WHEN NOT dsch.is_working_day THEN 'DIA_NO_LABORAL'
            WHEN te.clock_in IS NOT NULL AND dsch.is_working_day THEN
                CASE 
                    WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - dsch.start_time)) / 60 <= 0 THEN 'PUNTUAL'
                    WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - dsch.start_time)) / 60 <= 15 THEN 'RETRASO_LEVE'
                    WHEN EXTRACT(EPOCH FROM (te.clock_in::TIME - dsch.start_time)) / 60 <= 30 THEN 'RETRASO_MODERADO'
                    ELSE 'RETRASO_GRAVE'
                END
            ELSE 'DESCONOCIDO'
        END AS arrival_status,
        
        -- Estado de salida
        CASE 
            WHEN te.clock_out IS NULL AND dsch.is_working_day AND te.clock_in IS NOT NULL THEN 'SIN_SALIDA_REGISTRADA'
            WHEN NOT dsch.is_working_day THEN 'DIA_NO_LABORAL'
            WHEN te.clock_out IS NOT NULL AND dsch.is_working_day THEN
                CASE 
                    WHEN EXTRACT(EPOCH FROM (te.clock_out::TIME - dsch.end_time)) / 60 < -30 THEN 'SALIDA_ANTICIPADA'
                    WHEN EXTRACT(EPOCH FROM (te.clock_out::TIME - dsch.end_time)) / 60 >= -30 AND 
                         EXTRACT(EPOCH FROM (te.clock_out::TIME - dsch.end_time)) / 60 <= 30 THEN 'SALIDA_NORMAL'
                    ELSE 'SALIDA_TARDIA'
                END
            ELSE 'DESCONOCIDO'
        END AS departure_status,
        
        -- Horas esperadas
        CASE 
            WHEN dsch.is_working_day THEN
                EXTRACT(EPOCH FROM (dsch.end_time - dsch.start_time)) / 3600
            ELSE 0
        END AS expected_hours,
        
        -- Diferencia de horas
        CASE 
            WHEN dsch.is_working_day AND te.total_hours IS NOT NULL THEN
                te.total_hours - (EXTRACT(EPOCH FROM (dsch.end_time - dsch.start_time)) / 3600)
            ELSE NULL
        END AS hours_difference
        
    FROM daily_schedule dsch
    LEFT JOIN time_entries te 
        ON te.employee_id = p_employee_id
        AND te.date = dsch.date
    ORDER BY dsch.date DESC;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- FUNCIÓN: Obtener resumen mensual de cumplimiento
-- ============================================
CREATE OR REPLACE FUNCTION get_monthly_compliance_summary(
    p_employee_id UUID,
    p_month INTEGER,
    p_year INTEGER
)
RETURNS TABLE (
    total_working_days INTEGER,
    punctual_days INTEGER,
    late_days INTEGER,
    absent_days INTEGER,
    punctuality_percentage NUMERIC,
    absenteeism_percentage NUMERIC,
    avg_delay_minutes NUMERIC,
    total_hours_worked NUMERIC,
    total_expected_hours NUMERIC,
    hours_difference NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(CASE WHEN is_working_day = true THEN 1 END)::INTEGER AS total_working_days,
        COUNT(CASE WHEN arrival_status = 'PUNTUAL' THEN 1 END)::INTEGER AS punctual_days,
        COUNT(CASE WHEN arrival_status IN ('RETRASO_LEVE', 'RETRASO_MODERADO', 'RETRASO_GRAVE') THEN 1 END)::INTEGER AS late_days,
        COUNT(CASE WHEN arrival_status = 'AUSENTE' THEN 1 END)::INTEGER AS absent_days,
        ROUND(
            (COUNT(CASE WHEN arrival_status = 'PUNTUAL' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN is_working_day = true THEN 1 END), 0) * 100), 2
        ) AS punctuality_percentage,
        ROUND(
            (COUNT(CASE WHEN arrival_status = 'AUSENTE' THEN 1 END)::NUMERIC / 
            NULLIF(COUNT(CASE WHEN is_working_day = true THEN 1 END), 0) * 100), 2
        ) AS absenteeism_percentage,
        ROUND(AVG(CASE WHEN ac.arrival_delay_minutes > 0 THEN ac.arrival_delay_minutes END), 2) AS avg_delay_minutes,
        ROUND(SUM(CASE WHEN is_working_day = true THEN ac.total_hours END), 2) AS total_hours_worked,
        ROUND(SUM(CASE WHEN is_working_day = true THEN ac.expected_hours END), 2) AS total_expected_hours,
        ROUND(
            SUM(CASE WHEN is_working_day = true THEN ac.total_hours END) - 
            SUM(CASE WHEN is_working_day = true THEN ac.expected_hours END), 2
        ) AS hours_difference
    FROM attendance_compliance ac
    WHERE ac.employee_id = p_employee_id
    AND EXTRACT(MONTH FROM ac.date) = p_month
    AND EXTRACT(YEAR FROM ac.date) = p_year;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- POLÍTICAS RLS para las vistas
-- ============================================

-- Eliminar políticas existentes si existen
DROP POLICY IF EXISTS "Employees can view their own compliance" ON time_entries;
DROP POLICY IF EXISTS "Admins can view all compliance" ON time_entries;

-- Los empleados pueden ver su propio cumplimiento
CREATE POLICY "Employees can view their own compliance" ON time_entries
    FOR SELECT USING (
        employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
    );

-- Los administradores pueden ver todo
CREATE POLICY "Admins can view all compliance" ON time_entries
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- ============================================
-- ÍNDICES para mejorar rendimiento
-- ============================================
CREATE INDEX IF NOT EXISTS idx_time_entries_employee_date ON time_entries(employee_id, date);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_department_schedules_dept_day ON department_schedules(department_id, day_of_week);

-- ============================================
-- COMENTARIOS para documentación
-- ============================================
COMMENT ON VIEW attendance_compliance IS 'Vista que analiza el cumplimiento de horarios comparando registros de tiempo con horarios de departamento';
COMMENT ON VIEW employee_compliance_summary IS 'Resumen agregado de cumplimiento por empleado con métricas y porcentajes';
COMMENT ON FUNCTION get_employee_compliance IS 'Obtiene el detalle de cumplimiento de un empleado en un rango de fechas';
COMMENT ON FUNCTION get_monthly_compliance_summary IS 'Obtiene resumen mensual de cumplimiento de un empleado con métricas agregadas';
