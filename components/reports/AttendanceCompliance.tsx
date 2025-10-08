'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { useRole } from '@/lib/hooks/useRole'
import { formatDateForDB } from '@/lib/utils'
import EmployeeSearch from '@/components/common/EmployeeSearch'
import { 
  Clock, 
  CheckCircle, 
  XCircle, 
  AlertTriangle, 
  TrendingUp,
  TrendingDown,
  Calendar,
  User,
  Download
} from 'lucide-react'

interface ComplianceRecord {
  date: string
  day_name: string
  is_working_day: boolean
  expected_start_time: string
  expected_end_time: string
  clock_in: string | null
  clock_out: string | null
  total_hours: number | null
  arrival_delay_minutes: number | null
  arrival_status: string
  departure_status: string
  expected_hours: number
  hours_difference: number | null
}

interface ComplianceSummary {
  total_working_days: number
  punctual_days: number
  late_days: number
  absent_days: number
  punctuality_percentage: number
  absenteeism_percentage: number
  avg_delay_minutes: number
  total_hours_worked: number
  total_expected_hours: number
  hours_difference: number
}

interface Employee {
  id: string
  full_name: string
}

export default function AttendanceCompliance() {
  const { user } = useAuth()
  const { isAdmin } = useRole()
  const [records, setRecords] = useState<ComplianceRecord[]>([])
  const [summary, setSummary] = useState<ComplianceSummary | null>(null)
  const [loading, setLoading] = useState(true)
  const [dateRange, setDateRange] = useState({
    start: formatDateForDB(new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)),
    end: formatDateForDB(new Date())
  })
  const [employeeId, setEmployeeId] = useState<string | null>(null)
  const [employees, setEmployees] = useState<Employee[]>([])
  const [selectedEmployeeId, setSelectedEmployeeId] = useState<string>('')

  useEffect(() => {
    if (isAdmin !== null) {
      if (isAdmin) {
        loadEmployees()
      } else {
        loadEmployeeId()
      }
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [user, isAdmin])

  useEffect(() => {
    const targetEmployeeId = isAdmin ? selectedEmployeeId : employeeId
    if (targetEmployeeId) {
      loadCompliance(targetEmployeeId)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [employeeId, selectedEmployeeId, dateRange, isAdmin])

  const loadEmployees = async () => {
    try {
      const { data, error } = await supabase
        .from('employees')
        .select('id, full_name')
        .eq('is_active', true)
        .order('full_name')

      if (error) throw error
      setEmployees(data || [])
      
      if (data && data.length > 0 && !selectedEmployeeId) {
        setSelectedEmployeeId(data[0].id)
      }
    } catch (error) {
      console.error('Error loading employees:', error)
    }
  }

  const loadEmployeeId = async () => {
    if (!user) return

    try {
      const { data, error } = await supabase
        .from('employees')
        .select('id')
        .eq('user_id', user.id)
        .single()

      if (error) throw error
      setEmployeeId(data.id)
    } catch (error) {
      console.error('Error loading employee:', error)
    }
  }

  const loadCompliance = async (targetEmployeeId: string) => {
    if (!targetEmployeeId) return

    setLoading(true)
    try {
      // Cargar detalles del rango de fechas
      const { data: recordsData, error: recordsError } = await supabase
        .rpc('get_employee_compliance', {
          p_employee_id: targetEmployeeId,
          p_start_date: dateRange.start,
          p_end_date: dateRange.end
        })

      if (recordsError) throw recordsError
      setRecords(recordsData || [])

      // Calcular resumen desde los registros
      if (recordsData && recordsData.length > 0) {
        const workingDays = recordsData.filter((r: any) => r.is_working_day)
        const punctualDays = recordsData.filter((r: any) => r.arrival_status === 'PUNTUAL')
        const lateDays = recordsData.filter((r: any) => 
          ['RETRASO_LEVE', 'RETRASO_MODERADO', 'RETRASO_GRAVE'].includes(r.arrival_status)
        )
        const absentDays = recordsData.filter((r: any) => r.arrival_status === 'AUSENTE')
        
        const totalWorking = workingDays.length
        const avgDelay = lateDays.reduce((sum: number, r: any) => 
          sum + (r.arrival_delay_minutes || 0), 0
        ) / lateDays.length || 0
        
        const totalHours = workingDays.reduce((sum: number, r: any) => 
          sum + (r.total_hours || 0), 0
        )
        const totalExpected = workingDays.reduce((sum: number, r: any) => 
          sum + (r.expected_hours || 0), 0
        )

        setSummary({
          total_working_days: totalWorking,
          punctual_days: punctualDays.length,
          late_days: lateDays.length,
          absent_days: absentDays.length,
          punctuality_percentage: totalWorking > 0 ? (punctualDays.length / totalWorking * 100) : 0,
          absenteeism_percentage: totalWorking > 0 ? (absentDays.length / totalWorking * 100) : 0,
          avg_delay_minutes: avgDelay,
          total_hours_worked: totalHours,
          total_expected_hours: totalExpected,
          hours_difference: totalHours - totalExpected
        })
      } else {
        setSummary(null)
      }
    } catch (error) {
      console.error('Error loading compliance:', error)
      alert('Error al cargar el cumplimiento de horarios')
    } finally {
      setLoading(false)
    }
  }

  const getStatusIcon = (status: string) => {
    switch (status) {
      case 'PUNTUAL':
        return <CheckCircle className="h-5 w-5 text-green-500" />
      case 'RETRASO_LEVE':
        return <AlertTriangle className="h-5 w-5 text-yellow-500" />
      case 'RETRASO_MODERADO':
        return <AlertTriangle className="h-5 w-5 text-orange-500" />
      case 'RETRASO_GRAVE':
        return <XCircle className="h-5 w-5 text-red-500" />
      case 'AUSENTE':
        return <XCircle className="h-5 w-5 text-red-600" />
      default:
        return <Clock className="h-5 w-5 text-gray-400" />
    }
  }

  const getStatusLabel = (status: string) => {
    const labels: { [key: string]: string } = {
      'PUNTUAL': 'Puntual',
      'RETRASO_LEVE': 'Retraso Leve',
      'RETRASO_MODERADO': 'Retraso Moderado',
      'RETRASO_GRAVE': 'Retraso Grave',
      'AUSENTE': 'Ausente',
      'DIA_NO_LABORAL': 'No Laboral',
      'DESCONOCIDO': 'Desconocido'
    }
    return labels[status] || status
  }

  const getStatusColor = (status: string) => {
    const colors: { [key: string]: string } = {
      'PUNTUAL': 'text-green-700 bg-green-50 border-green-200',
      'RETRASO_LEVE': 'text-yellow-700 bg-yellow-50 border-yellow-200',
      'RETRASO_MODERADO': 'text-orange-700 bg-orange-50 border-orange-200',
      'RETRASO_GRAVE': 'text-red-700 bg-red-50 border-red-200',
      'AUSENTE': 'text-red-700 bg-red-100 border-red-300',
      'DIA_NO_LABORAL': 'text-gray-500 bg-gray-50 border-gray-200'
    }
    return colors[status] || 'text-gray-700 bg-gray-50 border-gray-200'
  }

  const formatTime = (time: string | null) => {
    if (!time) return '-'
    return new Date(time).toLocaleTimeString('es-ES', { 
      hour: '2-digit', 
      minute: '2-digit' 
    })
  }

  const formatTimeOnly = (time: string | null) => {
    if (!time) return '-'
    return time.substring(0, 5)
  }

  const exportToCSV = () => {
    const selectedEmp = employees.find(e => e.id === selectedEmployeeId)
    const empName = selectedEmp?.full_name || 'empleado'
    
    const headers = [
      'Fecha',
      'Día',
      'Día Laboral',
      'Hora Entrada Esperada',
      'Hora Salida Esperada',
      'Hora Entrada Real',
      'Hora Salida Real',
      'Minutos Retraso',
      'Estado Llegada',
      'Estado Salida',
      'Horas Trabajadas',
      'Horas Esperadas',
      'Diferencia Horas'
    ]
    
    const csvContent = [
      headers.join(','),
      ...records.map(record => [
        record.date,
        record.day_name.trim(),
        record.is_working_day ? 'Sí' : 'No',
        formatTimeOnly(record.expected_start_time),
        formatTimeOnly(record.expected_end_time),
        formatTime(record.clock_in),
        formatTime(record.clock_out),
        record.arrival_delay_minutes || 0,
        getStatusLabel(record.arrival_status),
        getStatusLabel(record.departure_status),
        record.total_hours?.toFixed(2) || 0,
        record.expected_hours?.toFixed(2) || 0,
        record.hours_difference?.toFixed(2) || 0
      ].join(','))
    ].join('\n')

    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `cumplimiento-${empName}-${dateRange.start}-${dateRange.end}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* Filtros */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex items-center justify-between flex-wrap gap-4">
          <div className="flex flex-wrap items-center gap-4">
            {/* Búsqueda de empleado (solo para admins) */}
            {isAdmin && employees.length > 0 && (
              <EmployeeSearch
                employees={employees}
                selectedEmployeeId={selectedEmployeeId}
                onSelectEmployee={setSelectedEmployeeId}
                placeholder="Buscar empleado..."
                showAllOption={false}
              />
            )}
            
            {/* Rango de fechas */}
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

          {/* Botón exportar */}
          <button
            onClick={exportToCSV}
            disabled={records.length === 0}
            className="btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <Download className="h-5 w-5 mr-2" />
            Exportar CSV
          </button>
        </div>
      </div>

      {/* Resumen de Métricas */}
      {summary && (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {/* Puntualidad */}
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Puntualidad</p>
                <p className="text-3xl font-bold text-green-600">
                  {summary.punctuality_percentage?.toFixed(1) || 0}%
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  {summary.punctual_days} de {summary.total_working_days} días
                </p>
              </div>
              <CheckCircle className="h-12 w-12 text-green-500 opacity-20" />
            </div>
          </div>

          {/* Absentismo */}
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Absentismo</p>
                <p className="text-3xl font-bold text-red-600">
                  {summary.absenteeism_percentage?.toFixed(1) || 0}%
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  {summary.absent_days} ausencias
                </p>
              </div>
              <XCircle className="h-12 w-12 text-red-500 opacity-20" />
            </div>
          </div>

          {/* Retrasos */}
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Días con Retraso</p>
                <p className="text-3xl font-bold text-orange-600">
                  {summary.late_days}
                </p>
                <p className="text-xs text-gray-500 mt-1">
                  Promedio: {summary.avg_delay_minutes?.toFixed(0) || 0} min
                </p>
              </div>
              <AlertTriangle className="h-12 w-12 text-orange-500 opacity-20" />
            </div>
          </div>

          {/* Horas Trabajadas */}
          <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm text-gray-600 dark:text-gray-400">Horas Trabajadas</p>
                <p className="text-3xl font-bold text-blue-600">
                  {summary.total_hours_worked?.toFixed(1) || 0}h
                </p>
                <p className="text-xs text-gray-500 mt-1 flex items-center">
                  {summary.hours_difference >= 0 ? (
                    <>
                      <TrendingUp className="h-3 w-3 mr-1 text-green-500" />
                      +{summary.hours_difference?.toFixed(1)}h
                    </>
                  ) : (
                    <>
                      <TrendingDown className="h-3 w-3 mr-1 text-red-500" />
                      {summary.hours_difference?.toFixed(1)}h
                    </>
                  )}
                </p>
              </div>
              <Clock className="h-12 w-12 text-blue-500 opacity-20" />
            </div>
          </div>
        </div>
      )}

      {/* Detalle por Día */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow overflow-hidden">
        <div className="p-6 border-b border-gray-200 dark:border-gray-700">
          <h3 className="text-lg font-semibold text-gray-900 dark:text-white">
            Detalle Diario
          </h3>
        </div>
        
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Fecha
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Horario Esperado
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Entrada Real
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Salida Real
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Estado
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Horas
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-700">
              {records.map((record, index) => (
                <tr key={index} className={!record.is_working_day ? 'bg-gray-50 dark:bg-gray-800/50' : ''}>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm font-medium text-gray-900 dark:text-white">
                      {new Date(record.date).toLocaleDateString('es-ES', { 
                        day: '2-digit', 
                        month: 'short' 
                      })}
                    </div>
                    <div className="text-xs text-gray-500">
                      {record.day_name.trim()}
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-700 dark:text-gray-300">
                    {record.is_working_day ? (
                      <>
                        {formatTimeOnly(record.expected_start_time)} - {formatTimeOnly(record.expected_end_time)}
                      </>
                    ) : (
                      <span className="text-gray-400">No laboral</span>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900 dark:text-white">
                      {formatTime(record.clock_in)}
                    </div>
                    {record.arrival_delay_minutes !== null && record.arrival_delay_minutes > 0 && (
                      <div className="text-xs text-red-500">
                        +{record.arrival_delay_minutes.toFixed(0)} min
                      </div>
                    )}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {formatTime(record.clock_out)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center gap-2">
                      {getStatusIcon(record.arrival_status)}
                      <span className={`px-2 py-1 text-xs font-medium rounded-md border ${getStatusColor(record.arrival_status)}`}>
                        {getStatusLabel(record.arrival_status)}
                      </span>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="text-sm text-gray-900 dark:text-white">
                      {record.total_hours?.toFixed(2) || '-'}h
                    </div>
                    {record.hours_difference !== null && record.is_working_day && (
                      <div className={`text-xs ${record.hours_difference >= 0 ? 'text-green-600' : 'text-red-600'}`}>
                        {record.hours_difference >= 0 ? '+' : ''}{record.hours_difference.toFixed(2)}h
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {records.length === 0 && (
          <div className="text-center py-12 text-gray-500 dark:text-gray-400">
            <User className="h-12 w-12 mx-auto mb-3 opacity-50" />
            <p>No hay registros para este período</p>
          </div>
        )}
      </div>
    </div>
  )
}
