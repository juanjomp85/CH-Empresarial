-- =====================================================
-- FIX DE ZONA HORARIA PARA NOTIFICACIONES
-- =====================================================
-- Este script corrige el problema de zona horaria que causa
-- un retraso de 2 horas en el envío de notificaciones

-- 1. Configurar la zona horaria de la sesión actual
SET timezone = 'Europe/Madrid';

-- 2. Verificar la zona horaria actual
SELECT 
    current_setting('timezone') as current_timezone,
    NOW() as current_time_utc,
    NOW() AT TIME ZONE 'Europe/Madrid' as current_time_spain;

-- 3. Probar las funciones de notificación con la zona horaria correcta
-- (Descomenta las siguientes líneas para probar)
-- SELECT * FROM get_employees_needing_clock_in_reminder();
-- SELECT * FROM get_employees_needing_clock_out_reminder();

-- 4. Verificar que los horarios se calculan correctamente
SELECT 
    'Ejemplo de horario 10:00:00' as descripcion,
    '10:00:00'::TIME as hora_entrada,
    ('10:00:00'::TIME + INTERVAL '5 minutes') as hora_notificacion,
    (NOW() AT TIME ZONE 'Europe/Madrid')::TIME as hora_actual_espana,
    (NOW() AT TIME ZONE 'UTC')::TIME as hora_actual_utc;
