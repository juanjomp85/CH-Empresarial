# ⚡ Guía Rápida: Corregir Notificaciones (5 minutos)

---

## 🐛 EL PROBLEMA
Después del fix de ayer, solo ~40% de usuarios reciben notificaciones.  
**Causa**: Ventana de detección de 1 minuto vs cron que ejecuta cada 5 minutos.

---

## ✅ LA SOLUCIÓN (3 pasos)

### 1️⃣ SUPABASE (3 min)

```
1. Abre: https://app.supabase.com
2. Ve a: SQL Editor
3. Copia y pega: Todo el contenido de supabase/notifications.sql
4. Click: Run
5. Verifica: ✅ "Success. No rows returned"
```

### 2️⃣ VERIFICAR (1 min)

```sql
-- Copia y ejecuta en SQL Editor:
SELECT * FROM get_employees_needing_clock_in_reminder();
SELECT * FROM get_employees_needing_clock_out_reminder();

-- ✅ Si ves empleados = funciona
-- ❌ Si no ves nadie = espera a que sea hora de notificar
```

### 3️⃣ PROBAR (1 min)

```bash
# Reemplaza TU_DOMINIO y TU_CRON_SECRET:
curl -X POST https://TU_DOMINIO/api/notifications/send \
  -H "Authorization: Bearer TU_CRON_SECRET"

# ✅ Debe responder: {"success":true,"message":"Notifications processed"}
```

---

## 📊 ANTES vs DESPUÉS

| Horario | Antes | Después |
|---------|-------|---------|
| 09:00   | ✅ Funciona | ✅ Funciona |
| 09:01   | ❌ Se pierde | ✅ Funciona |
| 09:02   | ❌ Se pierde | ✅ Funciona |
| 09:03   | ❌ Se pierde | ✅ Funciona |
| 09:04   | ❌ Se pierde | ✅ Funciona |

**Cobertura**: 20% → **100%** ✅

---

## 🔍 MONITOREO

```sql
-- Ver notificaciones enviadas HOY:
SELECT 
    sent_at AT TIME ZONE 'Europe/Madrid' as hora,
    e.full_name,
    notification_type,
    status
FROM notification_logs nl
JOIN employees e ON nl.employee_id = e.id
WHERE DATE(sent_at AT TIME ZONE 'Europe/Madrid') = CURRENT_DATE
ORDER BY sent_at DESC
LIMIT 20;
```

---

## ❓ TROUBLESHOOTING

**No se envían notificaciones:**
1. Verifica que el cron esté activo en Vercel
2. Revisa variables de entorno (RESEND_API_KEY, EMAIL_FROM)
3. Revisa logs: `notification_logs` donde `status = 'failed'`

**Se envían duplicados:**
- No debería pasar (protección activa)
- Revisa: `notification_logs` para el mismo empleado hoy

**Horario incorrecto:**
- Verifica zona horaria: `SELECT current_setting('timezone');`
- Debe mostrar: `Europe/Madrid`

---

## 📁 ARCHIVOS CLAVE

- `supabase/notifications.sql` ⭐ **ACTUALIZAR**
- `supabase/verify_notifications_fix.sql` → Script completo de verificación
- `FIX_NOTIFICACIONES_PERDIDAS.md` → Detalles técnicos
- `RESUMEN_CORRECCION_20OCT2025.md` → Resumen ejecutivo

---

## ✅ CHECKLIST POST-APLICACIÓN

- [ ] Script ejecutado en Supabase sin errores
- [ ] Funciones SQL retornan empleados correctamente
- [ ] Endpoint responde correctamente
- [ ] Notificaciones se envían a horarios NO múltiplos de 5
- [ ] NO hay duplicados

---

## 🎯 RESULTADO ESPERADO

✅ Todos los empleados con 5+ min de retraso reciben notificación  
✅ Funciona para cualquier horario (no solo :00, :05, :10...)  
✅ Máximo 5 minutos de espera para notificación  
✅ Solo 1 notificación por día por empleado  

---

**Urgencia**: 🔴 ALTA  
**Tiempo**: 5 minutos  
**Dificultad**: 🟢 FÁCIL

