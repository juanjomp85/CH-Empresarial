'use client'

import { useEffect, useState } from 'react'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'
import { supabase } from '@/lib/supabase'
import { useAuth } from '@/components/providers/AuthProvider'
import { useTheme } from '@/components/providers/ThemeProvider'
import { Save, Building, Clock, Euro, Globe, Palette, Sun, Moon, Monitor } from 'lucide-react'
import AdminRoute from '@/components/auth/AdminRoute'

interface CompanySettings {
  id: string
  company_name: string
  regular_hours_per_day: number
  overtime_threshold: number
  overtime_multiplier: number
  timezone: string
}

export default function SettingsPage() {
  const { user } = useAuth()
  const { theme, setTheme } = useTheme()
  const [settings, setSettings] = useState<CompanySettings>({
    id: '',
    company_name: '',
    regular_hours_per_day: 8,
    overtime_threshold: 8,
    overtime_multiplier: 1.5,
    timezone: 'Europe/Madrid'
  })
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    loadSettings()
  }, [])

  const loadSettings = async () => {
    try {
      const { data } = await supabase
        .from('company_settings')
        .select('*')
        .single()

      if (data) {
        setSettings(data)
      }
    } catch (error) {
      console.error('Error loading settings:', error)
    } finally {
      setLoading(false)
    }
  }

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault()
    setSaving(true)

    try {
      if (settings.id) {
        // Actualizar configuración existente
        const { error } = await supabase
          .from('company_settings')
          .update({
            company_name: settings.company_name,
            regular_hours_per_day: settings.regular_hours_per_day,
            overtime_threshold: settings.overtime_threshold,
            overtime_multiplier: settings.overtime_multiplier,
            timezone: settings.timezone
          })
          .eq('id', settings.id)

        if (error) throw error
      } else {
        // Crear nueva configuración
        const { data, error } = await supabase
          .from('company_settings')
          .insert({
            company_name: settings.company_name,
            regular_hours_per_day: settings.regular_hours_per_day,
            overtime_threshold: settings.overtime_threshold,
            overtime_multiplier: settings.overtime_multiplier,
            timezone: settings.timezone
          })
          .select()
          .single()

        if (error) throw error
        setSettings(data)
      }

      alert('Configuración guardada exitosamente')
    } catch (error) {
      console.error('Error saving settings:', error)
      alert('Error al guardar la configuración')
    } finally {
      setSaving(false)
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
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          Configuración de la Empresa
        </h1>
        <p className="text-gray-600">
          Ajusta los parámetros generales del sistema
        </p>
      </div>

      {/* Settings Form */}
      <form onSubmit={handleSave} className="space-y-6">
        {/* Company Information */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center mb-4">
            <Building className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">
              Información de la Empresa
            </h3>
          </div>
          
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Nombre de la Empresa
              </label>
              <input
                type="text"
                required
                value={settings.company_name}
                onChange={(e) => setSettings(prev => ({ ...prev, company_name: e.target.value }))}
                className="input-field"
                placeholder="Mi Empresa S.L."
              />
            </div>
          </div>
        </div>

        {/* Time Settings */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center mb-4">
            <Clock className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">
              Configuración de Horarios
            </h3>
          </div>
          
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Horas Regulares por Día
              </label>
              <input
                type="number"
                min="1"
                max="24"
                value={settings.regular_hours_per_day}
                onChange={(e) => setSettings(prev => ({ ...prev, regular_hours_per_day: parseInt(e.target.value) || 8 }))}
                className="input-field"
              />
              <p className="text-xs text-gray-500 mt-1">
                Número de horas consideradas como jornada regular
              </p>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Umbral de Horas Extra
              </label>
              <input
                type="number"
                step="0.5"
                min="0"
                max="24"
                value={settings.overtime_threshold}
                onChange={(e) => setSettings(prev => ({ ...prev, overtime_threshold: parseFloat(e.target.value) || 8 }))}
                className="input-field"
              />
              <p className="text-xs text-gray-500 mt-1">
                Horas a partir de las cuales se consideran horas extra
              </p>
            </div>
          </div>
        </div>

        {/* Payroll Settings */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center mb-4">
            <Euro className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">
              Configuración de Nómina
            </h3>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Multiplicador de Horas Extra
            </label>
            <input
              type="number"
              step="0.1"
              min="1"
              max="3"
              value={settings.overtime_multiplier}
              onChange={(e) => setSettings(prev => ({ ...prev, overtime_multiplier: parseFloat(e.target.value) || 1.5 }))}
              className="input-field"
            />
            <p className="text-xs text-gray-500 mt-1">
              Factor por el cual se multiplica la tarifa por hora para calcular horas extra
            </p>
          </div>
        </div>

        {/* System Settings */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex items-center mb-4">
            <Globe className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white">
              Configuración del Sistema
            </h3>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
              Zona Horaria
            </label>
            <select
              value={settings.timezone}
              onChange={(e) => setSettings(prev => ({ ...prev, timezone: e.target.value }))}
              className="input-field"
            >
              <option value="Europe/Madrid">Europa/Madrid (GMT+1/+2)</option>
              <option value="Europe/London">Europa/Londres (GMT+0/+1)</option>
              <option value="America/New_York">América/Nueva York (GMT-5/-4)</option>
              <option value="America/Los_Angeles">América/Los Ángeles (GMT-8/-7)</option>
              <option value="Asia/Tokyo">Asia/Tokio (GMT+9)</option>
              <option value="UTC">UTC (GMT+0)</option>
            </select>
            <p className="text-xs text-gray-500 mt-1">
              Zona horaria utilizada para todos los registros de tiempo
            </p>
          </div>
        </div>

        {/* Theme Settings */}
        <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
          <div className="flex items-center mb-4">
            <Palette className="h-6 w-6 text-primary-600 mr-3" />
            <h3 className="text-lg font-medium text-gray-900 dark:text-white dark:text-white">
              Configuración de Apariencia
            </h3>
          </div>
          
          <div>
            <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 dark:text-gray-300 mb-4">
              Tema de la aplicación
            </label>
            
            <div className="grid grid-cols-3 gap-4">
              {/* Light Theme */}
              <button
                type="button"
                onClick={() => setTheme('light')}
                className={`p-4 border-2 rounded-lg transition-all duration-200 ${
                  theme === 'light'
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/50'
                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                }`}
              >
                <div className="flex flex-col items-center space-y-2">
                  <Sun className={`h-8 w-8 ${
                    theme === 'light' ? 'text-primary-600' : 'text-gray-400'
                  }`} />
                  <span className={`text-sm font-medium ${
                    theme === 'light' ? 'text-primary-700 dark:text-primary-300' : 'text-gray-700 dark:text-gray-300 dark:text-gray-300'
                  }`}>
                    Claro
                  </span>
                </div>
              </button>

              {/* Dark Theme */}
              <button
                type="button"
                onClick={() => setTheme('dark')}
                className={`p-4 border-2 rounded-lg transition-all duration-200 ${
                  theme === 'dark'
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/50'
                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                }`}
              >
                <div className="flex flex-col items-center space-y-2">
                  <Moon className={`h-8 w-8 ${
                    theme === 'dark' ? 'text-primary-600' : 'text-gray-400'
                  }`} />
                  <span className={`text-sm font-medium ${
                    theme === 'dark' ? 'text-primary-700 dark:text-primary-300' : 'text-gray-700 dark:text-gray-300 dark:text-gray-300'
                  }`}>
                    Oscuro
                  </span>
                </div>
              </button>

              {/* System Theme */}
              <button
                type="button"
                onClick={() => setTheme('system')}
                className={`p-4 border-2 rounded-lg transition-all duration-200 ${
                  theme === 'system'
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/50'
                    : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                }`}
              >
                <div className="flex flex-col items-center space-y-2">
                  <Monitor className={`h-8 w-8 ${
                    theme === 'system' ? 'text-primary-600' : 'text-gray-400'
                  }`} />
                  <span className={`text-sm font-medium ${
                    theme === 'system' ? 'text-primary-700 dark:text-primary-300' : 'text-gray-700 dark:text-gray-300 dark:text-gray-300'
                  }`}>
                    Sistema
                  </span>
                </div>
              </button>
            </div>
            
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-3">
              {theme === 'system' 
                ? 'Se ajustará automáticamente según la configuración de tu sistema'
                : theme === 'dark'
                  ? 'Modo oscuro activado'
                  : 'Modo claro activado'
              }
            </p>
          </div>
        </div>

        {/* Save Button */}
        <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
          <div className="flex justify-end">
            <button
              type="submit"
              disabled={saving}
              className="btn-primary disabled:opacity-50"
            >
              <Save className="h-5 w-5 mr-2" />
              {saving ? 'Guardando...' : 'Guardar Configuración'}
            </button>
          </div>
        </div>
      </form>

      {/* Current Settings Summary */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h3 className="text-lg font-medium text-gray-900 dark:text-white mb-4">
          Resumen de Configuración Actual
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-sm text-gray-600">Empresa</div>
            <div className="text-lg font-semibold text-gray-900 dark:text-white">
              {settings.company_name || 'No configurado'}
            </div>
          </div>
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-sm text-gray-600">Horas Regulares</div>
            <div className="text-lg font-semibold text-gray-900 dark:text-white">
              {settings.regular_hours_per_day}h/día
            </div>
          </div>
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-sm text-gray-600">Umbral Extra</div>
            <div className="text-lg font-semibold text-gray-900 dark:text-white">
              {settings.overtime_threshold}h
            </div>
          </div>
          <div className="p-4 bg-gray-50 dark:bg-gray-800 rounded-lg">
            <div className="text-sm text-gray-600">Multiplicador</div>
            <div className="text-lg font-semibold text-gray-900 dark:text-white">
              {settings.overtime_multiplier}x
            </div>
          </div>
        </div>
      </div>
      </div>
    </AdminRoute>
  )
}
