'use client'

import { useEffect, useState } from 'react'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { Plus, Search, Edit, Trash2, User, Mail, Clock } from 'lucide-react'
import { formatDate } from '@/lib/utils'
import AdminRoute from '@/components/auth/AdminRoute'

interface Employee {
  id: string
  email: string
  full_name: string
  position: string
  department: string
  is_active: boolean
  hire_date: string
  created_at: string
}

interface Department {
  id: string
  name: string
}

interface Position {
  id: string
  title: string
  department_id: string
}

export default function EmployeesPage() {
  const { user } = useAuth()
  const [employees, setEmployees] = useState<Employee[]>([])
  const [departments, setDepartments] = useState<Department[]>([])
  const [positions, setPositions] = useState<Position[]>([])
  const [loading, setLoading] = useState(true)
  const [searchTerm, setSearchTerm] = useState('')
  const [showAddForm, setShowAddForm] = useState(false)
  const [editingEmployee, setEditingEmployee] = useState<Employee | null>(null)

  useEffect(() => {
    loadData()
  }, [])

  const loadData = async () => {
    try {
      // Cargar empleados con información de departamento y posición
      const { data: empData } = await supabase
        .from('employees')
        .select(`
          *,
          positions(title),
          departments(name)
        `)

      if (empData) {
        const formattedEmployees = empData.map(emp => ({
          id: emp.id,
          email: emp.email,
          full_name: emp.full_name,
          position: emp.positions?.title || 'Sin asignar',
          department: emp.departments?.name || 'Sin asignar',
          is_active: emp.is_active,
          hire_date: emp.hire_date,
          created_at: emp.created_at
        }))
        setEmployees(formattedEmployees)
      }

      // Cargar departamentos
      const { data: deptData } = await supabase
        .from('departments')
        .select('*')
        .order('name')

      if (deptData) {
        setDepartments(deptData)
      }

      // Cargar posiciones
      const { data: posData } = await supabase
        .from('positions')
        .select('*')
        .order('title')

      if (posData) {
        setPositions(posData)
      }
    } catch (error) {
      console.error('Error loading data:', error)
    } finally {
      setLoading(false)
    }
  }

  const filteredEmployees = employees.filter(emp =>
    emp.full_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    emp.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    emp.position.toLowerCase().includes(searchTerm.toLowerCase()) ||
    emp.department.toLowerCase().includes(searchTerm.toLowerCase())
  )

  const handleToggleActive = async (employeeId: string, currentStatus: boolean) => {
    try {
      const { error } = await supabase
        .from('employees')
        .update({ is_active: !currentStatus })
        .eq('id', employeeId)

      if (error) throw error

      setEmployees(prev => prev.map(emp =>
        emp.id === employeeId ? { ...emp, is_active: !currentStatus } : emp
      ))
    } catch (error) {
      console.error('Error updating employee:', error)
      alert('Error al actualizar empleado')
    }
  }

  const handleDeleteEmployee = async (employeeId: string) => {
    if (!confirm('¿Estás seguro de que quieres eliminar este empleado?')) {
      return
    }

    try {
      const { error } = await supabase
        .from('employees')
        .delete()
        .eq('id', employeeId)

      if (error) throw error

      setEmployees(prev => prev.filter(emp => emp.id !== employeeId))
    } catch (error) {
      console.error('Error deleting employee:', error)
      alert('Error al eliminar empleado')
    }
  }

  if (loading) {
    return (
      <AdminRoute>
        <div className="flex items-center justify-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
        </div>
      </AdminRoute>
    )
  }

  return (
    <AdminRoute>
      <div className="space-y-6">
      {/* Header */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
              Gestión de Empleados
            </h1>
            <p className="text-gray-600">
              Administra la información de los empleados
            </p>
          </div>
          <button
            onClick={() => setShowAddForm(true)}
            className="btn-primary"
          >
            <Plus className="h-5 w-5 mr-2" />
            Agregar Empleado
          </button>
        </div>
      </div>

      {/* Search and filters */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <div className="flex items-center space-x-4">
          <div className="flex-1 relative">
            <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 h-5 w-5 text-gray-400" />
            <input
              type="text"
              placeholder="Buscar empleados..."
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field pl-12"
            />
          </div>
        </div>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center">
            <User className="h-8 w-8 text-primary-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600 dark:text-gray-300">Total Empleados</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">{employees.length}</p>
            </div>
          </div>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center">
            <Clock className="h-8 w-8 text-green-600" />
            <div className="ml-4">
              <p className="text-sm font-medium text-gray-600 dark:text-gray-300">Activos</p>
              <p className="text-2xl font-bold text-gray-900 dark:text-white">
                {employees.filter(emp => emp.is_active).length}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* Employees table */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow overflow-hidden">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-800">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            Lista de Empleados
          </h3>
        </div>
        <div className="overflow-x-auto">
          <table className="min-w-full divide-y divide-gray-200 dark:divide-gray-800">
            <thead className="bg-gray-50 dark:bg-gray-800">
              <tr>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Empleado
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Posición
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Departamento
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Estado
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Fecha Contratación
                </th>
                <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider">
                  Acciones
                </th>
              </tr>
            </thead>
            <tbody className="bg-white dark:bg-gray-900 divide-y divide-gray-200 dark:divide-gray-800">
              {filteredEmployees.map((employee) => (
                <tr key={employee.id} className="hover:bg-gray-50 dark:bg-gray-800">
                  <td className="px-6 py-4 whitespace-nowrap">
                    <div className="flex items-center">
                      <div className="h-10 w-10 bg-primary-100 rounded-full flex items-center justify-center">
                        <User className="h-5 w-5 text-primary-600" />
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900 dark:text-white">
                          {employee.full_name}
                        </div>
                        <div className="text-sm text-gray-500 dark:text-gray-400 flex items-center">
                          <Mail className="h-4 w-4 mr-1" />
                          {employee.email}
                        </div>
                      </div>
                    </div>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {employee.position}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {employee.department}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap">
                    <span className={`inline-flex px-2 py-1 text-xs font-semibold rounded-full ${
                      employee.is_active
                        ? 'bg-green-100 text-green-800'
                        : 'bg-red-100 text-red-800'
                    }`}>
                      {employee.is_active ? 'Activo' : 'Inactivo'}
                    </span>
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-900 dark:text-white">
                    {formatDate(employee.hire_date)}
                  </td>
                  <td className="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <div className="flex space-x-2">
                      <button
                        onClick={() => setEditingEmployee(employee)}
                        className="text-primary-600 hover:text-primary-900"
                      >
                        <Edit className="h-4 w-4" />
                      </button>
                      <button
                        onClick={() => handleToggleActive(employee.id, employee.is_active)}
                        className={`${
                          employee.is_active 
                            ? 'text-yellow-600 hover:text-yellow-900' 
                            : 'text-green-600 hover:text-green-900'
                        }`}
                      >
                        {employee.is_active ? 'Desactivar' : 'Activar'}
                      </button>
                      <button
                        onClick={() => handleDeleteEmployee(employee.id)}
                        className="text-red-600 hover:text-red-900"
                      >
                        <Trash2 className="h-4 w-4" />
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add/Edit Employee Modal */}
      {(showAddForm || editingEmployee) && (
        <EmployeeForm
          employee={editingEmployee}
          departments={departments}
          positions={positions}
          onClose={() => {
            setShowAddForm(false)
            setEditingEmployee(null)
          }}
          onSave={() => {
            loadData()
            setShowAddForm(false)
            setEditingEmployee(null)
          }}
        />
      )}
      </div>
    </AdminRoute>
  )
}

// Componente para el formulario de empleado
function EmployeeForm({ 
  employee, 
  departments, 
  positions, 
  onClose, 
  onSave 
}: {
  employee: Employee | null
  departments: Department[]
  positions: Position[]
  onClose: () => void
  onSave: () => void
}) {
  const [formData, setFormData] = useState({
    email: employee?.email || '',
    full_name: employee?.full_name || '',
    position_id: '',
    department_id: '',
    is_active: employee?.is_active ?? true
  })
  const [loading, setLoading] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)

    try {
      if (employee) {
        // Actualizar empleado existente
        const { error } = await supabase
          .from('employees')
          .update({
            email: formData.email,
            full_name: formData.full_name,
            position_id: formData.position_id || null,
            department_id: formData.department_id || null,
            is_active: formData.is_active
          })
          .eq('id', employee.id)

        if (error) throw error
      } else {
        // Crear nuevo empleado
        const { error } = await supabase
          .from('employees')
          .insert({
            email: formData.email,
            full_name: formData.full_name,
            position_id: formData.position_id || null,
            department_id: formData.department_id || null,
            is_active: formData.is_active
          })

        if (error) throw error
      }

      onSave()
    } catch (error) {
      console.error('Error saving employee:', error)
      alert('Error al guardar empleado')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow-xl max-w-md w-full mx-4">
        <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-800">
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            {employee ? 'Editar Empleado' : 'Agregar Empleado'}
          </h3>
        </div>
        <form onSubmit={handleSubmit} className="px-6 py-4 space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Nombre Completo
            </label>
            <input
              type="text"
              required
              value={formData.full_name}
              onChange={(e) => setFormData(prev => ({ ...prev, full_name: e.target.value }))}
              className="input-field"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Email
            </label>
            <input
              type="email"
              required
              value={formData.email}
              onChange={(e) => setFormData(prev => ({ ...prev, email: e.target.value }))}
              className="input-field"
            />
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Departamento
            </label>
            <select
              value={formData.department_id}
              onChange={(e) => setFormData(prev => ({ ...prev, department_id: e.target.value }))}
              className="input-field"
            >
              <option value="">Seleccionar departamento</option>
              {departments.map(dept => (
                <option key={dept.id} value={dept.id}>
                  {dept.name}
                </option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Posición
            </label>
            <select
              value={formData.position_id}
              onChange={(e) => setFormData(prev => ({ ...prev, position_id: e.target.value }))}
              className="input-field"
            >
              <option value="">Seleccionar posición</option>
              {positions.map(pos => (
                <option key={pos.id} value={pos.id}>
                  {pos.title}
                </option>
              ))}
            </select>
          </div>
          <div className="flex items-center">
            <input
              type="checkbox"
              id="is_active"
              checked={formData.is_active}
              onChange={(e) => setFormData(prev => ({ ...prev, is_active: e.target.checked }))}
              className="h-4 w-4 text-primary-600 focus:ring-primary-500 border-gray-300 rounded"
            />
            <label htmlFor="is_active" className="ml-2 block text-sm text-gray-900 dark:text-white">
              Empleado activo
            </label>
          </div>
          <div className="flex justify-end space-x-3 pt-4">
            <button
              type="button"
              onClick={onClose}
              className="btn-secondary"
            >
              Cancelar
            </button>
            <button
              type="submit"
              disabled={loading}
              className="btn-primary disabled:opacity-50"
            >
              {loading ? 'Guardando...' : (employee ? 'Actualizar' : 'Crear')}
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
