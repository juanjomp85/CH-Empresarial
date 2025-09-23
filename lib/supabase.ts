import { createClient } from '@supabase/supabase-js'

// Función para crear el cliente de Supabase con validaciones
function createSupabaseClient() {
  const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL
  const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY

  // Durante el build, si las variables no están configuradas, usar valores mock
  if (process.env.NODE_ENV === 'production' && (!supabaseUrl || !supabaseAnonKey)) {
    console.warn('Variables de entorno de Supabase no configuradas durante el build')
    return createClient('https://placeholder.supabase.co', 'placeholder-key')
  }

  // Validaciones con mensajes de error detallados
  if (!supabaseUrl) {
    throw new Error('Falta la variable de entorno NEXT_PUBLIC_SUPABASE_URL')
  }

  if (!supabaseAnonKey) {
    throw new Error('Falta la variable de entorno NEXT_PUBLIC_SUPABASE_ANON_KEY')
  }

  // Validar formato de URL solo si no es un placeholder
  if (!supabaseUrl.includes('placeholder')) {
    try {
      new URL(supabaseUrl)
    } catch (error) {
      throw new Error(`NEXT_PUBLIC_SUPABASE_URL no es una URL válida: ${supabaseUrl}`)
    }
  }

  return createClient(supabaseUrl, supabaseAnonKey)
}

export const supabase = createSupabaseClient()

// Tipos para TypeScript
export interface Employee {
  id: string
  email: string
  full_name: string
  position: string
  department: string
  hourly_rate: number
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
  hourly_rate: number
  description?: string
  created_at: string
}
