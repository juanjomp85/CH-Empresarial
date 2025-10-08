# Sistema de Cumplimiento de Horarios

## 📋 Descripción

Este módulo permite analizar y visualizar el cumplimiento de los horarios establecidos por departamento para cada trabajador. El sistema compara las entradas de tiempo reales con los horarios configurados para calcular métricas de puntualidad, absentismo y cumplimiento general.

## 🎯 Funcionalidades

### Análisis de Cumplimiento
- ✅ **Puntualidad**: Calcula si el empleado llegó a tiempo, con retraso leve, moderado o grave
- ✅ **Absentismo**: Detecta ausencias en días laborables
- ✅ **Horas trabajadas**: Compara horas trabajadas vs. horas esperadas
- ✅ **Métricas agregadas**: Porcentajes y promedios mensuales
- ✅ **Detalle diario**: Vista día por día del cumplimiento

### Clasificación de Estados

#### Estado de Llegada (arrival_status)
- **PUNTUAL**: Llegó a tiempo o antes del horario establecido
- **RETRASO_LEVE**: Retraso de 1-15 minutos
- **RETRASO_MODERADO**: Retraso de 16-30 minutos
- **RETRASO_GRAVE**: Retraso de más de 30 minutos
- **AUSENTE**: No registró entrada en día laboral
- **DIA_NO_LABORAL**: Día no laboral según configuración

#### Estado de Salida (departure_status)
- **SALIDA_NORMAL**: Salió dentro del rango normal (±30 min)
- **SALIDA_ANTICIPADA**: Salió más de 30 minutos antes
- **SALIDA_TARDIA**: Salió más de 30 minutos después
- **SIN_SALIDA_REGISTRADA**: No registró salida

---

## 🚀 Instalación

### 1. Ejecutar el Script SQL en Supabase

**Importante:** Debes ejecutar este script después de haber configurado departamentos y horarios.

1. Ve a tu proyecto de Supabase
2. Abre el **SQL Editor**
3. Ejecuta el archivo: `supabase/attendance_compliance.sql`
4. Verifica que se hayan creado correctamente:

```sql
-- Verificar las vistas
SELECT * FROM attendance_compliance LIMIT 5;
SELECT * FROM employee_compliance_summary;

-- Verificar las funciones
SELECT * FROM get_employee_compliance(
    'id-del-empleado'::UUID,
    '2024-01-01'::DATE,
    '2024-01-31'::DATE
);
```

### 2. Prerequisitos

Asegúrate de tener configurado:
- ✅ Tabla `departments` con departamentos creados
- ✅ Tabla `department_schedules` con horarios configurados
- ✅ Tabla `employees` con empleados asignados a departamentos
- ✅ Tabla `time_entries` con registros de tiempo

---

## 📂 Archivos Creados/Modificados

### 1. **Base de Datos**
- `supabase/attendance_compliance.sql` - Funciones y vistas SQL

### 2. **Componentes**
- `components/reports/AttendanceCompliance.tsx` - Componente principal de cumplimiento

### 3. **Páginas**
- `app/dashboard/compliance/page.tsx` - Página dedicada de cumplimiento
- `app/dashboard/reports/page.tsx` - Incluye sección de cumplimiento

### 4. **Layout**
- `components/layout/Sidebar.tsx` - Añadida opción "Cumplimiento" en menú

---

## 🎨 Interfaz de Usuario

### Página de Cumplimiento (`/dashboard/compliance`)

**Componentes principales:**

1. **Selector de Mes/Año**
   - Dropdown para seleccionar mes
   - Dropdown para seleccionar año
   - Actualización automática al cambiar

2. **Tarjetas de Resumen (4 métricas)**
   - **Puntualidad**: Porcentaje de días puntuales
   - **Absentismo**: Porcentaje de ausencias
   - **Retrasos**: Número de días con retraso + promedio de minutos
   - **Horas Trabajadas**: Total de horas + diferencia con esperadas

3. **Tabla Detallada por Día**
   - Fecha y día de la semana
   - Horario esperado (entrada - salida)
   - Entrada real (con indicador de retraso en minutos)
   - Salida real
   - Estado visual con iconos y colores
   - Horas trabajadas vs. esperadas

### Colores y Estados Visuales

- 🟢 **Verde**: Puntual / Cumplimiento correcto
- 🟡 **Amarillo**: Retraso leve
- 🟠 **Naranja**: Retraso moderado
- 🔴 **Rojo**: Retraso grave / Ausencia
- ⚪ **Gris**: Día no laboral

---

## 🔧 Funciones SQL Disponibles

### 1. `get_expected_schedule(employee_id, date)`

Obtiene el horario esperado para un empleado en una fecha específica.

```sql
SELECT * FROM get_expected_schedule(
    'uuid-del-empleado'::UUID,
    '2024-10-08'::DATE
);
```

**Retorna:**
- `day_of_week`: Día de la semana (0-6)
- `start_time`: Hora de entrada esperada
- `end_time`: Hora de salida esperada
- `is_working_day`: Si es día laboral

### 2. `get_employee_compliance(employee_id, start_date, end_date)`

Obtiene el detalle de cumplimiento de un empleado en un rango de fechas.

```sql
SELECT * FROM get_employee_compliance(
    'uuid-del-empleado'::UUID,
    '2024-10-01'::DATE,
    '2024-10-31'::DATE
);
```

**Retorna por cada día:**
- Fecha y nombre del día
- Horarios esperados y reales
- Minutos de retraso
- Estados de llegada y salida
- Horas trabajadas vs. esperadas

### 3. `get_monthly_compliance_summary(employee_id, month, year)`

Obtiene el resumen mensual agregado de cumplimiento.

```sql
SELECT * FROM get_monthly_compliance_summary(
    'uuid-del-empleado'::UUID,
    10, -- Octubre
    2024
);
```

**Retorna:**
- Días laborables totales
- Días puntuales, con retraso, ausentes
- Porcentajes de puntualidad y absentismo
- Promedio de minutos de retraso
- Horas trabajadas vs. esperadas

---

## 📊 Vistas SQL

### 1. `attendance_compliance`

Vista principal que combina datos de empleados, departamentos, horarios y registros de tiempo.

**Campos principales:**
- `employee_id`, `employee_name`, `department_name`
- `date`, `clock_in`, `clock_out`, `total_hours`
- `expected_start_time`, `expected_end_time`
- `arrival_delay_minutes` - Minutos de retraso (positivo = tarde)
- `arrival_status` - Estado categorizado de llegada
- `departure_status` - Estado categorizado de salida
- `hours_difference` - Diferencia entre horas trabajadas y esperadas

```sql
-- Ejemplo: Ver cumplimiento de todos los empleados hoy
SELECT 
    employee_name,
    arrival_status,
    arrival_delay_minutes,
    total_hours,
    hours_difference
FROM attendance_compliance
WHERE date = CURRENT_DATE
AND is_working_day = true;
```

### 2. `employee_compliance_summary`

Vista agregada con resumen por empleado.

**Campos principales:**
- `punctual_days`, `late_days`, `absent_days`
- `punctuality_percentage`, `absenteeism_percentage`
- `avg_delay_minutes`, `avg_hours_worked`
- `total_hours_worked`, `total_expected_hours`

```sql
-- Ejemplo: Ranking de empleados por puntualidad
SELECT 
    employee_name,
    punctuality_percentage,
    punctual_days,
    total_working_days
FROM employee_compliance_summary
ORDER BY punctuality_percentage DESC;
```

---

## 🔒 Seguridad (RLS)

### Políticas Implementadas

1. **Lectura propia**: Los empleados solo pueden ver su propio cumplimiento
2. **Lectura admin**: Los administradores pueden ver el cumplimiento de todos
3. **Protección de datos**: Las vistas respetan las políticas RLS de `time_entries`

```sql
-- Los empleados ven solo sus datos
CREATE POLICY "Employees can view their own compliance" 
    ON time_entries FOR SELECT 
    USING (employee_id IN (
        SELECT id FROM employees WHERE user_id = auth.uid()
    ));

-- Los admins ven todos los datos
CREATE POLICY "Admins can view all compliance" 
    ON time_entries FOR SELECT 
    USING (EXISTS (
        SELECT 1 FROM employees 
        WHERE user_id = auth.uid() AND role = 'admin'
    ));
```

---

## 🧪 Casos de Uso

### Caso 1: Empleado consulta su puntualidad

1. Acceder a **Dashboard → Cumplimiento**
2. Seleccionar mes y año
3. Visualizar:
   - Porcentaje de puntualidad del mes
   - Días con retrasos y minutos promedio
   - Detalle diario con estados

### Caso 2: Empleado revisa un día específico

1. En la tabla de detalle diario
2. Localizar la fecha
3. Ver:
   - Horario esperado: 09:00 - 18:00
   - Llegada real: 09:15 (+15 min) → RETRASO_LEVE
   - Salida real: 18:30
   - Horas trabajadas: 9.25h (+ 1.25h sobre esperadas)

### Caso 3: Administrador revisa cumplimiento del equipo

1. Acceder a **Dashboard → Reportes**
2. Ver sección de cumplimiento de horarios
3. Analizar métricas agregadas de todos los empleados

### Caso 4: Detectar patrones de absentismo

```sql
-- Query SQL para detectar empleados con alto absentismo
SELECT 
    employee_name,
    department_name,
    absent_days,
    total_working_days,
    absenteeism_percentage
FROM employee_compliance_summary
WHERE absenteeism_percentage > 10
ORDER BY absenteeism_percentage DESC;
```

---

## 💡 Cálculos y Lógica

### Cálculo de Retraso

```typescript
arrival_delay_minutes = (clock_in_time - expected_start_time) en minutos

Si arrival_delay_minutes:
  ≤ 0     → PUNTUAL
  1-15    → RETRASO_LEVE
  16-30   → RETRASO_MODERADO
  > 30    → RETRASO_GRAVE
```

### Cálculo de Horas Trabajadas vs. Esperadas

```typescript
expected_hours = (end_time - start_time) del departamento
actual_hours = total_hours del time_entry
hours_difference = actual_hours - expected_hours

Positivo (+): Trabajó más horas de las esperadas
Negativo (-): Trabajó menos horas de las esperadas
```

### Porcentaje de Puntualidad

```typescript
punctuality_percentage = (días_puntuales / total_días_laborables) * 100
```

### Porcentaje de Absentismo

```typescript
absenteeism_percentage = (días_ausentes / total_días_laborables) * 100
```

---

## 📈 Métricas y KPIs

### KPIs Principales

1. **Puntualidad**: Target > 95%
2. **Absentismo**: Target < 3%
3. **Promedio de retraso**: Target < 5 minutos
4. **Cumplimiento de horas**: ±5% de las horas esperadas

### Alertas Sugeridas

- 🟡 **Advertencia**: Absentismo > 5%
- 🔴 **Crítico**: Absentismo > 10%
- 🟡 **Advertencia**: Puntualidad < 90%
- 🔴 **Crítico**: Puntualidad < 80%

---

## 🐛 Solución de Problemas

### Problema: No aparecen datos de cumplimiento

**Solución:**
1. Verifica que el departamento tenga horarios configurados
2. Verifica que haya registros de tiempo (time_entries)
3. Ejecuta el script SQL si no está instalado
4. Revisa que el empleado esté asignado a un departamento

### Problema: Los estados no se calculan correctamente

**Solución:**
1. Verifica la zona horaria configurada
2. Asegúrate de que los horarios del departamento son correctos
3. Revisa que los time_entries tengan clock_in y clock_out

### Problema: Error al cargar funciones RPC

**Solución:**
```sql
-- Verificar que las funciones existan
SELECT * FROM pg_proc 
WHERE proname LIKE '%compliance%';

-- Si no existen, re-ejecutar el script
\i supabase/attendance_compliance.sql
```

### Problema: Permisos insuficientes

**Solución:**
```sql
-- Verificar políticas RLS
SELECT * FROM pg_policies 
WHERE tablename = 'time_entries';

-- Verificar rol del usuario
SELECT role FROM employees WHERE user_id = auth.uid();
```

---

## 🔍 Consultas SQL Útiles

### Empleados con mejor puntualidad del mes

```sql
SELECT 
    employee_name,
    punctuality_percentage,
    punctual_days,
    late_days
FROM employee_compliance_summary
ORDER BY punctuality_percentage DESC
LIMIT 10;
```

### Días con más retrasos en el mes

```sql
SELECT 
    date,
    COUNT(*) as total_late,
    ROUND(AVG(arrival_delay_minutes), 2) as avg_delay
FROM attendance_compliance
WHERE arrival_status IN ('RETRASO_LEVE', 'RETRASO_MODERADO', 'RETRASO_GRAVE')
AND EXTRACT(MONTH FROM date) = EXTRACT(MONTH FROM CURRENT_DATE)
GROUP BY date
ORDER BY total_late DESC;
```

### Departamentos con mejor cumplimiento

```sql
SELECT 
    department_name,
    ROUND(AVG(punctuality_percentage), 2) as avg_punctuality,
    ROUND(AVG(absenteeism_percentage), 2) as avg_absenteeism,
    COUNT(*) as total_employees
FROM employee_compliance_summary
GROUP BY department_name
ORDER BY avg_punctuality DESC;
```

---

## 📚 Integración con Otros Módulos

### Con Departamentos y Horarios
- Lee los horarios configurados por departamento
- Compara con los registros reales de tiempo
- Respeta días laborables vs. no laborables

### Con Control de Tiempo
- Utiliza los registros de `time_entries`
- Compara `clock_in` y `clock_out` con horarios esperados
- Calcula diferencias y genera estados

### Con Reportes
- Se integra en la página de reportes
- Proporciona métricas adicionales
- Permite exportación de datos

---

## 🎉 Beneficios

### Para Empleados
- ✅ Visibilidad de su propio cumplimiento
- ✅ Identificar patrones de retraso
- ✅ Monitorear horas trabajadas
- ✅ Transparencia en la evaluación

### Para Administradores
- ✅ Monitoreo del equipo en tiempo real
- ✅ Identificar problemas de puntualidad
- ✅ Tomar decisiones basadas en datos
- ✅ Generar reportes de cumplimiento

### Para la Empresa
- ✅ Mejorar la productividad
- ✅ Reducir absentismo
- ✅ Optimizar horarios
- ✅ Cumplimiento normativo

---

## ✅ Checklist de Implementación

- [x] Script SQL ejecutado en Supabase
- [x] Vistas `attendance_compliance` y `employee_compliance_summary` creadas
- [x] Funciones RPC disponibles
- [x] Componente `AttendanceCompliance` creado
- [x] Página `/dashboard/compliance` creada
- [x] Integrado en página de reportes
- [x] Opción añadida al menú de navegación
- [x] Documentación completa
- [ ] Departamentos con horarios configurados
- [ ] Empleados asignados a departamentos
- [ ] Registros de tiempo existentes
- [ ] Pruebas realizadas con datos reales

---

## 🚀 Próximas Mejoras (Opcional)

- [ ] Gráficos de tendencias de puntualidad
- [ ] Notificaciones por bajo cumplimiento
- [ ] Exportar reportes de cumplimiento a PDF
- [ ] Comparativas entre departamentos
- [ ] Historial de cumplimiento anual
- [ ] Gamificación (badges por puntualidad)
- [ ] Alertas automáticas por patrones anormales

---

## 📖 Referencias

- **SQL:** `supabase/attendance_compliance.sql`
- **Componente:** `components/reports/AttendanceCompliance.tsx`
- **Página:** `app/dashboard/compliance/page.tsx`
- **Documentación de horarios:** `DEPARTAMENTOS_HORARIOS.md`

---

¡El sistema de cumplimiento de horarios está listo para ayudar a monitorear y mejorar la puntualidad y asistencia en tu empresa!
