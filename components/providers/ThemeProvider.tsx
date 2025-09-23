'use client'

import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import { supabase } from '@/lib/supabase'
import { useAuth } from './AuthProvider'

type Theme = 'light' | 'dark' | 'system'

interface ThemeContextType {
  theme: Theme
  setTheme: (theme: Theme) => void
  resolvedTheme: 'light' | 'dark'
}

const ThemeContext = createContext<ThemeContextType>({
  theme: 'system',
  setTheme: () => {},
  resolvedTheme: 'light'
})

export const useTheme = () => {
  const context = useContext(ThemeContext)
  if (!context) {
    throw new Error('useTheme debe ser usado dentro de ThemeProvider')
  }
  return context
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>('system')
  const [resolvedTheme, setResolvedTheme] = useState<'light' | 'dark'>('light')
  const { user } = useAuth()

  // Detectar preferencia del sistema
  const getSystemTheme = (): 'light' | 'dark' => {
    if (typeof window !== 'undefined') {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
    }
    return 'light'
  }

  // Resolver tema actual
  const resolveTheme = useCallback((currentTheme: Theme): 'light' | 'dark' => {
    if (currentTheme === 'system') {
      return getSystemTheme()
    }
    return currentTheme
  }, [])

  // Aplicar tema al DOM
  const applyTheme = (resolvedTheme: 'light' | 'dark') => {
    const root = document.documentElement
    root.classList.remove('light', 'dark')
    root.classList.add(resolvedTheme)
    setResolvedTheme(resolvedTheme)
  }

  // Cargar tema guardado
  useEffect(() => {
    const loadTheme = async () => {
      try {
        // Intentar cargar desde localStorage primero (más rápido)
        const localTheme = localStorage.getItem('theme') as Theme
        if (localTheme && ['light', 'dark', 'system'].includes(localTheme)) {
          setThemeState(localTheme)
          applyTheme(resolveTheme(localTheme))
        }

        // Si hay usuario, cargar desde Supabase
        if (user) {
          const { data } = await supabase
            .from('user_preferences')
            .select('theme')
            .eq('user_id', user.id)
            .single()

          if (data?.theme && ['light', 'dark', 'system'].includes(data.theme)) {
            setThemeState(data.theme as Theme)
            applyTheme(resolveTheme(data.theme as Theme))
            // Sincronizar con localStorage
            localStorage.setItem('theme', data.theme)
          }
        }
      } catch (error) {
        console.log('Error loading theme:', error)
        // Usar tema del sistema por defecto
        const systemTheme = getSystemTheme()
        setThemeState('system')
        applyTheme(systemTheme)
      }
    }

    loadTheme()
  }, [user, resolveTheme])

  // Escuchar cambios en la preferencia del sistema
  useEffect(() => {
    if (theme === 'system') {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      const handleChange = () => {
        applyTheme(getSystemTheme())
      }

      mediaQuery.addEventListener('change', handleChange)
      return () => mediaQuery.removeEventListener('change', handleChange)
    }
  }, [theme])

  // Función para cambiar tema
  const setTheme = async (newTheme: Theme) => {
    setThemeState(newTheme)
    const resolved = resolveTheme(newTheme)
    applyTheme(resolved)

    // Guardar en localStorage
    localStorage.setItem('theme', newTheme)

    // Guardar en Supabase si hay usuario
    if (user) {
      try {
        await supabase
          .from('user_preferences')
          .upsert({
            user_id: user.id,
            theme: newTheme,
            updated_at: new Date().toISOString()
          }, {
            onConflict: 'user_id'
          })
      } catch (error) {
        console.error('Error saving theme to database:', error)
      }
    }
  }

  const value = {
    theme,
    setTheme,
    resolvedTheme
  }

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  )
}
