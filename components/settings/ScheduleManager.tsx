'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { Clock, Save, AlertCircle } from 'lucide-react'

interface Department {
  id: string
  name: string
}

interface DepartmentSchedule {
  id: string
  department_id: string
  day_of_week: number
  start_time: string
  end_time: string
  is_working_day: boolean
}

const DAYS_OF_WEEK = [
  { value: 1, label: 'Lunes' },
  { value: 2, label: 'Martes' },
  { value: 3, label: 'Miércoles' },
  { value: 4, label: 'Jueves' },
  { value: 5, label: 'Viernes' },
  { value: 6, label: 'Sábado' },
  { value: 0, label: 'Domingo' }
]

export default function ScheduleManager() {
  const [departments, setDepartments] = useState<Department[]>([])
  const [selectedDepartmentId, setSelectedDepartmentId] = useState<string>('')
  const [schedules, setSchedules] = useState<DepartmentSchedule[]>([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    loadDepartments()
  }, [])

  useEffect(() => {
    if (selectedDepartmentId) {
      loadSchedules(selectedDepartmentId)
    }
  }, [selectedDepartmentId])

  const loadDepartments = async () => {
    try {
      const { data, error } = await supabase
        .from('departments')
        .select('id, name')
        .order('name')

      if (error) throw error
      setDepartments(data || [])
      
      if (data && data.length > 0 && !selectedDepartmentId) {
        setSelectedDepartmentId(data[0].id)
      }
    } catch (error) {
      console.error('Error loading departments:', error)
      alert('Error al cargar los departamentos')
    } finally {
      setLoading(false)
    }
  }

  const loadSchedules = async (departmentId: string) => {
    try {
      const { data, error } = await supabase
        .from('department_schedules')
        .select('*')
        .eq('department_id', departmentId)
        .order('day_of_week')

      if (error) throw error

      // Si no hay horarios, crear los predeterminados
      if (!data || data.length === 0) {
        const defaultSchedules = DAYS_OF_WEEK.map(day => ({
          id: '',
          department_id: departmentId,
          day_of_week: day.value,
          start_time: '09:00',
          end_time: '18:00',
          is_working_day: day.value >= 1 && day.value <= 5 // Lunes a Viernes
        }))
        setSchedules(defaultSchedules)
      } else {
        setSchedules(data)
      }
    } catch (error) {
      console.error('Error loading schedules:', error)
      alert('Error al cargar los horarios')
    }
  }

  const updateSchedule = (dayOfWeek: number, field: string, value: any) => {
    setSchedules(prev => prev.map(schedule => 
      schedule.day_of_week === dayOfWeek
        ? { ...schedule, [field]: value }
        : schedule
    ))
  }

  const handleSave = async () => {
    if (!selectedDepartmentId) return

    setSaving(true)
    try {
      // Eliminar horarios existentes
      await supabase
        .from('department_schedules')
        .delete()
        .eq('department_id', selectedDepartmentId)

      // Insertar nuevos horarios
      const schedulesToInsert = schedules.map(schedule => ({
        department_id: selectedDepartmentId,
        day_of_week: schedule.day_of_week,
        start_time: schedule.start_time,
        end_time: schedule.end_time,
        is_working_day: schedule.is_working_day
      }))

      const { error } = await supabase
        .from('department_schedules')
        .insert(schedulesToInsert)

      if (error) throw error

      alert('Horarios guardados exitosamente')
      loadSchedules(selectedDepartmentId)
    } catch (error) {
      console.error('Error saving schedules:', error)
      alert('Error al guardar los horarios')
    } finally {
      setSaving(false)
    }
  }

  const applyToAllWorkingDays = () => {
    const mondaySchedule = schedules.find(s => s.day_of_week === 1)
    if (!mondaySchedule) return

    setSchedules(prev => prev.map(schedule => 
      schedule.day_of_week >= 1 && schedule.day_of_week <= 5
        ? {
            ...schedule,
            start_time: mondaySchedule.start_time,
            end_time: mondaySchedule.end_time,
            is_working_day: mondaySchedule.is_working_day
          }
        : schedule
    ))
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  if (departments.length === 0) {
    return (
      <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg p-4">
        <div className="flex items-start">
          <AlertCircle className="h-5 w-5 text-yellow-600 dark:text-yellow-500 mr-3 mt-0.5" />
          <div>
            <h4 className="text-sm font-medium text-yellow-800 dark:text-yellow-200">
              No hay departamentos disponibles
            </h4>
            <p className="text-sm text-yellow-700 dark:text-yellow-300 mt-1">
              Primero debes crear al menos un departamento en la sección superior.
            </p>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center">
          <Clock className="h-6 w-6 text-primary-600 mr-3" />
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            Horarios por Departamento
          </h3>
        </div>
      </div>

      {/* Selector de departamento */}
      <div>
        <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Seleccionar Departamento
        </label>
        <select
          value={selectedDepartmentId}
          onChange={(e) => setSelectedDepartmentId(e.target.value)}
          className="input-field max-w-md"
        >
          {departments.map(dept => (
            <option key={dept.id} value={dept.id}>
              {dept.name}
            </option>
          ))}
        </select>
      </div>

      {/* Tabla de horarios */}
      {selectedDepartmentId && (
        <div className="bg-white dark:bg-gray-800 rounded-lg border border-gray-200 dark:border-gray-700 overflow-hidden">
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
              <thead className="bg-gray-50 dark:bg-gray-900">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Día
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Día Laboral
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Hora de Entrada
                  </th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                    Hora de Salida
                  </th>
                </tr>
              </thead>
              <tbody className="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700">
                {DAYS_OF_WEEK.map((day) => {
                  const schedule = schedules.find(s => s.day_of_week === day.value)
                  if (!schedule) return null

                  return (
                    <tr key={day.value} className={!schedule.is_working_day ? 'bg-gray-50 dark:bg-gray-900/50' : ''}>
                      <td className="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900 dark:text-white">
                        {day.label}
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <input
                          type="checkbox"
                          checked={schedule.is_working_day}
                          onChange={(e) => updateSchedule(day.value, 'is_working_day', e.target.checked)}
                          className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
                        />
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <input
                          type="time"
                          value={schedule.start_time}
                          onChange={(e) => updateSchedule(day.value, 'start_time', e.target.value)}
                          disabled={!schedule.is_working_day}
                          className="input-field max-w-[150px]"
                        />
                      </td>
                      <td className="px-6 py-4 whitespace-nowrap">
                        <input
                          type="time"
                          value={schedule.end_time}
                          onChange={(e) => updateSchedule(day.value, 'end_time', e.target.value)}
                          disabled={!schedule.is_working_day}
                          className="input-field max-w-[150px]"
                        />
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>

          {/* Acciones rápidas */}
          <div className="bg-gray-50 dark:bg-gray-900 px-6 py-4 border-t border-gray-200 dark:border-gray-700">
            <div className="flex items-center justify-between">
              <button
                type="button"
                onClick={applyToAllWorkingDays}
                className="text-sm text-primary-600 hover:text-primary-700 dark:text-primary-400 dark:hover:text-primary-300 font-medium"
              >
                Aplicar horario de Lunes a todos los días laborales
              </button>
              <button
                onClick={handleSave}
                disabled={saving}
                className="btn-primary disabled:opacity-50"
              >
                <Save className="h-4 w-4 mr-2" />
                {saving ? 'Guardando...' : 'Guardar Horarios'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Información adicional */}
      <div className="bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg p-4">
        <div className="flex items-start">
          <AlertCircle className="h-5 w-5 text-blue-600 dark:text-blue-400 mr-3 mt-0.5" />
          <div className="text-sm text-blue-800 dark:text-blue-200">
            <p className="font-medium mb-1">Información sobre horarios:</p>
            <ul className="list-disc list-inside space-y-1 text-blue-700 dark:text-blue-300">
              <li>Los horarios se aplican a todos los empleados del departamento</li>
              <li>Desmarca "Día Laboral" para días no laborables</li>
              <li>Los horarios se utilizan para calcular horas extras y ausencias</li>
              <li>Puedes configurar diferentes horarios para cada departamento</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}
