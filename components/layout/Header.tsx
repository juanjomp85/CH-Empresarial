'use client'

import { useAuth } from '@/components/providers/AuthProvider'
import { useTheme } from '@/components/providers/ThemeProvider'
import { usePathname } from 'next/navigation'
import { Bell, User, Sun, Moon, Bug } from 'lucide-react'

export default function Header() {
  const { user } = useAuth()
  const { theme, setTheme, resolvedTheme } = useTheme()
  const pathname = usePathname()

  const toggleTheme = () => {
    setTheme(resolvedTheme === 'dark' ? 'light' : 'dark')
  }

  // Función para obtener el título de la página según la ruta
  const getPageTitle = () => {
    const pathMap: { [key: string]: string } = {
      '/dashboard': 'Dashboard',
      '/dashboard/time': 'Mi Tiempo',
      '/dashboard/employees': 'Empleados', 
      '/dashboard/reports': 'Reportes',
      '/dashboard/calendar': 'Calendario',
      '/dashboard/settings': 'Configuración'
    }
    
    // Si la ruta exacta existe en el mapa, la devolvemos
    if (pathMap[pathname]) {
      return pathMap[pathname]
    }
    
    // Si no, buscamos por prefijo (para manejar subrutas)
    for (const [path, title] of Object.entries(pathMap)) {
      if (pathname.startsWith(path) && path !== '/dashboard') {
        return title
      }
    }
    
    return 'Dashboard'
  }

  return (
    <header className="bg-white dark:bg-gray-950 shadow-sm border-b border-gray-200 dark:border-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between items-center h-16">
          {/* Page title - se puede personalizar según la página */}
          <div className="flex items-center">
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white">
              {getPageTitle()}
            </h2>
          </div>

          {/* Right side */}
          <div className="flex items-center space-x-4">
            {/* Debug button (temporary) */}
            <a
              href="/debug"
              className="p-2 text-orange-600 dark:text-orange-400 hover:text-orange-900 dark:hover:text-orange-300 transition-colors"
              title="Diagnóstico de conexión"
            >
              <Bug className="h-5 w-5" />
            </a>
            
            {/* Theme toggle */}
            <button 
              onClick={toggleTheme}
              className="p-2 text-gray-400 hover:text-gray-500 dark:text-gray-300 dark:hover:text-gray-100 transition-colors duration-200"
              title={`Cambiar a modo ${resolvedTheme === 'dark' ? 'claro' : 'oscuro'}`}
            >
              {resolvedTheme === 'dark' ? (
                <Sun className="h-5 w-5" />
              ) : (
                <Moon className="h-5 w-5" />
              )}
            </button>

            {/* Notifications */}
            <button className="p-2 text-gray-400 hover:text-gray-500 dark:text-gray-300 dark:hover:text-gray-100 relative">
              <Bell className="h-6 w-6" />
              <span className="absolute top-1 right-1 h-2 w-2 bg-red-500 rounded-full"></span>
            </button>

            {/* User menu */}
            <div className="flex items-center space-x-3">
              <div className="flex items-center space-x-2">
                <div className="h-8 w-8 bg-primary-100 dark:bg-primary-900 rounded-full flex items-center justify-center">
                  <User className="h-5 w-5 text-primary-600 dark:text-primary-400" />
                </div>
                <div className="hidden sm:block">
                  <p className="text-sm font-medium text-gray-900 dark:text-white">
                    {user?.user_metadata?.full_name || user?.email}
                  </p>
                  <p className="text-xs text-gray-500 dark:text-gray-400">
                    {user?.email}
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </header>
  )
}
