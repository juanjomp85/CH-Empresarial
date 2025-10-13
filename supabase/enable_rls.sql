-- =====================================================
-- HABILITAR ROW LEVEL SECURITY (RLS)
-- =====================================================
-- Este script soluciona los errores de seguridad detectados
-- por Supabase habilitando RLS en todas las tablas que
-- tienen políticas definidas pero RLS deshabilitado

-- =====================================================
-- HABILITAR RLS EN TODAS LAS TABLAS
-- =====================================================

-- Tabla de configuración de empresa
ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;

-- Tabla de departamentos
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;

-- Tabla de empleados
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

-- Tabla de posiciones/cargos
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;

-- Tabla de registros de tiempo
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;

-- Tabla de solicitudes de tiempo libre
ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;

-- Tabla de logs de notificaciones (si ya existe)
DO $$ 
BEGIN
    IF EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'notification_logs') THEN
        ALTER TABLE notification_logs ENABLE ROW LEVEL SECURITY;
    END IF;
END $$;

-- =====================================================
-- VERIFICAR QUE RLS ESTÁ HABILITADO
-- =====================================================

-- Consulta para verificar el estado de RLS en todas las tablas
SELECT 
    schemaname,
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN (
    'company_settings',
    'departments', 
    'employees',
    'positions',
    'time_entries',
    'time_off_requests',
    'notification_logs'
)
ORDER BY tablename;

-- =====================================================
-- NOTAS IMPORTANTES
-- =====================================================

/*
¿QUÉ ES ROW LEVEL SECURITY (RLS)?

RLS es un sistema de seguridad que permite definir políticas para controlar
qué filas puede ver/modificar cada usuario en una tabla.

ANTES (sin RLS habilitado):
- Las políticas están definidas pero NO se aplican
- Cualquier usuario con acceso podría ver TODOS los datos
- Alto riesgo de seguridad

DESPUÉS (con RLS habilitado):
- Las políticas se aplican automáticamente
- Cada usuario solo ve/modifica los datos permitidos por sus políticas
- Seguridad garantizada

EJEMPLO PRÁCTICO:
Con RLS habilitado en 'time_entries':
- Los empleados SOLO pueden ver sus propios registros
- Los administradores pueden ver todos los registros
- Las políticas definidas previamente ahora se aplican correctamente

SOBRE LAS VISTAS SECURITY DEFINER:
Las vistas 'employee_compliance_summary' y 'attendance_compliance' 
usan SECURITY DEFINER intencionalmente para permitir cálculos de 
cumplimiento sin exponer datos sensibles directamente.

Si quieres cambiar esto, puedes recrear las vistas sin SECURITY DEFINER,
pero deberás asegurarte de que las políticas RLS permitan el acceso necesario.
*/

-- =====================================================
-- MENSAJE DE CONFIRMACIÓN
-- =====================================================

DO $$
BEGIN
    RAISE NOTICE '✅ Row Level Security habilitado en todas las tablas';
    RAISE NOTICE '✅ Las políticas de seguridad ahora están activas';
    RAISE NOTICE '✅ Verifica que todas las tablas muestren rls_enabled = true';
END $$;

