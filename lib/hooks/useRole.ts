import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'

export type UserRole = 'employee' | 'admin' | null

interface RoleData {
  role: UserRole
  loading: boolean
  isAdmin: boolean
  employeeId: string | null
}

/**
 * Hook para obtener y verificar el rol del usuario actual
 * @returns {RoleData} Objeto con el rol, estado de carga y función de verificación
 */
export function useRole(): RoleData {
  const { user } = useAuth()
  const [role, setRole] = useState<UserRole>(null)
  const [employeeId, setEmployeeId] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    async function loadUserRole() {
      if (!user) {
        setRole(null)
        setEmployeeId(null)
        setLoading(false)
        return
      }

      try {
        // Obtener información del empleado incluyendo el rol
        const { data, error } = await supabase
          .from('employees')
          .select('id, role')
          .eq('user_id', user.id)
          .single()

        if (error) {
          console.error('Error loading user role:', error)
          setRole('employee') // Por defecto, si no se encuentra
          setEmployeeId(null)
        } else if (data) {
          setRole(data.role as UserRole)
          setEmployeeId(data.id)
        } else {
          setRole('employee')
          setEmployeeId(null)
        }
      } catch (error) {
        console.error('Error in loadUserRole:', error)
        setRole('employee')
        setEmployeeId(null)
      } finally {
        setLoading(false)
      }
    }

    loadUserRole()
  }, [user])

  return {
    role,
    loading,
    isAdmin: role === 'admin',
    employeeId
  }
}

/**
 * Hook simplificado que solo verifica si el usuario es administrador
 * @returns {boolean | null} true si es admin, false si no lo es, null si está cargando
 */
export function useIsAdmin(): boolean | null {
  const { isAdmin, loading } = useRole()
  return loading ? null : isAdmin
}

