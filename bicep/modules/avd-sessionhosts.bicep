// =============================================================
// avd-sessionhosts.bicep
// Crea: NICs + VMs + extensiones (AAD Join, AVD DSC, Monitor)
// Loop: crea sessionHostCount recursos de cada tipo
// =============================================================

param location string
param namingPrefix string
param sessionHostCount int
param vmSize string
param osDiskType string
param imageOffer string
param imageSku string
param avdSubnetId string
param hostPoolName string
param logAnalyticsWorkspaceId string
param tags object

@secure()
param vmAdminUsername string

@secure()
param vmAdminPassword string

// ─────────────────────────────────────────────────────────────
// VARIABLES
// ─────────────────────────────────────────────────────────────

// Prefijo para el nombre de las VMs
// Ejemplo: vm-avddev → vm-avddev-01, vm-avddev-02, vm-avddev-03
// Azure tiene límite de 15 chars en nombres de VM Windows
var vmPrefix = 'vm-${take(replace(namingPrefix, '-', ''), 9)}'

// URL del artefacto DSC de Microsoft para registrar VMs a AVD
// Microsoft mantiene este artefacto actualizado
var dscArtifactUri = 'https://wvdportalstorageblob.blob.${environment().suffixes.storage}/galleryartifacts/Configuration_1.0.02790.446.zip'

// ─────────────────────────────────────────────────────────────
// LOOP 1 — NETWORK INTERFACES
// Una NIC por VM — conecta cada VM a la subnet de AVD
// ─────────────────────────────────────────────────────────────

resource nics 'Microsoft.Network/networkInterfaces@2025-05-01' = [
  for i in range(0, sessionHostCount): {
    name:     'nic-${vmPrefix}-${padLeft(i + 1, 2, '0')}'
    location: location
    tags:     tags
    properties: {
      ipConfigurations: [
        {
          name: 'ipconfig1'
          properties: {
            privateIPAllocationMethod: 'Dynamic'  // Azure asigna IP automáticamente
            subnet: {
              id: avdSubnetId  // snet-avd-hosts (10.10.1.0/24)
            }
          }
        }
      ]
      // Accelerated Networking: bypass del hipervisor para mejor rendimiento de red
      // Soportado en D4s_v5 — reduce latencia de red entre VMs y storage
      enableAcceleratedNetworking: true
    }
  }
]

// ─────────────────────────────────────────────────────────────
// LOOP 2 — VIRTUAL MACHINES
// ─────────────────────────────────────────────────────────────

resource sessionHosts 'Microsoft.Compute/virtualMachines@2025-04-01' = [
  for i in range(0, sessionHostCount): {
    name:     '${vmPrefix}-${padLeft(i + 1, 2, '0')}'
    location: location
    tags:     union(tags, { avdHostPool: hostPoolName })  // tag extra para identificar a qué pool pertenece
    identity: {
      // SystemAssigned: la VM tiene su propia identidad en Entra ID
      // Necesario para AAD Join y para que la VM pueda
      // autenticarse contra servicios de Azure sin contraseñas
      type: 'SystemAssigned'
    }
    properties: {
      hardwareProfile: {
        vmSize: vmSize  // Standard_D4s_v5
      }
      osProfile: {
        computerName:  '${vmPrefix}-${padLeft(i + 1, 2, '0')}'
        adminUsername: vmAdminUsername
        adminPassword: vmAdminPassword
        windowsConfiguration: {
          // Las actualizaciones las gestiona el agente AVD
          enableAutomaticUpdates: false
          patchSettings: {
            patchMode: 'Manual'
          }
          // Zona horaria de España
          timeZone: 'W. Europe Standard Time'
        }
      }
      storageProfile: {
        osDisk: {
          name:         'osdisk-${vmPrefix}-${padLeft(i + 1, 2, '0')}'
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: osDiskType  // Premium_LRS
          }
          // Delete: cuando se borra la VM se borra también el disco
          deleteOption: 'Delete'
        }
        imageReference: {
          publisher: 'MicrosoftWindowsDesktop'
          offer:     imageOffer  // office-365
          sku:       imageSku    // win11-23h2-avd-m365
          version:   'latest'   // siempre la última versión del SO
        }
      }
      networkProfile: {
        networkInterfaces: [
          {
            id: nics[i].id
            properties: {
              // Delete: cuando se borra la VM se borra también la NIC
              deleteOption: 'Delete'
            }
          }
        ]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          // Guarda capturas de pantalla del arranque
          // Imprescindible para diagnosticar VMs que no arrancan
          enabled: true
        }
      }
      // Azure Hybrid Benefit: usa tu licencia Windows existente
      // Reduce el coste de las VMs significativamente
      licenseType: 'Windows_Client'
    }
    dependsOn: [nics[i]]
  }
]

// ─────────────────────────────────────────────────────────────
// LOOP 3 — EXTENSIÓN: ENTRA ID JOIN (AAD Join)
// Une cada VM a Entra ID automáticamente
// ─────────────────────────────────────────────────────────────

resource aadJoinExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [
  for i in range(0, sessionHostCount): {
    name:     'AADLoginForWindows'
    parent:   sessionHosts[i]
    location: location
    tags:     tags
    properties: {
      publisher:               'Microsoft.Azure.ActiveDirectory'
      type:                    'AADLoginForWindows'
      typeHandlerVersion:      '2.0'
      autoUpgradeMinorVersion: true
      settings: {
        mdmId: ''
      }
    }
  }
]

// ─────────────────────────────────────────────────────────────
// LOOP 4 — EXTENSIÓN: AZURE MONITOR AGENT
// Envía métricas y logs de las VMs a Log Analytics
// Necesario para AVD Insights y para ver el rendimiento de las VMs
// ─────────────────────────────────────────────────────────────

resource amaExtension 'Microsoft.Compute/virtualMachines/extensions@2025-04-01' = [
  for i in range(0, sessionHostCount): {
    name:     'AzureMonitorWindowsAgent'
    parent:   sessionHosts[i]
    location: location
    tags:     tags
    properties: {
      publisher:               'Microsoft.Azure.Monitor'
      type:                    'AzureMonitorWindowsAgent'
      typeHandlerVersion:      '1.0'
      autoUpgradeMinorVersion: true
      settings: {
        workspaceId: logAnalyticsWorkspaceId
      }
    }
  }
]

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

// Array con los nombres de todas las VMs
output sessionHostNames array = [
  for i in range(0, sessionHostCount): sessionHosts[i].name
]

// Array con los IDs de todas las VMs
output sessionHostIds array = [
  for i in range(0, sessionHostCount): sessionHosts[i].id
]
