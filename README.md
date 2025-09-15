# Control Horario Empresarial

Una aplicación web moderna para el control de horarios empresariales, construida con Next.js, TypeScript, Supabase y desplegada en Netlify.

## 🚀 Características

- **Autenticación segura** con Supabase Auth
- **Registro de tiempo** en tiempo real con entrada/salida y descansos
- **Gestión de empleados** completa con departamentos y posiciones
- **Reportes y estadísticas** con gráficos interactivos
- **Dashboard intuitivo** con métricas en tiempo real
- **Exportación de datos** en formato CSV
- **Diseño responsive** para móviles y escritorio

## 🛠️ Tecnologías

- **Frontend**: Next.js 14, TypeScript, Tailwind CSS
- **Backend**: Supabase (PostgreSQL, Auth, Real-time)
- **Gráficos**: Recharts
- **Iconos**: Lucide React
- **Despliegue**: Netlify

## 📋 Prerrequisitos

- Node.js 18+
- Cuenta de Supabase
- Cuenta de Netlify
- Cuenta de GitHub

## 🚀 Instalación

1. **Clona el repositorio**
   ```bash
   git clone <tu-repositorio>
   cd control-horario-empresarial
   ```

2. **Instala las dependencias**
   ```bash
   npm install
   ```

3. **Configura las variables de entorno**
   ```bash
   cp env.example .env.local
   ```
   
   Edita `.env.local` con tus credenciales de Supabase:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=tu_url_de_supabase
   NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anonima_de_supabase
   NEXT_PUBLIC_APP_URL=http://localhost:3000
   ```

4. **Configura la base de datos**
   - Ve a tu proyecto de Supabase
   - Abre el SQL Editor
   - Ejecuta el script en `supabase/schema.sql`

5. **Ejecuta la aplicación**
   ```bash
   npm run dev
   ```

   La aplicación estará disponible en `http://localhost:3000`

## 🗄️ Configuración de Supabase

### 1. Crear proyecto
- Ve a [supabase.com](https://supabase.com)
- Crea una nueva cuenta o inicia sesión
- Crea un nuevo proyecto

### 2. Ejecutar esquema
- Ve a la sección "SQL Editor"
- Copia y pega el contenido de `supabase/schema.sql`
- Ejecuta el script

### 3. Configurar autenticación
- Ve a Authentication > Settings
- Configura las URLs de redirección:
  - Site URL: `http://localhost:3000` (desarrollo)
  - Redirect URLs: `http://localhost:3000/auth/callback`

### 4. Obtener credenciales
- Ve a Settings > API
- Copia la URL del proyecto y la clave anónima
- Actualiza las variables en `.env.local`

## 🚀 Despliegue en Netlify

### 1. Preparar el repositorio
```bash
git add .
git commit -m "Initial commit"
git push origin main
```

### 2. Conectar con Netlify
- Ve a [netlify.com](https://netlify.com)
- Inicia sesión con tu cuenta de GitHub
- Haz clic en "New site from Git"
- Selecciona tu repositorio

### 3. Configurar el build
- Build command: `npm run build`
- Publish directory: `.next`
- Node version: `18`

### 4. Configurar variables de entorno
En el dashboard de Netlify, ve a Site settings > Environment variables y agrega:
```
NEXT_PUBLIC_SUPABASE_URL=tu_url_de_supabase_produccion
NEXT_PUBLIC_SUPABASE_ANON_KEY=tu_clave_anonima_de_supabase_produccion
NEXT_PUBLIC_APP_URL=https://tu-app.netlify.app
```

### 5. Actualizar Supabase
- Ve a Authentication > Settings en Supabase
- Actualiza las URLs de redirección:
  - Site URL: `https://tu-app.netlify.app`
  - Redirect URLs: `https://tu-app.netlify.app/auth/callback`

## 📱 Uso de la aplicación

### Para empleados:
1. **Registro**: Crea una cuenta con tu email
2. **Entrada**: Haz clic en "Entrada" al comenzar tu jornada
3. **Descansos**: Usa "Iniciar Descanso" y "Finalizar Descanso"
4. **Salida**: Haz clic en "Salida" al terminar tu jornada
5. **Dashboard**: Ve tus estadísticas y registros recientes

### Para administradores:
1. **Empleados**: Gestiona la información de empleados
2. **Reportes**: Ve estadísticas y exporta datos
3. **Configuración**: Ajusta parámetros de la empresa

## 🏗️ Estructura del proyecto

```
├── app/                    # App Router de Next.js
│   ├── dashboard/         # Páginas del dashboard
│   ├── auth/             # Páginas de autenticación
│   └── globals.css       # Estilos globales
├── components/           # Componentes reutilizables
│   ├── auth/            # Componentes de autenticación
│   ├── layout/          # Componentes de layout
│   └── providers/       # Context providers
├── lib/                 # Utilidades y configuración
│   ├── supabase.ts      # Cliente de Supabase
│   ├── auth.ts          # Funciones de autenticación
│   └── utils.ts         # Utilidades generales
├── supabase/            # Esquemas y configuración de BD
└── public/              # Archivos estáticos
```

## 🔧 Personalización

### Colores y tema
Edita `tailwind.config.js` para cambiar los colores:
```javascript
theme: {
  extend: {
    colors: {
      primary: {
        // Tus colores personalizados
      }
    }
  }
}
```

### Configuración de empresa
Modifica `supabase/company_settings` para ajustar:
- Horas regulares por día
- Umbral de horas extra
- Multiplicador de horas extra
- Zona horaria

## 🐛 Solución de problemas

### Error de autenticación
- Verifica que las URLs de redirección estén configuradas correctamente
- Asegúrate de que las variables de entorno sean correctas

### Error de base de datos
- Verifica que el esquema se haya ejecutado correctamente
- Revisa los permisos RLS (Row Level Security)

### Error de build en Netlify
- Verifica que la versión de Node.js sea 18+
- Revisa que todas las variables de entorno estén configuradas

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:
1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📞 Soporte

Si tienes problemas o preguntas:
- Abre un issue en GitHub
- Revisa la documentación de [Supabase](https://supabase.com/docs)
- Revisa la documentación de [Next.js](https://nextjs.org/docs)
- Revisa la documentación de [Netlify](https://docs.netlify.com)

---

¡Gracias por usar Control Horario Empresarial! 🎉
