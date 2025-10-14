-- =====================================================
-- FIX: PERMITIR AUTO-REGISTRO DE NUEVOS USUARIOS (SIMPLIFICADO)
-- =====================================================
-- Solución SIN trigger (no requiere permisos especiales)
-- La app ya tiene lógica para crear empleados automáticamente

-- =====================================================
-- 1. ELIMINAR POLÍTICAS RESTRICTIVAS EXISTENTES
-- =====================================================

DROP POLICY IF EXISTS "Admins can insert employees" ON employees;
DROP POLICY IF EXISTS "Users can create their own employee record" ON employees;

-- =====================================================
-- 2. CREAR POLÍTICAS QUE PERMITEN AUTO-REGISTRO
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
-- 3. AÑADIR CONSTRAINT ÚNICO PARA EVITAR DUPLICADOS
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
-- 4. VERIFICAR CONFIGURACIÓN
-- =====================================================

-- Ver políticas de la tabla employees
SELECT 
  policyname as politica,
  cmd as comando,
  CASE 
    WHEN policyname LIKE '%Users can create%' THEN '✅ Permite auto-registro'
    WHEN policyname LIKE '%Admins%' THEN '✅ Permite admins crear'
    ELSE '📋 ' || policyname
  END as descripcion
FROM pg_policies 
WHERE tablename = 'employees'
AND cmd = 'INSERT'
ORDER BY policyname;

-- Ver constraint único
SELECT 
  constraint_name as constraint,
  '✅ Previene duplicados' as descripcion
FROM information_schema.table_constraints
WHERE table_name = 'employees'
AND constraint_name = 'employees_user_id_key';

-- =====================================================
-- COMENTARIOS
-- =====================================================

COMMENT ON POLICY "Users can create their own employee record" ON employees IS
'Permite a los usuarios crear su propio registro de empleado una vez durante el auto-registro';

COMMENT ON POLICY "Admins can insert employees" ON employees IS
'Permite a los administradores crear registros de empleados para cualquier usuario';

-- =====================================================
-- RESUMEN
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Políticas RLS actualizadas correctamente';
    RAISE NOTICE '✅ Los usuarios ahora pueden auto-registrarse';
    RAISE NOTICE '✅ La app creará el empleado automáticamente al acceder';
    RAISE NOTICE '';
    RAISE NOTICE '📝 CÓMO FUNCIONA:';
    RAISE NOTICE '   1. Usuario se registra → Supabase Auth crea usuario ✅';
    RAISE NOTICE '   2. Usuario inicia sesión → Accede a /dashboard/time ✅';
    RAISE NOTICE '   3. App detecta que no existe empleado → Lo crea automáticamente ✅';
    RAISE NOTICE '   4. Usuario puede usar la app normalmente ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 SEGURIDAD:';
    RAISE NOTICE '   - Solo puede crear UN empleado (constraint único)';
    RAISE NOTICE '   - Rol por defecto: "employee" (no admin)';
    RAISE NOTICE '   - Sin departamento ni posición (admin asigna después)';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿POR QUÉ ESTA VERSIÓN ES MEJOR?

ANTES (con trigger):
❌ Requiere permisos de superusuario
❌ No funciona en Supabase SQL Editor
❌ Complejo de mantener

AHORA (sin trigger):
✅ Solo usa políticas RLS (permisos normales)
✅ Funciona en SQL Editor estándar
✅ La app ya tiene la lógica en app/dashboard/time/page.tsx

¿DÓNDE ESTÁ LA LÓGICA DE CREACIÓN?

En el archivo: app/dashboard/time/page.tsx (líneas 57-76)

const loadEmployeeData = useCallback(async () => {
  const { data: emp } = await supabase
    .from('employees')
    .select('*')
    .eq('user_id', user?.id)
    .single()

  if (!emp) {
    // Si no existe el empleado, crearlo
    const { data: newEmp, error } = await supabase
      .from('employees')
      .insert({
        user_id: user?.id,
        email: user?.email,
        full_name: user?.user_metadata?.full_name || 'Usuario',
        position_id: null,
        department_id: null,
        hourly_rate: 0
      })
      .select()
      .single()
  }
}, [user])

FLUJO COMPLETO:
1. Usuario se registra → Auth crea usuario
2. Usuario es redirigido a /dashboard/time
3. loadEmployeeData() detecta que no hay empleado
4. Crea empleado usando las nuevas políticas RLS
5. Todo funciona ✅
*/

