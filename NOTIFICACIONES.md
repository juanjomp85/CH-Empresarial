# 📧 Sistema de Notificaciones por Correo Electrónico

Este documento describe el sistema de notificaciones automáticas para recordar a los empleados que registren su entrada o salida.

## 🎯 Funcionalidad

El sistema envía correos electrónicos automáticos cuando:

- **Recordatorio de Entrada**: Han pasado 5 minutos después de la hora de entrada esperada y el empleado no ha fichado.
- **Recordatorio de Salida**: Han pasado 5 minutos después de la hora de salida esperada y el empleado no ha fichado salida.

### Características:
- ✅ Verificación cada 5 minutos
- ✅ Evita spam (no envía más de 1 correo cada 2 horas por empleado)
- ✅ Solo envía en horario laboral (06:00 - 23:00)
- ✅ Incluye enlace directo a la página de registro
- ✅ Registro completo de notificaciones enviadas
- ✅ Diseño responsive para correos

## 📋 Requisitos Previos

1. Tener ejecutado el script SQL: `supabase/notifications.sql`
2. Configurar un proveedor de correo electrónico (Resend o SendGrid)
3. Configurar las variables de entorno
4. Desplegar en Vercel (para usar Vercel Cron) o configurar un cron job alternativo

## ⚙️ Configuración

### 1. Ejecutar el Script SQL

Ejecuta el archivo `supabase/notifications.sql` en tu base de datos Supabase:

\`\`\`bash
# Opción 1: Desde el dashboard de Supabase
# Ve a SQL Editor y pega el contenido del archivo

# Opción 2: Usando CLI de Supabase
supabase db push
\`\`\`

Este script crea:
- Tabla `notification_logs` para registrar notificaciones enviadas
- Función `get_employees_needing_clock_in_reminder()` para detectar empleados sin entrada
- Función `get_employees_needing_clock_out_reminder()` para detectar empleados sin salida
- Función `log_notification()` para registrar envíos

### 2. Configurar Proveedor de Correo

#### Opción A: Resend (Recomendado)

1. Crea una cuenta en [Resend](https://resend.com)
2. Verifica tu dominio
3. Obtén tu API Key
4. Configura las variables de entorno:

\`\`\`env
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_tu_api_key
EMAIL_FROM=Control Horario <noreply@tudominio.com>
\`\`\`

#### Opción B: SendGrid

1. Crea una cuenta en [SendGrid](https://sendgrid.com)
2. Verifica tu dominio
3. Obtén tu API Key
4. Configura las variables de entorno:

\`\`\`env
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.tu_api_key
EMAIL_FROM=noreply@tudominio.com
\`\`\`

#### Opción C: Sin Proveedor (Solo Logs)

Para desarrollo o testing, puedes dejar `EMAIL_PROVIDER` vacío y los correos solo se registrarán en los logs:

\`\`\`env
EMAIL_PROVIDER=
\`\`\`

### 3. Configurar Seguridad del Cron

Genera un token secreto aleatorio para proteger el endpoint:

\`\`\`bash
# En Linux/Mac
openssl rand -base64 32

# O usa cualquier generador de strings aleatorios
\`\`\`

Añade el token a tus variables de entorno:

\`\`\`env
CRON_SECRET=tu_token_secreto_generado
\`\`\`

### 4. Desplegar con Vercel Cron

El archivo `vercel.json` ya está configurado para ejecutar las notificaciones cada 5 minutos:

\`\`\`json
{
  "crons": [
    {
      "path": "/api/notifications/send",
      "schedule": "*/5 * * * *"
    }
  ]
}
\`\`\`

**Importante**: Vercel Cron solo funciona en planes Pro o superiores. Para el plan gratuito, ver alternativas abajo.

### 5. Alternativas a Vercel Cron

#### Opción A: Cron-job.org (Gratuito)

1. Regístrate en [cron-job.org](https://cron-job.org)
2. Crea un nuevo cron job con:
   - URL: `https://tudominio.com/api/notifications/send`
   - Método: POST
   - Headers: `Authorization: Bearer tu_cron_secret`
   - Frecuencia: Cada 5 minutos

#### Opción B: EasyCron (Gratuito hasta 250 ejecuciones/mes)

1. Regístrate en [easycron.com](https://www.easycron.com)
2. Configura similar a cron-job.org

#### Opción C: GitHub Actions

Crea `.github/workflows/notifications.yml`:

\`\`\`yaml
name: Send Notifications
on:
  schedule:
    - cron: '*/5 * * * *'  # Cada 5 minutos
  workflow_dispatch:

jobs:
  send-notifications:
    runs-on: ubuntu-latest
    steps:
      - name: Trigger Notification API
        run: |
          curl -X POST https://tudominio.com/api/notifications/send \
            -H "Authorization: Bearer ${{ secrets.CRON_SECRET }}"
\`\`\`

## 🧪 Testing

### Probar la API Manualmente

\`\`\`bash
# Desarrollo local
curl -X POST http://localhost:3000/api/notifications/send \
  -H "Authorization: Bearer tu_cron_secret"

# Producción
curl -X POST https://tudominio.com/api/notifications/send \
  -H "Authorization: Bearer tu_cron_secret"
\`\`\`

### Verificar Funciones SQL

\`\`\`sql
-- Ver empleados que necesitan recordatorio de entrada
SELECT * FROM get_employees_needing_clock_in_reminder();

-- Ver empleados que necesitan recordatorio de salida
SELECT * FROM get_employees_needing_clock_out_reminder();

-- Ver log de notificaciones
SELECT * FROM notification_logs 
ORDER BY created_at DESC 
LIMIT 10;
\`\`\`

## 📊 Monitoreo

### Ver Notificaciones Enviadas

Los administradores pueden ver todas las notificaciones en la tabla `notification_logs`:

\`\`\`sql
-- Notificaciones del día
SELECT 
  nl.sent_at,
  e.full_name,
  nl.notification_type,
  nl.status
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE DATE(nl.sent_at) = CURRENT_DATE
ORDER BY nl.sent_at DESC;

-- Estadísticas por empleado
SELECT 
  e.full_name,
  COUNT(*) as total_notifications,
  SUM(CASE WHEN nl.notification_type = 'clock_in_reminder' THEN 1 ELSE 0 END) as clock_in_reminders,
  SUM(CASE WHEN nl.notification_type = 'clock_out_reminder' THEN 1 ELSE 0 END) as clock_out_reminders
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE nl.sent_at >= NOW() - INTERVAL '30 days'
GROUP BY e.full_name
ORDER BY total_notifications DESC;
\`\`\`

## 🎨 Personalizar Correos

Los templates de correo están en `/app/api/notifications/send/route.ts`:

- `sendClockInReminderEmail()` - Template de entrada
- `sendClockOutReminderEmail()` - Template de salida

Puedes modificar:
- Diseño HTML
- Colores y estilos
- Texto del mensaje
- Información adicional

## 🔧 Troubleshooting

### Los correos no se envían

1. Verifica que el cron job esté ejecutándose
2. Revisa los logs de Vercel/tu servidor
3. Verifica las credenciales del proveedor de correo
4. Comprueba que `EMAIL_PROVIDER` esté configurado correctamente

### Los empleados no reciben notificaciones

1. Verifica que tengan email configurado en la tabla `employees`
2. Comprueba que tengan un horario asignado en `department_schedules`
3. Verifica que `is_active = true` en employees
4. Revisa `notification_logs` para ver si se enviaron

### Se envían demasiados correos

El sistema está configurado para:
- No enviar más de 1 correo cada 2 horas por empleado/tipo
- Solo enviar en horario laboral (06:00 - 23:00)

Si necesitas ajustar estos límites, modifica las funciones SQL en `notifications.sql`.

## 📝 Variables de Entorno

\`\`\`env
# Obligatorias
NEXT_PUBLIC_APP_URL=https://tudominio.com
CRON_SECRET=tu_token_secreto

# Para Resend
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_tu_api_key
EMAIL_FROM=Control Horario <noreply@tudominio.com>

# Para SendGrid
EMAIL_PROVIDER=sendgrid
SENDGRID_API_KEY=SG.tu_api_key
EMAIL_FROM=noreply@tudominio.com
\`\`\`

## 🚀 Próximos Pasos

1. Ejecutar `supabase/notifications.sql`
2. Configurar variables de entorno
3. Desplegar en Vercel o configurar cron job
4. Probar el endpoint manualmente
5. Monitorear los primeros días

## 📞 Soporte

Si tienes problemas, revisa:
- Logs de la aplicación
- Tabla `notification_logs` en Supabase
- Consola del proveedor de correo
- Logs del cron job


