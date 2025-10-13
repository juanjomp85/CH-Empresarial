import { createClient } from '@supabase/supabase-js'
import { NextRequest, NextResponse } from 'next/server'

// Esta ruta debe ser llamada por un cron job cada 5 minutos
export async function POST(request: NextRequest) {
  try {
    // Verificar token de autorización para evitar llamadas no autorizadas
    const authHeader = request.headers.get('authorization')
    const cronSecret = process.env.CRON_SECRET
    
    if (cronSecret && authHeader !== `Bearer ${cronSecret}`) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }

    // Usar Service Role Key para acceso sin autenticación de usuario
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Obtener empleados que necesitan recordatorio de entrada
    const { data: clockInReminders, error: clockInError } = await supabase
      .rpc('get_employees_needing_clock_in_reminder')

    if (clockInError) {
      console.error('Error getting clock in reminders:', clockInError)
    }

    // Obtener empleados que necesitan recordatorio de salida
    const { data: clockOutReminders, error: clockOutError } = await supabase
      .rpc('get_employees_needing_clock_out_reminder')

    if (clockOutError) {
      console.error('Error getting clock out reminders:', clockOutError)
    }

    const results = {
      clockInSent: 0,
      clockOutSent: 0,
      errors: [] as any[]
    }

    // Enviar recordatorios de entrada
    if (clockInReminders && clockInReminders.length > 0) {
      for (const reminder of clockInReminders) {
        try {
          await sendClockInReminderEmail(
            reminder.employee_email,
            reminder.employee_name,
            reminder.expected_clock_in,
            reminder.minutes_late
          )
          
          // Registrar en el log
          await supabase.rpc('log_notification', {
            p_employee_id: reminder.employee_id,
            p_notification_type: 'clock_in_reminder',
            p_email: reminder.employee_email,
            p_status: 'sent'
          })
          
          results.clockInSent++
        } catch (error: any) {
          console.error('Error sending clock in reminder:', error)
          results.errors.push({
            type: 'clock_in',
            employee: reminder.employee_email,
            error: error.message
          })
          
          // Registrar error en el log
          await supabase.rpc('log_notification', {
            p_employee_id: reminder.employee_id,
            p_notification_type: 'clock_in_reminder',
            p_email: reminder.employee_email,
            p_status: 'failed',
            p_error_message: error.message
          })
        }
      }
    }

    // Enviar recordatorios de salida
    if (clockOutReminders && clockOutReminders.length > 0) {
      for (const reminder of clockOutReminders) {
        try {
          await sendClockOutReminderEmail(
            reminder.employee_email,
            reminder.employee_name,
            reminder.expected_clock_out,
            reminder.minutes_late
          )
          
          // Registrar en el log
          await supabase.rpc('log_notification', {
            p_employee_id: reminder.employee_id,
            p_notification_type: 'clock_out_reminder',
            p_email: reminder.employee_email,
            p_status: 'sent'
          })
          
          results.clockOutSent++
        } catch (error: any) {
          console.error('Error sending clock out reminder:', error)
          results.errors.push({
            type: 'clock_out',
            employee: reminder.employee_email,
            error: error.message
          })
          
          // Registrar error en el log
          await supabase.rpc('log_notification', {
            p_employee_id: reminder.employee_id,
            p_notification_type: 'clock_out_reminder',
            p_email: reminder.employee_email,
            p_status: 'failed',
            p_error_message: error.message
          })
        }
      }
    }

    return NextResponse.json({
      success: true,
      message: 'Notifications processed',
      results
    })

  } catch (error: any) {
    console.error('Error in notification route:', error)
    return NextResponse.json(
      { error: 'Internal server error', details: error.message },
      { status: 500 }
    )
  }
}

// Función para enviar correo de recordatorio de entrada
async function sendClockInReminderEmail(
  email: string,
  name: string,
  expectedTime: string,
  minutesLate: number
) {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'
  const timeUrl = `${appUrl}/dashboard/time`

  // Si tienes configurado Resend, SendGrid u otro servicio de correo
  const emailProvider = process.env.EMAIL_PROVIDER // 'resend', 'sendgrid', 'supabase'

  const subject = '⏰ Recordatorio: Registra tu entrada'
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Recordatorio de Entrada</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #f8f9fa; border-radius: 10px; padding: 30px; border-left: 5px solid #2563eb;">
        <h2 style="color: #2563eb; margin-top: 0;">⏰ Recordatorio de Entrada</h2>
        
        <p>Hola <strong>${name}</strong>,</p>
        
        <p>Te recordamos que tu hora de entrada era a las <strong>${expectedTime}</strong> y aún no has registrado tu entrada.</p>
        
        <p>Llevas <strong>${Math.floor(minutesLate)} minutos</strong> de retraso.</p>
        
        <div style="background-color: #fff; border-radius: 8px; padding: 20px; margin: 20px 0;">
          <p style="margin: 0 0 15px 0;">Haz clic en el botón para registrar tu entrada ahora:</p>
          <a href="${timeUrl}" 
             style="display: inline-block; background-color: #2563eb; color: white; text-decoration: none; padding: 12px 30px; border-radius: 6px; font-weight: bold;">
            Registrar Entrada
          </a>
        </div>
        
        <p style="font-size: 14px; color: #666; margin-top: 20px;">
          Si ya has registrado tu entrada, por favor ignora este mensaje.
        </p>
        
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        
        <p style="font-size: 12px; color: #999;">
          Este es un correo automático del sistema de Control Horario. Por favor no respondas a este correo.
        </p>
      </div>
    </body>
    </html>
  `

  // Aquí implementarías el envío según tu proveedor
  if (emailProvider === 'resend') {
    return await sendWithResend(email, subject, htmlContent)
  } else if (emailProvider === 'sendgrid') {
    return await sendWithSendGrid(email, subject, htmlContent)
  } else {
    // Por defecto, solo registramos en consola (para desarrollo)
    console.log(`[EMAIL] To: ${email}, Subject: ${subject}`)
    console.log(`[EMAIL] Content: ${htmlContent.substring(0, 100)}...`)
    return { success: true, provider: 'console' }
  }
}

// Función para enviar correo de recordatorio de salida
async function sendClockOutReminderEmail(
  email: string,
  name: string,
  expectedTime: string,
  minutesLate: number
) {
  const appUrl = process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'
  const timeUrl = `${appUrl}/dashboard/time`

  const subject = '🚪 Recordatorio: Registra tu salida'
  const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>Recordatorio de Salida</title>
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
      <div style="background-color: #f8f9fa; border-radius: 10px; padding: 30px; border-left: 5px solid #dc2626;">
        <h2 style="color: #dc2626; margin-top: 0;">🚪 Recordatorio de Salida</h2>
        
        <p>Hola <strong>${name}</strong>,</p>
        
        <p>Te recordamos que tu hora de salida era a las <strong>${expectedTime}</strong> y aún no has registrado tu salida.</p>
        
        <p>Han pasado <strong>${Math.floor(minutesLate)} minutos</strong> desde tu hora de salida.</p>
        
        <div style="background-color: #fff; border-radius: 8px; padding: 20px; margin: 20px 0;">
          <p style="margin: 0 0 15px 0;">Haz clic en el botón para registrar tu salida ahora:</p>
          <a href="${timeUrl}" 
             style="display: inline-block; background-color: #dc2626; color: white; text-decoration: none; padding: 12px 30px; border-radius: 6px; font-weight: bold;">
            Registrar Salida
          </a>
        </div>
        
        <p style="font-size: 14px; color: #666; margin-top: 20px;">
          Si ya has registrado tu salida, por favor ignora este mensaje.
        </p>
        
        <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
        
        <p style="font-size: 12px; color: #999;">
          Este es un correo automático del sistema de Control Horario. Por favor no respondas a este correo.
        </p>
      </div>
    </body>
    </html>
  `

  const emailProvider = process.env.EMAIL_PROVIDER

  if (emailProvider === 'resend') {
    return await sendWithResend(email, subject, htmlContent)
  } else if (emailProvider === 'sendgrid') {
    return await sendWithSendGrid(email, subject, htmlContent)
  } else {
    console.log(`[EMAIL] To: ${email}, Subject: ${subject}`)
    console.log(`[EMAIL] Content: ${htmlContent.substring(0, 100)}...`)
    return { success: true, provider: 'console' }
  }
}

// Implementación con Resend (si lo usas)
async function sendWithResend(to: string, subject: string, html: string) {
  const resendApiKey = process.env.RESEND_API_KEY
  
  if (!resendApiKey) {
    throw new Error('RESEND_API_KEY not configured')
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: process.env.EMAIL_FROM || 'Control Horario <noreply@tudominio.com>',
      to: [to],
      subject,
      html
    })
  })

  if (!response.ok) {
    const error = await response.json()
    throw new Error(`Resend error: ${JSON.stringify(error)}`)
  }

  return await response.json()
}

// Implementación con SendGrid (si lo usas)
async function sendWithSendGrid(to: string, subject: string, html: string) {
  const sendGridApiKey = process.env.SENDGRID_API_KEY
  
  if (!sendGridApiKey) {
    throw new Error('SENDGRID_API_KEY not configured')
  }

  const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${sendGridApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      personalizations: [{
        to: [{ email: to }]
      }],
      from: {
        email: process.env.EMAIL_FROM || 'noreply@tudominio.com',
        name: 'Control Horario'
      },
      subject,
      content: [{
        type: 'text/html',
        value: html
      }]
    })
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`SendGrid error: ${error}`)
  }

  return { success: true }
}

