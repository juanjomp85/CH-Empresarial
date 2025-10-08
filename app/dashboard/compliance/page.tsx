'use client'

import AttendanceCompliance from '@/components/reports/AttendanceCompliance'

// Evitar prerendering estático para páginas que usan Supabase
export const dynamic = 'force-dynamic'

export default function CompliancePage() {
  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-white dark:bg-gray-900 rounded-lg shadow p-6">
        <h1 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
          Mi Cumplimiento de Horarios
        </h1>
        <p className="text-gray-600 dark:text-gray-400">
          Consulta tu puntualidad, asistencia y cumplimiento de horarios establecidos
        </p>
      </div>

      {/* Compliance Component */}
      <AttendanceCompliance />
    </div>
  )
}
