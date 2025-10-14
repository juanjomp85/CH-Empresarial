-- =====================================================
-- DIAGNÓSTICO COMPLETO: ¿Por qué falla el registro?
-- =====================================================

-- =====================================================
-- 1. VERIFICAR SI EL EMAIL YA ESTÁ REGISTRADO
-- =====================================================

SELECT 
    '1️⃣ USUARIOS EXISTENTES EN AUTH' as seccion,
    email,
    created_at,
    confirmed_at,
    CASE 
        WHEN confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado
FROM auth.users
WHERE email ILIKE '%informatica@aspapros.es%'
   OR email ILIKE '%aspapros%';

-- =====================================================
-- 2. VERIFICAR EMPLEADOS EXISTENTES
-- =====================================================

SELECT 
    '2️⃣ EMPLEADOS EXISTENTES' as seccion,
    e.email,
    e.full_name,
    e.user_id,
    e.is_active,
    e.created_at
FROM employees e
WHERE e.email ILIKE '%informatica@aspapros.es%'
   OR e.email ILIKE '%aspapros%'
   OR e.full_name ILIKE '%aspapros%';

-- =====================================================
-- 3. VERIFICAR POLÍTICAS RLS DE EMPLOYEES
-- =====================================================

SELECT 
    '3️⃣ POLÍTICAS RLS PARA INSERT' as seccion,
    policyname as politica,
    cmd as comando,
    qual as condicion,
    with_check as verificacion
FROM pg_policies 
WHERE tablename = 'employees'
AND cmd = 'INSERT'
ORDER BY policyname;

-- =====================================================
-- 4. VERIFICAR SI HAY FUNCIONES/TRIGGERS ACTIVOS
-- =====================================================

-- Triggers en auth.users
SELECT 
    '4️⃣ TRIGGERS EN AUTH.USERS' as seccion,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- Triggers en employees
SELECT 
    '4️⃣ TRIGGERS EN EMPLOYEES' as seccion,
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'public'
AND event_object_table = 'employees';

-- =====================================================
-- 5. VERIFICAR CONSTRAINT ÚNICO
-- =====================================================

SELECT 
    '5️⃣ CONSTRAINTS ÚNICOS' as seccion,
    constraint_name,
    column_name,
    '✅ Configurado' as estado
FROM information_schema.constraint_column_usage
WHERE table_name = 'employees'
AND constraint_name LIKE '%user_id%';

-- =====================================================
-- 6. PROBAR CREACIÓN MANUAL DE EMPLEADO
-- =====================================================

-- Esta query simula lo que intentaría hacer la app
-- IMPORTANTE: Reemplaza 'uuid-de-prueba' con un UUID real o comenta esta sección

/*
DO $$
DECLARE
    test_user_id UUID := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::UUID;
BEGIN
    -- Intentar crear un empleado de prueba
    BEGIN
        INSERT INTO employees (
            user_id,
            email,
            full_name,
            role,
            is_active,
            department_id,
            position_id,
            hourly_rate
        ) VALUES (
            test_user_id,
            'test@ejemplo.com',
            'Usuario Test',
            'employee',
            true,
            NULL,
            NULL,
            0
        );
        RAISE NOTICE '✅ INSERT funcionó correctamente';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ ERROR al insertar: %', SQLERRM;
    END;
    
    -- Limpiar prueba
    DELETE FROM employees WHERE user_id = test_user_id;
END $$;
*/

-- =====================================================
-- 7. VERIFICAR CONFIGURACIÓN DE SUPABASE AUTH
-- =====================================================

SELECT 
    '7️⃣ CONFIGURACIÓN AUTH' as seccion,
    'Revisa en Dashboard → Authentication → Settings' as instruccion,
    '- Enable email confirmations?' as check_1,
    '- Auto-confirm users?' as check_2,
    '- Secure email change?' as check_3;

-- =====================================================
-- 8. VER LOGS RECIENTES DE ERRORES (si existen)
-- =====================================================

-- Nota: Esta tabla puede no existir dependiendo de tu configuración
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'error_logs') THEN
        EXECUTE 'SELECT * FROM error_logs ORDER BY created_at DESC LIMIT 10';
    ELSE
        RAISE NOTICE 'No hay tabla error_logs configurada';
    END IF;
END $$;

-- =====================================================
-- RESUMEN DE POSIBLES CAUSAS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔍 POSIBLES CAUSAS DEL ERROR:';
    RAISE NOTICE '';
    RAISE NOTICE '1️⃣  Email ya existe en auth.users';
    RAISE NOTICE '   → Query 1 mostrará el usuario existente';
    RAISE NOTICE '   → Solución: Usa otro email o elimina el usuario';
    RAISE NOTICE '';
    RAISE NOTICE '2️⃣  Políticas RLS bloquean el INSERT';
    RAISE NOTICE '   → Query 3 debe mostrar "Users can create their own employee record"';
    RAISE NOTICE '   → Si no aparece, ejecuta fix_registration_simple.sql';
    RAISE NOTICE '';
    RAISE NOTICE '3️⃣  Trigger está fallando';
    RAISE NOTICE '   → Query 4 mostrará triggers activos';
    RAISE NOTICE '   → Si hay trigger en auth.users, puede estar causando error';
    RAISE NOTICE '';
    RAISE NOTICE '4️⃣  Confirmación de email requerida';
    RAISE NOTICE '   → Revisa Dashboard → Authentication → Settings';
    RAISE NOTICE '   → Si "Enable email confirmations" está activo, el usuario debe confirmar';
    RAISE NOTICE '';
    RAISE NOTICE '5️⃣  Error en el frontend (mensaje genérico)';
    RAISE NOTICE '   → Abre la consola del navegador (F12)';
    RAISE NOTICE '   → Busca el error real de Supabase';
    RAISE NOTICE '';
END $$;

-- =====================================================
-- QUERIES DE LIMPIEZA (OPCIONAL)
-- =====================================================

-- ⚠️  SOLO EJECUTA ESTAS SI QUIERES ELIMINAR USUARIOS DE PRUEBA

-- Ver usuarios que NO tienen empleado asociado
/*
SELECT 
    u.email,
    u.created_at,
    u.confirmed_at,
    '❌ Sin empleado asociado' as estado
FROM auth.users u
LEFT JOIN employees e ON e.user_id = u.id
WHERE e.id IS NULL
ORDER BY u.created_at DESC;
*/

-- Eliminar usuario específico (CUIDADO!)
/*
DELETE FROM auth.users 
WHERE email = 'informatica@aspapros.es';
*/

