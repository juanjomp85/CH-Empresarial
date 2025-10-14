-- =====================================================
-- DIAGNÓSTICO: ¿Por qué informatica@aspapros.es no aparece?
-- =====================================================

-- =====================================================
-- 1. VERIFICAR SI EL USUARIO EXISTE EN AUTH
-- =====================================================

SELECT 
    '1️⃣ USUARIO EN AUTH' as seccion,
    email,
    created_at,
    confirmed_at,
    CASE 
        WHEN confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado,
    raw_user_meta_data
FROM auth.users
WHERE email = 'informatica@aspapros.es';

-- =====================================================
-- 2. VERIFICAR SI TIENE EMPLEADO ASOCIADO
-- =====================================================

SELECT 
    '2️⃣ EMPLEADO ASOCIADO' as seccion,
    e.email,
    e.full_name,
    e.user_id,
    e.role,
    e.is_active,
    e.created_at
FROM employees e
WHERE e.email = 'informatica@aspapros.es';

-- =====================================================
-- 3. VERIFICAR SI HAY ERRORES EN EL PROCESO DE CREACIÓN
-- =====================================================

-- Ver si hay algún log de error o problema
SELECT 
    '3️⃣ LOGS DE ERRORES' as seccion,
    'Revisa la consola del navegador para errores específicos' as instruccion;

-- =====================================================
-- 4. CREAR EMPLEADO MANUALMENTE SI NO EXISTE
-- =====================================================

-- Si el usuario existe en auth pero no en employees, crearlo
INSERT INTO employees (
    user_id,
    email,
    full_name,
    role,
    is_active,
    department_id,
    position_id
) 
SELECT 
    u.id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Usuario'),
    'employee',
    true,
    NULL,
    NULL
FROM auth.users u
WHERE u.email = 'informatica@aspapros.es'
AND NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.user_id = u.id
);

-- =====================================================
-- 5. VERIFICAR QUE AHORA TIENE EMPLEADO
-- =====================================================

SELECT 
    '5️⃣ EMPLEADO DESPUÉS DEL FIX' as seccion,
    e.email,
    e.full_name,
    e.role,
    e.is_active,
    e.created_at
FROM employees e
WHERE e.email = 'informatica@aspapros.es';

-- =====================================================
-- 6. VERIFICAR TODOS LOS USUARIOS Y EMPLEADOS
-- =====================================================

-- Ver todos los usuarios en auth
SELECT 
    '6️⃣ TODOS LOS USUARIOS EN AUTH' as seccion,
    email,
    created_at,
    confirmed_at,
    CASE 
        WHEN confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado
FROM auth.users
ORDER BY created_at DESC;

-- Ver todos los empleados
SELECT 
    '6️⃣ TODOS LOS EMPLEADOS' as seccion,
    e.email,
    e.full_name,
    e.role,
    e.is_active,
    e.created_at
FROM employees e
ORDER BY e.created_at DESC;

-- =====================================================
-- 7. VERIFICAR USUARIOS SIN EMPLEADO
-- =====================================================

-- Usuarios que existen en auth pero NO en employees
SELECT 
    '7️⃣ USUARIOS SIN EMPLEADO' as seccion,
    u.email,
    u.created_at,
    u.confirmed_at,
    '❌ Sin empleado asociado' as problema
FROM auth.users u
LEFT JOIN employees e ON e.user_id = u.id
WHERE e.id IS NULL
ORDER BY u.created_at DESC;

-- =====================================================
-- COMENTARIOS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 DIAGNÓSTICO DE INFORMATICA@ASPAPROS.ES:';
    RAISE NOTICE '';
    RAISE NOTICE '1️⃣  Verificar si existe en auth.users';
    RAISE NOTICE '2️⃣  Verificar si tiene empleado asociado';
    RAISE NOTICE '3️⃣  Si no tiene empleado, se creará automáticamente';
    RAISE NOTICE '4️⃣  Verificar que ahora aparece en employees';
    RAISE NOTICE '';
    RAISE NOTICE '📝 POSIBLES CAUSAS:';
    RAISE NOTICE '   - Usuario se registró pero no confirmó email';
    RAISE NOTICE '   - Error al crear empleado (trigger falló)';
    RAISE NOTICE '   - Usuario existe pero sin empleado asociado';
    RAISE NOTICE '';
    RAISE NOTICE '✅ SOLUCIÓN:';
    RAISE NOTICE '   - El script creará el empleado automáticamente';
    RAISE NOTICE '   - Después podrá usar la app normalmente';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿POR QUÉ PUEDE PASAR ESTO?

1️⃣  USUARIO NO CONFIRMÓ EMAIL:
   - Se registró pero no confirmó
   - No puede iniciar sesión
   - No se crea empleado

2️⃣  TRIGGER FALLÓ ANTES DE ELIMINARLO:
   - Se registró cuando el trigger aún existía
   - Trigger falló al crear empleado
   - Usuario existe pero sin empleado

3️⃣  ERROR EN LA APP:
   - Usuario se registró correctamente
   - App no pudo crear empleado
   - Error en loadEmployeeData()

4️⃣  PROBLEMA DE PERMISOS:
   - Usuario se registró
   - Políticas RLS bloquean creación de empleado
   - No se puede insertar en employees

SOLUCIÓN:
- El script creará el empleado manualmente
- Después funcionará normalmente
*/
