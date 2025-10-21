# 🚨 Fix Crítico: Almacenamiento Incorrecto de clock_out

**Fecha de detección**: 21 de octubre de 2025 - 20:05h  
**Reportado por**: Usuario en producción (Diana Pina)  
**Severidad**: 🔴 CRÍTICA

---

## 🐛 Problema Detectado en Producción

### Síntomas observados:
- El cierre automático se **ejecuta a la hora correcta** (ej: 20:05)
- PERO el valor almacenado en `clock_out` es **2 horas mayor** (ej: 22:00)

### Ejemplo real:
```
Empleada: Diana Pina
Fecha: 21 de octubre de 2025
Entrada: 10:05
Hora de fin programada: ~18:00 (estimado)
Hora esperada de cierre automático: 20:00 (18:00 + 2h)

✅ El cierre se ejecutó a las 20:05 (correcto - 5 min después de las 2h)
❌ El clock_out almacenado fue: 22:00 (incorrecto - 2 horas de más)
```

### Verificación realizada:
- Usuario verificó a las **20:05** → El sistema ya mostraba cierre a las **22:00**
- Esto confirma que el problema NO es cuándo se ejecuta, sino **qué valor se almacena**

---

## 🔍 Diagnóstico Técnico

### Causa raíz:
PostgreSQL estaba interpretando el timestamp calculado como **UTC** en lugar de **Europe/Madrid**.

### Código problemático (línea 303 - ANTES):
```sql
clock_out = employee_record.entry_date + employee_record.expected_clock_out + INTERVAL '2 hours'
```

### Flujo del error:
1. `employee_record.entry_date` = `DATE` (ej: 2025-10-21)
2. `employee_record.expected_clock_out` = `TIME` (ej: 18:00:00)
3. `DATE + TIME` = `TIMESTAMP` sin zona horaria (ej: 2025-10-21 18:00:00)
4. `+ INTERVAL '2 hours'` = `2025-10-21 20:00:00` (aún sin zona horaria)
5. Al insertar en `clock_out` (columna tipo `TIMESTAMPTZ`):
   - PostgreSQL asume que es **UTC**
   - Convierte a hora local: `20:00 UTC` → `22:00 Europe/Madrid` ❌

### Resultado:
- **Hora calculada**: 20:00 (correcta)
- **Hora almacenada**: 22:00 (incorrecta +2h)

---

## ✅ Solución Implementada

### Código corregido (línea 304 - DESPUÉS):
```sql
clock_out = timezone('Europe/Madrid', employee_record.entry_date + employee_record.expected_clock_out + INTERVAL '2 hours')
```

### Cómo funciona `timezone()`:
```sql
-- timezone(zone, timestamp) crea un TIMESTAMPTZ en la zona especificada
timezone('Europe/Madrid', '2025-10-21 20:00:00')
-- Retorna: 2025-10-21 20:00:00+02 (en verano) o +01 (en invierno)
-- Al almacenar: Se guarda 20:00 en hora local ✅
```

### Flujo corregido:
1. `employee_record.entry_date` = `2025-10-21`
2. `employee_record.expected_clock_out` = `18:00:00`
3. `DATE + TIME + INTERVAL '2 hours'` = `2025-10-21 20:00:00`
4. `timezone('Europe/Madrid', ...)` = `2025-10-21 20:00:00+02`
5. Se almacena: **20:00 en hora local** ✅

---

## 📋 Cómo Aplicar la Corrección

### Paso 1: Actualizar la función en Supabase
```bash
1. Abre el SQL Editor en tu dashboard de Supabase
2. Copia y ejecuta TODO el contenido de: supabase/notifications.sql
3. Verifica que se ejecute sin errores
```

### Paso 2: Verificar la corrección
Ejecuta esta query para verificar que los **nuevos** cierres automáticos se almacenan correctamente:

```sql
-- Ver los últimos cierres automáticos
SELECT 
    e.full_name,
    te.date,
    ds.end_time as fin_programado,
    te.clock_out as cierre_registrado,
    -- Calcular cuándo DEBERÍA haberse cerrado
    (te.date + ds.end_time + INTERVAL '2 hours') as deberia_ser,
    -- Calcular la diferencia
    EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time + INTERVAL '2 hours'))) as diferencia_horas,
    -- Verificación
    CASE 
        WHEN EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time + INTERVAL '2 hours'))) = 0
        THEN '✅ CORRECTO'
        WHEN EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time + INTERVAL '2 hours'))) = 2
        THEN '❌ ERROR: +2 horas (aún con bug)'
        ELSE '⚠️ Revisar'
    END as estado
FROM time_entries te
JOIN employees e ON te.employee_id = e.id
LEFT JOIN department_schedules ds ON e.department_id = ds.department_id 
    AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
JOIN notification_logs nl ON nl.employee_id = e.id 
    AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
    AND nl.notification_type = 'auto_clock_out'
WHERE te.clock_out IS NOT NULL
AND nl.sent_at >= NOW() - INTERVAL '3 days'
ORDER BY nl.sent_at DESC
LIMIT 10;
```

### Paso 3: Monitorear
- Espera al próximo cierre automático (máximo 2 días)
- Ejecuta la query de verificación
- Los **nuevos** cierres deben mostrar "✅ CORRECTO"
- Los **antiguos** (como Diana Pina) seguirán mostrando "❌ ERROR" (es normal)

---

## 🔧 Corrección de Datos Históricos (OPCIONAL)

Si quieres corregir los registros afectados históricos:

```sql
-- ⚠️ CUIDADO: Esto modificará datos históricos
-- Solo ejecuta si estás seguro y has hecho backup

UPDATE time_entries te
SET clock_out = clock_out - INTERVAL '2 hours'
WHERE te.id IN (
    SELECT te.id
    FROM time_entries te
    JOIN notification_logs nl ON nl.employee_id = te.employee_id 
        AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
        AND nl.notification_type = 'auto_clock_out'
    LEFT JOIN department_schedules ds ON te.employee_id IN (
        SELECT id FROM employees WHERE department_id = ds.department_id
    ) AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
    WHERE EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time + INTERVAL '2 hours'))) = 2
    AND te.date >= '2025-10-01'  -- Solo corregir desde octubre
);

-- Verificar cuántos registros se corregirían (sin modificar):
SELECT COUNT(*) FROM time_entries te
JOIN notification_logs nl ON nl.employee_id = te.employee_id 
    AND DATE(nl.sent_at AT TIME ZONE 'Europe/Madrid') = te.date
    AND nl.notification_type = 'auto_clock_out'
LEFT JOIN department_schedules ds ON te.employee_id IN (
    SELECT id FROM employees WHERE department_id = ds.department_id
) AND ds.day_of_week = EXTRACT(DOW FROM te.date)::INTEGER
WHERE EXTRACT(HOUR FROM (te.clock_out - (te.date + ds.end_time + INTERVAL '2 hours'))) = 2
AND te.date >= '2025-10-01';
```

---

## 📊 Comparación Antes/Después

| Aspecto | Antes (con bug) | Después (corregido) |
|---------|----------------|---------------------|
| **Ejecución del cierre** | ✅ Correcta (20:05) | ✅ Correcta (20:05) |
| **Valor almacenado** | ❌ Incorrecto (22:00) | ✅ Correcto (20:00) |
| **Interpretación del timestamp** | UTC (por defecto) | Europe/Madrid (explícito) |
| **Conversión al almacenar** | +2 horas (bug) | Sin conversión (correcto) |

---

## ⚠️ Lecciones Aprendidas

1. **No es suficiente con calcular correctamente**: También hay que almacenar correctamente
2. **PostgreSQL y zonas horarias**: `TIMESTAMP` vs `TIMESTAMPTZ` requiere atención especial
3. **Usar `timezone()` explícitamente**: Cuando creas timestamps dinámicamente
4. **Importancia del testing en producción**: Este bug solo se detectó en uso real

---

## 🎯 Resumen Ejecutivo

### Problema:
- ❌ Cierre automático almacenaba `clock_out` con 2 horas de más

### Causa:
- ❌ PostgreSQL interpretaba el timestamp como UTC en lugar de Europe/Madrid

### Solución:
- ✅ Usar `timezone('Europe/Madrid', ...)` para crear el timestamp explícitamente

### Estado:
- ✅ Corregido en `supabase/notifications.sql` línea 304
- ⏳ Pendiente de aplicar en Supabase
- ⏳ Pendiente de verificar en próximo cierre automático

---

**Actualización**: 21 de octubre de 2025 - 20:30h  
**Archivo relacionado**: `supabase/notifications.sql`  
**Línea corregida**: 304  
**Impacto**: 🔴 CRÍTICO - Afecta a todos los cierres automáticos

