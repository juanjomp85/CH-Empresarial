# Configuración de Supabase

## Archivos SQL Disponibles

### 🏗️ **Configuración Base**
- **`schema.sql`** - Esquema principal de la base de datos
- **`enable_rls.sql`** - Habilitar Row Level Security en todas las tablas

### 👥 **Gestión de Usuarios y Roles**
- **`add_roles.sql`** - Sistema de roles (admin/employee) y políticas RLS
- **`user_preferences.sql`** - Preferencias de usuario y configuraciones

### 📊 **Reportes y Cumplimiento**
- **`attendance_compliance.sql`** - Sistema de reportes de cumplimiento horario
- **`department_schedules.sql`** - Configuración de horarios por departamento

### 🔔 **Notificaciones**
- **`notifications.sql`** - Sistema de notificaciones por email (recordatorios de fichaje)

### 🧹 **Mantenimiento**
- **`remove_economic_fields.sql`** - Eliminar campos económicos (opcional)

## Pasos para Configurar la Base de Datos

### 1️⃣ **Configuración Inicial**
1. Crear proyecto en [supabase.com](https://supabase.com)
2. Ejecutar **`schema.sql`** en SQL Editor
3. Ejecutar **`enable_rls.sql`** para habilitar seguridad

### 2️⃣ **Sistema de Roles**
1. Ejecutar **`add_roles.sql`** para configurar roles de admin/employee
2. Asignar rol de admin al primer usuario manualmente

### 3️⃣ **Funcionalidades Avanzadas**
1. Ejecutar **`notifications.sql`** para sistema de notificaciones
2. Ejecutar **`attendance_compliance.sql`** para reportes
3. Ejecutar **`department_schedules.sql`** para horarios por departamento

### 4️⃣ **Configuración de Variables de Entorno**
```bash
# Copiar archivo de ejemplo
cp env.example .env.local

# Configurar variables de Supabase
NEXT_PUBLIC_SUPABASE_URL=tu_url_aqui
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_aqui
SUPABASE_SERVICE_ROLE_KEY=tu_service_role_key_aqui

# Configurar notificaciones (opcional)
EMAIL_PROVIDER=resend
RESEND_API_KEY=tu_api_key_aqui
EMAIL_FROM=Control Horario <noreply@tudominio.com>
```

### 5️⃣ **Configuración de Autenticación**
En Supabase Dashboard → Authentication → Settings:
- **Site URL**: `https://tu-dominio.com` (producción) o `http://localhost:3000` (desarrollo)
- **Redirect URLs**: `https://tu-dominio.com/auth/callback`

## Estructura de la Base de Datos

### 📋 **Tablas Principales**
- **`employees`** - Información de empleados con roles
- **`departments`** - Departamentos de la empresa
- **`positions`** - Posiciones/cargos
- **`time_entries`** - Registros de entrada y salida
- **`time_off_requests`** - Solicitudes de tiempo libre
- **`company_settings`** - Configuraciones globales

### 📊 **Tablas de Sistema**
- **`notification_logs`** - Log de notificaciones enviadas
- **`department_schedules`** - Horarios por departamento
- **`attendance_compliance_view`** - Vista para reportes de cumplimiento

## Funcionalidades Automáticas

### ⏰ **Control de Tiempo**
- Cálculo automático de horas trabajadas
- Cálculo automático de horas extra
- Actualización automática de timestamps

### 🔒 **Seguridad**
- Row Level Security (RLS) habilitado
- Políticas por rol de usuario
- Solo admins pueden gestionar empleados

### 📧 **Notificaciones**
- Recordatorios automáticos de fichaje
- Envío por email cada 5 minutos
- Configuración por departamento

### 📈 **Reportes**
- Cumplimiento horario por empleado
- Reportes por departamento
- Exportación a CSV

## Orden de Ejecución Recomendado

```sql
-- 1. Base de datos
schema.sql

-- 2. Seguridad
enable_rls.sql

-- 3. Roles y permisos
add_roles.sql

-- 4. Funcionalidades
notifications.sql
attendance_compliance.sql
department_schedules.sql

-- 5. Opcional
user_preferences.sql
remove_economic_fields.sql
```

## Notas Importantes

- ⚠️ **Ejecutar scripts en orden** para evitar errores de dependencias
- 🔐 **Asignar rol de admin** manualmente después de `add_roles.sql`
- 📧 **Configurar dominio** para notificaciones por email
- 🔄 **Los triggers y funciones** se crean automáticamente con cada script
