-- =====================================================
-- FIX: SOLUCIONAR WARNINGS DE SEGURIDAD DE SUPABASE
-- =====================================================
-- Este script soluciona los warnings del Database Linter
-- relacionados con search_path mutable en funciones

-- =====================================================
-- ¿QUÉ ES EL PROBLEMA DEL SEARCH_PATH?
-- =====================================================
/*
Cuando una función no tiene un search_path explícito, puede
ser vulnerable a ataques de inyección SQL si un usuario
malicioso manipula el search_path de la sesión.

SOLUCIÓN: Añadir "SET search_path = public, pg_catalog"
a todas las funciones SECURITY DEFINER
*/

-- =====================================================
-- 1. FUNCIÓN: handle_new_user (Trigger de registro)
-- =====================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER 
LANGUAGE plpgsql 
SECURITY DEFINER 
SET search_path = public, pg_catalog
AS $$
BEGIN
  INSERT INTO public.employees (
    user_id,
    email,
    full_name,
    role,
    is_active,
    department_id,
    position_id,
    hourly_rate
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
    'employee',
    true,
    NULL,
    NULL,
    0
  )
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$;

-- =====================================================
-- 2. FUNCIÓN: is_admin
-- =====================================================

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN 
LANGUAGE plpgsql 
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM employees 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
    AND is_active = true
  );
END;
$$;

-- =====================================================
-- 3. FUNCIÓN: update_updated_at_column
-- =====================================================

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

-- =====================================================
-- 4. FUNCIÓN: calculate_total_hours
-- =====================================================

CREATE OR REPLACE FUNCTION public.calculate_total_hours()
RETURNS TRIGGER 
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NEW.clock_out IS NOT NULL THEN
        -- Calcular horas totales
        NEW.total_hours := EXTRACT(EPOCH FROM (NEW.clock_out - NEW.clock_in)) / 3600;
        
        -- Si hubo descanso, restar ese tiempo
        IF NEW.break_start IS NOT NULL AND NEW.break_end IS NOT NULL THEN
            NEW.total_hours := NEW.total_hours - 
                (EXTRACT(EPOCH FROM (NEW.break_end - NEW.break_start)) / 3600);
        END IF;
        
        -- Calcular horas extras (más de 8 horas)
        IF NEW.total_hours > 8 THEN
            NEW.overtime_hours := NEW.total_hours - 8;
        ELSE
            NEW.overtime_hours := 0;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- =====================================================
-- 5. FUNCIÓN: get_employees_needing_clock_in_reminder
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
        AND DATE(nl.sent_at) = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.start_time,
        (EXTRACT(EPOCH FROM (CURRENT_TIME - es.start_time)) / 60)::INTEGER AS minutes_late,
        es.dept_name
    FROM employee_schedules es
    LEFT JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        te.clock_in IS NULL
        AND CURRENT_TIME > (es.start_time + INTERVAL '5 minutes')
        AND (rn.last_sent IS NULL OR rn.last_sent < NOW() - INTERVAL '2 hours')
        AND CURRENT_TIME >= '06:00:00'
        AND CURRENT_TIME <= '23:00:00';
END;
$$;

-- =====================================================
-- 6. FUNCIÓN: get_employees_needing_clock_out_reminder
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
        AND DATE(nl.sent_at) = CURRENT_DATE
        GROUP BY nl.employee_id
    )
    SELECT 
        es.emp_id,
        es.full_name,
        es.email,
        es.end_time,
        (EXTRACT(EPOCH FROM (CURRENT_TIME - es.end_time)) / 60)::INTEGER AS minutes_late,
        te.clock_in,
        es.dept_name
    FROM employee_schedules es
    INNER JOIN todays_entries te ON es.emp_id = te.employee_id
    LEFT JOIN recent_notifications rn ON es.emp_id = rn.employee_id
    WHERE 
        te.clock_in IS NOT NULL
        AND te.clock_out IS NULL
        AND CURRENT_TIME > (es.end_time + INTERVAL '5 minutes')
        AND (rn.last_sent IS NULL OR rn.last_sent < NOW() - INTERVAL '2 hours')
        AND CURRENT_TIME >= '06:00:00'
        AND CURRENT_TIME <= '23:59:59';
END;
$$;

-- =====================================================
-- 7. FUNCIÓN: log_notification
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
SET search_path = public, pg_catalog
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
-- NOTA: Las siguientes funciones requieren revisar
-- su implementación completa. Si no existen aún,
-- puedes omitir estas secciones.
-- =====================================================

-- Si tienes estas funciones, añádeles también el search_path:
-- - update_user_role
-- - get_expected_schedule
-- - calculate_time_difference_minutes
-- - get_employee_compliance
-- - get_monthly_compliance_summary

-- =====================================================
-- VERIFICAR FUNCIONES CORREGIDAS
-- =====================================================

-- Ver todas las funciones y su search_path
SELECT 
    n.nspname as schema,
    p.proname as function_name,
    pg_get_function_arguments(p.oid) as arguments,
    CASE 
        WHEN prosecdef THEN 'SECURITY DEFINER'
        ELSE 'SECURITY INVOKER'
    END as security,
    CASE
        WHEN proconfig IS NULL THEN 'No search_path set ⚠️'
        ELSE array_to_string(proconfig, ', ')
    END as config
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname IN (
    'handle_new_user',
    'is_admin',
    'update_updated_at_column',
    'calculate_total_hours',
    'get_employees_needing_clock_in_reminder',
    'get_employees_needing_clock_out_reminder',
    'log_notification'
)
ORDER BY p.proname;

-- =====================================================
-- COMENTARIOS
-- =====================================================

COMMENT ON FUNCTION public.handle_new_user() IS 'Trigger function con search_path seguro - Crea empleado al registrarse';
COMMENT ON FUNCTION public.is_admin() IS 'Verifica si el usuario es admin - search_path seguro';
COMMENT ON FUNCTION public.log_notification IS 'Registra notificación - search_path seguro';

-- =====================================================
-- RESUMEN
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Funciones actualizadas con search_path seguro';
    RAISE NOTICE '✅ Warnings de seguridad solucionados';
    RAISE NOTICE '⚠️  Recuerda activar "Leaked Password Protection" en el dashboard de Supabase';
END $$;

