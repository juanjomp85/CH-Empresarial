-- 🔍 DIAGNÓSTICO: Verificar si el cierre automático se está aplicando 2 o 4 horas después
-- Fecha: 21 de octubre de 2025

-- Configurar zona horaria
SET timezone = 'Europe/Madrid';

-- =====================================
-- 1. VERIFICAR HORA ACTUAL Y ZONA HORARIA
-- =====================================
SELECT 
    '1. VERIFICACIÓN DE HORA ACTUAL Y DESFASE' as seccion,
    NOW() as hora_utc,
    NOW() AT TIME ZONE 'Europe/Madrid' as hora_madrid,
    CURRENT_DATE as fecha_utc,
    (NOW() AT TIME ZONE 'Europe/Madrid')::DATE as fecha_madrid,
    current_setting('timezone') as zona_horaria_configurada,
    -- Mostrar si hay desfase entre CURRENT_DATE y la fecha en Madrid
    CASE 
        WHEN CURRENT_DATE = (NOW() AT TIME ZONE 'Europe/Madrid')::DATE 
        THEN '✅ Sin desfase de fecha'
        ELSE '⚠️ HAY DESFASE: CURRENT_DATE usa UTC, no zona local'
    END as diagnostico_desfase;

-- =====================================
-- 2. VER CIERRES AUTOMÁTICOS RECIENTES
-- =====================================
SELECT 
    '2. CIERRES AUTOMÁTICOS REGISTRADOS HOY' as seccion;

SELECT 
    e.full_name as empleado,
    ds.end_time as hora_fin_programada,
    te.clock_out as hora_cierre_automatico,
    nl.sent_at as cuando_se_registro,
    -- Calcular las horas entre fin programado y cierre automático
    EXTRACT(HOUR FROM (te.clock_out - (CURRENT_DATE + ds.end_time))) as horas_diferencia,
    EXTRACT(MINUTE FROM (te.clock_out - (CURRENT_DATE + ds.end_time))) as minutos_diferencia,
    -- Verificar si es 2 o 4 horas
    CASE 
        WHEN EXTRACT(HOUR FROM (te.clock_out - (CURRENT_DATE + ds.end_time))) = 2 
        THEN '✅ Correcto: 2 horas después'
        WHEN EXTRACT(HOUR FROM (te.clock_out - (CURRENT_DATE + ds.end_time))) = 4 
        THEN '❌ ERROR: 4 horas después'
        ELSE '⚠️ Otro valor: revisar'
    END as diagnostico
FROM time_entries te
JOIN employees e ON te.employee_id = e.id
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
LEFT JOIN notification_logs nl ON nl.employee_id = e.id 
    AND nl.notification_type = 'auto_clock_out'
    AND DATE(nl.sent_at) = te.date
WHERE te.date >= CURRENT_DATE - INTERVAL '7 days'
AND te.clock_out IS NOT NULL
AND nl.notification_type = 'auto_clock_out'
ORDER BY te.date DESC, te.clock_out DESC
LIMIT 20;

-- =====================================
-- 3. SIMULAR: ¿Cuándo SE CERRARÍA una jornada?
-- =====================================
SELECT 
    '3. SIMULACIÓN: Jornadas que serían cerradas automáticamente AHORA' as seccion;

-- Simular con un horario de fin a las 18:00
WITH test_cases AS (
    SELECT 
        '18:00:00'::TIME as hora_fin,
        'Jornada normal (fin 18:00)' as caso
    UNION ALL
    SELECT 
        '14:00:00'::TIME as hora_fin,
        'Jornada reducida (fin 14:00)' as caso
    UNION ALL
    SELECT 
        '23:00:00'::TIME as hora_fin,
        'Jornada nocturna (fin 23:00)' as caso
)
SELECT 
    tc.caso,
    tc.hora_fin as hora_fin_programada,
    (CURRENT_DATE + tc.hora_fin) as timestamp_fin,
    (CURRENT_DATE + tc.hora_fin + INTERVAL '2 hours') as cierre_automatico_a_las,
    (CURRENT_DATE + tc.hora_fin + INTERVAL '4 hours') as si_fuera_4_horas_seria,
    (NOW() AT TIME ZONE 'Europe/Madrid') as hora_actual,
    -- Verificar si YA DEBERÍA cerrarse con 2 horas
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + tc.hora_fin + INTERVAL '2 hours')
        THEN '🔴 SÍ: Con regla de 2 horas'
        ELSE '🟢 NO: Todavía no (2 horas)'
    END as se_cerraria_con_2h,
    -- Verificar si YA DEBERÍA cerrarse con 4 horas
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + tc.hora_fin + INTERVAL '4 hours')
        THEN '🔴 SÍ: Con regla de 4 horas'
        ELSE '🟢 NO: Todavía no (4 horas)'
    END as se_cerraria_con_4h
FROM test_cases tc;

-- =====================================
-- 4. VERIFICAR LA CONDICIÓN ACTUAL EN LA FUNCIÓN
-- =====================================
SELECT 
    '4. VERIFICACIÓN DE LA CONDICIÓN SQL EN auto_generate_clock_out()' as seccion;

-- Buscar empleados que coincidan con la condición actual
WITH employee_schedules AS (
    SELECT 
        e.id as emp_id,
        e.full_name,
        e.email,
        d.name as dept_name,
        ds.end_time,
        ds.day_of_week,
        ds.is_working_day
    FROM employees e
    LEFT JOIN department_schedules ds ON e.department_id = ds.department_id
    LEFT JOIN departments d ON e.department_id = d.id
    WHERE e.is_active = true
    AND ds.is_working_day = true
    AND ds.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
),
todays_entries AS (
    SELECT 
        te.employee_id,
        te.clock_in,
        te.clock_out,
        te.date
    FROM time_entries te
    WHERE te.date = CURRENT_DATE
)
SELECT 
    es.full_name as empleado,
    es.end_time as hora_fin_programada,
    te.clock_in as fichaje_entrada,
    te.clock_out as fichaje_salida,
    -- Calcular cuándo debería cerrarse con la fórmula ACTUAL
    (CURRENT_DATE + es.end_time + INTERVAL '2 hours') as cierre_con_formula_actual,
    (NOW() AT TIME ZONE 'Europe/Madrid') as hora_actual,
    -- Verificar si cumple la condición ACTUAL (2 horas)
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + es.end_time + INTERVAL '2 hours')
        THEN '✅ CUMPLE condición (>= 2 horas)'
        ELSE '❌ NO CUMPLE (< 2 horas)'
    END as cumple_condicion_2h,
    -- Verificar si cumpliría con 4 horas
    CASE 
        WHEN (NOW() AT TIME ZONE 'Europe/Madrid') >= (CURRENT_DATE + es.end_time + INTERVAL '4 hours')
        THEN '✅ CUMPLE condición (>= 4 horas)'
        ELSE '❌ NO CUMPLE (< 4 horas)'
    END as cumple_condicion_4h
FROM employee_schedules es
LEFT JOIN todays_entries te ON es.emp_id = te.employee_id
WHERE te.clock_in IS NOT NULL
ORDER BY es.end_time;

-- =====================================
-- 5. ANÁLISIS DE LOS ÚLTIMOS CIERRES AUTOMÁTICOS
-- =====================================
SELECT 
    '5. ANÁLISIS DETALLADO: Últimos 10 cierres automáticos' as seccion;

SELECT 
    DATE(nl.sent_at) as fecha,
    e.full_name as empleado,
    te.clock_in as entrada,
    te.clock_out as salida_auto,
    ds.end_time as fin_programado,
    -- Calcular qué hora DEBERÍA ser con 2 horas
    (te.date + ds.end_time + INTERVAL '2 hours') as deberia_ser_con_2h,
    -- Calcular qué hora SERÍA con 4 horas
    (te.date + ds.end_time + INTERVAL '4 hours') as seria_con_4h,
    -- Comparar con la salida real
    CASE 
        WHEN te.clock_out = (te.date + ds.end_time + INTERVAL '2 hours')
        THEN '✅ CORRECTO: Se aplicó 2 horas'
        WHEN te.clock_out = (te.date + ds.end_time + INTERVAL '4 hours')
        THEN '❌ ERROR: Se aplicó 4 horas'
        ELSE '⚠️ OTRO: ' || te.clock_out::TEXT
    END as verificacion,
    -- Calcular la diferencia real
    EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time))) || ' horas ' ||
    EXTRACT(MINUTE FROM (te.clock_out - (te.date + ds.end_time))) || ' minutos' as diferencia_real
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
JOIN time_entries te ON te.employee_id = e.id AND DATE(nl.sent_at) = te.date
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
WHERE nl.notification_type = 'auto_clock_out'
AND nl.sent_at >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY nl.sent_at DESC
LIMIT 10;

-- =====================================
-- CONCLUSIONES Y RECOMENDACIONES
-- =====================================
SELECT 
    '6. RESUMEN DEL DIAGNÓSTICO' as seccion,
    '
    ✅ VERIFICACIONES REALIZADAS:
    - Zona horaria configurada
    - Hora actual del sistema (UTC vs Europe/Madrid)
    - Desfase de fecha entre CURRENT_DATE y fecha local
    - Cierres automáticos registrados (últimos 7 días)
    - Simulación de condiciones
    - Análisis de diferencias reales
    
    📊 INTERPRETACIÓN:
    - Si "diferencia_real" muestra "2 horas": ✅ Funcionamiento correcto
    - Si "diferencia_real" muestra "~4 horas": ❌ Problema de zona horaria con CURRENT_DATE
    
    🔧 CAUSA PRINCIPAL DEL PROBLEMA DE 4 HORAS:
    ❌ Uso de CURRENT_DATE (que retorna fecha en UTC)
    ✅ Solución: Usar (NOW() AT TIME ZONE ''Europe/Madrid'')::DATE
    
    El desfase de ~4 horas se debe a:
    - CURRENT_DATE está en UTC
    - Europe/Madrid es UTC+1 (invierno) o UTC+2 (verano)
    - Al sumar CURRENT_DATE + hora + INTERVAL ''2 hours'', se acumulan los desfases
    - Resultado: ~2h (zona horaria) + 2h (intervalo) = ~4h total
    
    📝 CORRECCIÓN APLICADA:
    1. Línea 293: Usar (NOW() AT TIME ZONE ''Europe/Madrid'')::DATE en lugar de CURRENT_DATE
    2. Línea 299: Usar te.date en lugar de CURRENT_DATE
    3. Línea 279: Filtrar por (NOW() AT TIME ZONE ''Europe/Madrid'')::DATE
    4. Línea 270: Día de semana usando zona horaria local
    
    ' as informacion;

