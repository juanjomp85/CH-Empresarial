-- =====================================================
-- VERIFICAR ESTADO REAL DE USUARIOS Y EMPLEADOS
-- =====================================================
-- Script para ver exactamente qué usuarios tienen empleado
-- y cuáles no, antes de intentar crear empleados

-- =====================================================
-- 1. VER TODOS LOS USUARIOS EN AUTH
-- =====================================================

SELECT 
    '1️⃣ TODOS LOS USUARIOS EN AUTH' as seccion,
    email,
    created_at,
    confirmed_at,
    CASE 
        WHEN confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado
FROM auth.users
ORDER BY created_at DESC;

-- =====================================================
-- 2. VER TODOS LOS EMPLEADOS
-- =====================================================

SELECT 
    '2️⃣ TODOS LOS EMPLEADOS' as seccion,
    email,
    full_name,
    role,
    is_active,
    created_at
FROM employees
ORDER BY created_at DESC;

-- =====================================================
-- 3. VER USUARIOS SIN EMPLEADO (JOIN CORRECTO)
-- =====================================================

-- Usuarios que existen en auth pero NO en employees
SELECT 
    '3️⃣ USUARIOS SIN EMPLEADO' as seccion,
    u.email,
    u.created_at,
    u.confirmed_at,
    CASE 
        WHEN u.confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado,
    '❌ Sin empleado asociado' as problema
FROM auth.users u
LEFT JOIN employees e ON e.user_id = u.id
WHERE e.id IS NULL
ORDER BY u.created_at DESC;

-- =====================================================
-- 4. VER USUARIOS CON EMPLEADO (JOIN CORRECTO)
-- =====================================================

-- Usuarios que SÍ tienen empleado asociado
SELECT 
    '4️⃣ USUARIOS CON EMPLEADO' as seccion,
    u.email,
    u.created_at,
    u.confirmed_at,
    e.full_name as nombre_empleado,
    e.role as rol_empleado,
    e.is_active as empleado_activo
FROM auth.users u
INNER JOIN employees e ON e.user_id = u.id
ORDER BY u.created_at DESC;

-- =====================================================
-- 5. VERIFICAR EMAILS DUPLICADOS EN EMPLOYEES
-- =====================================================

-- Buscar emails duplicados en la tabla employees
SELECT 
    '5️⃣ EMAILS DUPLICADOS EN EMPLOYEES' as seccion,
    email,
    COUNT(*) as cantidad,
    '❌ Email duplicado' as problema
FROM employees
GROUP BY email
HAVING COUNT(*) > 1;

-- =====================================================
-- 6. VERIFICAR CONSTRAINT ÚNICO EN EMAIL
-- =====================================================

-- Ver constraints de la tabla employees
SELECT 
    '6️⃣ CONSTRAINTS DE EMPLOYEES' as seccion,
    constraint_name,
    column_name,
    '✅ Configurado' as estado
FROM information_schema.constraint_column_usage
WHERE table_name = 'employees'
AND constraint_name LIKE '%email%';

-- =====================================================
-- 7. BUSCAR EMPLEADO ESPECÍFICO PROBLEMÁTICO
-- =====================================================

-- Buscar el empleado que está causando el conflicto
SELECT 
    '7️⃣ EMPLEADO PROBLEMÁTICO' as seccion,
    e.email,
    e.full_name,
    e.user_id,
    e.role,
    e.is_active,
    e.created_at,
    u.email as email_auth,
    u.created_at as fecha_auth
FROM employees e
LEFT JOIN auth.users u ON u.id = e.user_id
WHERE e.email = 'sentidodelocomun@gmail.com';

-- =====================================================
-- COMENTARIOS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 DIAGNÓSTICO DEL ESTADO REAL:';
    RAISE NOTICE '';
    RAISE NOTICE '1️⃣  Ver todos los usuarios en auth.users';
    RAISE NOTICE '2️⃣  Ver todos los empleados en employees';
    RAISE NOTICE '3️⃣  Identificar usuarios sin empleado';
    RAISE NOTICE '4️⃣  Verificar usuarios con empleado';
    RAISE NOTICE '5️⃣  Buscar emails duplicados';
    RAISE NOTICE '6️⃣  Verificar constraints';
    RAISE NOTICE '7️⃣  Analizar empleado problemático';
    RAISE NOTICE '';
    RAISE NOTICE '📝 POSIBLES CAUSAS DEL ERROR:';
    RAISE NOTICE '   - sentidodelocomun@gmail.com ya tiene empleado';
    RAISE NOTICE '   - Hay un empleado con ese email pero user_id diferente';
    RAISE NOTICE '   - Constraint único en email está funcionando';
    RAISE NOTICE '';
    RAISE NOTICE '✅ SOLUCIÓN:';
    RAISE NOTICE '   - Identificar qué usuarios realmente necesitan empleado';
    RAISE NOTICE '   - Crear solo los que faltan';
    RAISE NOTICE '   - Evitar duplicados';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿POR QUÉ ESTE ERROR?

1️⃣  EMPLEADO YA EXISTE:
   - sentidodelocomun@gmail.com ya tiene empleado
   - El script intenta crearlo de nuevo
   - Constraint único en email lo impide

2️⃣  USER_ID DIFERENTE:
   - Puede haber un empleado con ese email
   - Pero asociado a un user_id diferente
   - Esto causaría el conflicto

3️⃣  DATOS INCONSISTENTES:
   - Usuario en auth.users
   - Empleado en employees
   - Pero con user_id diferente

SOLUCIÓN:
- Verificar el estado real
- Crear solo los empleados que faltan
- Evitar duplicados
*/
