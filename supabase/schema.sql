-- Habilitar extensiones necesarias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Crear tabla de departamentos
CREATE TABLE departments (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de posiciones/cargos
CREATE TABLE positions (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE,
    hourly_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de empleados
CREATE TABLE employees (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL UNIQUE,
    full_name VARCHAR(255) NOT NULL,
    position_id UUID REFERENCES positions(id),
    department_id UUID REFERENCES departments(id),
    hourly_rate DECIMAL(10,2) NOT NULL DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    hire_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de registros de tiempo
CREATE TABLE time_entries (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    clock_in TIMESTAMP WITH TIME ZONE NOT NULL,
    clock_out TIMESTAMP WITH TIME ZONE,
    break_start TIMESTAMP WITH TIME ZONE,
    break_end TIMESTAMP WITH TIME ZONE,
    total_hours DECIMAL(5,2),
    overtime_hours DECIMAL(5,2) DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(employee_id, date)
);

-- Crear tabla de solicitudes de tiempo libre
CREATE TABLE time_off_requests (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    type VARCHAR(50) NOT NULL, -- 'vacation', 'sick', 'personal', 'other'
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    reason TEXT,
    approved_by UUID REFERENCES employees(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de configuraciones de la empresa
CREATE TABLE company_settings (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    company_name VARCHAR(255) NOT NULL,
    regular_hours_per_day INTEGER DEFAULT 8,
    overtime_threshold DECIMAL(5,2) DEFAULT 8.0,
    overtime_multiplier DECIMAL(3,2) DEFAULT 1.5,
    timezone VARCHAR(50) DEFAULT 'Europe/Madrid',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para mejorar el rendimiento
CREATE INDEX idx_employees_user_id ON employees(user_id);
CREATE INDEX idx_employees_email ON employees(email);
CREATE INDEX idx_time_entries_employee_id ON time_entries(employee_id);
CREATE INDEX idx_time_entries_date ON time_entries(date);
CREATE INDEX idx_time_off_requests_employee_id ON time_off_requests(employee_id);
CREATE INDEX idx_time_off_requests_status ON time_off_requests(status);

-- Función para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Crear triggers para updated_at
CREATE TRIGGER update_departments_updated_at BEFORE UPDATE ON departments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_positions_updated_at BEFORE UPDATE ON positions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_employees_updated_at BEFORE UPDATE ON employees FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_time_entries_updated_at BEFORE UPDATE ON time_entries FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_time_off_requests_updated_at BEFORE UPDATE ON time_off_requests FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_company_settings_updated_at BEFORE UPDATE ON company_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Función para calcular horas totales automáticamente
CREATE OR REPLACE FUNCTION calculate_total_hours()
RETURNS TRIGGER AS $$
DECLARE
    total_work_hours DECIMAL(5,2);
    break_duration DECIMAL(5,2) := 0;
BEGIN
    -- Solo calcular si clock_out está presente
    IF NEW.clock_out IS NOT NULL THEN
        -- Calcular horas de trabajo (clock_in a clock_out)
        total_work_hours := EXTRACT(EPOCH FROM (NEW.clock_out - NEW.clock_in)) / 3600;
        
        -- Restar tiempo de descanso si está presente
        IF NEW.break_start IS NOT NULL AND NEW.break_end IS NOT NULL THEN
            break_duration := EXTRACT(EPOCH FROM (NEW.break_end - NEW.break_start)) / 3600;
            total_work_hours := total_work_hours - break_duration;
        END IF;
        
        NEW.total_hours := ROUND(total_work_hours, 2);
        
        -- Calcular horas extra (asumiendo 8 horas regulares por día)
        IF NEW.total_hours > 8 THEN
            NEW.overtime_hours := ROUND(NEW.total_hours - 8, 2);
        ELSE
            NEW.overtime_hours := 0;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Crear trigger para calcular horas automáticamente
CREATE TRIGGER calculate_hours_trigger 
    BEFORE INSERT OR UPDATE ON time_entries 
    FOR EACH ROW EXECUTE FUNCTION calculate_total_hours();

-- Insertar datos iniciales
INSERT INTO departments (name, description) VALUES 
('Recursos Humanos', 'Gestión de personal y administración'),
('Desarrollo', 'Desarrollo de software y tecnología'),
('Ventas', 'Ventas y atención al cliente'),
('Marketing', 'Marketing y comunicación'),
('Finanzas', 'Contabilidad y finanzas');

INSERT INTO positions (title, department_id, hourly_rate, description) VALUES 
('Desarrollador Senior', (SELECT id FROM departments WHERE name = 'Desarrollo'), 25.00, 'Desarrollador con experiencia'),
('Desarrollador Junior', (SELECT id FROM departments WHERE name = 'Desarrollo'), 18.00, 'Desarrollador en formación'),
('Gerente de Ventas', (SELECT id FROM departments WHERE name = 'Ventas'), 30.00, 'Responsable del equipo de ventas'),
('Especialista en Marketing', (SELECT id FROM departments WHERE name = 'Marketing'), 22.00, 'Especialista en estrategias de marketing'),
('Contador', (SELECT id FROM departments WHERE name = 'Finanzas'), 20.00, 'Responsable de contabilidad');

INSERT INTO company_settings (company_name, regular_hours_per_day, overtime_threshold, overtime_multiplier, timezone) VALUES 
('Mi Empresa', 8, 8.0, 1.5, 'Europe/Madrid');

-- Configurar RLS (Row Level Security)
ALTER TABLE departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE positions ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE time_off_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_settings ENABLE ROW LEVEL SECURITY;

-- Políticas de seguridad básicas (se pueden ajustar según necesidades)
CREATE POLICY "Users can view their own data" ON employees FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update their own data" ON employees FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Employees can view their own time entries" ON time_entries FOR SELECT USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);

CREATE POLICY "Employees can insert their own time entries" ON time_entries FOR INSERT WITH CHECK (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);

CREATE POLICY "Employees can update their own time entries" ON time_entries FOR UPDATE USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
);

-- Políticas para administradores (asumiendo que hay un campo is_admin en auth.users)
-- Estas se pueden ajustar según el sistema de roles que implementes
CREATE POLICY "Admins can view all data" ON employees FOR ALL USING (
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
);

CREATE POLICY "Admins can view all time entries" ON time_entries FOR ALL USING (
    EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND raw_user_meta_data->>'role' = 'admin')
);

-- Tabla para preferencias de usuario
CREATE TABLE user_preferences (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    theme VARCHAR(10) DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
    language VARCHAR(5) DEFAULT 'es',
    timezone VARCHAR(50) DEFAULT 'Europe/Madrid',
    notifications_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para preferencias de usuario
CREATE INDEX idx_user_preferences_user_id ON user_preferences(user_id);

-- Trigger para updated_at
CREATE TRIGGER update_user_preferences_updated_at 
    BEFORE UPDATE ON user_preferences 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- RLS para preferencias de usuario
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;

-- Políticas para preferencias de usuario
CREATE POLICY "Users can view their own preferences" ON user_preferences 
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own preferences" ON user_preferences 
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own preferences" ON user_preferences 
    FOR UPDATE USING (auth.uid() = user_id);
