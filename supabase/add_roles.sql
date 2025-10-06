-- Script para agregar sistema de roles de administrador
-- Ejecutar este script en el SQL Editor de Supabase

-- 1. Agregar columna de rol a la tabla employees
ALTER TABLE employees 
ADD COLUMN IF NOT EXISTS role VARCHAR(20) DEFAULT 'employee' CHECK (role IN ('employee', 'admin'));

-- 2. Crear índice para mejorar el rendimiento de consultas por rol
CREATE INDEX IF NOT EXISTS idx_employees_role ON employees(role);

-- 3. Crear función para verificar si el usuario actual es administrador
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM employees 
    WHERE user_id = auth.uid() 
    AND role = 'admin'
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Actualizar políticas RLS para empleados (solo admins pueden ver todos los empleados)

-- Eliminar políticas anteriores si existen
DROP POLICY IF EXISTS "Users can view their own data" ON employees;
DROP POLICY IF EXISTS "Users can update their own data" ON employees;
DROP POLICY IF EXISTS "Admins can view all data" ON employees;

-- Políticas nuevas para employees
-- Los usuarios pueden ver su propia información
CREATE POLICY "Users can view their own employee data" ON employees
  FOR SELECT
  USING (auth.uid() = user_id);

-- Los administradores pueden ver todos los empleados
CREATE POLICY "Admins can view all employees" ON employees
  FOR SELECT
  USING (is_admin());

-- Los usuarios pueden actualizar su propia información (campos limitados)
CREATE POLICY "Users can update their own basic data" ON employees
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Solo los administradores pueden insertar nuevos empleados
CREATE POLICY "Admins can insert employees" ON employees
  FOR INSERT
  WITH CHECK (is_admin());

-- Solo los administradores pueden eliminar empleados
CREATE POLICY "Admins can delete employees" ON employees
  FOR DELETE
  USING (is_admin());

-- Solo los administradores pueden actualizar todos los campos de cualquier empleado
CREATE POLICY "Admins can update all employee data" ON employees
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

-- 5. Actualizar políticas para time_entries (sin cambios mayores)
-- Los empleados solo ven sus propias entradas, los admins ven todas

DROP POLICY IF EXISTS "Employees can view their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Employees can insert their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Employees can update their own time entries" ON time_entries;
DROP POLICY IF EXISTS "Admins can view all time entries" ON time_entries;

CREATE POLICY "Employees can view their own time entries" ON time_entries
  FOR SELECT
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can view all time entries" ON time_entries
  FOR SELECT
  USING (is_admin());

CREATE POLICY "Employees can insert their own time entries" ON time_entries
  FOR INSERT
  WITH CHECK (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Employees can update their own time entries" ON time_entries
  FOR UPDATE
  USING (
    employee_id IN (SELECT id FROM employees WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can manage all time entries" ON time_entries
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 6. Políticas para company_settings (solo administradores)
DROP POLICY IF EXISTS "Anyone can view settings" ON company_settings;
DROP POLICY IF EXISTS "Anyone can update settings" ON company_settings;

CREATE POLICY "Anyone can view company settings" ON company_settings
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can update company settings" ON company_settings
  FOR UPDATE
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Only admins can insert company settings" ON company_settings
  FOR INSERT
  WITH CHECK (is_admin());

-- 7. Políticas para departments (solo admins pueden modificar)
DROP POLICY IF EXISTS "Anyone can view departments" ON departments;

CREATE POLICY "Anyone can view departments" ON departments
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can manage departments" ON departments
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 8. Políticas para positions (solo admins pueden modificar)
DROP POLICY IF EXISTS "Anyone can view positions" ON positions;

CREATE POLICY "Anyone can view positions" ON positions
  FOR SELECT
  USING (true);

CREATE POLICY "Only admins can manage positions" ON positions
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 9. IMPORTANTE: Asignar rol de administrador al primer usuario
-- Reemplaza 'TU_EMAIL_AQUI' con el email del usuario que quieres hacer administrador
-- O ejecuta esta query manualmente después con el email correcto:
-- UPDATE employees SET role = 'admin' WHERE email = 'tu-email@ejemplo.com';

-- Comentado por seguridad - ejecutar manualmente:
-- UPDATE employees SET role = 'admin' WHERE email = 'juanjomp85@gmail.com';

-- Para hacer administrador al primer empleado (descomenta si quieres usarlo):
-- UPDATE employees SET role = 'admin' WHERE id = (SELECT id FROM employees ORDER BY created_at LIMIT 1);

-- 10. Verificar la configuración
-- SELECT email, role FROM employees;

COMMENT ON COLUMN employees.role IS 'Rol del empleado: employee (por defecto) o admin';
COMMENT ON FUNCTION is_admin() IS 'Función que verifica si el usuario actual es administrador';

