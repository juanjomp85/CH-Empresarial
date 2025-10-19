'use client'

import { useState, useEffect, useRef } from 'react'
import { Search, X, User } from 'lucide-react'

interface Employee {
  id: string
  full_name: string
}

interface EmployeeSearchProps {
  employees: Employee[]
  selectedEmployeeId: string
  onSelectEmployee: (id: string) => void
  placeholder?: string
  showAllOption?: boolean
}

export default function EmployeeSearch({
  employees,
  selectedEmployeeId,
  onSelectEmployee,
  placeholder = "Buscar empleado...",
  showAllOption = false
}: EmployeeSearchProps) {
  const [searchTerm, setSearchTerm] = useState('')
  const [isOpen, setIsOpen] = useState(false)
  const [filteredEmployees, setFilteredEmployees] = useState<Employee[]>(employees)
  const wrapperRef = useRef<HTMLDivElement>(null)

  const selectedEmployee = employees.find(emp => emp.id === selectedEmployeeId)

  useEffect(() => {
    const filtered = employees.filter(emp =>
      emp.full_name.toLowerCase().includes(searchTerm.toLowerCase())
    )
    setFilteredEmployees(filtered)
  }, [searchTerm, employees])

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target as Node)) {
        setIsOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  const handleSelect = (id: string) => {
    onSelectEmployee(id)
    setIsOpen(false)
    setSearchTerm('')
  }

  const handleClear = () => {
    if (showAllOption) {
      onSelectEmployee('all')
    }
    setSearchTerm('')
  }

  return (
    <div ref={wrapperRef} className="relative w-full max-w-xs">
      {/* Input con lupa */}
      <div className="relative">
        <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
          <Search className="h-5 w-5 text-gray-400" />
        </div>
        <input
          type="text"
          value={isOpen ? searchTerm : (selectedEmployeeId === 'all' ? 'Todos los empleados' : selectedEmployee?.full_name || '')}
          onChange={(e) => {
            setSearchTerm(e.target.value)
            setIsOpen(true)
          }}
          onFocus={() => setIsOpen(true)}
          placeholder={placeholder}
          className="input-field-with-icon pr-10"
        />
        {(searchTerm || selectedEmployeeId !== 'all') && (
          <button
            onClick={handleClear}
            className="absolute inset-y-0 right-0 pr-3 flex items-center"
          >
            <X className="h-5 w-5 text-gray-400 hover:text-gray-600" />
          </button>
        )}
      </div>

      {/* Dropdown de resultados */}
      {isOpen && (
        <div className="absolute z-10 mt-1 w-full bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg max-h-60 overflow-auto">
          {showAllOption && (
            <button
              onClick={() => handleSelect('all')}
              className={`
                w-full px-4 py-2 text-left hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-2
                ${selectedEmployeeId === 'all' ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-300' : 'text-gray-900 dark:text-white'}
              `}
            >
              <User className="h-4 w-4" />
              <span className="font-medium">Todos los empleados</span>
            </button>
          )}
          
          {filteredEmployees.length > 0 ? (
            filteredEmployees.map(employee => (
              <button
                key={employee.id}
                onClick={() => handleSelect(employee.id)}
                className={`
                  w-full px-4 py-2 text-left hover:bg-gray-50 dark:hover:bg-gray-700 flex items-center gap-2
                  ${selectedEmployeeId === employee.id ? 'bg-primary-50 dark:bg-primary-900/20 text-primary-700 dark:text-primary-300' : 'text-gray-900 dark:text-white'}
                `}
              >
                <User className="h-4 w-4" />
                {employee.full_name}
              </button>
            ))
          ) : (
            <div className="px-4 py-3 text-sm text-gray-500 dark:text-gray-400">
              No se encontraron empleados
            </div>
          )}
        </div>
      )}
    </div>
  )
}
