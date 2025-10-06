import { createClient } from '@supabase/supabase-js'

// Función para crear el cliente de Supabase con validaciones
function createSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  // Log de debugging para producción
  if (typeof window !== 'undefined') {
    console.log('🔧 Supabase Client Debug Info:')
    console.log('- URL configured:', !!supabaseUrl)
    console.log('- Key configured:', !!supabaseAnonKey)
    console.log('- Environment:', process.env.NODE_ENV)
    if (supabaseUrl && !supabaseUrl.includes('placeholder')) {
      console.log('- URL domain:', new URL(supabaseUrl).hostname)
    }
  }

  // Durante el build, si las variables no están configuradas, usar valores mock
  if (process.env.NODE_ENV === 'production' && (!supabaseUrl || !supabaseAnonKey)) {
    console.warn('⚠️ Variables de entorno de Supabase no configuradas durante el build')
    return createClient('https://placeholder.supabase.co', 'placeholder-key')
  }

  // Validaciones con mensajes de error detallados
  if (!supabaseUrl) {
    const error = 'Falta la variable de entorno NEXT_PUBLIC_SUPABASE_URL'
    console.error('❌ Supabase Error:', error)
    throw new Error(error)
  }

  if (!supabaseAnonKey) {
    const error = 'Falta la variable de entorno NEXT_PUBLIC_SUPABASE_ANON_KEY'
    console.error('❌ Supabase Error:', error)
    throw new Error(error)
  }

  // Validar formato de URL solo si no es un placeholder
  if (!supabaseUrl.includes('placeholder')) {
    try {
      new URL(supabaseUrl)
    } catch (error) {
      const errorMsg = `NEXT_PUBLIC_SUPABASE_URL no es una URL válida: ${supabaseUrl}`
      console.error('❌ Supabase URL Error:', errorMsg)
      throw new Error(errorMsg)
    }
  }

  const client = createClient(supabaseUrl, supabaseAnonKey)
  
  if (typeof window !== 'undefined') {
    console.log('✅ Supabase client created successfully')
  }

  return client
}

export const supabase = createSupabaseClient()

// Tipos para TypeScript
export interface Employee {
  id: string
  email: string
  full_name: string
  position: string
  department: string
  is_active: boolean
  created_at: string
  updated_at: string
}

export interface TimeEntry {
  id: string
  employee_id: string
  date: string
  clock_in: string
  clock_out?: string
  break_start?: string
  break_end?: string
  total_hours?: number
  overtime_hours?: number
  notes?: string
  created_at: string
  updated_at: string
}

export interface Department {
  id: string
  name: string
  description?: string
  created_at: string
}

export interface Position {
  id: string
  title: string
  department_id: string
  description?: string
  created_at: string
}

