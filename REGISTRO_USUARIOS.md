# 🔐 Sistema de Registro de Usuarios

## 🔴 Problema Identificado

Los usuarios externos no podían registrarse debido a una política RLS demasiado restrictiva que solo permitía a administradores crear registros de empleados.

### Flujo Anterior (Roto):
1. Usuario se registra → ✅ Auth crea usuario
2. Usuario accede → ❌ Intenta crear empleado pero falla (RLS lo bloquea)
3. Usuario queda sin acceso a la aplicación

## ✅ Solución Implementada

### 1. Trigger Automático

Se crea automáticamente un registro de empleado cuando un usuario se registra:

```sql
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
```

### 2. Nuevas Políticas RLS

- ✅ **Auto-registro**: Los usuarios pueden crear su propio registro de empleado (una vez)
- ✅ **Admins**: Los administradores pueden crear cualquier empleado
- ✅ **Seguridad**: Constraint unique previene duplicados

### 3. Mejor Manejo de Errores

El formulario de login ahora muestra:
- ✅ Mensajes específicos según el tipo de error
- ✅ Feedback verde para éxitos
- ✅ Feedback rojo para errores
- ✅ Instrucciones claras (confirmación de email, etc.)

## 🚀 Flujo Nuevo (Funcional):

1. **Usuario se registra** → Supabase Auth crea usuario ✅
2. **Trigger automático** → Crea registro de empleado automáticamente ✅
3. **Usuario recibe email** (si está configurado) → Confirma cuenta
4. **Usuario inicia sesión** → Accede sin problemas ✅
5. **Usuario puede usar la app** → Todo funciona ✅

## 📋 Instalación

### Paso 1: Ejecutar el Script SQL

En **Supabase SQL Editor**, ejecuta:

```
supabase/fix_registration.sql
```

Este script:
- Elimina la política restrictiva anterior
- Crea nuevas políticas que permiten auto-registro
- Añade trigger automático para crear empleados
- Añade constraint único para evitar duplicados

### Paso 2: Configurar Confirmación de Email (Opcional)

En **Supabase Dashboard** → **Authentication** → **Email Templates**:

#### Opción A: Desactivar Confirmación (Más simple)
1. Ve a **Settings** → **Auth** → **Email** 
2. Desactiva "Enable email confirmations"
3. Los usuarios pueden acceder inmediatamente después de registrarse

#### Opción B: Activar Confirmación (Más seguro)
1. Mantén activada "Enable email confirmations"
2. Los usuarios deben confirmar su email antes de acceder
3. Personaliza el template de confirmación con tu marca

### Paso 3: Redesplegar Frontend

Los cambios en el frontend ya están incluidos en el repositorio:
- Mejor manejo de errores
- Mensajes específicos
- Feedback visual mejorado

## 🔍 Verificación

### Probar el Registro

1. **Registrar nuevo usuario:**
   ```
   Email: test@ejemplo.com
   Password: test123456
   Nombre: Usuario Test
   ```

2. **Verificar que se creó el empleado:**
   ```sql
   SELECT 
     u.email,
     u.confirmed_at,
     e.full_name,
     e.role,
     e.is_active
   FROM auth.users u
   LEFT JOIN employees e ON e.user_id = u.id
   WHERE u.email = 'test@ejemplo.com';
   ```

3. **Resultado esperado:**
   - Usuario en `auth.users` ✅
   - Empleado en `employees` con rol 'employee' ✅
   - `is_active = true` ✅

### Probar el Login

1. **Sin confirmación de email:**
   - Usuario puede acceder inmediatamente

2. **Con confirmación de email:**
   - Usuario ve mensaje: "Revisa tu email para confirmar tu cuenta"
   - Después de confirmar, puede iniciar sesión

## 🛠️ Gestión de Nuevos Empleados

### Flujo para Administradores

1. **Usuario se auto-registra** → Empleado creado con:
   - `role = 'employee'`
   - `department_id = NULL`
   - `position_id = NULL`
   - `is_active = true`

2. **Admin asigna departamento y posición:**
   ```sql
   UPDATE employees 
   SET 
     department_id = 'uuid-del-departamento',
     position_id = 'uuid-de-la-posicion'
   WHERE email = 'usuario@ejemplo.com';
   ```

3. **Usuario puede ver su horario** según el departamento asignado

### Promoción a Administrador

```sql
-- Solo ejecutar para usuarios de confianza
UPDATE employees 
SET role = 'admin' 
WHERE email = 'usuario@ejemplo.com';
```

## ⚠️ Seguridad

### Protecciones Implementadas

- ✅ **Constraint Único**: Un usuario = un empleado
- ✅ **Rol por Defecto**: Nuevos usuarios son 'employee', no 'admin'
- ✅ **RLS Activo**: Solo pueden ver/modificar sus propios datos
- ✅ **Sin Privilegios**: Sin departamento/posición hasta que admin asigne

### Recomendaciones

1. **Monitorea nuevos registros:**
   ```sql
   SELECT 
     email,
     full_name,
     created_at
   FROM employees
   WHERE created_at > NOW() - INTERVAL '24 hours'
   ORDER BY created_at DESC;
   ```

2. **Configura Email de Administrador:**
   - Recibe notificación cuando hay nuevo registro
   - Revisa y asigna departamento/posición

3. **Desactiva usuarios no deseados:**
   ```sql
   UPDATE employees 
   SET is_active = false 
   WHERE email = 'spam@ejemplo.com';
   ```

## 📊 Troubleshooting

### Problema: Usuario no puede acceder después de registrarse

**Solución:**
1. Verifica que el script SQL se ejecutó correctamente
2. Verifica que existe el trigger:
   ```sql
   SELECT * FROM information_schema.triggers 
   WHERE trigger_name = 'on_auth_user_created';
   ```

### Problema: Se crean múltiples empleados para el mismo usuario

**Solución:**
1. Verifica el constraint único:
   ```sql
   SELECT constraint_name 
   FROM information_schema.table_constraints 
   WHERE table_name = 'employees' 
   AND constraint_name = 'employees_user_id_key';
   ```

2. Si no existe, ejecuta:
   ```sql
   ALTER TABLE employees 
   ADD CONSTRAINT employees_user_id_key UNIQUE (user_id);
   ```

### Problema: Mensajes de error genéricos

**Solución:**
- Abre la consola del navegador (F12)
- Revisa los errores de Supabase
- Los errores detallados aparecen en `console.error()`

## 📚 Referencias

- [Supabase Auth](https://supabase.com/docs/guides/auth)
- [RLS Policies](https://supabase.com/docs/guides/auth/row-level-security)
- [Database Triggers](https://www.postgresql.org/docs/current/sql-createtrigger.html)

