import { createClient } from '@supabase/supabase-js'

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!

export const supabase = createClient(supabaseUrl, supabaseAnonKey)

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
