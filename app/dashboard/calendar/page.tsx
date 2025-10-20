'use client'

import { useEffect, useState, useCallback } from 'react'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { ChevronLeft, ChevronRight, Clock, Users } from 'lucide-react'
import { formatDate, formatTime, formatDateForDB, formatDuration } from '@/lib/utils'

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
  const [selectedDate, setSelectedDate] = useState<Date | null>(null)

  const loadTimeEntries = useCallback(async () => {
    if (!user) return

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
  }, [user, currentDate])

  useEffect(() => {
    loadTimeEntries()
  }, [loadTimeEntries])

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
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-4 sm:p-6">
        <div className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4">
          <div>
            <h1 className="text-xl sm:text-2xl font-bold text-gray-900 dark:text-white mb-1 sm:mb-2">
              Calendario de Horarios
            </h1>
            <p className="text-sm sm:text-base text-gray-600 dark:text-gray-300">
              Vista mensual de registros de tiempo
            </p>
          </div>
          <div className="flex items-center space-x-2 sm:space-x-4 self-end sm:self-auto">
            <button
              onClick={() => navigateMonth('prev')}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
            >
              <ChevronLeft className="h-5 w-5 text-gray-600 dark:text-gray-300" />
            </button>
            <h2 className="text-base sm:text-xl font-semibold text-gray-900 dark:text-white min-w-[140px] sm:min-w-[200px] text-center">
              {monthNames[currentDate.getMonth()]} {currentDate.getFullYear()}
            </h2>
            <button
              onClick={() => navigateMonth('next')}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-lg transition-colors"
            >
              <ChevronRight className="h-5 w-5 text-gray-600 dark:text-gray-300" />
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

            const isSelected = selectedDate && day.date.toDateString() === selectedDate.toDateString()

            return (
              <div
                key={index}
                onClick={() => day.isCurrentMonth && setSelectedDate(day.date)}
                className={`min-h-[120px] p-2 border-r border-b border-gray-200 dark:border-gray-800 last:border-r-0 ${
                  day.isCurrentMonth ? 'bg-white dark:bg-gray-900 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-800' : 'bg-gray-50 dark:bg-gray-800'
                } ${isToday ? 'bg-primary-50 dark:bg-primary-900/20' : ''} ${isSelected ? 'ring-2 ring-primary-500 ring-inset' : ''} transition-all`}
              >
                <div className={`text-sm font-medium mb-1 ${
                  day.isCurrentMonth ? 'text-gray-900 dark:text-white' : 'text-gray-400'
                } ${isToday ? 'text-primary-600 dark:text-primary-400' : ''} ${isSelected ? 'text-primary-600 dark:text-primary-400' : ''}`}>
                  {day.date.getDate()}
                </div>
                
                {entries.length > 0 && (
                  <div className="space-y-1">
                    <div className="flex items-center text-xs text-gray-600 dark:text-gray-300">
                      <Clock className="h-3 w-3 mr-1" />
                      <span>{formatDuration(totalHours)}</span>
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

      {/* Detalles del Día Seleccionado */}
      {selectedDate && (
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">
              Registros del {selectedDate.getDate()} de {monthNames[selectedDate.getMonth()]} de {selectedDate.getFullYear()}
            </h3>
            <button
              onClick={() => setSelectedDate(null)}
              className="text-sm text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-300"
            >
              Cerrar ✕
            </button>
          </div>

          {(() => {
            const selectedEntries = getEntriesForDate(selectedDate)
            
            if (selectedEntries.length === 0) {
              return (
                <div className="text-center py-8">
                  <div className="text-gray-400 dark:text-gray-500 mb-2">
                    <Clock className="h-12 w-12 mx-auto mb-3 opacity-50" />
                  </div>
                  <p className="text-gray-600 dark:text-gray-400">
                    No hay registros para este día
                  </p>
                </div>
              )
            }

            return (
              <div className="space-y-4">
                {/* Resumen del día */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-4">
                  <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
                    <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total de Horas</div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white">
                      {formatDuration(selectedEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0))}
                    </div>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
                    <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Empleados</div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white">
                      {selectedEntries.length}
                    </div>
                  </div>
                  <div className="bg-gray-50 dark:bg-gray-800 rounded-lg p-4">
                    <div className="text-sm text-gray-600 dark:text-gray-400 mb-1">Promedio de Horas</div>
                    <div className="text-2xl font-bold text-gray-900 dark:text-white">
                      {formatDuration((selectedEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)) / selectedEntries.length)}
                    </div>
                  </div>
                </div>

                {/* Lista de registros */}
                <div className="overflow-x-auto">
                  <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
                    <thead className="bg-gray-50 dark:bg-gray-800">
                      <tr>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Empleado
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Hora de Entrada
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Hora de Salida
                        </th>
                        <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                          Total de Horas
                        </th>
                      </tr>
                    </thead>
                    <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
                      {selectedEntries.map((entry) => (
                        <tr key={entry.id} className="hover:bg-gray-50 dark:hover:bg-gray-800">
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center">
                              <div className="flex-shrink-0 h-8 w-8 bg-primary-100 dark:bg-primary-900 rounded-full flex items-center justify-center">
                                <span className="text-sm font-medium text-primary-600 dark:text-primary-400">
                                  {entry.employee?.full_name?.charAt(0).toUpperCase()}
                                </span>
                              </div>
                              <div className="ml-3">
                                <div className="text-sm font-medium text-gray-900 dark:text-white">
                                  {entry.employee?.full_name}
                                </div>
                              </div>
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center text-sm text-gray-900 dark:text-white">
                              <Clock className="h-4 w-4 mr-2 text-green-500" />
                              {formatTime(entry.clock_in)}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="flex items-center text-sm text-gray-900 dark:text-white">
                              <Clock className="h-4 w-4 mr-2 text-red-500" />
                              {entry.clock_out ? formatTime(entry.clock_out) : (
                                <span className="text-yellow-600 dark:text-yellow-400">En curso</span>
                              )}
                            </div>
                          </td>
                          <td className="px-6 py-4 whitespace-nowrap">
                            <div className="text-sm font-medium text-gray-900 dark:text-white">
                              {entry.total_hours ? formatDuration(entry.total_hours) : '-'}
                            </div>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </div>
            )
          })()}
        </div>
      )}

      {/* Legend */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Leyenda
        </h3>
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex items-center">
            <div className="w-4 h-4 bg-primary-50 dark:bg-primary-900/20 rounded mr-2"></div>
            <span className="text-sm text-gray-600 dark:text-gray-300">Hoy</span>
          </div>
          <div className="flex items-center">
            <div className="w-4 h-4 bg-white dark:bg-gray-900 border-2 border-primary-500 rounded mr-2"></div>
            <span className="text-sm text-gray-600 dark:text-gray-300">Día seleccionado</span>
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
              {formatDuration(timeEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0))}
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
