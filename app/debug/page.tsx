'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'

interface DebugInfo {
  environmentVars: {
    supabaseUrl: string | undefined
    supabaseKey: string | undefined
    appUrl: string | undefined
  }
  supabaseConnection: {
    canConnect: boolean
    error: string | null
    testQuery: any
  }
  authStatus: {
    user: any
    session: any
    isAuthenticated: boolean
  }
}

export default function DebugPage() {
  const { user, loading } = useAuth()
  const [debugInfo, setDebugInfo] = useState<DebugInfo | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    const runDiagnostics = async () => {
      const info: DebugInfo = {
        environmentVars: {
          supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
          supabaseKey: process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ? '***HIDDEN***' : undefined,
          appUrl: process.env.NEXT_PUBLIC_APP_URL
        },
        supabaseConnection: {
          canConnect: false,
          error: null,
          testQuery: null
        },
        authStatus: {
          user: user || null,
          session: null,
          isAuthenticated: !!user
        }
      }

      // Test Supabase connection
      try {
        console.log('🔍 Testing Supabase connection...')
        
        // Test 1: Simple query to check connection
        const { data, error } = await supabase
          .from('departments')
          .select('count')
          .limit(1)

        if (error) {
          throw error
        }

        info.supabaseConnection.canConnect = true
        info.supabaseConnection.testQuery = data
        console.log('✅ Supabase connection successful:', data)

        // Test 2: Get session
        const { data: session } = await supabase.auth.getSession()
        info.authStatus.session = session
        console.log('📝 Auth session:', session)

      } catch (error: any) {
        console.error('❌ Supabase connection failed:', error)
        info.supabaseConnection.error = error.message || 'Unknown error'
      }

      setDebugInfo(info)
      setIsLoading(false)
    }

    runDiagnostics()
  }, [user])

  if (isLoading || loading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
      </div>
    )
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 py-8">
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-6">
            🔍 Diagnóstico de Conexión
          </h1>
          
          <div className="space-y-6">
            {/* Variables de Entorno */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Variables de Entorno
              </h2>
              <div className="bg-gray-50 dark:bg-gray-800 rounded p-4 space-y-2">
                <div className="flex justify-between">
                  <span className="font-medium">NEXT_PUBLIC_SUPABASE_URL:</span>
                  <span className={`${debugInfo?.environmentVars.supabaseUrl ? 'text-green-600' : 'text-red-600'}`}>
                    {debugInfo?.environmentVars.supabaseUrl || '❌ No configurada'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="font-medium">NEXT_PUBLIC_SUPABASE_ANON_KEY:</span>
                  <span className={`${debugInfo?.environmentVars.supabaseKey ? 'text-green-600' : 'text-red-600'}`}>
                    {debugInfo?.environmentVars.supabaseKey || '❌ No configurada'}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="font-medium">NEXT_PUBLIC_APP_URL:</span>
                  <span className={`${debugInfo?.environmentVars.appUrl ? 'text-green-600' : 'text-red-600'}`}>
                    {debugInfo?.environmentVars.appUrl || '❌ No configurada'}
                  </span>
                </div>
              </div>
            </div>

            {/* Conexión con Supabase */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Conexión con Supabase
              </h2>
              <div className="bg-gray-50 dark:bg-gray-800 rounded p-4">
                <div className="flex items-center mb-2">
                  <span className="font-medium mr-2">Estado:</span>
                  <span className={`${debugInfo?.supabaseConnection.canConnect ? 'text-green-600' : 'text-red-600'}`}>
                    {debugInfo?.supabaseConnection.canConnect ? '✅ Conectado' : '❌ Sin conexión'}
                  </span>
                </div>
                {debugInfo?.supabaseConnection.error && (
                  <div className="text-red-600 text-sm mt-2">
                    <strong>Error:</strong> {debugInfo.supabaseConnection.error}
                  </div>
                )}
                {debugInfo?.supabaseConnection.testQuery && (
                  <div className="text-green-600 text-sm mt-2">
                    <strong>Test Query Result:</strong> {JSON.stringify(debugInfo.supabaseConnection.testQuery)}
                  </div>
                )}
              </div>
            </div>

            {/* Estado de Autenticación */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Estado de Autenticación
              </h2>
              <div className="bg-gray-50 dark:bg-gray-800 rounded p-4">
                <div className="flex items-center mb-2">
                  <span className="font-medium mr-2">Usuario:</span>
                  <span className={`${debugInfo?.authStatus.isAuthenticated ? 'text-green-600' : 'text-red-600'}`}>
                    {debugInfo?.authStatus.isAuthenticated ? '✅ Autenticado' : '❌ No autenticado'}
                  </span>
                </div>
                {debugInfo?.authStatus.user && (
                  <div className="text-sm mt-2">
                    <strong>Email:</strong> {debugInfo.authStatus.user.email}
                  </div>
                )}
              </div>
            </div>

            {/* Información del Sistema */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Información del Sistema
              </h2>
              <div className="bg-gray-50 dark:bg-gray-800 rounded p-4 text-sm">
                <div>URL actual: {typeof window !== 'undefined' ? window.location.href : 'N/A'}</div>
                <div>User Agent: {typeof navigator !== 'undefined' ? navigator.userAgent : 'N/A'}</div>
                <div>Timestamp: {new Date().toISOString()}</div>
              </div>
            </div>

            {/* Acciones de Debug */}
            <div>
              <h2 className="text-lg font-semibold text-gray-900 dark:text-white mb-3">
                Acciones de Debug
              </h2>
              <div className="space-y-2">
                <button
                  onClick={() => window.location.reload()}
                  className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded mr-2"
                >
                  Recargar Diagnóstico
                </button>
                <button
                  onClick={() => console.log('Debug Info:', debugInfo)}
                  className="bg-gray-600 hover:bg-gray-700 text-white px-4 py-2 rounded mr-2"
                >
                  Log a Consola
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
