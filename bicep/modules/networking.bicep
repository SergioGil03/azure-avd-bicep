// =============================================================
// networking.bicep
// Crea: NSG + VNet con 2 subnets
// =============================================================

param location string
param namingPrefix string
param vnetAddressPrefix string
param avdSubnetPrefix string
param tags object

// ─────────────────────────────────────────────────────────────
// NSG — Network Security Group
// Se asocia a la subnet de las VMs de AVD
// ─────────────────────────────────────────────────────────────

resource nsg 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-${namingPrefix}'
  location: location
  tags: tags
  properties: {
    securityRules: [

      // ── REGLAS DE ENTRADA ──────────────────────────────────
      // AVD usa reverse connect — las VMs salen ellas al gateway
      // No necesitamos abrir RDP (3389) desde internet
      // Solo permitimos tráfico desde el service tag de AVD

      {
        name: 'Allow-AVD-ReverseConnect'
        properties: {
          priority:                   100
          protocol:                   'Tcp'
          access:                     'Allow'
          direction:                  'Inbound'
          sourceAddressPrefix:        'WindowsVirtualDesktop' // service tag de MS
          sourcePortRange:            '*'
          destinationAddressPrefix:   '*'
          destinationPortRange:       '443'
          description:                'Permite reverse connect desde el gateway de AVD'
        }
      }

      {
        name: 'Deny-All-Inbound'
        properties: {
          priority:                   4096   // máxima prioridad = última regla
          protocol:                   '*'
          access:                     'Deny'
          direction:                  'Inbound'
          sourceAddressPrefix:        '*'
          sourcePortRange:            '*'
          destinationAddressPrefix:   '*'
          destinationPortRange:       '*'
          description:                'Deniega todo lo demás — seguridad por defecto'
        }
      }

      // ── REGLAS DE SALIDA ───────────────────────────────────
      // Las VMs necesitan salir a internet para:
      //   - Conectar al gateway de AVD (443)
      //   - Activar Windows con KMS
      //   - Resolver DNS
      //   - Descargar actualizaciones

      {
        name: 'Allow-HTTPS-Outbound'
        properties: {
          priority:                   100
          protocol:                   'Tcp'
          access:                     'Allow'
          direction:                  'Outbound'
          sourceAddressPrefix:        '*'
          sourcePortRange:            '*'
          destinationAddressPrefix:   'Internet'
          destinationPortRange:       '443'
          description:                'AVD agents, actualizaciones, activación'
        }
      }

      {
        name: 'Allow-DNS-Outbound'
        properties: {
          priority:                   110
          protocol:                   'Udp'
          access:                     'Allow'
          direction:                  'Outbound'
          sourceAddressPrefix:        '*'
          sourcePortRange:            '*'
          destinationAddressPrefix:   '*'
          destinationPortRange:       '53'
          description:                'Resolución DNS'
        }
      }

      {
        name: 'Allow-KMS-Outbound'
        properties: {
          priority:                   120
          protocol:                   'Tcp'
          access:                     'Allow'
          direction:                  'Outbound'
          sourceAddressPrefix:        '*'
          sourcePortRange:            '*'
          destinationAddressPrefix:   '23.102.135.246'  // KMS de Microsoft
          destinationPortRange:       '1688'
          description:                'Activación de licencias Windows'
        }
      }

      {
        name: 'Allow-AzureCloud-Outbound'
        properties: {
          priority:                   130
          protocol:                   'Tcp'
          access:                     'Allow'
          direction:                  'Outbound'
          sourceAddressPrefix:        '*'
          sourcePortRange:            '*'
          destinationAddressPrefix:   'AzureCloud'  // service tag de Azure
          destinationPortRange:       '443'
          description:                'Comunicación con servicios de Azure (Monitor, Storage, etc.)'
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────
// VIRTUAL NETWORK
// ─────────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: 'vnet-${namingPrefix}'
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [vnetAddressPrefix]  // 10.10.0.0/16 — 65534 IPs disponibles
    }
    subnets: [

      // Subnet donde viven las VMs de AVD
      // Tiene el NSG asociado
      {
        name: 'snet-avd-hosts'
        properties: {
          addressPrefix:                     avdSubnetPrefix  // 10.10.1.0/24
          networkSecurityGroup: {
            id: nsg.id
          }
          // Necesario para que los Private Endpoints funcionen en otras subnets
          privateEndpointNetworkPolicies:    'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// Estos IDs los necesitan otros módulos para conectarse a la red
// ─────────────────────────────────────────────────────────────

output vnetId      string = vnet.id
output vnetName    string = vnet.name

// El ID de la subnet lo usa avd-sessionhosts.bicep para las NICs de las VMs
output avdSubnetId string = vnet.properties.subnets[0].id

output nsgId       string = nsg.id
