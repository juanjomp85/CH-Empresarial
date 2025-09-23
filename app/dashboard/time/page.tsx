'use client'

import { useEffect, useState, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { Clock, Play, Pause, Square, Coffee } from 'lucide-react'
import { formatTime, formatDate, calculateHours, getTodayString, formatDuration } from '@/lib/utils'

interface TimeEntry {
  id: string
  date: string
  clock_in: string
  clock_out: string | null
  break_start: string | null
  break_end: string | null
  total_hours: number | null
  overtime_hours: number | null
  notes: string | null
}

interface CurrentSession {
  clockIn: string | null
  breakStart: string | null
  isOnBreak: boolean
}

export default function TimeTrackingPage() {
  const { user } = useAuth()
  const [employee, setEmployee] = useState<any>(null)
  const [currentSession, setCurrentSession] = useState<CurrentSession>({
    clockIn: null,
    breakStart: null,
    isOnBreak: false
  })
  const [todayEntry, setTodayEntry] = useState<TimeEntry | null>(null)
  const [loading, setLoading] = useState(true)
  const [actionLoading, setActionLoading] = useState(false)
  const [currentTime, setCurrentTime] = useState(new Date())

  const loadEmployeeData = useCallback(async () => {
    console.log('🔄 Loading employee data for user:', user?.id)
    try {
      // Obtener empleado actual
      const { data: emp, error: empError } = await supabase
        .from('employees')
        .select('*')
        .eq('user_id', user?.id)
        .single()

      console.log('👤 Employee query result:', { emp, empError })

      let currentEmployee = emp

      if (!emp) {
        console.log('🆕 Creating new employee for user:', user?.id)
        // Si no existe el empleado, crearlo
        const { data: newEmp, error: newEmpError } = await supabase
          .from('employees')
          .insert({
            user_id: user?.id,
            email: user?.email,
            full_name: user?.user_metadata?.full_name || 'Usuario',
            position_id: null,
            department_id: null,
            hourly_rate: 0
          })
          .select()
          .single()

        console.log('🆕 New employee created:', { newEmp, newEmpError })
        if (newEmpError) throw newEmpError
        currentEmployee = newEmp
        setEmployee(newEmp)
      } else {
        console.log('✅ Employee found:', emp)
        setEmployee(emp)
      }

      // Obtener entrada de hoy
      const today = getTodayString()
      const { data: entry } = await supabase
        .from('time_entries')
        .select('*')
        .eq('employee_id', currentEmployee?.id)
        .eq('date', today)
        .single()

      if (entry) {
        setTodayEntry(entry)
        setCurrentSession({
          clockIn: entry.clock_in,
          breakStart: entry.break_start,
          isOnBreak: !!entry.break_start && !entry.break_end
        })
      }
    } catch (error) {
      console.error('Error loading employee data:', error)
    } finally {
      setLoading(false)
    }
  }, [user])

  useEffect(() => {
    if (user) {
      console.log('🔄 User changed, loading employee data:', user.id)
      loadEmployeeData()
    } else {
      console.log('❌ No user found')
    }
  }, [user, loadEmployeeData])

  // Test Supabase connection on mount
  useEffect(() => {
    const testConnection = async () => {
      try {
        console.log('🔗 Testing Supabase connection...')
        const { data, error } = await supabase.from('departments').select('count').limit(1)
        if (error) {
          console.error('❌ Supabase connection failed:', error)
        } else {
          console.log('✅ Supabase connection successful')
        }
      } catch (error) {
        console.error('❌ Supabase connection test failed:', error)
      }
    }
    testConnection()
  }, [])

  useEffect(() => {
    const timer = setInterval(() => {
      setCurrentTime(new Date())
    }, 1000)

    return () => clearInterval(timer)
  }, [])


  const handleClockIn = async () => {
    console.log('🔄 handleClockIn called')
    console.log('👤 Employee:', employee)
    console.log('🔑 User:', user)
    
    if (!employee) {
      console.log('❌ No employee found, returning')
      alert('Error: No se encontró información del empleado. Por favor, recarga la página.')
      return
    }

    setActionLoading(true)
    try {
      const now = new Date().toISOString()
      const today = getTodayString()
      
      console.log('⏰ Current time:', now)
      console.log('📅 Today:', today)
      console.log('🆔 Employee ID:', employee.id)

      const { data, error } = await supabase
        .from('time_entries')
        .insert({
          employee_id: employee.id,
          date: today,
          clock_in: now
        })
        .select()
        .single()

      console.log('📝 Insert result:', { data, error })

      if (error) throw error

      setTodayEntry(data)
      setCurrentSession({
        clockIn: now,
        breakStart: null,
        isOnBreak: false
      })
      
      console.log('✅ Clock in successful')
      alert('¡Entrada registrada correctamente!')
    } catch (error) {
      console.error('❌ Error clocking in:', error)
      const errorMessage = error instanceof Error ? error.message : 'Error desconocido'
      alert(`Error al registrar entrada: ${errorMessage}`)
    } finally {
      setActionLoading(false)
    }
  }

  const handleClockOut = async () => {
    if (!employee || !todayEntry) return

    setActionLoading(true)
    try {
      const now = new Date().toISOString()

      const { data, error } = await supabase
        .from('time_entries')
        .update({
          clock_out: now
        })
        .eq('id', todayEntry.id)
        .select()
        .single()

      if (error) throw error

      setTodayEntry(data)
      setCurrentSession({
        clockIn: null,
        breakStart: null,
        isOnBreak: false
      })
    } catch (error) {
      console.error('Error clocking out:', error)
      alert('Error al registrar salida')
    } finally {
      setActionLoading(false)
    }
  }

  const handleBreakStart = async () => {
    if (!employee || !todayEntry) return

    setActionLoading(true)
    try {
      const now = new Date().toISOString()

      const { data, error } = await supabase
        .from('time_entries')
        .update({
          break_start: now
        })
        .eq('id', todayEntry.id)
        .select()
        .single()

      if (error) throw error

      setTodayEntry(data)
      setCurrentSession(prev => ({
        ...prev,
        breakStart: now,
        isOnBreak: true
      }))
    } catch (error) {
      console.error('Error starting break:', error)
      alert('Error al iniciar descanso')
    } finally {
      setActionLoading(false)
    }
  }

  const handleBreakEnd = async () => {
    if (!employee || !todayEntry) return

    setActionLoading(true)
    try {
      const now = new Date().toISOString()

      const { data, error } = await supabase
        .from('time_entries')
        .update({
          break_end: now
        })
        .eq('id', todayEntry.id)
        .select()
        .single()

      if (error) throw error

      setTodayEntry(data)
      setCurrentSession(prev => ({
        ...prev,
        isOnBreak: false
      }))
    } catch (error) {
      console.error('Error ending break:', error)
      alert('Error al finalizar descanso')
    } finally {
      setActionLoading(false)
    }
  }

  const getCurrentWorkTime = () => {
    if (!currentSession.clockIn) return 0

    const start = new Date(currentSession.clockIn)
    const now = currentTime
    let totalMs = now.getTime() - start.getTime()

    // Restar tiempo de descanso si está en descanso
    if (currentSession.isOnBreak && currentSession.breakStart) {
      const breakStart = new Date(currentSession.breakStart)
      totalMs -= (now.getTime() - breakStart.getTime())
    }

    // Restar tiempo de descanso ya completado
    if (todayEntry?.break_start && todayEntry?.break_end) {
      const breakStart = new Date(todayEntry.break_start)
      const breakEnd = new Date(todayEntry.break_end)
      totalMs -= (breakEnd.getTime() - breakStart.getTime())
    }

    return Math.max(0, totalMs / (1000 * 60 * 60))
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          Control de Tiempo
        </h1>
        <p className="text-gray-600 dark:text-gray-300">
          {formatDate(currentTime)} - {formatTime(currentTime)}
        </p>
      </div>

      {/* Time tracking card */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-8">
        <div className="text-center">
          {/* Current time display */}
          <div className="mb-8">
            <div className="text-6xl font-bold text-gray-900 dark:text-white mb-2">
              {formatTime(currentTime)}
            </div>
            <div className="text-lg text-gray-600 dark:text-gray-300">
              {formatDate(currentTime)}
            </div>
          </div>

          {/* Work time display */}
          {currentSession.clockIn && (
            <div className="mb-8">
              <div className="text-3xl font-bold text-primary-600 mb-2">
                {formatDuration(getCurrentWorkTime())}
              </div>
              <div className="text-sm text-gray-600 dark:text-gray-300">
                Tiempo trabajado hoy
              </div>
            </div>
          )}

          {/* Debug info - Hidden as requested */}

          {/* Action buttons */}
          <div className="space-y-4">
            {!currentSession.clockIn ? (
              <button
                onClick={handleClockIn}
                disabled={actionLoading || loading || !employee}
                className="w-full max-w-xs mx-auto btn-primary text-lg py-4 disabled:opacity-50"
              >
                <Play className="inline-block mr-2 h-6 w-6" />
                {actionLoading 
                  ? 'Registrando...' 
                  : loading 
                    ? 'Cargando...'
                    : !employee
                      ? 'Sin empleado'
                      : 'Entrada'
                }
              </button>
            ) : !todayEntry?.clock_out ? (
              <div className="space-y-4">
                {/* Break controls */}
                {!currentSession.isOnBreak ? (
                  <button
                    onClick={handleBreakStart}
                    disabled={actionLoading}
                    className="w-full max-w-xs mx-auto bg-yellow-600 hover:bg-yellow-700 text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200 disabled:opacity-50"
                  >
                    <Coffee className="inline-block mr-2 h-5 w-5" />
                    {actionLoading ? 'Iniciando...' : 'Iniciar Descanso'}
                  </button>
                ) : (
                  <button
                    onClick={handleBreakEnd}
                    disabled={actionLoading}
                    className="w-full max-w-xs mx-auto bg-green-600 hover:bg-green-700 text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200 disabled:opacity-50"
                  >
                    <Coffee className="inline-block mr-2 h-5 w-5" />
                    {actionLoading ? 'Finalizando...' : 'Finalizar Descanso'}
                  </button>
                )}

                {/* Clock out button */}
                <button
                  onClick={handleClockOut}
                  disabled={actionLoading}
                  className="w-full max-w-xs mx-auto bg-red-600 hover:bg-red-700 text-white font-medium py-3 px-6 rounded-lg transition-colors duration-200 disabled:opacity-50"
                >
                  <Square className="inline-block mr-2 h-5 w-5" />
                  {actionLoading ? 'Registrando...' : 'Salida'}
                </button>
              </div>
            ) : (
              <div className="text-center">
                <div className="text-lg text-gray-600 dark:text-gray-300 mb-4">
                  Jornada completada
                </div>
                <div className="text-2xl font-bold text-green-600">
                  {formatDuration(todayEntry.total_hours || 0)} trabajadas
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {/* Today's summary */}
      {todayEntry && (
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
            Resumen del Día
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-600 dark:text-gray-300">Entrada</div>
              <div className="text-lg font-semibold text-gray-900 dark:text-white">
                {formatTime(todayEntry.clock_in)}
              </div>
            </div>
            {todayEntry.clock_out && (
              <div className="text-center p-4 bg-gray-50 rounded-lg">
                <div className="text-sm text-gray-600 dark:text-gray-300">Salida</div>
                <div className="text-lg font-semibold text-gray-900 dark:text-white">
                  {formatTime(todayEntry.clock_out)}
                </div>
              </div>
            )}
            <div className="text-center p-4 bg-gray-50 rounded-lg">
              <div className="text-sm text-gray-600 dark:text-gray-300">Total</div>
              <div className="text-lg font-semibold text-gray-900 dark:text-white">
                {todayEntry.total_hours ? formatDuration(todayEntry.total_hours) : 'En curso'}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Status indicator */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex items-center justify-center space-x-4">
          <div className={`w-3 h-3 rounded-full ${
            currentSession.clockIn ? 'bg-green-500' : 'bg-gray-300'
          }`}></div>
          <span className="text-sm text-gray-600 dark:text-gray-300">
            {currentSession.clockIn ? 'En el trabajo' : 'Fuera del trabajo'}
          </span>
          {currentSession.isOnBreak && (
            <>
              <div className="w-3 h-3 rounded-full bg-yellow-500"></div>
              <span className="text-sm text-gray-600 dark:text-gray-300">En descanso</span>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
