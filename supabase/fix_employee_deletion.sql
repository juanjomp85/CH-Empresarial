-- =====================================================
-- SCRIPT PARA CORREGIR PROBLEMAS DE ELIMINACIÓN DE EMPLEADOS
-- =====================================================
-- Este script corrige los datos residuales que pueden quedar
-- al eliminar empleados del sistema

-- =====================================================
-- 1. CORREGIR CAMPO approved_by EN time_off_requests
-- =====================================================

-- Opción A: Establecer NULL cuando el empleado aprobador es eliminado
ALTER TABLE time_off_requests 
DROP CONSTRAINT IF EXISTS time_off_requests_approved_by_fkey;

ALTER TABLE time_off_requests 
ADD CONSTRAINT time_off_requests_approved_by_fkey 
FOREIGN KEY (approved_by) 
REFERENCES employees(id) 
ON DELETE SET NULL;

-- Opción B (alternativa): Si prefieres CASCADE
-- ALTER TABLE time_off_requests 
-- ADD CONSTRAINT time_off_requests_approved_by_fkey 
-- FOREIGN KEY (approved_by) 
-- REFERENCES employees(id) 
-- ON DELETE CASCADE;

-- =====================================================
-- 2. FUNCIÓN PARA ELIMINACIÓN SEGURA DE EMPLEADOS
-- =====================================================

CREATE OR REPLACE FUNCTION safe_delete_employee(p_employee_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee_record RECORD;
    v_auth_user_id UUID;
    v_result JSON;
    v_notifications_count INTEGER;
    v_time_entries_count INTEGER;
    v_time_off_requests_count INTEGER;
    v_user_preferences_count INTEGER;
BEGIN
    -- Verificar que el empleado existe
    SELECT user_id INTO v_auth_user_id
    FROM employees 
    WHERE id = p_employee_id;
    
    IF v_auth_user_id IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Empleado no encontrado'
        );
    END IF;
    
    -- Contar registros relacionados antes de eliminar
    SELECT COUNT(*) INTO v_notifications_count
    FROM notification_logs 
    WHERE employee_id = p_employee_id;
    
    SELECT COUNT(*) INTO v_time_entries_count
    FROM time_entries 
    WHERE employee_id = p_employee_id;
    
    SELECT COUNT(*) INTO v_time_off_requests_count
    FROM time_off_requests 
    WHERE employee_id = p_employee_id;
    
    SELECT COUNT(*) INTO v_user_preferences_count
    FROM user_preferences 
    WHERE user_id = v_auth_user_id;
    
    -- Obtener información del empleado
    SELECT * INTO v_employee_record
    FROM employees 
    WHERE id = p_employee_id;
    
    -- Eliminar empleado (esto activará CASCADE en las tablas relacionadas)
    DELETE FROM employees WHERE id = p_employee_id;
    
    -- Eliminar preferencias de usuario si existen
    DELETE FROM user_preferences WHERE user_id = v_auth_user_id;
    
    -- Eliminar usuario de autenticación
    -- NOTA: Esto requiere permisos especiales en Supabase
    -- DELETE FROM auth.users WHERE id = v_auth_user_id;
    
    -- Retornar resumen de eliminación
    RETURN json_build_object(
        'success', true,
        'employee_name', v_employee_record.full_name,
        'employee_email', v_employee_record.email,
        'deleted_records', json_build_object(
            'notifications', v_notifications_count,
            'time_entries', v_time_entries_count,
            'time_off_requests', v_time_off_requests_count,
            'user_preferences', v_user_preferences_count
        ),
        'auth_user_deleted', false, -- Cambiar a true cuando se implemente eliminación de auth.users
        'message', 'Empleado eliminado correctamente'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- =====================================================
-- 3. FUNCIÓN PARA DESACTIVAR EMPLEADO (ALTERNATIVA MÁS SEGURA)
-- =====================================================

CREATE OR REPLACE FUNCTION deactivate_employee(p_employee_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_employee_record RECORD;
    v_result JSON;
BEGIN
    -- Verificar que el empleado existe
    SELECT * INTO v_employee_record
    FROM employees 
    WHERE id = p_employee_id;
    
    IF v_employee_record IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Empleado no encontrado'
        );
    END IF;
    
    -- Desactivar empleado en lugar de eliminarlo
    UPDATE employees 
    SET 
        is_active = false,
        email = CONCAT(email, '_deactivated_', EXTRACT(EPOCH FROM NOW())::TEXT),
        updated_at = NOW()
    WHERE id = p_employee_id;
    
    -- Actualizar información del empleado
    SELECT * INTO v_employee_record
    FROM employees 
    WHERE id = p_employee_id;
    
    RETURN json_build_object(
        'success', true,
        'employee_name', v_employee_record.full_name,
        'new_email', v_employee_record.email,
        'message', 'Empleado desactivado correctamente. Los datos históricos se mantienen.'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- =====================================================
-- 4. FUNCIÓN PARA LIMPIAR DATOS HUÉRFANOS
-- =====================================================

CREATE OR REPLACE FUNCTION cleanup_orphaned_data()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_orphaned_approved_by INTEGER;
    v_orphaned_user_preferences INTEGER;
    v_orphaned_auth_users INTEGER;
    v_cleaned_approved_by INTEGER := 0;
    v_cleaned_user_preferences INTEGER := 0;
BEGIN
    -- Contar datos huérfanos
    SELECT COUNT(*) INTO v_orphaned_approved_by
    FROM time_off_requests tor
    LEFT JOIN employees e ON tor.approved_by = e.id
    WHERE tor.approved_by IS NOT NULL AND e.id IS NULL;
    
    SELECT COUNT(*) INTO v_orphaned_user_preferences
    FROM user_preferences up
    LEFT JOIN employees e ON up.user_id = e.user_id
    WHERE e.user_id IS NULL;
    
    -- Limpiar approved_by huérfanos
    UPDATE time_off_requests 
    SET approved_by = NULL
    WHERE approved_by IN (
        SELECT tor.approved_by
        FROM time_off_requests tor
        LEFT JOIN employees e ON tor.approved_by = e.id
        WHERE tor.approved_by IS NOT NULL AND e.id IS NULL
    );
    
    GET DIAGNOSTICS v_cleaned_approved_by = ROW_COUNT;
    
    -- Limpiar preferencias de usuario huérfanas
    DELETE FROM user_preferences 
    WHERE user_id NOT IN (
        SELECT DISTINCT user_id 
        FROM employees 
        WHERE user_id IS NOT NULL
    );
    
    GET DIAGNOSTICS v_cleaned_user_preferences = ROW_COUNT;
    
    RETURN json_build_object(
        'success', true,
        'orphaned_data_found', json_build_object(
            'approved_by_records', v_orphaned_approved_by,
            'user_preferences', v_orphaned_user_preferences
        ),
        'cleaned_data', json_build_object(
            'approved_by_set_null', v_cleaned_approved_by,
            'user_preferences_deleted', v_cleaned_user_preferences
        ),
        'message', 'Limpieza de datos huérfanos completada'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'error', SQLERRM
        );
END;
$$;

-- =====================================================
-- 5. COMENTARIOS Y DOCUMENTACIÓN
-- =====================================================

COMMENT ON FUNCTION safe_delete_employee(UUID) IS 'Elimina un empleado de forma segura, limpiando todos los datos relacionados';
COMMENT ON FUNCTION deactivate_employee(UUID) IS 'Desactiva un empleado manteniendo los datos históricos (recomendado)';
COMMENT ON FUNCTION cleanup_orphaned_data() IS 'Limpia datos huérfanos que pueden quedar en el sistema';

-- =====================================================
-- 6. POLÍTICAS DE SEGURIDAD PARA LAS NUEVAS FUNCIONES
-- =====================================================

-- Solo administradores pueden ejecutar estas funciones
GRANT EXECUTE ON FUNCTION safe_delete_employee(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION deactivate_employee(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_orphaned_data() TO authenticated;
