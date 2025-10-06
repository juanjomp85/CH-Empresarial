# Sistema de Roles de Administrador

## 📋 Descripción

Este sistema implementa roles de usuario (empleado/administrador) para controlar el acceso a diferentes secciones de la aplicación.

## 🎯 Funcionalidades

### Roles Disponibles

1. **`employee`** (Por defecto)
   - Acceso al dashboard personal
   - Control de tiempo propio
   - Visualización de reportes propios
   - Calendario personal

2. **`admin`** (Administrador)
   - Todo lo del rol `employee`
   - **Gestión de empleados** (CRUD completo)
   - **Configuración de la empresa**
   - **Página de debug y diagnóstico**
   - Visualización de datos de todos los empleados

---

## 🚀 Instalación y Configuración

### 1. Ejecutar el Script SQL en Supabase

1. Ve a tu proyecto de Supabase
2. Abre el **SQL Editor**
3. Ejecuta el archivo: `supabase/add_roles.sql`
4. Verifica que se haya creado correctamente:

```sql
-- Verificar la nueva columna
SELECT email, role, is_active FROM employees;
```

### 2. Asignar el Primer Administrador

**Opción A: Desde Supabase SQL Editor**

```sql
-- Reemplaza con el email del usuario administrador
UPDATE employees 
SET role = 'admin' 
WHERE email = 'tu-email@ejemplo.com';
```

**Opción B: Desde la interfaz de Supabase**

1. Ve a **Database** > **Tables** > `employees`
2. Busca tu usuario
3. Edita el campo `role` y cámbialo a `'admin'`
4. Guarda los cambios

### 3. Verificar la Configuración

Una vez asignado el rol de administrador:

1. Inicia sesión con el usuario administrador
2. Verás un **badge amarillo "Administrador"** en el sidebar
3. Tendrás acceso a:
   - ✅ **Empleados** (`/dashboard/employees`)
   - ✅ **Configuración** (`/dashboard/settings`)
   - ✅ **Debug** (`/debug`)

---

## 🏗️ Arquitectura Técnica

### Archivos Creados/Modificados

#### 1. **Base de Datos** (`supabase/add_roles.sql`)
- ✅ Columna `role` en la tabla `employees`
- ✅ Función `is_admin()` para verificar permisos
- ✅ Políticas RLS actualizadas para cada tabla
- ✅ Índice para optimizar consultas por rol

#### 2. **Hook personalizado** (`lib/hooks/useRole.ts`)
```typescript
import { useRole } from '@/lib/hooks/useRole'

const { role, isAdmin, loading, employeeId } = useRole()

// O uso simplificado:
import { useIsAdmin } from '@/lib/hooks/useRole'

const isAdmin = useIsAdmin() // true, false, o null (cargando)
```

#### 3. **Componente de protección** (`components/auth/AdminRoute.tsx`)
```tsx
import AdminRoute from '@/components/auth/AdminRoute'

export default function MiPaginaProtegida() {
  return (
    <AdminRoute>
      {/* Contenido solo para administradores */}
    </AdminRoute>
  )
}
```

#### 4. **Sidebar actualizado** (`components/layout/Sidebar.tsx`)
- ✅ Muestra badge de "Administrador" si el usuario es admin
- ✅ Oculta opciones de menú según el rol
- ✅ Marca las opciones como `adminOnly: true`

#### 5. **Páginas protegidas**
- ✅ `/dashboard/employees` - Solo administradores
- ✅ `/dashboard/settings` - Solo administradores
- ✅ `/debug` - Solo administradores

---

## 🔒 Seguridad

### Row Level Security (RLS)

El sistema utiliza políticas de seguridad a nivel de base de datos:

#### Tabla `employees`
- ✅ Los empleados solo ven su propia información
- ✅ Los administradores ven todos los empleados
- ✅ Solo administradores pueden crear/eliminar empleados

#### Tabla `time_entries`
- ✅ Los empleados solo ven sus propias entradas
- ✅ Los administradores ven todas las entradas
- ✅ Los empleados solo pueden modificar sus propias entradas

#### Tabla `company_settings`
- ✅ Todos pueden ver la configuración
- ✅ Solo administradores pueden modificarla

#### Tablas `departments` y `positions`
- ✅ Todos pueden verlas
- ✅ Solo administradores pueden modificarlas

---

## 🎨 UI/UX del Sistema de Roles

### Para Empleados Normales
- **Sidebar** muestra:
  - Dashboard
  - Mi Tiempo
  - Reportes
  - Calendario

### Para Administradores
- **Badge amarillo** en el sidebar: "Administrador"
- **Sidebar** muestra todas las opciones:
  - Dashboard
  - Mi Tiempo
  - **Empleados** ⭐
  - Reportes
  - Calendario
  - **Configuración** ⭐

### Mensajes de Acceso Denegado

Si un usuario no administrador intenta acceder a una ruta protegida:

```
🛡️ Acceso Denegado
No tienes permisos para acceder a esta página.
[Botón: Volver al Dashboard]
```

---

## 🧪 Pruebas

### Test 1: Usuario Empleado Normal

1. Crea un usuario normal (sin rol admin)
2. Inicia sesión
3. **Verifica:**
   - ✅ NO ve el badge "Administrador"
   - ✅ NO ve "Empleados" en el menú
   - ✅ NO ve "Configuración" en el menú
   - ✅ Si intenta acceder directamente a `/dashboard/employees`, es redirigido
   - ✅ Solo ve sus propios datos en reportes

### Test 2: Usuario Administrador

1. Asigna rol `admin` a un usuario
2. Inicia sesión
3. **Verifica:**
   - ✅ Ve el badge "Administrador" en el sidebar
   - ✅ Ve "Empleados" en el menú
   - ✅ Ve "Configuración" en el menú
   - ✅ Puede acceder a `/dashboard/employees`
   - ✅ Puede acceder a `/dashboard/settings`
   - ✅ Puede acceder a `/debug`
   - ✅ Ve todos los empleados y sus datos

---

## 🔧 Cómo Agregar Nuevas Rutas Protegidas

### Para proteger una nueva página (solo admins):

```tsx
'use client'

import AdminRoute from '@/components/auth/AdminRoute'

export default function MiNuevaPagina() {
  return (
    <AdminRoute>
      {/* Tu contenido aquí */}
    </AdminRoute>
  )
}
```

### Para agregar al menú (solo visible para admins):

```typescript
// En components/layout/Sidebar.tsx

const navigation: NavigationItem[] = [
  // ... otras opciones
  { 
    name: 'Mi Nueva Opción', 
    href: '/dashboard/mi-nueva-opcion', 
    icon: MiIcono,
    adminOnly: true // 👈 Marca como solo admin
  },
]
```

---

## 📊 Gestión de Roles

### Promover a Administrador

```sql
UPDATE employees 
SET role = 'admin' 
WHERE email = 'usuario@ejemplo.com';
```

### Degradar a Empleado

```sql
UPDATE employees 
SET role = 'employee' 
WHERE email = 'admin@ejemplo.com';
```

### Ver Todos los Administradores

```sql
SELECT email, full_name, role, created_at 
FROM employees 
WHERE role = 'admin' 
AND is_active = true;
```

---

## ⚠️ Notas Importantes

1. **Primer Usuario**: Asegúrate de asignar al menos un administrador después de ejecutar el script SQL.

2. **Seguridad de la BD**: Las políticas RLS aseguran que aunque un usuario modifique el código del frontend, no podrá acceder a datos restringidos.

3. **Cache del Navegador**: Si cambias el rol de un usuario, es posible que necesite cerrar sesión y volver a iniciar para que los cambios surtan efecto.

4. **Desarrollo Local**: En desarrollo, recuerda ejecutar el script SQL también en tu instancia local de Supabase.

5. **Deployment**: Al hacer deploy, ejecuta el script SQL en tu instancia de producción de Supabase.

---

## 🐛 Solución de Problemas

### Problema: No veo las opciones de administrador

**Solución:**
1. Verifica que tu usuario tenga `role = 'admin'` en la tabla `employees`
2. Cierra sesión y vuelve a iniciar
3. Verifica en las DevTools Console si hay errores

### Problema: Error al acceder a páginas de admin

**Solución:**
1. Verifica que el script SQL se haya ejecutado correctamente
2. Asegúrate de que la función `is_admin()` exista
3. Revisa las políticas RLS en Supabase

### Problema: Las políticas RLS bloquean todo

**Solución:**
```sql
-- Verificar políticas
SELECT * FROM pg_policies WHERE tablename = 'employees';

-- Si hay problemas, re-ejecutar el script add_roles.sql
```

---

## 📚 Referencias

- **Hook useRole**: `lib/hooks/useRole.ts`
- **Componente AdminRoute**: `components/auth/AdminRoute.tsx`
- **Script SQL**: `supabase/add_roles.sql`
- **Sidebar**: `components/layout/Sidebar.tsx`

---

## ✅ Checklist de Implementación

- [x] Script SQL ejecutado en Supabase
- [x] Al menos un usuario con rol `admin` asignado
- [x] Páginas protegidas con `AdminRoute`
- [x] Sidebar muestra opciones según rol
- [x] Políticas RLS verificadas y funcionando
- [ ] Pruebas con usuario empleado realizadas
- [ ] Pruebas con usuario administrador realizadas
- [ ] Deploy a producción completado

