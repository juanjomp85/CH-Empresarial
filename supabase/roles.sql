-- Migración para gestionar roles de usuario
-- Este script añade funcionalidad de roles al sistema

-- Función para actualizar el rol de un usuario
-- Solo puede ser ejecutada por administradores o mediante la consola de Supabase
CREATE OR REPLACE FUNCTION update_user_role(user_id UUID, new_role TEXT)
RETURNS void AS $$
BEGIN
  UPDATE auth.users
  SET raw_user_meta_data = 
    COALESCE(raw_user_meta_data, '{}'::jsonb) || 
    jsonb_build_object('role', new_role)
  WHERE id = user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Función para verificar si un usuario es administrador
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    SELECT (raw_user_meta_data->>'role') = 'admin'
    FROM auth.users
    WHERE id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Actualizar políticas existentes para usar la función is_admin()
-- Eliminar políticas antiguas si existen
DROP POLICY IF EXISTS "Admins can view all data" ON employees;
DROP POLICY IF EXISTS "Admins can view all time entries" ON time_entries;

-- Crear nuevas políticas mejoradas
CREATE POLICY "Admins can manage all employees" ON employees
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can manage all time entries" ON time_entries
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE POLICY "Admins can view all departments" ON departments
  FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can view all positions" ON positions
  FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can manage company settings" ON company_settings
  FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Política para que todos puedan leer la configuración de la empresa
CREATE POLICY "Everyone can view company settings" ON company_settings
  FOR SELECT
  USING (true);

-- INSTRUCCIONES DE USO:
-- Para asignar el rol de administrador a un usuario, ejecuta en la consola SQL de Supabase:
-- SELECT update_user_role('UUID_DEL_USUARIO', 'admin');
--
-- Para asignar rol de empleado regular:
-- SELECT update_user_role('UUID_DEL_USUARIO', 'employee');
--
-- Para obtener el UUID de un usuario por email:
-- SELECT id FROM auth.users WHERE email = 'usuario@ejemplo.com';
--
-- Ejemplo completo para hacer administrador al usuario con email juanjomp85@gmail.com:
-- SELECT update_user_role(
--   (SELECT id FROM auth.users WHERE email = 'juanjomp85@gmail.com'),
--   'admin'
-- );

