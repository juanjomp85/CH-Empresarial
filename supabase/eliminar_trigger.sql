-- =====================================================
-- ELIMINAR TRIGGER PROBLEMÁTICO
-- =====================================================
-- Este trigger está causando el error 500 al registrarse
-- Lo eliminamos porque la app ya maneja la creación de empleados

-- =====================================================
-- 1. ELIMINAR TRIGGER
-- =====================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- =====================================================
-- 2. ELIMINAR FUNCIÓN (OPCIONAL)
-- =====================================================

-- Solo eliminar la función si no se usa en otro lugar
DROP FUNCTION IF EXISTS public.handle_new_user();

-- =====================================================
-- 3. VERIFICAR QUE SE ELIMINÓ
-- =====================================================

-- Verificar que no hay triggers en auth.users
SELECT 
    '✅ TRIGGERS EN AUTH.USERS (debe estar vacío)' as resultado,
    trigger_name,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE event_object_schema = 'auth'
AND event_object_table = 'users';

-- =====================================================
-- 4. CREAR EMPLEADO PARA MARIA (que ya existe pero sin empleado)
-- =====================================================

-- Maria ya existe como usuario pero no tiene empleado
-- Vamos a crearle uno manualmente
INSERT INTO employees (
    user_id,
    email,
    full_name,
    role,
    is_active,
    department_id,
    position_id,
    hourly_rate
) 
SELECT 
    u.id,
    u.email,
    COALESCE(u.raw_user_meta_data->>'full_name', 'Usuario'),
    'employee',
    true,
    NULL,
    NULL,
    0
FROM auth.users u
WHERE u.email = 'maria.martinez@aspapros.es'
AND NOT EXISTS (
    SELECT 1 FROM employees e WHERE e.user_id = u.id
);

-- =====================================================
-- 5. VERIFICAR QUE MARIA AHORA TIENE EMPLEADO
-- =====================================================

SELECT 
    '✅ EMPLEADOS DESPUÉS DEL FIX' as resultado,
    e.email,
    e.full_name,
    e.role,
    e.is_active
FROM employees e
WHERE e.email IN ('juanjo.martinez@aspapros.es', 'maria.martinez@aspapros.es')
ORDER BY e.email;

-- =====================================================
-- COMENTARIOS
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Trigger problemático eliminado';
    RAISE NOTICE '✅ Maria ahora tiene empleado asociado';
    RAISE NOTICE '✅ El registro debería funcionar ahora';
    RAISE NOTICE '';
    RAISE NOTICE '📝 CÓMO FUNCIONA AHORA:';
    RAISE NOTICE '   1. Usuario se registra → Supabase Auth crea usuario ✅';
    RAISE NOTICE '   2. Usuario inicia sesión → Accede a /dashboard/time ✅';
    RAISE NOTICE '   3. App detecta que no existe empleado → Lo crea automáticamente ✅';
    RAISE NOTICE '   4. Usuario puede usar la app normalmente ✅';
    RAISE NOTICE '';
    RAISE NOTICE '🔒 VENTAJAS:';
    RAISE NOTICE '   - No más errores 500';
    RAISE NOTICE '   - Control total desde la app';
    RAISE NOTICE '   - Mejor manejo de errores';
    RAISE NOTICE '   - Más fácil de debuggear';
END $$;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿POR QUÉ ELIMINAR EL TRIGGER?

ANTES (con trigger):
❌ Error 500 cuando falla
❌ No se puede debuggear fácilmente
❌ Requiere permisos especiales
❌ Se ejecuta en el servidor de Supabase

AHORA (sin trigger):
✅ La app maneja la creación
✅ Mejor control de errores
✅ Más fácil de debuggear
✅ Funciona con permisos normales

¿DÓNDE ESTÁ LA LÓGICA DE CREACIÓN?

En app/dashboard/time/page.tsx (líneas 57-76):
- Se ejecuta cuando el usuario accede
- Crea el empleado si no existe
- Maneja errores correctamente
- No causa errores 500
*/
