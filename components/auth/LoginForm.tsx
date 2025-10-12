'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { signIn, signUp } from '@/lib/auth'
import { Eye, EyeOff, Clock, Users, BarChart3 } from 'lucide-react'

export default function LoginForm() {
  const [isLogin, setIsLogin] = useState(true)
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [fullName, setFullName] = useState('')
  const [showPassword, setShowPassword] = useState(false)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const router = useRouter()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')

    try {
      if (isLogin) {
        const { error } = await signIn(email, password)
        if (error) {
          setError('Credenciales incorrectas')
        } else {
          router.push('/dashboard/time')
        }
      } else {
        const { error } = await signUp(email, password, fullName)
        if (error) {
          setError('Error al crear la cuenta')
        } else {
          setError('Revisa tu email para confirmar la cuenta')
        }
      }
    } catch (err) {
      setError('Error inesperado')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl p-8">
      <form onSubmit={handleSubmit} className="space-y-6">
        <div className="text-center mb-6">
          <h2 className="text-2xl font-bold text-gray-900">
            {isLogin ? 'Iniciar Sesión' : 'Crear Cuenta'}
          </h2>
          <p className="text-gray-600 mt-2">
            {isLogin 
              ? 'Accede a tu panel de control' 
              : 'Regístrate para comenzar'
            }
          </p>
        </div>

        {!isLogin && (
          <div>
            <label htmlFor="fullName" className="block text-sm font-medium text-gray-700 mb-2">
              Nombre Completo
            </label>
            <input
              id="fullName"
              type="text"
              required={!isLogin}
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="input-field"
              placeholder="Tu nombre completo"
            />
          </div>
        )}

        <div>
          <label htmlFor="email" className="block text-sm font-medium text-gray-700 mb-2">
            Email
          </label>
          <input
            id="email"
            type="email"
            required
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="input-field"
            placeholder="tu@empresa.com"
          />
        </div>

        <div>
          <label htmlFor="password" className="block text-sm font-medium text-gray-700 mb-2">
            Contraseña
          </label>
          <div className="relative">
            <input
              id="password"
              type={showPassword ? 'text' : 'password'}
              required
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="input-field pr-10"
              placeholder="••••••••"
            />
            <button
              type="button"
              onClick={() => setShowPassword(!showPassword)}
              className="absolute inset-y-0 right-0 pr-3 flex items-center"
            >
              {showPassword ? (
                <EyeOff className="h-5 w-5 text-gray-400" />
              ) : (
                <Eye className="h-5 w-5 text-gray-400" />
              )}
            </button>
          </div>
        </div>

        {error && (
          <div className="bg-red-50 border border-red-200 text-red-600 px-4 py-3 rounded-lg">
            {error}
          </div>
        )}

        <button
          type="submit"
          disabled={loading}
          className="w-full btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
        >
          {loading ? 'Cargando...' : (isLogin ? 'Iniciar Sesión' : 'Crear Cuenta')}
        </button>

        <div className="text-center">
          <button
            type="button"
            onClick={() => setIsLogin(!isLogin)}
            className="text-primary-600 hover:text-primary-700 font-medium"
          >
            {isLogin 
              ? '¿No tienes cuenta? Regístrate' 
              : '¿Ya tienes cuenta? Inicia sesión'
            }
          </button>
        </div>
      </form>

      {/* Características destacadas */}
      <div className="mt-8 pt-6 border-t border-gray-200">
        <h3 className="text-sm font-medium text-gray-900 mb-4 text-center">
          Características principales
        </h3>
        <div className="grid grid-cols-3 gap-4 text-center">
          <div className="flex flex-col items-center">
            <Clock className="h-6 w-6 text-primary-600 mb-2" />
            <span className="text-xs text-gray-600">Control de Tiempo</span>
          </div>
          <div className="flex flex-col items-center">
            <Users className="h-6 w-6 text-primary-600 mb-2" />
            <span className="text-xs text-gray-600">Gestión de Empleados</span>
          </div>
          <div className="flex flex-col items-center">
            <BarChart3 className="h-6 w-6 text-primary-600 mb-2" />
            <span className="text-xs text-gray-600">Reportes</span>
          </div>
        </div>
      </div>
    </div>
  )
}
