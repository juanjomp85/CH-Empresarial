# Configuración de Supabase

## Pasos para configurar la base de datos

1. **Crear proyecto en Supabase**
   - Ve a [supabase.com](https://supabase.com)
   - Crea una nueva cuenta o inicia sesión
   - Crea un nuevo proyecto

2. **Ejecutar el esquema de base de datos**
   - Ve a la sección "SQL Editor" en tu dashboard de Supabase
   - Copia y pega el contenido de `schema.sql`
   - Ejecuta el script

3. **Configurar variables de entorno**
   - Copia `env.example` a `.env.local`
   - Obtén tu URL y clave anónima desde Settings > API
   - Actualiza las variables en `.env.local`

4. **Configurar autenticación**
   - Ve a Authentication > Settings
   - Configura las URLs de redirección:
     - Site URL: `http://localhost:3000` (desarrollo)
     - Redirect URLs: `http://localhost:3000/auth/callback`

5. **Configurar políticas de seguridad**
   - Las políticas básicas están incluidas en el schema
   - Ajusta según tus necesidades de seguridad

## Estructura de la base de datos

- **departments**: Departamentos de la empresa
- **positions**: Posiciones/cargos con tarifas por hora
- **employees**: Información de empleados
- **time_entries**: Registros de entrada y salida
- **time_off_requests**: Solicitudes de tiempo libre
- **company_settings**: Configuraciones de la empresa

## Funcionalidades automáticas

- Cálculo automático de horas trabajadas
- Cálculo automático de horas extra
- Actualización automática de timestamps
- Políticas de seguridad por usuario
