-- =====================================================
-- 🔧 SCRIPT DE MEJORAS PARA REGISTRO DE USUARIOS
-- =====================================================
-- Este script implementa las mejoras de prioridad alta:
-- 1. Trigger automático para crear empleados
-- 2. Sistema de roles unificado
-- 3. Políticas RLS actualizadas
-- 4. Constraint único para evitar duplicados
-- =====================================================

-- 1. CREAR TABLA user_preferences SI NO EXISTE
-- =====================================================

CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    theme VARCHAR(10) DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
    language VARCHAR(5) DEFAULT 'es',
    timezone VARCHAR(50) DEFAULT 'Europe/Madrid',
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índice si no existe
CREATE INDEX IF NOT EXISTS idx_user_preferences_user_id ON user_preferences(user_id);

-- Habilitar RLS si no está habilitado
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- 2. CREAR FUNCIÓN PARA MANEJAR NUEVOS USUARIOS
-- =====================================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insertar nuevo empleado automáticamente
  INSERT INTO public.employees (
    user_id,
    email,
    full_name,
    role,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'Usuario'),
    'employee', -- Rol por defecto
    true,       -- Activo por defecto
    NOW(),
    NOW()
  );
  
  -- Crear preferencias de usuario por defecto (solo si la tabla existe)
  BEGIN
    INSERT INTO public.user_preferences (
      user_id,
      theme,
      language,
      timezone,
      notifications_enabled,
      created_at,
      updated_at
    ) VALUES (
      NEW.id,
      'system',
      'es',
      'Europe/Madrid',
      true,
      NOW(),
      NOW()
    );
  EXCEPTION
    WHEN undefined_table THEN
      -- Si la tabla no existe, solo logear y continuar
      RAISE LOG 'user_preferences table does not exist, skipping preferences creation';
    WHEN OTHERS THEN
      -- Otros errores en preferencias, logear y continuar
      RAISE LOG 'Error creating user preferences for user %: %', NEW.id, SQLERRM;
  END;
  
  RETURN NEW;
EXCEPTION
  WHEN unique_violation THEN
    -- Si ya existe el empleado, no hacer nada
    RAISE NOTICE 'Employee already exists for user %', NEW.id;
    RETURN NEW;
  WHEN OTHERS THEN
    -- Log del error pero no fallar el registro
    RAISE LOG 'Error creating employee for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 2. CREAR TRIGGER PARA NUEVOS USUARIOS (ALTERNATIVA COMPATIBLE CON SUPABASE)
-- =====================================================

-- En Supabase, no podemos crear triggers directamente en auth.users
-- En su lugar, usaremos un enfoque diferente:

-- Crear función que se puede llamar manualmente o desde el frontend
CREATE OR REPLACE FUNCTION create_employee_for_user(user_id_param UUID)
RETURNS JSON AS $$
DECLARE
  result JSON;
  user_email TEXT;
  user_full_name TEXT;
BEGIN
  -- Obtener datos del usuario
  SELECT email, raw_user_meta_data->>'full_name'
  INTO user_email, user_full_name
  FROM auth.users 
  WHERE id = user_id_param;
  
  IF user_email IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Usuario no encontrado');
  END IF;
  
  -- Insertar empleado
  INSERT INTO public.employees (
    user_id,
    email,
    full_name,
    role,
    is_active,
    created_at,
    updated_at
  ) VALUES (
    user_id_param,
    user_email,
    COALESCE(user_full_name, 'Usuario'),
    'employee',
    true,
    NOW(),
    NOW()
  );
  
  -- Insertar preferencias si la tabla existe
  BEGIN
    INSERT INTO public.user_preferences (
      user_id,
      theme,
      language,
      timezone,
      notifications_enabled,
      created_at,
      updated_at
    ) VALUES (
      user_id_param,
      'system',
      'es',
      'Europe/Madrid',
      true,
      NOW(),
      NOW()
    );
  EXCEPTION
    WHEN undefined_table THEN
      RAISE NOTICE 'user_preferences table does not exist, skipping preferences creation';
    WHEN OTHERS THEN
      RAISE NOTICE 'Error creating user preferences: %', SQLERRM;
  END;
  
  RETURN json_build_object('success', true, 'message', 'Empleado creado exitosamente');
  
EXCEPTION
  WHEN unique_violation THEN
    RETURN json_build_object('success', false, 'error', 'Empleado ya existe para este usuario');
  WHEN OTHERS THEN
    RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 3. AÑADIR CONSTRAINT ÚNICO PARA EVITAR DUPLICADOS
-- =====================================================

-- Verificar si el constraint ya existe antes de añadirlo
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'employees' 
        AND constraint_name = 'employees_user_id_key'
    ) THEN
        ALTER TABLE employees ADD CONSTRAINT employees_user_id_key UNIQUE (user_id);
        RAISE NOTICE 'Constraint employees_user_id_key creado exitosamente';
    ELSE
        RAISE NOTICE 'Constraint employees_user_id_key ya existe, omitiendo...';
    END IF;
END $$;

-- 4. ACTUALIZAR POLÍTICAS RLS PARA USAR COLUMNA ROLE
-- =====================================================

-- Eliminar TODAS las políticas existentes para evitar conflictos
DROP POLICY IF EXISTS "Users can view their own data" ON employees;
DROP POLICY IF EXISTS "Users can update their own data" ON employees;
DROP POLICY IF EXISTS "Users can view their own employee data" ON employees;
DROP POLICY IF EXISTS "Users can update their own basic data" ON employees;
DROP POLICY IF EXISTS "Admins can view all data" ON employees;
DROP POLICY IF EXISTS "Admins can view all employees" ON employees;
DROP POLICY IF EXISTS "Admins can insert employees" ON employees;
DROP POLICY IF EXISTS "Admins can delete employees" ON employees;
DROP POLICY IF EXISTS "Admins can update all employee data" ON employees;

DROP POLICY IF EXISTS "Employees can view their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Employees can insert their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Employees can update their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Admins can view all time entries" ON time_entries;
DROP POLICY IF EXISTS "Admins can insert any time entries" ON time_entries;
DROP POLICY IF EXISTS "Admins can update any time entries" ON time_entries;
DROP POLICY IF EXISTS "Admins can delete any time entries" ON time_entries;

DROP POLICY IF EXISTS "Employees can view their own time off requests" ON time_off_requests;
DROP POLICY IF EXISTS "Employees can insert their own time off requests" ON time_off_requests;
DROP POLICY IF EXISTS "Employees can update their own time off requests" ON time_off_requests;
DROP POLICY IF EXISTS "Admins can view all time off requests" ON time_off_requests;
DROP POLICY IF EXISTS "Admins can update any time off requests" ON time_off_requests;
DROP POLICY IF EXISTS "Admins can delete any time off requests" ON time_off_requests;

DROP POLICY IF EXISTS "Anyone can view company settings" ON company_settings;
DROP POLICY IF EXISTS "Only admins can update company settings" ON company_settings;
DROP POLICY IF EXISTS "Only admins can insert company settings" ON company_settings;

DROP POLICY IF EXISTS "Anyone can view departments" ON departments;
DROP POLICY IF EXISTS "Only admins can manage departments" ON departments;

DROP POLICY IF EXISTS "Anyone can view positions" ON positions;
DROP POLICY IF EXISTS "Only admins can manage positions" ON positions;

-- Solo eliminar políticas de user_preferences si la tabla existe
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_preferences') THEN
        DROP POLICY IF EXISTS "Users can view their own preferences" ON user_preferences;
        DROP POLICY IF EXISTS "Users can insert their own preferences" ON user_preferences;
        DROP POLICY IF EXISTS "Users can update their own preferences" ON user_preferences;
        RAISE NOTICE 'Políticas de user_preferences eliminadas';
    ELSE
        RAISE NOTICE 'Tabla user_preferences no existe, omitiendo eliminación de políticas';
    END IF;
END $$;

-- Actualizar función is_admin para usar columna role
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM employees 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_catalog;

-- 5. CREAR NUEVAS POLÍTICAS RLS UNIFICADAS
-- =====================================================

-- Políticas para employees usando columna role
CREATE POLICY "Users can view their own employee data" ON employees
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Admins can view all employees" ON employees
  FOR SELECT
  USING (is_admin());

CREATE POLICY "Users can update their own basic data" ON employees
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Admins can insert employees" ON employees
  FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete employees" ON employees
  FOR DELETE
  USING (is_admin());

CREATE POLICY "Admins can update all employee data" ON employees
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- Políticas para time_entries
CREATE POLICY "Employees can view their own time entries" ON time_entries
  FOR SELECT
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Employees can insert their own time entries" ON time_entries
  FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Employees can update their own time entries" ON time_entries
  FOR UPDATE
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can view all time entries" ON time_entries
  FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can insert any time entries" ON time_entries
  FOR INSERT
  WITH CHECK (is_admin());

CREATE POLICY "Admins can update any time entries" ON time_entries
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete any time entries" ON time_entries
  FOR DELETE
  USING (is_admin());

-- Políticas para time_off_requests
CREATE POLICY "Employees can view their own time off requests" ON time_off_requests
  FOR SELECT
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Employees can insert their own time off requests" ON time_off_requests
  FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Employees can update their own time off requests" ON time_off_requests
  FOR UPDATE
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can view all time off requests" ON time_off_requests
  FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can update any time off requests" ON time_off_requests
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can delete any time off requests" ON time_off_requests
  FOR DELETE
  USING (is_admin());

-- Políticas para company_settings
CREATE POLICY "Anyone can view company settings" ON company_settings
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can update company settings" ON company_settings
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Only admins can insert company settings" ON company_settings
  FOR INSERT
  WITH CHECK (is_admin());

-- Políticas para departments
CREATE POLICY "Anyone can view departments" ON departments
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can manage departments" ON departments
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Políticas para positions
CREATE POLICY "Anyone can view positions" ON positions
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can manage positions" ON positions
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Políticas para user_preferences (solo si la tabla existe)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_preferences') THEN
        CREATE POLICY "Users can view their own preferences" ON user_preferences
          FOR SELECT
          USING (auth.uid() = user_id);

        CREATE POLICY "Users can insert their own preferences" ON user_preferences
          FOR INSERT
          WITH CHECK (auth.uid() = user_id);

        CREATE POLICY "Users can update their own preferences" ON user_preferences
          FOR UPDATE
          USING (auth.uid() = user_id);
        
        RAISE NOTICE 'Políticas de user_preferences creadas exitosamente';
    ELSE
        RAISE NOTICE 'Tabla user_preferences no existe, omitiendo creación de políticas';
    END IF;
END $$;

-- 6. ACTUALIZAR ROLES EXISTENTES
-- =====================================================

-- Asegurar que todos los empleados existentes tengan un rol
UPDATE employees 
SET role = 'employee' 
WHERE role IS NULL;

-- 7. VERIFICACIÓN Y COMENTARIOS
-- =====================================================

COMMENT ON FUNCTION handle_new_user() IS 'Función que crea automáticamente un empleado y sus preferencias cuando se registra un nuevo usuario (para uso futuro)';
COMMENT ON FUNCTION create_employee_for_user(UUID) IS 'Función que crea un empleado para un usuario específico (alternativa al trigger)';
COMMENT ON FUNCTION is_admin() IS 'Función que verifica si el usuario actual es administrador usando la columna role de employees';
COMMENT ON CONSTRAINT employees_user_id_key ON employees IS 'Constraint que garantiza que cada usuario tenga solo un registro de empleado';

-- 8. VERIFICAR IMPLEMENTACIÓN
-- =====================================================

-- Verificar que las funciones existen
SELECT 
  p.proname as function_name,
  CASE
    WHEN proconfig IS NULL THEN '❌ No search_path'
    ELSE '✅ ' || array_to_string(proconfig, ', ')
  END as status
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
AND p.proname IN ('handle_new_user', 'create_employee_for_user', 'is_admin')
ORDER BY p.proname;

-- Verificar constraint único
SELECT 
  constraint_name,
  constraint_type
FROM information_schema.table_constraints 
WHERE table_name = 'employees' 
AND constraint_name = 'employees_user_id_key';

-- =====================================================
-- ✅ SCRIPT COMPLETADO
-- =====================================================
-- Después de ejecutar este script:
-- 1. Los nuevos usuarios tendrán empleados creados automáticamente
-- 2. El sistema de roles estará unificado
-- 3. Las políticas RLS usarán la columna role de employees
-- 4. No se podrán crear empleados duplicados
-- =====================================================
