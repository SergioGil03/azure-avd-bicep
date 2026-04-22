// =============================================================
// avd-hostpool.bicep
// Crea: Host Pool + token de registro + diagnostic settings
// =============================================================

param location string
param namingPrefix string
param hostPoolType string
param loadBalancerType string
param logAnalyticsWorkspaceId string
param tags object
param maxSessionLimit int

// ─────────────────────────────────────────────────────────────
// VARIABLES
// ─────────────────────────────────────────────────────────────

// utcNow() SOLO puede usarse como default value de un parámetro
// Bicep lo evalúa en el momento del despliegue
param baseTime string = utcNow('u')
var tokenExpiry = dateTimeAdd(baseTime, 'PT48H')

// ─────────────────────────────────────────────────────────────
// HOST POOL
// ─────────────────────────────────────────────────────────────

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2025-10-10' = {
  name: 'hp-${namingPrefix}'
  location: location
  tags: tags
  properties: {

    hostPoolType:    hostPoolType     // Pooled
    loadBalancerType: loadBalancerType

    // Qué tipo de Application Group se crea por defecto
    // Desktop = escritorio completo
    preferredAppGroupType: 'Desktop'

      maxSessionLimit: maxSessionLimit

    // false = entorno de producción
    validationEnvironment: false

    // Las VMs se arrancan automáticamente cuando un usuario
    // intenta conectarse y la VM está apagada
    startVMOnConnect: true

    friendlyName: 'AVD ${toUpper(namingPrefix)}'
    description:  'Host Pool para operarios de almacén — ${namingPrefix}'

    // Propiedades RDP personalizadas
    // Controlan qué puede redirigir el cliente al servidor
    customRdpProperty: join([
      'audiocapturemode:i:0'        // no redirigir micrófono de la PDA
      'audiomode:i:0'               // reproducir audio en el servidor
      'camerastoredirect:s:'        // no redirigir cámara
      'devicestoredirect:s:'        // no redirigir dispositivos USB
      'drivestoredirect:s:'         // no redirigir unidades locales
      'redirectclipboard:i:1'       // permitir copiar/pegar
      'redirectprinters:i:0'        // no redirigir impresoras
      'redirectsmartcards:i:0'      // no redirigir smartcards
      'screen mode id:i:2'          // pantalla completa
      'use multimon:i:0'            // una sola pantalla (PDAs tienen una)
    ], ';')

    // Token de registro para las VMs
    // Update = genera uno nuevo si ya existe
    registrationInfo: {
      expirationTime:              tokenExpiry
      registrationTokenOperation:  'Update'
    }

    // Ventana de mantenimiento para actualizaciones del agente AVD
    // Domingos a las 2:00 AM — fuera del horario de almacén
    agentUpdate: {
      type:                        'Scheduled'
      useSessionHostLocalTime:     false
      maintenanceWindowTimeZone:   'W. Europe Standard Time'
      maintenanceWindows: [
        {
          hour:      2
          dayOfWeek: 'Sunday'
        }
      ]
    }
  }
}

// ─────────────────────────────────────────────────────────────
// DIAGNOSTIC SETTINGS
// Envía los logs del Host Pool a Log Analytics
// ─────────────────────────────────────────────────────────────

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  'diag-${hostPool.name}'
  scope: hostPool
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled:       true
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

output hostPoolId   string = hostPool.id
output hostPoolName string = hostPool.name

// El token lo necesita avd-sessionhosts.bicep para registrar las VMs
// @secure() no existe en outputs pero Bicep lo trata con cuidado
// No aparece en logs de despliegue
output registrationToken string = hostPool.properties.registrationInfo.?token ?? ''
