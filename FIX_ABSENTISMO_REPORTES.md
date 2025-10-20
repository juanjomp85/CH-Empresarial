# 🔧 Corrección: Cálculo de Absentismo en Reportes

**Fecha**: 20 de octubre de 2025  
**Estado**: ✅ Corrección aplicada  
**Prioridad**: 🟡 MEDIA

---

## 🐛 Problema Identificado

### Síntoma
En el reporte de cumplimiento, el **Absentismo mostraba 0.0%** aunque había días laborales en los que el empleado no había fichado.

### Ejemplo Real
- **Usuario**: Juan Jose Martinez (Administrador)
- **Departamento**: Desarrollo
- **Horario**: Lunes a Viernes, 10:00 - 18:00
- **Fecha**: Lunes 20 de octubre de 2025
- **Estado**: No ha fichado
- **Resultado**: Absentismo: 0.0% ❌ (debería contar como ausencia)

### Causa Raíz

La función SQL `get_employee_compliance()` solo devolvía días que **ya existían en la tabla `time_entries`**.

**Cómo funcionaba ANTES**:
```sql
FROM employees e
LEFT JOIN time_entries te ON te.employee_id = e.id
```

Si un empleado no fichaba ningún día, **ese día simplemente no aparecía** en el reporte y **no se contaba como ausencia**.

---

## ✅ Solución Aplicada

### Enfoque: Generar Todos los Días del Rango (Hasta Ayer)

He modificado la función `get_employee_compliance()` para que:

1. ✅ **Genere todas las fechas** del rango solicitado
2. ✅ **Limite hasta AYER** (excluye el día actual)
3. ✅ Para cada fecha, obtenga el horario esperado del empleado
4. ✅ Haga LEFT JOIN con `time_entries` para ver si fichó
5. ✅ Marque como **'AUSENTE'** los días laborales sin fichaje

### ¿Por Qué Solo Hasta Ayer?

El día **actual NO se incluye** porque:
- ⏰ El día puede estar en curso (ejemplo: son las 11:00 AM)
- 🔄 El empleado todavía puede fichar
- ✅ Evita contar como ausencia un día incompleto
- ✅ Los reportes muestran solo días completos y definitivos

### Cómo Funciona DESPUÉS

```sql
WITH date_range AS (
    -- Generar TODAS las fechas (hasta ayer)
    SELECT generate_series(
        p_start_date,
        LEAST(p_end_date, CURRENT_DATE - INTERVAL '1 day'),
        '1 day'
    )::DATE AS date_val
),
daily_schedule AS (
    -- Para cada fecha, obtener horario esperado
    SELECT dr.date_val, ds.start_time, ds.end_time, ds.is_working_day
    FROM date_range dr
    LEFT JOIN department_schedules ds ON ...
)
SELECT ...
FROM daily_schedule
LEFT JOIN time_entries te ON te.date = dsch.date  -- Puede ser NULL
```

Ahora **cada día tiene una fila**, haya o no fichaje.

---

## 📊 Comparación: Antes vs Después

### Escenario: Empleado NO ficha varios días

**Rango**: 16 Oct - 20 Oct (5 días: Mié, Jue, Vie, Sáb, Dom, Lun)  
**Días laborales**: 16, 17, 18 Oct (Mié, Jue, Vie) - Lun 20 excluido (día actual)  
**Fichajes**: Solo fichó el 17 Oct

#### ANTES ❌
| Fecha | Aparece en Reporte | Estado |
|-------|-------------------|--------|
| 16 Oct | ❌ NO | No aparece |
| 17 Oct | ✅ SÍ | PUNTUAL |
| 18 Oct | ❌ NO | No aparece |
| 19 Oct (Sáb) | ❌ NO | Fin de semana |
| 20 Oct (Lun) | ❌ NO | No aparece |

**Resultado**:
- Total días laborales: 1 (solo cuenta el 17)
- Ausencias: 0
- Absentismo: **0.0%** ❌

---

#### DESPUÉS ✅
| Fecha | Aparece en Reporte | Estado |
|-------|-------------------|--------|
| 16 Oct | ✅ SÍ | **AUSENTE** |
| 17 Oct | ✅ SÍ | PUNTUAL |
| 18 Oct | ✅ SÍ | **AUSENTE** |
| 19 Oct (Sáb) | ✅ SÍ | DIA_NO_LABORAL |
| 20 Oct (Lun) | ❌ NO | Día actual (excluido) |

**Resultado**:
- Total días laborales: 3 (16, 17, 18 Oct)
- Días puntuales: 1 (17 Oct)
- Ausencias: **2** (16 y 18 Oct)
- Absentismo: **66.7%** ✅

---

## 📋 Cambios Realizados

### Archivo Modificado: `supabase/attendance_compliance.sql`

**Función modificada**: `get_employee_compliance()` (líneas 175-300)

**Cambios principales**:

1. **Nueva variable**: `v_end_date` - Limita a ayer
   ```sql
   v_end_date := LEAST(p_end_date, CURRENT_DATE - INTERVAL '1 day');
   ```

2. **CTE `date_range`**: Genera todas las fechas
   ```sql
   SELECT generate_series(p_start_date, v_end_date, '1 day')::DATE
   ```

3. **CTE `employee_info`**: Obtiene info del empleado
   ```sql
   SELECT id, department_id FROM employees WHERE id = p_employee_id
   ```

4. **CTE `daily_schedule`**: Horario esperado por fecha
   ```sql
   CROSS JOIN employee_info
   LEFT JOIN department_schedules ON day_of_week = EXTRACT(DOW FROM date)
   ```

5. **LEFT JOIN con time_entries**: Puede ser NULL
   ```sql
   LEFT JOIN time_entries te ON te.employee_id = p_employee_id AND te.date = dsch.date
   ```

6. **Lógica de estado**: Si no hay fichaje + es día laboral → 'AUSENTE'
   ```sql
   CASE 
       WHEN te.clock_in IS NULL AND dsch.is_working_day THEN 'AUSENTE'
       ...
   END
   ```

---

## 🚀 Pasos para Aplicar

### Paso 1: Actualizar Supabase (2 min)

1. Abre el **SQL Editor** en Supabase
2. Copia y ejecuta el contenido de: `supabase/attendance_compliance.sql`
3. Verifica que se ejecute sin errores

### Paso 2: Verificar los Cambios (2 min)

```sql
-- Probar la función con un rango que incluye hoy
SELECT * FROM get_employee_compliance(
    'TU_EMPLOYEE_ID'::UUID,
    '2025-10-16'::DATE,
    '2025-10-20'::DATE
);

-- Verificar que:
-- 1. Aparecen TODOS los días del rango (excepto hoy 20 Oct)
-- 2. Los días sin fichaje muestran estado 'AUSENTE'
-- 3. Los fines de semana muestran 'DIA_NO_LABORAL'
```

### Paso 3: Refrescar el Reporte en la App

1. Ve a **Dashboard → Reportes → Reporte de Cumplimiento**
2. Recarga la página (F5)
3. Verifica que ahora muestra:
   - ✅ Todos los días del rango (excepto hoy)
   - ✅ Ausencias contabilizadas correctamente
   - ✅ Porcentaje de absentismo correcto

---

## 🧪 Casos de Prueba

### Test 1: Empleado con Ausencias
```sql
-- Preparación: Empleado sin fichajes del 16-18 Oct
-- Ejecutar función para rango 16-20 Oct
-- Resultado esperado:
-- - 16 Oct: AUSENTE
-- - 17 Oct: AUSENTE
-- - 18 Oct: AUSENTE
-- - 19 Oct: DIA_NO_LABORAL
-- - 20 Oct: NO APARECE (día actual)
-- Absentismo: 100% (3 de 3 días laborales)
```

### Test 2: Empleado Puntual
```sql
-- Preparación: Empleado fichó todos los días
-- Resultado esperado:
-- - Todos los días: PUNTUAL
-- - Absentismo: 0%
```

### Test 3: Empleado con Mezcla
```sql
-- Preparación: Fichó 16 y 18, faltó 17
-- Resultado esperado:
-- - 16 Oct: PUNTUAL
-- - 17 Oct: AUSENTE
-- - 18 Oct: PUNTUAL
-- Absentismo: 33.3% (1 de 3)
```

### Test 4: Verificar que HOY no Cuenta
```sql
-- Hoy es 20 Oct, es lunes laboral, no ha fichado
-- Ejecutar para rango 16-20 Oct
-- Resultado esperado:
-- - 20 Oct: NO DEBE APARECER
-- - Absentismo: calculado solo con 16, 17, 18
```

---

## 📈 Impacto Esperado

### Antes vs Después

| Métrica | ANTES | DESPUÉS |
|---------|-------|---------|
| Días mostrados | Solo con fichajes | Todos (hasta ayer) |
| Ausencias detectadas | Parcial | Completo |
| Absentismo calculado | Incorrecto | Correcto |
| Días actuales | Incluidos | Excluidos |
| Precisión del reporte | Baja | Alta |

---

## ⚠️ Consideraciones Importantes

### 1. El Día Actual NO Aparece
- El día de hoy **nunca** aparece en el reporte
- Aparecerá **mañana** si ayer no fichó
- Esto es **intencional** para evitar contabilizar días incompletos

### 2. Solo Afecta a la Función de Reporte
- La vista `attendance_compliance` **NO se modificó**
- Solo se cambió `get_employee_compliance()`
- Los fichajes en tiempo real siguen funcionando igual

### 3. Compatibilidad
- ✅ Compatible con el frontend actual
- ✅ No requiere cambios en el código TypeScript
- ✅ La interfaz muestra los datos correctamente
- ✅ El cálculo de métricas en el frontend sigue igual

### 4. Rendimiento
- ⚠️ Genera más filas (todos los días del rango)
- ✅ Usa índices existentes
- ✅ Rendimiento aceptable para rangos de 1-2 meses
- ⚠️ Evitar rangos muy grandes (>3 meses) si no es necesario

---

## 🔍 Verificación Post-Aplicación

### Checklist

- [ ] Script SQL ejecutado sin errores en Supabase
- [ ] Función `get_employee_compliance()` actualizada
- [ ] Reporte muestra días sin fichaje como 'AUSENTE'
- [ ] El día actual (hoy) NO aparece en el reporte
- [ ] Absentismo se calcula correctamente
- [ ] Los fines de semana muestran 'DIA_NO_LABORAL'
- [ ] El rango de fechas funciona correctamente

### Consulta de Verificación

```sql
-- Ver todos los estados posibles para un empleado
SELECT 
    date,
    day_name,
    is_working_day,
    expected_start_time,
    expected_end_time,
    clock_in,
    arrival_status,
    CASE 
        WHEN date = CURRENT_DATE THEN '❌ NO DEBERÍA APARECER'
        WHEN date = CURRENT_DATE - 1 THEN '✅ Ayer (debe aparecer)'
        ELSE '✅ OK'
    END as verificacion
FROM get_employee_compliance(
    'TU_EMPLOYEE_ID'::UUID,
    CURRENT_DATE - INTERVAL '7 days',
    CURRENT_DATE
)
ORDER BY date DESC;

-- El día actual NO debe estar en los resultados
```

---

## 🐛 Troubleshooting

### Problema 1: Sigue sin mostrar ausencias

**Posible causa**: Cache del navegador  
**Solución**: Refrescar con Ctrl+F5 o limpiar cache

---

### Problema 2: Aparece el día de hoy

**Posible causa**: Función no se actualizó  
**Solución**: 
```sql
-- Verificar la función
SELECT pg_get_functiondef('get_employee_compliance'::regproc);
-- Debe mostrar: v_end_date := LEAST(p_end_date, CURRENT_DATE - INTERVAL '1 day');
```

---

### Problema 3: Error al ejecutar la función

**Posible causa**: Sintaxis SQL  
**Solución**: Ejecutar todo el archivo `attendance_compliance.sql` completo

---

### Problema 4: Días laborables incorrectos

**Posible causa**: `department_schedules` mal configurado  
**Solución**:
```sql
-- Verificar horarios del departamento
SELECT * FROM department_schedules 
WHERE department_id = (
    SELECT department_id FROM employees WHERE id = 'TU_EMPLOYEE_ID'
);
```

---

## 📊 Ejemplos Visuales

### Antes de la Corrección
```
Reporte del 16-20 Oct:
┌──────────┬──────────┬────────────┐
│  Fecha   │  Estado  │  Mostrar   │
├──────────┼──────────┼────────────┤
│ 16 Oct   │ No fichó │ ❌ NO      │
│ 17 Oct   │ Puntual  │ ✅ SÍ      │
│ 18 Oct   │ No fichó │ ❌ NO      │
│ 19 Oct   │ Sábado   │ ❌ NO      │
│ 20 Oct   │ Hoy      │ ❌ NO      │
└──────────┴──────────┴────────────┘

Absentismo: 0.0% (0 de 1 días) ❌
```

### Después de la Corrección
```
Reporte del 16-20 Oct:
┌──────────┬──────────────────┬────────────┐
│  Fecha   │     Estado       │  Mostrar   │
├──────────┼──────────────────┼────────────┤
│ 16 Oct   │ AUSENTE         │ ✅ SÍ      │
│ 17 Oct   │ PUNTUAL         │ ✅ SÍ      │
│ 18 Oct   │ AUSENTE         │ ✅ SÍ      │
│ 19 Oct   │ DIA_NO_LABORAL  │ ✅ SÍ      │
│ 20 Oct   │ (Día actual)    │ ❌ NO      │
└──────────┴──────────────────┴────────────┘

Absentismo: 66.7% (2 de 3 días) ✅
```

---

## 📞 Resumen

### ¿Qué cambió?
- ✅ La función ahora genera **todos los días** del rango (hasta ayer)
- ✅ Días sin fichaje cuentan como **'AUSENTE'**
- ✅ El **día actual se excluye** para evitar conteos incorrectos

### ¿Qué NO cambió?
- ✅ El frontend sigue igual
- ✅ Los fichajes en tiempo real funcionan igual
- ✅ La tabla `time_entries` no se modifica

### Resultado Final
- ✅ **Reportes más precisos**
- ✅ **Absentismo calculado correctamente**
- ✅ **Métricas confiables para toma de decisiones**

---

**Estado**: ✅ Listo para aplicar  
**Urgencia**: 🟡 Media - Aplica cuando puedas  
**Complejidad**: 🟢 Baja - Solo actualizar script SQL  
**Impacto**: 🟢 Alto - Mejora significativa en precisión de reportes

