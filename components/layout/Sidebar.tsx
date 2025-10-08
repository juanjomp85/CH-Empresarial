'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { cn } from '@/lib/utils'
import {
  Clock,
  Users,
  BarChart3,
  Settings,
  Calendar,
  FileText,
  Menu,
  X,
  LogOut,
  Shield,
  ClipboardCheck
} from 'lucide-react'
import { useAuth } from '@/components/providers/AuthProvider'
import { useRole } from '@/lib/hooks/useRole'

interface NavigationItem {
  name: string
  href: string
  icon: any
  adminOnly?: boolean
}

const navigation: NavigationItem[] = [
  { name: 'Dashboard', href: '/dashboard', icon: BarChart3 },
  { name: 'Mi Tiempo', href: '/dashboard/time', icon: Clock },
  { name: 'Cumplimiento', href: '/dashboard/compliance', icon: ClipboardCheck },
  { name: 'Empleados', href: '/dashboard/employees', icon: Users, adminOnly: true },
  { name: 'Reportes', href: '/dashboard/reports', icon: FileText },
  { name: 'Calendario', href: '/dashboard/calendar', icon: Calendar },
  { name: 'Configuración', href: '/dashboard/settings', icon: Settings, adminOnly: true },
]

export default function Sidebar() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const pathname = usePathname()
  const { signOut } = useAuth()
  const { isAdmin, loading: roleLoading } = useRole()

  const handleSignOut = async () => {
    await signOut()
  }

  // Filtrar navegación según el rol del usuario
  const filteredNavigation = navigation.filter(item => {
    // Si el item no requiere permisos de admin, mostrarlo
    if (!item.adminOnly) return true
    // Si requiere admin, solo mostrarlo si el usuario es admin
    return isAdmin
  })

  return (
    <>
      {/* Mobile menu button */}
      <div className="lg:hidden fixed top-6 left-4 z-50">
        <button
          type="button"
          className="bg-white dark:bg-gray-800 p-2 rounded-md shadow-md border dark:border-gray-700"
          onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
        >
          {mobileMenuOpen ? (
            <X className="h-6 w-6 text-gray-600 dark:text-gray-300" />
          ) : (
            <Menu className="h-6 w-6 text-gray-600 dark:text-gray-300" />
          )}
        </button>
      </div>

      {/* Sidebar */}
      <div className={cn(
        "fixed inset-y-0 left-0 z-40 w-64 bg-white dark:bg-gray-950 shadow-lg transform transition-transform duration-300 ease-in-out lg:translate-x-0",
        mobileMenuOpen ? "translate-x-0" : "-translate-x-full"
      )}>
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="flex items-center justify-center h-20 px-4 bg-primary-600 dark:bg-primary-700">
            <h1 className="text-xl font-bold text-white">
              Control Horario
            </h1>
          </div>

          {/* Navigation */}
          <nav className="flex-1 px-4 py-6 space-y-2">
            {/* Indicador de rol de administrador */}
            {isAdmin && (
              <div className="mb-4 px-4 py-2 bg-amber-100 dark:bg-amber-900/30 rounded-lg">
                <div className="flex items-center text-amber-800 dark:text-amber-200">
                  <Shield className="h-4 w-4 mr-2" />
                  <span className="text-xs font-semibold">Administrador</span>
                </div>
              </div>
            )}

            {filteredNavigation.map((item) => {
              const isActive = pathname === item.href
              return (
                <Link
                  key={item.name}
                  href={item.href}
                  className={cn(
                    "flex items-center px-4 py-2 text-sm font-medium rounded-lg transition-colors duration-200",
                    isActive
                      ? "bg-primary-100 dark:bg-primary-900/50 text-primary-700 dark:text-primary-300"
                      : "text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-900 hover:text-gray-900 dark:hover:text-white"
                  )}
                  onClick={() => setMobileMenuOpen(false)}
                >
                  <item.icon className="mr-3 h-5 w-5" />
                  {item.name}
                </Link>
              )
            })}
          </nav>

          {/* Sign out button */}
          <div className="p-4 border-t border-gray-200 dark:border-gray-800">
            <button
              onClick={handleSignOut}
              className="flex items-center w-full px-4 py-2 text-sm font-medium text-red-600 dark:text-red-400 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors duration-200"
            >
              <LogOut className="mr-3 h-5 w-5" />
              Cerrar Sesión
            </button>
          </div>
        </div>
      </div>

      {/* Mobile overlay */}
      {mobileMenuOpen && (
        <div
          className="fixed inset-0 z-30 bg-black bg-opacity-50 dark:bg-opacity-70 lg:hidden"
          onClick={() => setMobileMenuOpen(false)}
        />
      )}
    </>
  )
}
