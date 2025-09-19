import { type ClassValue, clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function formatTime(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  return d.toLocaleTimeString('es-ES', { 
    hour: '2-digit', 
    minute: '2-digit' 
  })
}

export function formatDate(date: Date | string): string {
  const d = typeof date === 'string' ? new Date(date) : date
  return d.toLocaleDateString('es-ES', {
    year: 'numeric',
    month: 'long',
    day: 'numeric'
  })
}

export function calculateHours(start: string, end: string): number {
  const startTime = new Date(start)
  const endTime = new Date(end)
  const diffMs = endTime.getTime() - startTime.getTime()
  return Math.round((diffMs / (1000 * 60 * 60)) * 100) / 100
}

export function calculateOvertimeHours(totalHours: number, regularHours: number = 8): number {
  return Math.max(0, totalHours - regularHours)
}

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat('es-ES', {
    style: 'currency',
    currency: 'EUR'
  }).format(amount)
}

/**
 * Convierte una fecha a string en formato YYYY-MM-DD usando la zona horaria local
 * Evita problemas de zona horaria que ocurren con toISOString()
 */
export function formatDateForDB(date: Date = new Date()): string {
  const year = date.getFullYear()
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

/**
 * Obtiene la fecha de hoy en formato YYYY-MM-DD (zona horaria local)
 */
export function getTodayString(): string {
  return formatDateForDB(new Date())
}
