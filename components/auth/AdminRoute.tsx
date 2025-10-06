'use client'

import { useRouter } from 'next/navigation'
import { useEffect } from 'react'
import { useRole } from '@/lib/hooks/useRole'
import { ShieldAlert } from 'lucide-react'

interface AdminRouteProps {
  children: React.ReactNode
  fallbackPath?: string
}

/**
 * Componente que protege rutas para que solo los administradores puedan acceder
 * Si el usuario no es admin, será redirigido al fallbackPath o mostrará un mensaje de acceso denegado
 */
export default function AdminRoute({ children, fallbackPath = '/dashboard' }: AdminRouteProps) {
  const { isAdmin, loading } = useRole()
  const router = useRouter()

  useEffect(() => {
    // Si ya terminó de cargar y no es admin, redirigir
    if (!loading && !isAdmin) {
      router.push(fallbackPath)
    }
  }, [isAdmin, loading, router, fallbackPath])

  // Mostrar loading mientras se verifica el rol
  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  // Si no es admin, mostrar mensaje de acceso denegado
  if (!isAdmin) {
    return (
      <div className="flex flex-col items-center justify-center h-64 space-y-4">
        <ShieldAlert className="h-16 w-16 text-red-500" />
        <h2 className="text-2xl font-bold text-gray-900 dark:text-white">
          Acceso Denegado
        </h2>
        <p className="text-gray-600 dark:text-gray-300">
          No tienes permisos para acceder a esta página.
        </p>
        <button
          onClick={() => router.push(fallbackPath)}
          className="btn-primary mt-4"
        >
          Volver al Dashboard
        </button>
      </div>
    )
  }

  // Si es admin, renderizar el contenido
  return <>{children}</>
}

