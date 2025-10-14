-- =====================================================
-- FIX: CREAR EMPLEADOS PARA USUARIOS SIN EMPLEADO
-- =====================================================
-- Script para crear empleados para usuarios que existen
-- en auth.users pero no tienen empleado asociado

-- =====================================================
-- 1. CREAR EMPLEADO PARA MARTINEZHERRADAMARIA@GMAIL.COM
-- =====================================================

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

-- =====================================================
-- 2. CREAR EMPLEADO PARA SENTIDODELOCOMUN@GMAIL.COM
-- =====================================================

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
WHERE u.email = 'sentidodelocomun@gmail.com'
AND NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.user_id = u.id
);

-- =====================================================
-- 3. CREAR EMPLEADO PARA DIANA@EJEMPLO.COM
-- =====================================================

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
-- 4. VERIFICAR QUE TODOS TIENEN EMPLEADO
-- =====================================================

-- Ver todos los empleados después del fix
SELECT 
    '✅ EMPLEADOS DESPUÉS DEL FIX' as resultado,
    e.email,
    e.full_name,
    e.role,
    e.is_active,
    e.created_at
FROM employees e
ORDER BY e.created_at DESC;

-- =====================================================
-- 5. VERIFICAR QUE NO HAY USUARIOS SIN EMPLEADO
-- =====================================================

-- Usuarios que existen en auth pero NO en employees (debe estar vacío)
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
-- 6. RESUMEN FINAL
-- =====================================================

-- Contar usuarios y empleados
SELECT 
    '📊 RESUMEN FINAL' as seccion,
    (SELECT COUNT(*) FROM auth.users) as total_usuarios,
    (SELECT COUNT(*) FROM employees) as total_empleados,
    (SELECT COUNT(*) FROM auth.users WHERE confirmed_at IS NOT NULL) as usuarios_confirmados,
    (SELECT COUNT(*) FROM employees WHERE is_active = true) as empleados_activos;

-- =====================================================
-- COMENTARIOS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '✅ EMPLEADOS CREADOS PARA:';
    RAISE NOTICE '   - martinezherradamaria@gmail.com';
    RAISE NOTICE '   - sentidodelocomun@gmail.com';
    RAISE NOTICE '   - diana@ejemplo.com';
    RAISE NOTICE '';
    RAISE NOTICE '📝 ESTADO DE CADA USUARIO:';
    RAISE NOTICE '   - martinezherradamaria@gmail.com: ✅ Confirmado + Empleado';
    RAISE NOTICE '   - sentidodelocomun@gmail.com: ⚠️  No confirmado + Empleado';
    RAISE NOTICE '   - diana@ejemplo.com: ⚠️  No confirmado + Empleado';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 NOTA IMPORTANTE:';
    RAISE NOTICE '   Los usuarios no confirmados necesitan confirmar su email';
    RAISE NOTICE '   antes de poder iniciar sesión en la app.';
    RAISE NOTICE '';
    RAISE NOTICE '✅ RESULTADO:';
    RAISE NOTICE '   Todos los usuarios ahora tienen empleado asociado';
    RAISE NOTICE '   y pueden usar la app (después de confirmar email si es necesario)';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿QUÉ HACE ESTE SCRIPT?

1️⃣  CREA EMPLEADOS FALTANTES:
   - martinezherradamaria@gmail.com (confirmado)
   - sentidodelocomun@gmail.com (no confirmado)
   - diana@ejemplo.com (no confirmado)

2️⃣  VERIFICA QUE TODO FUNCIONA:
   - Cuenta total de usuarios y empleados
   - Verifica que no hay usuarios sin empleado
   - Muestra el estado de cada usuario

3️⃣  RESULTADO ESPERADO:
   - Todos los usuarios tienen empleado asociado
   - Los usuarios confirmados pueden usar la app
   - Los usuarios no confirmados necesitan confirmar email

¿QUÉ PASA CON LOS USUARIOS NO CONFIRMADOS?

- ✅ Tienen empleado creado
- ⚠️  Necesitan confirmar email para iniciar sesión
- 📧 Deben revisar su email y hacer clic en el enlace de confirmación
- ✅ Después de confirmar, pueden usar la app normalmente

¿CÓMO CONFIRMAR EMAIL?

1. Usuario revisa su email
2. Busca el correo de Supabase
3. Hace clic en "Confirmar cuenta"
4. Es redirigido a la app
5. Puede iniciar sesión normalmente
*/
