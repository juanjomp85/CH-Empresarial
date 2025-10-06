# Sistema de Roles - Guía de Configuración

## Descripción

Se ha implementado un sistema de roles para controlar el acceso a ciertas funcionalidades de la aplicación. Los siguientes elementos están protegidos y solo son visibles para usuarios con rol de **administrador**:

### Elementos Protegidos:
- **Menú Lateral (Sidebar):**
  - Empleados
  - Configuración

- **Header:**
  - Ícono de configuración (engranaje naranja)

- **Rutas Protegidas:**
  - `/dashboard/employees`
  - `/dashboard/settings`

## Tipos de Roles

- **`admin`**: Acceso completo a todas las funcionalidades
- **`employee`**: Acceso limitado (sin acceso a empleados ni configuración)

## Cómo Asignar Roles

### Opción 1: Mediante la Consola SQL de Supabase

1. Accede a tu proyecto en [Supabase](https://supabase.com)
2. Ve a la sección **SQL Editor**
3. Ejecuta el archivo `supabase/roles.sql` para crear las funciones necesarias
4. Luego, para asignar el rol de administrador a un usuario:

```sql
-- Obtener el UUID del usuario por email
SELECT id FROM auth.users WHERE email = 'usuario@ejemplo.com';

-- Asignar rol de administrador
SELECT update_user_role('UUID_DEL_USUARIO', 'admin');
```

**Ejemplo completo:**
```sql
-- Hacer administrador al usuario juanjomp85@gmail.com
SELECT update_user_role(
  (SELECT id FROM auth.users WHERE email = 'juanjomp85@gmail.com'),
  'admin'
);
```

### Opción 2: Al Registrar un Usuario

Para asignar un rol durante el registro, modifica la función `signUp` en `lib/auth.ts`:

```typescript
export const signUp = async (email: string, password: string, fullName: string, role: string = 'employee') => {
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      data: {
        full_name: fullName,
        role: role, // 'admin' o 'employee'
      },
    },
  })
  return { data, error }
}
```

### Opción 3: Actualizar el Rol Manualmente en Supabase Dashboard

1. Ve a **Authentication** → **Users** en tu proyecto de Supabase
2. Selecciona el usuario que quieres modificar
3. En la sección **User Metadata**, edita el JSON y añade:
```json
{
  "full_name": "Nombre del Usuario",
  "role": "admin"
}
```
4. Guarda los cambios
5. El usuario deberá cerrar sesión y volver a iniciar sesión para que los cambios surtan efecto

## Verificar el Rol de un Usuario

Para verificar qué rol tiene un usuario actualmente:

```sql
SELECT 
  email,
  raw_user_meta_data->>'role' as role,
  raw_user_meta_data->>'full_name' as full_name
FROM auth.users
WHERE email = 'usuario@ejemplo.com';
```

## Seguridad

El sistema implementa protección tanto en el frontend como en el backend:

- **Frontend**: Los elementos se ocultan usando el contexto `useAuth()` y la propiedad `isAdmin`
- **Backend**: El middleware protege las rutas a nivel de servidor
- **Base de Datos**: Las políticas RLS (Row Level Security) en Supabase protegen los datos

⚠️ **Importante**: Los usuarios sin rol de administrador serán redirigidos automáticamente al dashboard principal si intentan acceder a rutas protegidas.

## Notas Adicionales

- Después de cambiar el rol de un usuario, este debe cerrar sesión y volver a iniciar sesión
- Se recomienda tener al menos un usuario administrador configurado antes de implementar en producción
- Los cambios en los metadatos del usuario se reflejan inmediatamente en la sesión activa

