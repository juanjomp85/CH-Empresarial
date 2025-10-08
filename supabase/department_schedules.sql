-- Crear tabla de horarios por departamento
CREATE TABLE IF NOT EXISTS department_schedules (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week >= 0 AND day_of_week <= 6), -- 0 = Domingo, 1 = Lunes, ..., 6 = Sábado
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_working_day BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(department_id, day_of_week)
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_department_schedules_department_id ON department_schedules(department_id);
CREATE INDEX IF NOT EXISTS idx_department_schedules_day_of_week ON department_schedules(day_of_week);

-- Trigger para actualizar updated_at
CREATE TRIGGER update_department_schedules_updated_at 
    BEFORE UPDATE ON department_schedules 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Configurar RLS (Row Level Security)
ALTER TABLE department_schedules ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad para horarios de departamento
-- Todos pueden ver los horarios
CREATE POLICY "Everyone can view department schedules" ON department_schedules 
    FOR SELECT USING (true);

-- Solo administradores pueden crear horarios
CREATE POLICY "Admins can insert department schedules" ON department_schedules 
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Solo administradores pueden actualizar horarios
CREATE POLICY "Admins can update department schedules" ON department_schedules 
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Solo administradores pueden eliminar horarios
CREATE POLICY "Admins can delete department schedules" ON department_schedules 
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Políticas adicionales para departamentos (para permitir gestión completa por admins)
CREATE POLICY "Admins can manage departments" ON departments 
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM employees 
            WHERE user_id = auth.uid() 
            AND role = 'admin'
        )
    );

-- Política para que todos puedan ver departamentos
CREATE POLICY "Everyone can view departments" ON departments 
    FOR SELECT USING (true);

-- Insertar horarios por defecto para departamentos existentes (Lunes a Viernes, 9:00 - 18:00)
-- Solo si no existen horarios previos
DO $$
DECLARE
    dept_record RECORD;
    day INTEGER;
BEGIN
    FOR dept_record IN SELECT id FROM departments LOOP
        FOR day IN 1..5 LOOP -- Lunes a Viernes
            INSERT INTO department_schedules (department_id, day_of_week, start_time, end_time, is_working_day)
            VALUES (dept_record.id, day, '09:00'::TIME, '18:00'::TIME, true)
            ON CONFLICT (department_id, day_of_week) DO NOTHING;
        END LOOP;
        
        -- Sábado y Domingo como no laborables
        FOR day IN 0..0 LOOP -- Domingo
            INSERT INTO department_schedules (department_id, day_of_week, start_time, end_time, is_working_day)
            VALUES (dept_record.id, day, '09:00'::TIME, '18:00'::TIME, false)
            ON CONFLICT (department_id, day_of_week) DO NOTHING;
        END LOOP;
        
        FOR day IN 6..6 LOOP -- Sábado
            INSERT INTO department_schedules (department_id, day_of_week, start_time, end_time, is_working_day)
            VALUES (dept_record.id, day, '09:00'::TIME, '18:00'::TIME, false)
            ON CONFLICT (department_id, day_of_week) DO NOTHING;
        END LOOP;
    END LOOP;
END $$;
