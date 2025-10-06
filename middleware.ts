import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'
import { NextResponse } from 'next/server'
import type { NextRequest } from 'next/server'

// Rutas que requieren permisos de administrador
const adminRoutes = [
  '/dashboard/employees',
  '/dashboard/settings',
]

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient({ req, res })

  // Verificar si el usuario está autenticado
  const {
    data: { session },
  } = await supabase.auth.getSession()

  // Si no hay sesión y está intentando acceder al dashboard, redirigir al login
  if (!session && req.nextUrl.pathname.startsWith('/dashboard')) {
    const redirectUrl = req.nextUrl.clone()
    redirectUrl.pathname = '/'
    return NextResponse.redirect(redirectUrl)
  }

  // Verificar si la ruta requiere permisos de admin
  const isAdminRoute = adminRoutes.some(route => 
    req.nextUrl.pathname.startsWith(route)
  )

  if (isAdminRoute && session) {
    // Verificar si el usuario tiene rol de administrador
    const userRole = session.user.user_metadata?.role
    
    if (userRole !== 'admin') {
      // Si no es admin, redirigir al dashboard principal
      const redirectUrl = req.nextUrl.clone()
      redirectUrl.pathname = '/dashboard'
      return NextResponse.redirect(redirectUrl)
    }
  }

  return res
}

// Configurar en qué rutas se ejecuta el middleware
export const config = {
  matcher: [
    '/dashboard/:path*',
  ],
}

