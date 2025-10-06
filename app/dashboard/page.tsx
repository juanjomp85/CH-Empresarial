'use client'

import { useEffect, useState, useCallback } from 'react'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { Clock, Users, Calendar, TrendingUp } from 'lucide-react'
import { formatDate, formatTime, getTodayString, formatDateForDB, formatDuration } from '@/lib/utils'

interface DashboardStats {
  totalHours: number
  todayHours: number
  weeklyHours: number
  monthlyHours: number
}

interface RecentTimeEntry {
  id: string
  date: string
  clock_in: string
  clock_out: string | null
  total_hours: number | null
}

export default function DashboardPage() {
  const { user } = useAuth()
  const [stats, setStats] = useState<DashboardStats>({
    totalHours: 0,
    todayHours: 0,
    weeklyHours: 0,
    monthlyHours: 0
  })
  const [recentEntries, setRecentEntries] = useState<RecentTimeEntry[]>([])
  const [loading, setLoading] = useState(true)
  const [currentTime, setCurrentTime] = useState(new Date())

  const loadDashboardData = useCallback(async () => {
    if (!user) return

    try {
      // Obtener empleado
      const { data: employee } = await supabase
        .from('employees')
        .select('id')
        .eq('user_id', user.id)
        .single()

      if (!employee) return

      const today = getTodayString()
      
      // Obtener todas las entradas de tiempo del empleado
      const { data: timeEntries } = await supabase
        .from('time_entries')
        .select('*')
        .eq('employee_id', employee.id)
        .order('date', { ascending: false })

      if (timeEntries) {
        // Para entradas recientes, tomar solo las últimas 5
        setRecentEntries(timeEntries.slice(0, 5))
        
        // Calcular estadísticas
        const totalHours = timeEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)
        const todayEntry = timeEntries.find(entry => entry.date === today)
        const todayHours = todayEntry?.total_hours || 0
        
        // Calcular horas de esta semana
        const weekStart = new Date()
        weekStart.setDate(weekStart.getDate() - weekStart.getDay())
        const weekEntries = timeEntries.filter(entry => {
          const entryDate = new Date(entry.date)
          return entryDate >= weekStart
        })
        const weeklyHours = weekEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)
        
        // Calcular horas de este mes
        const monthStart = new Date()
        monthStart.setDate(1)
        const monthEntries = timeEntries.filter(entry => {
          const entryDate = new Date(entry.date)
          return entryDate >= monthStart
        })
        const monthlyHours = monthEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)
        
        setStats({
          totalHours,
          todayHours,
          weeklyHours,
          monthlyHours
        })
      }
    } catch (error) {
      console.error('Error loading dashboard data:', error)
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => {
    loadDashboardData()
  }, [loadDashboardData])

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date())
    }, 1000)

    return () => clearInterval(timer)
  }, [])


  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Welcome message */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          ¡Bienvenido de vuelta!
        </h1>
        <p className="text-gray-600">
          Aquí tienes un resumen de tu actividad laboral
        </p>
        <div className="mt-4 text-sm text-gray-500 dark:text-gray-400">
          {formatDate(currentTime)} - {formatTime(currentTime)}
        </div>
      </div>

      {/* Stats cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div className="stat-card">
          <div className="flex items-center">
            <Clock className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Hoy</p>
              <p className="text-2xl font-bold text-white">
                {formatDuration(stats.todayHours)}
              </p>
            </div>
          </div>
        </div>

        <div className="stat-card">
          <div className="flex items-center">
            <Calendar className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Esta Semana</p>
              <p className="text-2xl font-bold text-white">
                {formatDuration(stats.weeklyHours)}
              </p>
            </div>
          </div>
        </div>

        <div className="stat-card">
          <div className="flex items-center">
            <TrendingUp className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Este Mes</p>
              <p className="text-2xl font-bold text-white">
                {formatDuration(stats.monthlyHours)}
              </p>
            </div>
          </div>
        </div>

        <div className="stat-card">
          <div className="flex items-center">
            <Users className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Total</p>
              <p className="text-2xl font-bold text-white">
                {formatDuration(stats.totalHours)}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Recent time entries */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-800">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            Registros Recientes
          </h3>
        </div>
        <div className="divide-y divide-gray-200 dark:divide-gray-800">
          {recentEntries.length > 0 ? (
            recentEntries.map((entry) => (
              <div key={entry.id} className="px-6 py-4">
                <div className="flex items-center justify-between">
                  <div>
                    <p className="text-sm font-medium text-gray-900 dark:text-white">
                      {formatDate(entry.date)}
                    </p>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      {formatTime(entry.clock_in)} - {entry.clock_out ? formatTime(entry.clock_out) : 'En curso'}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="text-sm font-medium text-gray-900 dark:text-white">
                      {entry.total_hours ? formatDuration(entry.total_hours) : 'En curso'}
                    </p>
                    {entry.clock_out && (
                      <p className="text-xs text-gray-500 dark:text-gray-400">
                        {entry.total_hours && entry.total_hours > 8 
                          ? `+${formatDuration(entry.total_hours - 8)} extra`
                          : 'Horario normal'
                        }
                      </p>
                    )}
                  </div>
                </div>
              </div>
            ))
          ) : (
            <div className="px-6 py-8 text-center text-gray-500 dark:text-gray-400">
              No hay registros de tiempo aún
            </div>
          )}
        </div>
      </div>

      {/* Quick actions */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">
          Acciones Rápidas
        </h3>
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <a
            href="/dashboard/time"
            className="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <Clock className="h-6 w-6 text-primary-600 mr-3" />
            <span className="font-medium">Registrar Tiempo</span>
          </a>
          <a
            href="/dashboard/reports"
            className="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <TrendingUp className="h-6 w-6 text-primary-600 mr-3" />
            <span className="font-medium">Ver Reportes</span>
          </a>
          <a
            href="/dashboard/calendar"
            className="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors"
          >
            <Calendar className="h-6 w-6 text-primary-600 mr-3" />
            <span className="font-medium">Calendario</span>
          </a>
        </div>
      </div>
    </div>
  )
}
