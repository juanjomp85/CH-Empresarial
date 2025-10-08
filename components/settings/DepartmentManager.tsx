'use client'

import { useEffect, useState } from 'react'
import { supabase } from '@/lib/supabase'
import { Building, Plus, Edit2, Trash2, X, Save } from 'lucide-react'

interface Department {
  id: string
  name: string
  description: string | null
  created_at: string
  updated_at: string
}

export default function DepartmentManager() {
  const [departments, setDepartments] = useState<Department[]>([])
  const [loading, setLoading] = useState(true)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [isCreating, setIsCreating] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    description: ''
  })

  useEffect(() => {
    loadDepartments()
  }, [])

  const loadDepartments = async () => {
    try {
      const { data, error } = await supabase
        .from('departments')
        .select('*')
        .order('name')

      if (error) throw error
      setDepartments(data || [])
    } catch (error) {
      console.error('Error loading departments:', error)
      alert('Error al cargar los departamentos')
    } finally {
      setLoading(false)
    }
  }

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!formData.name.trim()) return

    try {
      const { error } = await supabase
        .from('departments')
        .insert({
          name: formData.name,
          description: formData.description || null
        })

      if (error) throw error

      alert('Departamento creado exitosamente')
      setFormData({ name: '', description: '' })
      setIsCreating(false)
      loadDepartments()
    } catch (error: any) {
      console.error('Error creating department:', error)
      if (error.code === '23505') {
        alert('Ya existe un departamento con ese nombre')
      } else {
        alert('Error al crear el departamento')
      }
    }
  }

  const handleUpdate = async (id: string) => {
    if (!formData.name.trim()) return

    try {
      const { error } = await supabase
        .from('departments')
        .update({
          name: formData.name,
          description: formData.description || null
        })
        .eq('id', id)

      if (error) throw error

      alert('Departamento actualizado exitosamente')
      setEditingId(null)
      setFormData({ name: '', description: '' })
      loadDepartments()
    } catch (error: any) {
      console.error('Error updating department:', error)
      if (error.code === '23505') {
        alert('Ya existe un departamento con ese nombre')
      } else {
        alert('Error al actualizar el departamento')
      }
    }
  }

  const handleDelete = async (id: string, name: string) => {
    if (!confirm(`¿Estás seguro de que deseas eliminar el departamento "${name}"? Esto también eliminará todos los horarios asociados.`)) {
      return
    }

    try {
      const { error } = await supabase
        .from('departments')
        .delete()
        .eq('id', id)

      if (error) throw error

      alert('Departamento eliminado exitosamente')
      loadDepartments()
    } catch (error) {
      console.error('Error deleting department:', error)
      alert('Error al eliminar el departamento. Puede que tenga empleados asignados.')
    }
  }

  const startEdit = (dept: Department) => {
    setEditingId(dept.id)
    setFormData({
      name: dept.name,
      description: dept.description || ''
    })
    setIsCreating(false)
  }

  const cancelEdit = () => {
    setEditingId(null)
    setIsCreating(false)
    setFormData({ name: '', description: '' })
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center p-8">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary-600"></div>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      {/* Header con botón de crear */}
      <div className="flex items-center justify-between">
        <div className="flex items-center">
          <Building className="h-6 w-6 text-primary-600 mr-3" />
          <h3 className="text-lg font-medium text-gray-900 dark:text-white">
            Gestión de Departamentos
          </h3>
        </div>
        {!isCreating && !editingId && (
          <button
            onClick={() => setIsCreating(true)}
            className="btn-primary flex items-center"
          >
            <Plus className="h-4 w-4 mr-2" />
            Nuevo Departamento
          </button>
        )}
      </div>

      {/* Formulario de creación */}
      {isCreating && (
        <form onSubmit={handleCreate} className="bg-gray-50 dark:bg-gray-800 p-4 rounded-lg border-2 border-primary-300 dark:border-primary-700">
          <div className="space-y-3">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Nombre del Departamento *
              </label>
              <input
                type="text"
                required
                value={formData.name}
                onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                className="input-field"
                placeholder="ej. Recursos Humanos"
                autoFocus
              />
            </div>
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                Descripción
              </label>
              <textarea
                value={formData.description}
                onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                className="input-field"
                placeholder="Descripción del departamento..."
                rows={2}
              />
            </div>
            <div className="flex gap-2 justify-end">
              <button
                type="button"
                onClick={cancelEdit}
                className="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600"
              >
                <X className="h-4 w-4 inline mr-1" />
                Cancelar
              </button>
              <button type="submit" className="btn-primary">
                <Save className="h-4 w-4 inline mr-1" />
                Crear
              </button>
            </div>
          </div>
        </form>
      )}

      {/* Lista de departamentos */}
      <div className="space-y-2">
        {departments.map((dept) => (
          <div
            key={dept.id}
            className="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4"
          >
            {editingId === dept.id ? (
              // Modo edición
              <form onSubmit={(e) => { e.preventDefault(); handleUpdate(dept.id); }} className="space-y-3">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Nombre del Departamento *
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.name}
                    onChange={(e) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                    className="input-field"
                    autoFocus
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1">
                    Descripción
                  </label>
                  <textarea
                    value={formData.description}
                    onChange={(e) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                    className="input-field"
                    rows={2}
                  />
                </div>
                <div className="flex gap-2 justify-end">
                  <button
                    type="button"
                    onClick={cancelEdit}
                    className="px-4 py-2 text-sm font-medium text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-700 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-600"
                  >
                    <X className="h-4 w-4 inline mr-1" />
                    Cancelar
                  </button>
                  <button type="submit" className="btn-primary">
                    <Save className="h-4 w-4 inline mr-1" />
                    Guardar
                  </button>
                </div>
              </form>
            ) : (
              // Modo vista
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <h4 className="text-lg font-semibold text-gray-900 dark:text-white">
                    {dept.name}
                  </h4>
                  {dept.description && (
                    <p className="text-sm text-gray-600 dark:text-gray-400 mt-1">
                      {dept.description}
                    </p>
                  )}
                  <p className="text-xs text-gray-500 dark:text-gray-500 mt-2">
                    Creado: {new Date(dept.created_at).toLocaleDateString('es-ES')}
                  </p>
                </div>
                <div className="flex gap-2 ml-4">
                  <button
                    onClick={() => startEdit(dept)}
                    className="p-2 text-blue-600 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-lg transition-colors"
                    title="Editar"
                  >
                    <Edit2 className="h-4 w-4" />
                  </button>
                  <button
                    onClick={() => handleDelete(dept.id, dept.name)}
                    className="p-2 text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 rounded-lg transition-colors"
                    title="Eliminar"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              </div>
            )}
          </div>
        ))}

        {departments.length === 0 && (
          <div className="text-center py-8 text-gray-500 dark:text-gray-400">
            <Building className="h-12 w-12 mx-auto mb-3 opacity-50" />
            <p>No hay departamentos creados</p>
            <p className="text-sm">Crea tu primer departamento para comenzar</p>
          </div>
        )}
      </div>
    </div>
  )
}
