-- =====================================================
-- SCRIPT DE VERIFICACIÓN: Corrección de Absentismo
-- =====================================================
-- Este script verifica que el cálculo de absentismo
-- funciona correctamente después de aplicar los cambios
-- Fecha: 20 de octubre de 2025

SET timezone = 'Europe/Madrid';

-- =====================================================
-- 1. INFORMACIÓN DEL SISTEMA
-- =====================================================
SELECT 
    'INFORMACIÓN DEL SISTEMA' as seccion,
    '---' as separador;

SELECT 
    CURRENT_DATE as fecha_actual,
    CURRENT_DATE - INTERVAL '1 day' as fecha_limite_reportes,
    TO_CHAR(CURRENT_DATE, 'Day') as dia_actual,
    EXTRACT(DOW FROM CURRENT_DATE)::INTEGER as dia_semana_numero,
    'El día actual NO debe aparecer en los reportes' as nota_importante;

-- =====================================================
-- 2. VER EMPLEADOS ACTIVOS Y SUS DEPARTAMENTOS
-- =====================================================
SELECT 
    '---' as separador,
    'EMPLEADOS ACTIVOS' as seccion;

SELECT 
    e.id as employee_id,
    e.full_name,
    e.email,
    d.name as departamento,
    e.is_active
FROM employees e
LEFT JOIN departments d ON e.department_id = d.id
WHERE e.is_active = true
ORDER BY e.full_name;

-- =====================================================
-- 3. HORARIOS CONFIGURADOS POR DEPARTAMENTO
-- =====================================================
SELECT 
    '---' as separador,
    'HORARIOS CONFIGURADOS' as seccion;

SELECT 
    d.name as departamento,
    CASE ds.day_of_week
        WHEN 0 THEN 'Domingo'
        WHEN 1 THEN 'Lunes'
        WHEN 2 THEN 'Martes'
        WHEN 3 THEN 'Miércoles'
        WHEN 4 THEN 'Jueves'
        WHEN 5 THEN 'Viernes'
        WHEN 6 THEN 'Sábado'
    END as dia,
    ds.start_time as entrada,
    ds.end_time as salida,
    ds.is_working_day as laboral
FROM department_schedules ds
JOIN departments d ON ds.department_id = d.id
ORDER BY d.name, ds.day_of_week;

-- =====================================================
-- 4. FICHAJES DE LA ÚLTIMA SEMANA
-- =====================================================
SELECT 
    '---' as separador,
    'FICHAJES ÚLTIMA SEMANA' as seccion;

SELECT 
    e.full_name as empleado,
    te.date as fecha,
    TO_CHAR(te.date, 'Day') as dia,
    te.clock_in AT TIME ZONE 'Europe/Madrid' as entrada,
    te.clock_out AT TIME ZONE 'Europe/Madrid' as salida,
    te.total_hours as horas
FROM time_entries te
JOIN employees e ON te.employee_id = e.id
WHERE te.date >= CURRENT_DATE - INTERVAL '7 days'
AND te.date < CURRENT_DATE  -- Solo días pasados
ORDER BY te.date DESC, e.full_name;

-- =====================================================
-- 5. TEST: Función con Rango de Últimos 7 Días
-- =====================================================
SELECT 
    '---' as separador,
    'TEST FUNCIÓN: Últimos 7 días (un empleado)' as seccion;

-- Cambiar por el ID de un empleado real
-- Puedes obtenerlo de la sección 2
DO $$
DECLARE
    test_employee_id UUID;
BEGIN
    -- Obtener el primer empleado activo
    SELECT id INTO test_employee_id
    FROM employees
    WHERE is_active = true
    LIMIT 1;
    
    -- Mostrar ID del empleado de prueba
    RAISE NOTICE 'Probando con employee_id: %', test_employee_id;
END $$;

-- Ejecutar la función para un empleado
-- IMPORTANTE: Reemplaza 'TU_EMPLOYEE_ID' con un ID real de la sección 2
-- SELECT * FROM get_employee_compliance(
--     'REEMPLAZA_CON_ID_REAL'::UUID,
--     CURRENT_DATE - INTERVAL '7 days',
--     CURRENT_DATE
-- );

-- =====================================================
-- 6. VERIFICACIÓN: ¿El día actual aparece?
-- =====================================================
SELECT 
    '---' as separador,
    'VERIFICACIÓN: El día actual NO debe aparecer' as seccion;

-- Este query debe retornar 0 filas si la corrección funciona
-- SELECT 
--     date,
--     '❌ ERROR: El día actual NO debe aparecer en el reporte' as problema
-- FROM get_employee_compliance(
--     'REEMPLAZA_CON_ID_REAL'::UUID,
--     CURRENT_DATE - INTERVAL '7 days',
--     CURRENT_DATE
-- )
-- WHERE date = CURRENT_DATE;

-- Si retorna 0 filas = ✅ Correcto
-- Si retorna 1+ filas = ❌ Error, el día actual aparece

-- =====================================================
-- 7. COMPARACIÓN: Antes vs Después
-- =====================================================
SELECT 
    '---' as separador,
    'COMPARACIÓN DE RESULTADOS' as seccion;

SELECT 
    'La función debe retornar TODAS las fechas del rango (excepto hoy)' as verificacion_1,
    'Los días sin fichaje deben mostrar arrival_status = AUSENTE' as verificacion_2,
    'Los fines de semana deben mostrar arrival_status = DIA_NO_LABORAL' as verificacion_3,
    'El día actual (hoy) NO debe aparecer en los resultados' as verificacion_4;

-- =====================================================
-- 8. CÁLCULO MANUAL DE ABSENTISMO
-- =====================================================
SELECT 
    '---' as separador,
    'CÁLCULO MANUAL DE ABSENTISMO (últimos 7 días)' as seccion;

-- Para verificar que el cálculo es correcto
WITH date_series AS (
    SELECT generate_series(
        (CURRENT_DATE - INTERVAL '7 days')::DATE,
        (CURRENT_DATE - INTERVAL '1 day')::DATE,
        '1 day'::INTERVAL
    )::DATE as date_val
),
stats AS (
    SELECT 
        e.id,
        e.full_name,
        COUNT(CASE WHEN ds.is_working_day THEN 1 END) as dias_laborables_en_periodo,
        COUNT(CASE WHEN te.date IS NOT NULL AND ds.is_working_day THEN 1 END) as dias_fichados,
        COUNT(CASE WHEN te.date IS NULL AND ds.is_working_day THEN 1 END) as dias_ausentes
    FROM employees e
    CROSS JOIN date_series
    LEFT JOIN department_schedules ds 
        ON ds.department_id = e.department_id
        AND ds.day_of_week = EXTRACT(DOW FROM date_series.date_val)::INTEGER
    LEFT JOIN time_entries te 
        ON te.employee_id = e.id 
        AND te.date = date_series.date_val
    WHERE e.is_active = true
    GROUP BY e.id, e.full_name
)
SELECT 
    full_name as empleado,
    dias_laborables_en_periodo as total_dias_lab,
    dias_fichados as dias_con_fichaje,
    dias_ausentes as dias_sin_fichaje,
    CASE 
        WHEN dias_laborables_en_periodo > 0 
        THEN ROUND((dias_ausentes::NUMERIC / dias_laborables_en_periodo * 100), 1)
        ELSE 0
    END as absentismo_porcentaje
FROM stats
ORDER BY absentismo_porcentaje DESC;

-- =====================================================
-- 9. INSTRUCCIONES DE USO
-- =====================================================
SELECT 
    '---' as separador,
    'INSTRUCCIONES' as seccion;

SELECT 
    'PASO 1: Ejecuta las secciones 1-5 para ver el estado actual' as paso,
    'PASO 2: Copia un employee_id de la sección 2' as paso_2,
    'PASO 3: Reemplaza TU_EMPLOYEE_ID en las queries comentadas (líneas 94 y 116)' as paso_3,
    'PASO 4: Descomenta y ejecuta esas queries' as paso_4,
    'PASO 5: Verifica que el día actual NO aparece (sección 6)' as paso_5,
    'PASO 6: Verifica que días sin fichaje muestran AUSENTE' as paso_6;

-- =====================================================
-- 10. EJEMPLO DE USO COMPLETO
-- =====================================================
-- Para probar con un empleado específico, usa esta query:
-- 
-- SELECT 
--     date as fecha,
--     TO_CHAR(date, 'Day') as dia,
--     is_working_day as laboral,
--     expected_start_time as entrada_esperada,
--     expected_end_time as salida_esperada,
--     clock_in AT TIME ZONE 'Europe/Madrid' as entrada_real,
--     clock_out AT TIME ZONE 'Europe/Madrid' as salida_real,
--     arrival_status as estado,
--     CASE 
--         WHEN date = CURRENT_DATE THEN '❌ NO DEBERÍA APARECER'
--         WHEN date = CURRENT_DATE - 1 THEN '✅ Ayer'
--         WHEN arrival_status = 'AUSENTE' THEN '✅ Ausencia detectada correctamente'
--         WHEN arrival_status = 'DIA_NO_LABORAL' THEN '✅ Fin de semana'
--         ELSE '✅ OK'
--     END as verificacion
-- FROM get_employee_compliance(
--     'REEMPLAZA_CON_ID_REAL'::UUID,
--     CURRENT_DATE - INTERVAL '7 days',
--     CURRENT_DATE
-- )
-- ORDER BY date DESC;

-- =====================================================
-- RESULTADO ESPERADO
-- =====================================================
SELECT 
    '---' as separador,
    'RESULTADO ESPERADO' as seccion;

SELECT 
    '✅ Cada día laboral del rango debe aparecer (excepto hoy)' as check_1,
    '✅ Días sin fichaje deben mostrar arrival_status = AUSENTE' as check_2,
    '✅ El cálculo de absentismo debe ser correcto' as check_3,
    '✅ El día actual NO debe aparecer en los resultados' as check_4,
    '✅ Los reportes en la app deben mostrar las ausencias' as check_5;

