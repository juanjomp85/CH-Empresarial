'use client'

import { useEffect, useState, useCallback } from 'react'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { useRole } from '@/lib/hooks/useRole'
import { Calendar, Download, TrendingUp, Clock, Users } from 'lucide-react'
import { formatDate, formatTime, formatDateForDB, formatDuration } from '@/lib/utils'
import AttendanceCompliance from '@/components/reports/AttendanceCompliance'

interface TimeEntry {
  id: string
  date: string
  clock_in: string
  clock_out: string | null
  total_hours: number | null
  overtime_hours: number | null
  employee: {
    full_name: string
  }
}

interface ReportData {
  dailyHours: Array<{ date: string; hours: number; overtime: number }>
  weeklyHours: Array<{ week: string; hours: number; overtime: number }>
  monthlyHours: Array<{ month: string; hours: number; overtime: number }>
  departmentHours: Array<{ department: string; hours: number; employees: number }>
}

export default function ReportsPage() {
  const { user } = useAuth()
  const { isAdmin, employeeId } = useRole()
  const [timeEntries, setTimeEntries] = useState<TimeEntry[]>([])
  const [reportData, setReportData] = useState<ReportData>({
    dailyHours: [],
    weeklyHours: [],
    monthlyHours: [],
    departmentHours: []
  })
  const [loading, setLoading] = useState(true)
  const [dateRange, setDateRange] = useState({
    start: formatDateForDB(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)),
    end: formatDateForDB(new Date())
  })

  const loadReportData = useCallback(async () => {
    if (!user) return

    try {
      // Construir la consulta base
      let query = supabase
        .from('time_entries')
        .select(`
          *,
          employee:employees!inner(
            full_name,
            departments(name)
          )
        `)
        .gte('date', dateRange.start)
        .lte('date', dateRange.end)

      // Si no es admin, filtrar solo sus propias entradas
      if (!isAdmin && employeeId) {
        query = query.eq('employee_id', employeeId)
      }

      const { data: entries, error } = await query.order('date', { ascending: false })

      console.log('📊 Report data query result:', { entries, error, isAdmin, employeeId })

      if (entries) {
        setTimeEntries(entries)
        processReportData(entries)
      }
    } catch (error) {
      console.error('Error loading report data:', error)
    } finally {
      setLoading(false)
    }
  }, [user, dateRange, isAdmin, employeeId])

  useEffect(() => {
    loadReportData()
  }, [loadReportData])


  const processReportData = (entries: any[]) => {
    // Procesar datos diarios
    const dailyMap = new Map()
    const weeklyMap = new Map()
    const monthlyMap = new Map()
    const departmentMap = new Map()

    entries.forEach(entry => {
      const date = new Date(entry.date)
      const dateStr = entry.date
      const weekStr = `${date.getFullYear()}-W${Math.ceil((date.getDate() + new Date(date.getFullYear(), date.getMonth(), 1).getDay()) / 7)}`
      const monthStr = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
      
      const hours = entry.total_hours || 0
      const overtime = entry.overtime_hours || 0
      const department = entry.employees.departments?.name || 'Sin departamento'
      const employeeName = entry.employees.full_name

      // Datos diarios
      if (!dailyMap.has(dateStr)) {
        dailyMap.set(dateStr, { date: dateStr, hours: 0, overtime: 0 })
      }
      const daily = dailyMap.get(dateStr)
      daily.hours += hours
      daily.overtime += overtime

      // Datos semanales
      if (!weeklyMap.has(weekStr)) {
        weeklyMap.set(weekStr, { week: weekStr, hours: 0, overtime: 0 })
      }
      const weekly = weeklyMap.get(weekStr)
      weekly.hours += hours
      weekly.overtime += overtime

      // Datos mensuales
      if (!monthlyMap.has(monthStr)) {
        monthlyMap.set(monthStr, { month: monthStr, hours: 0, overtime: 0 })
      }
      const monthly = monthlyMap.get(monthStr)
      monthly.hours += hours
      monthly.overtime += overtime

      // Datos por departamento
      if (!departmentMap.has(department)) {
        departmentMap.set(department, { department, hours: 0, employees: new Set() })
      }
      const dept = departmentMap.get(department)
      dept.hours += hours
      dept.employees.add(employeeName)
    })

    // Convertir mapas a arrays y ordenar
    const dailyHours = Array.from(dailyMap.values()).sort((a, b) => a.date.localeCompare(b.date))
    const weeklyHours = Array.from(weeklyMap.values()).sort((a, b) => a.week.localeCompare(b.week))
    const monthlyHours = Array.from(monthlyMap.values()).sort((a, b) => a.month.localeCompare(b.month))
    const departmentHours = Array.from(departmentMap.values()).map(dept => ({
      ...dept,
      employees: dept.employees.size
    })).sort((a, b) => b.hours - a.hours)

    setReportData({
      dailyHours,
      weeklyHours,
      monthlyHours,
      departmentHours
    })
  }

  const exportToCSV = () => {
    const headers = ['Fecha', 'Empleado', 'Entrada', 'Salida', 'Horas Totales', 'Horas Extra']
    const csvContent = [
      headers.join(','),
      ...timeEntries.map(entry => [
        entry.date,
        entry.employee?.full_name || 'N/A',
        formatTime(entry.clock_in),
        entry.clock_out ? formatTime(entry.clock_out) : 'En curso',
        entry.total_hours || 0,
        entry.overtime_hours || 0
      ].join(','))
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `reporte-horarios-${dateRange.start}-${dateRange.end}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  const totalHours = timeEntries.reduce((sum, entry) => sum + (entry.total_hours || 0), 0)
  const totalOvertime = timeEntries.reduce((sum, entry) => sum + (entry.overtime_hours || 0), 0)

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Reportes y Estadísticas
            </h1>
            <p className="text-gray-600">
              Análisis de tiempo y productividad
            </p>
          </div>
          <button
            onClick={exportToCSV}
            className="btn-primary"
          >
            <Download className="h-5 w-5 mr-2" />
            Exportar CSV
          </button>
        </div>
      </div>

      {/* Filters */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex flex-wrap items-center gap-4">
          <div className="flex items-center space-x-2">
            <Calendar className="h-5 w-5 text-gray-400" />
            <input
              type="date"
              value={dateRange.start}
              onChange={(e) => setDateRange(prev => ({ ...prev, start: e.target.value }))}
              className="input-field"
            />
            <span className="text-gray-500 dark:text-gray-400">a</span>
            <input
              type="date"
              value={dateRange.end}
              onChange={(e) => setDateRange(prev => ({ ...prev, end: e.target.value }))}
              className="input-field"
            />
          </div>
        </div>
      </div>

      {/* Summary Stats */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="stat-card">
          <div className="flex items-center">
            <Clock className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Total Horas</p>
              <p className="text-2xl font-bold text-white">{formatDuration(totalHours)}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center">
            <TrendingUp className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Horas Extra</p>
              <p className="text-2xl font-bold text-white">{formatDuration(totalOvertime)}</p>
            </div>
          </div>
        </div>
        <div className="stat-card">
          <div className="flex items-center">
            <Users className="h-8 w-8 text-white" />
            <div className="ml-4">
              <p className="text-sm font-medium text-primary-100">Empleados</p>
              <p className="text-2xl font-bold text-white">
                {new Set(timeEntries.map(e => e.employee?.full_name).filter(Boolean)).size}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Attendance Compliance Section */}
      <AttendanceCompliance />

      {/* Recent Entries */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-800">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            Entradas Recientes
          </h3>
        </div>
        <div className="divide-y divide-gray-200 dark:divide-gray-800">
          {timeEntries.slice(0, 10).map((entry) => (
            <div key={entry.id} className="px-6 py-4">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-gray-900 dark:text-white">
                    {entry.employee?.full_name || 'N/A'}
                  </p>
                  <p className="text-sm text-gray-500 dark:text-gray-400">
                    {formatDate(entry.date)} - {formatTime(entry.clock_in)} a {entry.clock_out ? formatTime(entry.clock_out) : 'En curso'}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-medium text-gray-900 dark:text-white">
                    {entry.total_hours ? formatDuration(entry.total_hours) : 'En curso'}
                  </p>
                  {entry.overtime_hours && entry.overtime_hours > 0 ? (
                    <p className="text-xs text-gray-500 dark:text-gray-400">
                      +{formatDuration(entry.overtime_hours)} extra
                    </p>
                  ) : null}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
