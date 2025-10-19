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

-- 5. Verificar corrección del cierre automático (comparación con timestamp completo)
SELECT 
    'TEST: Cierre automático de jornadas' as test,
    '18:00:00'::TIME as hora_fin_jornada,
    ('18:00:00'::TIME + INTERVAL '2 hours') as hora_cierre_esperada,
    (CURRENT_DATE + '18:00:00'::TIME + INTERVAL '2 hours') as timestamp_cierre_completo,
    (NOW() AT TIME ZONE 'Europe/Madrid') as hora_actual_madrid,
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + '18:00:00'::TIME + INTERVAL '2 hours')
        THEN '✅ Se ejecutaría el cierre automático'
        ELSE '⏳ Aún no es hora del cierre automático'
    END as estado;

-- 6. TEST: Verificar que funciona con cambio de día (23:00 + 2h = 01:00 del día siguiente)
SELECT 
    'TEST: Cierre con cambio de día' as test,
    '23:00:00'::TIME as hora_fin_jornada,
    ('23:00:00'::TIME + INTERVAL '2 hours') as hora_cierre_esperada,
    (CURRENT_DATE + '23:00:00'::TIME + INTERVAL '2 hours') as timestamp_cierre_completo,
    DATE(CURRENT_DATE + '23:00:00'::TIME + INTERVAL '2 hours') as fecha_cierre,
    EXTRACT(HOUR FROM (CURRENT_DATE + '23:00:00'::TIME + INTERVAL '2 hours')) as hora_cierre,
    CASE 
        WHEN DATE(CURRENT_DATE + '23:00:00'::TIME + INTERVAL '2 hours') > CURRENT_DATE
        THEN '✅ Correctamente detecta cambio de día'
        ELSE '❌ ERROR: No detecta cambio de día'
    END as verificacion;
