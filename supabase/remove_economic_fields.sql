-- Script para eliminar aspectos económicos de la aplicación
-- Ejecutar este script en el SQL Editor de Supabase

-- 1. Eliminar columna hourly_rate de la tabla employees
ALTER TABLE employees 
DROP COLUMN IF EXISTS hourly_rate;

-- 2. Eliminar columna hourly_rate de la tabla positions
ALTER TABLE positions 
DROP COLUMN IF EXISTS hourly_rate;

-- 3. Eliminar columnas económicas de company_settings
ALTER TABLE company_settings 
DROP COLUMN IF EXISTS overtime_multiplier;

-- 4. Verificar los cambios
-- Descomentar para verificar:
-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'employees';

-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'positions';

-- SELECT column_name, data_type 
-- FROM information_schema.columns 
-- WHERE table_name = 'company_settings';

COMMENT ON TABLE employees IS 'Tabla de empleados sin información económica';
COMMENT ON TABLE positions IS 'Tabla de posiciones sin información de tarifas';
COMMENT ON TABLE company_settings IS 'Configuración de la empresa sin aspectos de nómina';

