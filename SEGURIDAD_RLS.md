# 🔒 Solución de Errores de Seguridad RLS

## ⚠️ Problema Detectado

Supabase ha detectado **errores críticos de seguridad** en tu base de datos:

- ❌ **Tablas con políticas RLS definidas pero RLS deshabilitado**
- ❌ **Tablas públicas sin protección**

Esto significa que aunque has creado políticas de seguridad, **no se están aplicando** porque Row Level Security (RLS) no está habilitado en las tablas.

## 🎯 ¿Qué es Row Level Security (RLS)?

**Row Level Security** es un sistema de seguridad de PostgreSQL/Supabase que:

- ✅ Controla qué filas puede ver/modificar cada usuario
- ✅ Aplica automáticamente las políticas de seguridad
- ✅ Protege contra accesos no autorizados

### Ejemplo Práctico:

**Sin RLS habilitado:**
```sql
-- Un empleado podría ejecutar:
SELECT * FROM time_entries;
-- Y vería TODOS los registros de TODOS los empleados ❌
```

**Con RLS habilitado:**
```sql
-- El mismo empleado ejecuta:
SELECT * FROM time_entries;
-- Solo ve SUS PROPIOS registros ✅
-- Las políticas se aplican automáticamente
```

## 🔧 Solución

### 1️⃣ Ejecutar el Script SQL

Ve a **Supabase Dashboard** → **SQL Editor** y ejecuta el archivo:

```
supabase/enable_rls.sql
```

Este script:
- Habilita RLS en todas las tablas afectadas
- Verifica que el cambio se aplicó correctamente
- No elimina ninguna política existente

### 2️⃣ Tablas que se Arreglan

El script habilita RLS en:
- ✅ `company_settings` - Configuración de empresa
- ✅ `departments` - Departamentos
- ✅ `employees` - Empleados
- ✅ `positions` - Posiciones/Cargos
- ✅ `time_entries` - Registros de tiempo
- ✅ `time_off_requests` - Solicitudes de tiempo libre
- ✅ `notification_logs` - Logs de notificaciones

### 3️⃣ Verificar que Funcionó

Después de ejecutar el script, verás una tabla que muestra:

```
tablename          | rls_enabled
-------------------+-------------
company_settings   | true
departments        | true
employees          | true
positions          | true
time_entries       | true
...
```

**Todas deben mostrar `true`** ✅

## 📊 Impacto en tu Aplicación

### ¿Se romperá algo?

**NO**, porque:
- Las políticas ya estaban definidas
- Solo las estamos activando
- Tu aplicación ya usa autenticación de Supabase
- Los accesos autorizados seguirán funcionando

### ¿Qué cambia?

**ANTES:**
- Cualquier acceso directo a la base de datos veía todos los datos
- Alto riesgo de seguridad
- Las políticas existían pero no se aplicaban

**DESPUÉS:**
- Solo se ve/modifica lo permitido por las políticas
- Seguridad garantizada
- Las políticas se aplican automáticamente

## 🔍 Sobre las Vistas SECURITY DEFINER

El linter también reporta estas vistas:
- `employee_compliance_summary`
- `attendance_compliance`

**¿Es un problema?**

**NO necesariamente**. Estas vistas usan `SECURITY DEFINER` **intencionalmente** para:
- Permitir cálculos de cumplimiento
- Sin exponer datos sensibles directamente
- Con permisos del creador de la vista

**¿Deberías cambiarlo?**

Solo si:
- Quieres que cada usuario vea diferentes resultados según sus permisos
- Prefieres aplicar RLS en las vistas también

Para la mayoría de casos, **está bien dejarlo así**.

## ⚡ Comandos Rápidos

### Habilitar RLS en una tabla específica:
```sql
ALTER TABLE nombre_tabla ENABLE ROW LEVEL SECURITY;
```

### Deshabilitar RLS (NO recomendado):
```sql
ALTER TABLE nombre_tabla DISABLE ROW LEVEL SECURITY;
```

### Ver estado de RLS en todas las tablas:
```sql
SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY tablename;
```

### Ver todas las políticas de una tabla:
```sql
SELECT * FROM pg_policies 
WHERE tablename = 'employees';
```

## 📚 Más Información

- [Documentación oficial de RLS en Supabase](https://supabase.com/docs/guides/auth/row-level-security)
- [Guía de seguridad de PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
- [Database Linter de Supabase](https://supabase.com/docs/guides/database/database-linter)

## ✅ Checklist de Seguridad

Después de ejecutar el script, verifica:

- [ ] Ejecutaste `supabase/enable_rls.sql` en SQL Editor
- [ ] Todas las tablas muestran `rls_enabled = true`
- [ ] Los errores desaparecieron del Database Linter
- [ ] Tu aplicación sigue funcionando correctamente
- [ ] Los empleados solo ven sus propios datos
- [ ] Los administradores ven todos los datos

## 🆘 Si Algo Falla

Si después de habilitar RLS algo no funciona:

1. **Verifica las políticas existentes:**
   ```sql
   SELECT * FROM pg_policies WHERE tablename = 'nombre_tabla';
   ```

2. **Revisa los logs de Supabase** para ver errores de permisos

3. **Temporalmente deshabilita RLS** para verificar:
   ```sql
   ALTER TABLE nombre_tabla DISABLE ROW LEVEL SECURITY;
   ```

4. **Contacta con el equipo** si necesitas ajustar políticas específicas

---

**Nota:** Este script es **completamente seguro** y no borra datos ni políticas existentes. Solo activa la seguridad que ya habías configurado.

