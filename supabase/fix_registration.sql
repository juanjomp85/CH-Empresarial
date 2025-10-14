-- =====================================================
-- FIX: PERMITIR AUTO-REGISTRO DE NUEVOS USUARIOS
-- =====================================================
-- Este script soluciona el problema donde usuarios externos
-- no pueden registrarse porque no tienen permisos para crear
-- su propio registro de empleado

-- =====================================================
-- 1. ELIMINAR POLÍTICA RESTRICTIVA
-- =====================================================

DROP POLICY IF EXISTS "Admins can insert employees" ON employees;

-- =====================================================
-- 2. NUEVA POLÍTICA: PERMITIR AUTO-REGISTRO
-- =====================================================

-- Los usuarios pueden crear su propio registro de empleado (UNA VEZ)
CREATE POLICY "Users can create their own employee record" ON employees
  FOR INSERT
  WITH CHECK (
    auth.uid() = user_id 
    AND NOT EXISTS (
      -- Evitar crear múltiples registros para el mismo usuario
      SELECT 1 FROM employees WHERE user_id = auth.uid()
    )
  );

-- Los administradores pueden insertar cualquier empleado
CREATE POLICY "Admins can insert employees" ON employees
  FOR INSERT
  WITH CHECK (is_admin());

-- =====================================================
-- 3. FUNCIÓN: CREAR EMPLEADO AUTOMÁTICAMENTE AL REGISTRARSE
-- =====================================================

-- Esta función se ejecuta automáticamente cuando un nuevo usuario
-- se registra en Supabase Auth

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  -- Insertar un nuevo registro de empleado para el usuario recién creado
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
    'employee', -- Rol por defecto
    true, -- Activo por defecto
    NULL, -- Sin departamento (el admin lo asignará)
    NULL, -- Sin posición (el admin lo asignará)
    0 -- Sin tarifa por defecto
  )
  ON CONFLICT (user_id) DO NOTHING; -- Evitar duplicados
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 4. TRIGGER: EJECUTAR FUNCIÓN AL CREAR USUARIO
-- =====================================================

-- Eliminar trigger anterior si existe
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Crear trigger que se ejecuta cuando un nuevo usuario se registra
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- 5. AÑADIR CONSTRAINT ÚNICO PARA EVITAR DUPLICADOS
-- =====================================================

-- Asegurarse de que no hay múltiples empleados con el mismo user_id
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'employees_user_id_key'
  ) THEN
    ALTER TABLE employees ADD CONSTRAINT employees_user_id_key UNIQUE (user_id);
  END IF;
END $$;

-- =====================================================
-- 6. VERIFICAR CONFIGURACIÓN
-- =====================================================

-- Ver políticas de la tabla employees
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'employees'
ORDER BY policyname;

-- Ver triggers en auth.users
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- =====================================================
-- COMENTARIOS
-- =====================================================

COMMENT ON FUNCTION public.handle_new_user() IS 
'Crea automáticamente un registro de empleado cuando un nuevo usuario se registra en Auth';

COMMENT ON POLICY "Users can create their own employee record" ON employees IS
'Permite a los usuarios crear su propio registro de empleado una vez durante el auto-registro';

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿CÓMO FUNCIONA EL NUEVO FLUJO?

ANTES (ROTO):
1. Usuario se registra → Auth crea usuario ✅
2. Usuario accede → Intenta crear empleado ❌
3. RLS bloquea (solo admins) → FALLA
4. Usuario no puede usar la app ❌

DESPUÉS (ARREGLADO):
1. Usuario se registra → Auth crea usuario ✅
2. Trigger automático → Crea empleado ✅
3. Usuario accede → Empleado ya existe ✅
4. Usuario puede usar la app ✅

SEGURIDAD:
- Solo se puede crear UNA VEZ por usuario (constraint unique)
- El empleado se crea con rol 'employee' (no admin)
- Sin departamento ni posición (admin los asigna después)
- Los admins siguen pudiendo crear empleados manualmente
*/

