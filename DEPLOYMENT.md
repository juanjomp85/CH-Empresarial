# Guía de Despliegue en Netlify

## Variables de Entorno Requeridas

Para que la aplicación funcione correctamente en Netlify, debes configurar las siguientes variables de entorno en el dashboard de Netlify:

### Variables Obligatorias

1. **NEXT_PUBLIC_SUPABASE_URL**
   - Tu URL de proyecto de Supabase
   - Formato: `https://tu-proyecto.supabase.co`
   - Se encuentra en: Supabase Dashboard > Settings > API > Project URL

2. **NEXT_PUBLIC_SUPABASE_ANON_KEY**
   - Tu clave anónima de Supabase
   - Se encuentra en: Supabase Dashboard > Settings > API > Project API keys > anon/public

3. **NEXT_PUBLIC_APP_URL**
   - La URL de tu aplicación desplegada
   - Formato: `https://tu-app.netlify.app`

## Cómo Configurar las Variables en Netlify

1. Ve a tu dashboard de Netlify
2. Selecciona tu sitio
3. Ve a **Site settings** > **Environment variables**
4. Haz clic en **Add a variable**
5. Agrega cada variable con su valor correspondiente

## Configuración de Supabase

Asegúrate de que tu proyecto de Supabase esté configurado correctamente:

1. **Esquema de base de datos**: Ejecuta el SQL en `supabase/schema.sql`
2. **RLS (Row Level Security)**: Configura las políticas según las necesidades
3. **Autenticación**: Configura los proveedores de autenticación necesarios

## Solución de Problemas

### Error: "Invalid supabaseUrl"
- Verifica que `NEXT_PUBLIC_SUPABASE_URL` sea una URL válida
- Asegúrate de que comience con `https://`
- No incluyas barras al final

### Error durante el build
- Verifica que todas las variables estén configuradas
- Revisa que no haya caracteres especiales o espacios en las variables

## Build y Deploy

El proceso de build en Netlify:
1. Clona el repositorio
2. Instala dependencias con `npm install`
3. Ejecuta `npm run build`
4. Despliega el contenido de `.next`

Si el build falla, revisa los logs de Netlify para identificar el problema específico.
