# Gestión de Departamentos y Horarios

## 📋 Descripción

Este módulo permite gestionar los departamentos de la empresa y configurar horarios de entrada y salida específicos para cada departamento desde el apartado de Configuración.

## 🎯 Funcionalidades

### Gestión de Departamentos
- ✅ **Crear departamentos** con nombre y descripción
- ✅ **Editar departamentos** existentes
- ✅ **Eliminar departamentos** (con validación)
- ✅ Vista completa de todos los departamentos
- ✅ Interfaz intuitiva con formularios inline

### Gestión de Horarios
- ✅ **Configurar horarios** para cada día de la semana
- ✅ **Marcar días laborables** vs. días no laborables
- ✅ **Horario de entrada y salida** personalizados
- ✅ Opción para aplicar el mismo horario a todos los días laborables
- ✅ Horarios independientes por departamento

---

## 🚀 Instalación

### 1. Ejecutar el Script SQL en Supabase

**Importante:** Debes ejecutar este script en tu base de datos de Supabase para crear las tablas necesarias.

1. Ve a tu proyecto de Supabase
2. Abre el **SQL Editor**
3. Ejecuta el archivo: `supabase/department_schedules.sql`
4. Verifica que se hayan creado correctamente:

```sql
-- Verificar la tabla de horarios
SELECT * FROM department_schedules;

-- Verificar las políticas RLS
SELECT * FROM pg_policies WHERE tablename = 'department_schedules';
```

### 2. Verificar Permisos

Esta funcionalidad está **protegida por el sistema de roles**. Solo los usuarios con rol `admin` pueden:
- Crear, editar y eliminar departamentos
- Configurar horarios de trabajo
- Acceder a la página de Configuración

Para asignar permisos de administrador a un usuario:

```sql
UPDATE employees 
SET role = 'admin' 
WHERE email = 'admin@ejemplo.com';
```

---

## 📂 Archivos Creados/Modificados

### 1. **Base de Datos**
- `supabase/department_schedules.sql` - Script SQL para crear tablas y políticas

### 2. **Componentes**
- `components/settings/DepartmentManager.tsx` - Gestión de departamentos
- `components/settings/ScheduleManager.tsx` - Gestión de horarios

### 3. **Páginas**
- `app/dashboard/settings/page.tsx` - Página de configuración actualizada

### 4. **Tipos TypeScript**
- `lib/supabase.ts` - Tipos actualizados con `DepartmentSchedule`

---

## 🎨 Interfaz de Usuario

### Gestión de Departamentos

**Características:**
- Lista completa de departamentos con nombre y descripción
- Botón "Nuevo Departamento" para crear
- Botones de acción (Editar/Eliminar) en cada departamento
- Formularios inline para crear y editar
- Confirmación antes de eliminar
- Fecha de creación visible

**Campos:**
- **Nombre** (requerido): Nombre del departamento
- **Descripción** (opcional): Descripción detallada del departamento

### Gestión de Horarios

**Características:**
- Selector de departamento (dropdown)
- Tabla con los 7 días de la semana
- Checkbox para marcar días laborables
- Campos de hora de entrada y salida (input type="time")
- Botón "Aplicar horario de Lunes a todos los días laborales"
- Los horarios se deshabilitan automáticamente para días no laborables

**Configuración por día:**
- ✅ **Día Laboral:** Checkbox para activar/desactivar
- ⏰ **Hora de Entrada:** Selector de hora (ej. 09:00)
- ⏰ **Hora de Salida:** Selector de hora (ej. 18:00)

**Días de la semana:**
- Lunes (1)
- Martes (2)
- Miércoles (3)
- Jueves (4)
- Viernes (5)
- Sábado (6)
- Domingo (0)

---

## 🔒 Seguridad (RLS)

### Tabla `department_schedules`

**Políticas implementadas:**
- ✅ **Lectura:** Todos los usuarios pueden ver los horarios
- ✅ **Creación:** Solo administradores pueden crear horarios
- ✅ **Actualización:** Solo administradores pueden modificar horarios
- ✅ **Eliminación:** Solo administradores pueden eliminar horarios

### Tabla `departments`

**Políticas implementadas:**
- ✅ **Lectura:** Todos los usuarios pueden ver los departamentos
- ✅ **Gestión completa:** Solo administradores pueden crear/editar/eliminar

---

## 🧪 Casos de Uso

### Caso 1: Crear un nuevo departamento

1. Ir a **Configuración** (`/dashboard/settings`)
2. Hacer clic en **"Nuevo Departamento"**
3. Rellenar el nombre (ej. "Desarrollo")
4. Agregar descripción (ej. "Equipo de desarrollo de software")
5. Hacer clic en **"Crear"**

### Caso 2: Configurar horarios de un departamento

1. Ir a **Configuración** → **Horarios por Departamento**
2. Seleccionar el departamento en el dropdown
3. Configurar cada día:
   - Marcar checkbox si es día laboral
   - Establecer hora de entrada (ej. 09:00)
   - Establecer hora de salida (ej. 18:00)
4. Hacer clic en **"Guardar Horarios"**

### Caso 3: Horario estándar de oficina (Lunes-Viernes)

1. Configurar el Lunes con el horario deseado (ej. 09:00 - 18:00)
2. Hacer clic en **"Aplicar horario de Lunes a todos los días laborales"**
3. Desmarcar Sábado y Domingo como días laborables
4. Guardar cambios

### Caso 4: Departamento con horario especial (turnos)

**Ejemplo: Atención al Cliente 24/7**
- Marcar todos los días como laborables
- Configurar turnos rotatorios por departamento
- Guardar configuración

---

## 💡 Funcionalidades Avanzadas

### Validaciones Implementadas

✅ **Nombres únicos:** No se pueden crear departamentos con el mismo nombre
✅ **Eliminación segura:** Confirmación antes de eliminar
✅ **Validación de horarios:** El horario de salida debe ser después de la entrada
✅ **Días no laborables:** Los campos de hora se deshabilitan automáticamente

### Funcionalidades de UX

✅ **Estados de carga:** Indicadores mientras se cargan datos
✅ **Formularios inline:** Edición sin cambiar de página
✅ **Feedback visual:** Alertas de éxito/error
✅ **Modo oscuro:** Soporte completo para tema oscuro
✅ **Diseño responsivo:** Funciona en móviles y tablets

---

## 📊 Estructura de Datos

### Tabla `department_schedules`

```sql
CREATE TABLE department_schedules (
    id UUID PRIMARY KEY,
    department_id UUID REFERENCES departments(id),
    day_of_week INTEGER (0-6), -- 0=Domingo, 1=Lunes, ...
    start_time TIME,
    end_time TIME,
    is_working_day BOOLEAN,
    created_at TIMESTAMP,
    updated_at TIMESTAMP
);
```

**Constraint:** Solo puede haber un horario por departamento y día (UNIQUE constraint)

### Horarios por Defecto

Al ejecutar el script SQL, se crean automáticamente horarios predeterminados:
- **Lunes a Viernes:** 09:00 - 18:00 (Días laborables)
- **Sábado y Domingo:** No laborables

---

## 🔧 Integración con Otros Módulos

### Empleados
Los empleados están asignados a departamentos, por lo que heredan:
- Horarios de entrada/salida esperados
- Días laborables del departamento

### Control de Tiempo
Los horarios configurados se pueden usar para:
- Calcular llegadas tarde
- Detectar salidas anticipadas
- Calcular horas extras basadas en el horario del departamento

### Reportes
Los horarios permiten generar reportes más precisos:
- Comparar horas trabajadas vs. horario esperado
- Identificar patrones de asistencia
- Calcular porcentajes de cumplimiento

---

## 🐛 Solución de Problemas

### Problema: No puedo crear departamentos

**Solución:**
1. Verifica que tu usuario tenga rol `admin`
2. Verifica que el script SQL se haya ejecutado correctamente
3. Revisa las políticas RLS en Supabase

### Problema: No aparecen los horarios

**Solución:**
1. Verifica que el departamento exista
2. Ejecuta el script SQL nuevamente para crear horarios predeterminados
3. Revisa la consola del navegador para errores

### Problema: Error al guardar horarios

**Solución:**
1. Asegúrate de que la hora de salida sea después de la entrada
2. Verifica que tengas permisos de administrador
3. Revisa las políticas RLS en la tabla `department_schedules`

### Problema: No se eliminan los departamentos

**Solución:**
- Los departamentos con empleados asignados no se pueden eliminar
- Primero reasigna los empleados a otro departamento
- Luego intenta eliminar nuevamente

---

## 📈 Mejoras Futuras (Opcional)

Posibles extensiones del módulo:
- [ ] Múltiples turnos por día
- [ ] Horarios diferentes para temporadas (verano/invierno)
- [ ] Excepciones de horario por festivos
- [ ] Notificaciones de cambios de horario
- [ ] Historial de cambios de horarios
- [ ] Exportar/importar horarios
- [ ] Plantillas de horarios predefinidos

---

## ✅ Checklist de Implementación

- [x] Script SQL ejecutado en Supabase
- [x] Tabla `department_schedules` creada
- [x] Políticas RLS configuradas
- [x] Componente `DepartmentManager` creado
- [x] Componente `ScheduleManager` creado
- [x] Página de Configuración actualizada
- [x] Tipos TypeScript actualizados
- [ ] Usuario administrador configurado
- [ ] Pruebas de creación de departamentos realizadas
- [ ] Pruebas de configuración de horarios realizadas
- [ ] Deploy a producción

---

## 📚 Referencias

- **Componentes:** `components/settings/`
- **SQL:** `supabase/department_schedules.sql`
- **Página:** `app/dashboard/settings/page.tsx`
- **Tipos:** `lib/supabase.ts`

---

## 👥 Acceso

**Solo Administradores:**
- Crear/editar/eliminar departamentos
- Configurar horarios
- Acceder a `/dashboard/settings`

**Todos los usuarios:**
- Ver departamentos y sus horarios (solo lectura)

---

## 🎉 ¡Listo!

Ahora puedes gestionar departamentos y configurar horarios de trabajo desde el apartado de Configuración. Los empleados asignados a cada departamento tendrán sus horarios de entrada y salida configurados automáticamente según la configuración del departamento.

Para acceder:
1. Inicia sesión como administrador
2. Ve a **Dashboard** → **Configuración**
3. Desplázate hasta las secciones de **Departamentos** y **Horarios**
