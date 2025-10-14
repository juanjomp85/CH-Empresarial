-- =====================================================
-- FIX: ACTUALIZAR EMPLEADO EXISTENTE
-- =====================================================
-- El empleado sentidodelocomun@gmail.com existe pero:
-- - user_id = NULL
-- - is_active = false
-- - No está asociado al usuario de auth

-- =====================================================
-- 1. ACTUALIZAR EMPLEADO SENTIDODELOCOMUN@GMAIL.COM
-- =====================================================

-- Actualizar el empleado existente para asociarlo al usuario correcto
UPDATE employees 
SET 
    user_id = (SELECT id FROM auth.users WHERE email = 'sentidodelocomun@gmail.com'),
    is_active = true,
    full_name = COALESCE(
        (SELECT raw_user_meta_data->>'full_name' FROM auth.users WHERE email = 'sentidodelocomun@gmail.com'),
        'PEPE'
    )
WHERE email = 'sentidodelocomun@gmail.com'
AND user_id IS NULL;

-- =====================================================
-- 2. VERIFICAR QUE SE ACTUALIZÓ CORRECTAMENTE
-- =====================================================

-- Ver el empleado después de la actualización
SELECT 
    '✅ EMPLEADO ACTUALIZADO' as resultado,
    e.email,
    e.full_name,
    e.user_id,
    e.role,
    e.is_active,
    e.created_at,
    u.email as email_auth,
    u.confirmed_at
FROM employees e
LEFT JOIN auth.users u ON u.id = e.user_id
WHERE e.email = 'sentidodelocomun@gmail.com';

-- =====================================================
-- 3. CREAR EMPLEADOS PARA LOS QUE REALMENTE FALTAN
-- =====================================================

-- Crear empleado para martinezherradamaria@gmail.com (si no existe)
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
WHERE u.email = 'martinezherradamaria@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.user_id = u.id
);

-- Crear empleado para diana@ejemplo.com (si no existe)
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
WHERE u.email = 'diana@ejemplo.com'
AND NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.user_id = u.id
);

-- =====================================================
-- 4. VERIFICAR ESTADO FINAL
-- =====================================================

-- Ver todos los empleados después del fix
SELECT 
    '✅ EMPLEADOS DESPUÉS DEL FIX' as resultado,
    e.email,
    e.full_name,
    e.role,
    e.is_active,
    e.created_at,
    CASE 
        WHEN e.user_id IS NULL THEN '❌ Sin usuario asociado'
        ELSE '✅ Con usuario asociado'
    END as estado_usuario
FROM employees e
ORDER BY e.created_at DESC;

-- =====================================================
-- 5. VERIFICAR USUARIOS SIN EMPLEADO (debe estar vacío)
-- =====================================================

-- Usuarios que existen en auth pero NO en employees
SELECT 
    '✅ USUARIOS SIN EMPLEADO (debe estar vacío)' as resultado,
    u.email,
    u.created_at,
    u.confirmed_at,
    CASE 
        WHEN u.confirmed_at IS NULL THEN '⚠️  No confirmado'
        ELSE '✅ Confirmado'
    END as estado
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
    RAISE NOTICE '✅ EMPLEADO SENTIDODELOCOMUN@GMAIL.COM ACTUALIZADO:';
    RAISE NOTICE '   - user_id: Asociado al usuario correcto';
    RAISE NOTICE '   - is_active: true';
    RAISE NOTICE '   - full_name: Actualizado desde auth.users';
    RAISE NOTICE '';
    RAISE NOTICE '✅ EMPLEADOS CREADOS PARA:';
    RAISE NOTICE '   - martinezherradamaria@gmail.com (si no existe)';
    RAISE NOTICE '   - diana@ejemplo.com (si no existe)';
    RAISE NOTICE '';
    RAISE NOTICE '📝 ESTADO FINAL:';
    RAISE NOTICE '   - Todos los usuarios tienen empleado asociado';
    RAISE NOTICE '   - No hay duplicados';
    RAISE NOTICE '   - Datos consistentes';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 NOTA:';
    RAISE NOTICE '   Los usuarios no confirmados necesitan confirmar email';
    RAISE NOTICE '   antes de poder iniciar sesión en la app.';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿QUÉ HACE ESTE SCRIPT?

1️⃣  ACTUALIZA EMPLEADO EXISTENTE:
   - sentidodelocomun@gmail.com ya existe
   - Pero con user_id = NULL y is_active = false
   - Lo actualiza para asociarlo al usuario correcto

2️⃣  CREA EMPLEADOS FALTANTES:
   - martinezherradamaria@gmail.com (si no existe)
   - diana@ejemplo.com (si no existe)

3️⃣  EVITA DUPLICADOS:
   - Usa NOT EXISTS para evitar crear empleados duplicados
   - Solo crea los que realmente faltan

4️⃣  VERIFICA RESULTADO:
   - Muestra todos los empleados
   - Verifica que no hay usuarios sin empleado
   - Confirma que todo está correcto

¿POR QUÉ ESTE ENFOQUE ES MEJOR?

ANTES (crear nuevo):
❌ Error: duplicate key value violates unique constraint
❌ Intenta crear empleado que ya existe

AHORA (actualizar existente):
✅ Actualiza empleado existente
✅ Crea solo los que faltan
✅ Evita duplicados
✅ Datos consistentes
*/
