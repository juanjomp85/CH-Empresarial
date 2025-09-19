'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { ChevronLeft, ChevronRight, Clock, Users } from 'lucide-react'
import { formatDate, formatTime, formatDateForDB } from '@/lib/utils'

interface TimeEntry {
  id: string
  date: string
  clock_in: string
  clock_out: string | null
  total_hours: number | null
  employee: {
    full_name: string
  }
}

export default function CalendarPage() {
  const { user } = useAuth()
  const [timeEntries, setTimeEntries] = useState<TimeEntry[]>([])
  const [currentDate, setCurrentDate] = useState(new Date())
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (user) {
      loadTimeEntries()
    }
  }, [user, currentDate])

  const loadTimeEntries = async () => {
    try {
      const startOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth(), 1)
      const endOfMonth = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 0)

      const { data, error } = await supabase
        .from('time_entries')
        .select(`
          *,
          employee:employees!inner(full_name)
        `)
        .gte('date', formatDateForDB(startOfMonth))
        .lte('date', formatDateForDB(endOfMonth))
        .order('date', { ascending: true })

      console.log('📅 Calendar data query result:', { data, error })

      setTimeEntries(data || [])
    } catch (error) {
      console.error('Error loading time entries:', error)
    } finally {
      setLoading(false)
    }
  }

  const getDaysInMonth = (date: Date) => {
    const year = date.getFullYear()
    const month = date.getMonth()
    const firstDay = new Date(year, month, 1)
    const lastDay = new Date(year, month + 1, 0)
    const daysInMonth = lastDay.getDate()
    const startingDayOfWeek = firstDay.getDay()

    const days = []
    
    // Días del mes anterior
    for (let i = startingDayOfWeek - 1; i >= 0; i--) {
      const prevDate = new Date(year, month, -i)
      days.push({ date: prevDate, isCurrentMonth: false })
    }
    
    // Días del mes actual
    for (let day = 1; day <= daysInMonth; day++) {
      const currentDate = new Date(year, month, day)
      days.push({ date: currentDate, isCurrentMonth: true })
    }
    
    // Días del mes siguiente para completar la cuadrícula
    const remainingDays = 42 - days.length
    for (let day = 1; day <= remainingDays; day++) {
      const nextDate = new Date(year, month + 1, day)
      days.push({ date: nextDate, isCurrentMonth: false })
    }
    
    return days
  }

  const getEntriesForDate = (date: Date) => {
    // Usar función utilitaria para evitar problemas de zona horaria
    const dateStr = formatDateForDB(date)
    console.log('📅 Getting entries for date:', dateStr, 'from date object:', date)
    return timeEntries.filter(entry => entry.date === dateStr)
  }

  const navigateMonth = (direction: 'prev' | 'next') => {
    setCurrentDate(prev => {
      const newDate = new Date(prev)
      if (direction === 'prev') {
        newDate.setMonth(prev.getMonth() - 1)
      } else {
        newDate.setMonth(prev.getMonth() + 1)
      }
      return newDate
    })
  }

  const monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ]

  const dayNames = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb']

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
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Calendario de Horarios
            </h1>
            <p className="text-gray-600 dark:text-gray-300">
              Vista mensual de registros de tiempo
            </p>
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={() => navigateMonth('prev')}
              className="p-2 hover:bg-gray-100 rounded-lg"
            >
              <ChevronLeft className="h-5 w-5" />
            </button>
            <h2 className="text-xl font-semibold text-gray-900 dark:text-white min-w-[200px] text-center">
              {monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}
            </h2>
            <button
              onClick={() => navigateMonth('next')}
              className="p-2 hover:bg-gray-100 rounded-lg"
            >
              <ChevronRight className="h-5 w-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Calendar Grid */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow overflow-hidden">
        {/* Day headers */}
        <div className="grid grid-cols-7 bg-gray-50 dark:bg-gray-800">
          {dayNames.map(day => (
            <div key={day} className="p-4 text-center text-sm font-medium text-gray-500 border-r border-gray-200 dark:border-gray-800 last:border-r-0">
              {day}
            </div>
          ))}
        </div>

        {/* Calendar days */}
        <div className="grid grid-cols-7">
          {getDaysInMonth(currentDate).map((day, index) => {
            const entries = getEntriesForDate(day.date)
            const isToday = day.date.toDateString() === new Date().toDateString()
            const totalHours = entries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)

            return (
              <div
                key={index}
                className={`min-h-[120px] p-2 border-r border-b border-gray-200 dark:border-gray-800 last:border-r-0 ${
                  day.isCurrentMonth ? 'bg-white dark:bg-gray-900' : 'bg-gray-50 dark:bg-gray-800'
                } ${isToday ? 'bg-primary-50' : ''}`}
              >
                <div className={`text-sm font-medium mb-1 ${
                  day.isCurrentMonth ? 'text-gray-900 dark:text-white' : 'text-gray-400'
                } ${isToday ? 'text-primary-600' : ''}`}>
                  {day.date.getDate()}
                </div>
                
                {entries.length > 0 && (
                  <div className="space-y-1">
                    <div className="flex items-center text-xs text-gray-600 dark:text-gray-300">
                      <Clock className="h-3 w-3 mr-1" />
                      <span>{totalHours.toFixed(1)}h</span>
                    </div>
                    <div className="flex items-center text-xs text-gray-600 dark:text-gray-300">
                      <Users className="h-3 w-3 mr-1" />
                      <span>{entries.length} empleado{entries.length !== 1 ? 's' : ''}</span>
                    </div>
                  </div>
                )}
              </div>
            )
          })}
        </div>
      </div>

      {/* Legend */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Leyenda
        </h3>
        <div className="flex items-center space-x-6">
          <div className="flex items-center">
            <div className="w-4 h-4 bg-primary-50 rounded mr-2"></div>
            <span className="text-sm text-gray-600 dark:text-gray-300">Hoy</span>
          </div>
          <div className="flex items-center">
            <div className="w-4 h-4 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded mr-2"></div>
            <span className="text-sm text-gray-600 dark:text-gray-300">Día del mes actual</span>
          </div>
          <div className="flex items-center">
            <div className="w-4 h-4 bg-gray-50 dark:bg-gray-800 rounded mr-2"></div>
            <span className="text-sm text-gray-600 dark:text-gray-300">Día de otro mes</span>
          </div>
        </div>
      </div>

      {/* Monthly Summary */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Resumen del Mes
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="text-center p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-2xl font-bold text-gray-900 dark:text-white">
              {timeEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0).toFixed(1)}h
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-300">Total de horas</div>
          </div>
          <div className="text-center p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-2xl font-bold text-gray-900 dark:text-white">
              {new Set(timeEntries.map(entry => entry.employee?.full_name).filter(Boolean)).size}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-300">Empleados activos</div>
          </div>
          <div className="text-center p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-2xl font-bold text-gray-900 dark:text-white">
              {timeEntries.length}
            </div>
            <div className="text-sm text-gray-600 dark:text-gray-300">Registros totales</div>
          </div>
        </div>
      </div>
    </div>
  )
}
