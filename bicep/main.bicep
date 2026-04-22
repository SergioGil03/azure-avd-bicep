// =============================================================
// main.bicep — Orquestador principal
// Caso: RemoteApp para 20 operarios de almacén con PDAs Android
// Join: Azure AD Join (Entra ID) — sin Domain Controller
// =============================================================

targetScope = 'subscription'

// ─────────────────────────────────────────────────────────────
// PARÁMETROS GENERALES
// ─────────────────────────────────────────────────────────────

@description('Entorno: dev, test o prod')
@allowed(['dev', 'test', 'prod'])
param environment string

@description('Región de Azure donde se despliega todo')
param location string = 'westeurope'

@description('Nombre del proyecto')
param projectName string = 'avd'

@description('Tags aplicados a todos los recursos')
param tags object = {
  environment: environment
  project: projectName
  managedBy: 'Bicep'
  deployedBy: 'GitHub Actions'
}

@description('Purge protection en Key Vault — solo prod')
param enablePurgeProtection bool = true

@allowed(['Allow', 'Deny'])
param kvNetworkDefaultAction string = 'Allow'

@description('Días de retención de logs en Log Analytics')
param retentionInDays int = 30

@description('Límite diario de ingesta en GB')
param dailyQuotaGb int = 5

// ─────────────────────────────────────────────────────────────
// PARÁMETROS DE RED
// ─────────────────────────────────────────────────────────────

@description('Espacio de direcciones del VNet')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet para las VMs de AVD')
param avdSubnetPrefix string = '10.10.1.0/24'

// ─────────────────────────────────────────────────────────────
// PARÁMETROS DE AVD
// ─────────────────────────────────────────────────────────────

@description('Pooled: varios usuarios comparten VMs')
param hostPoolType string = 'Pooled'

@description('BreadthFirst: distribuye usuarios entre todas las VMs por igual')
param loadBalancerType string = 'BreadthFirst'

@description('Máximo sesiones por VM — 7 usuarios x 3 VMs = 21, cubre las 20 PDAs')
param maxSessionLimit int = 7

@description('3 VMs para 20 usuarios simultáneos con margen')
param sessionHostCount int = 3

@description('D4s_v5: 4 vCPUs 16GB RAM — suficiente para app de almacén')
param vmSize string = 'Standard_D4s_v5'

@description('Premium SSD para mejor rendimiento de FSLogix')
param osDiskType string = 'Premium_LRS'

@description('Windows 11 con Microsoft 365 — licencia incluida en AVD')
param imageOffer string = 'office-365'
param imageSku   string = 'win11-23h2-avd-m365'

// ─────────────────────────────────────────────────────────────
// PARÁMETROS SENSIBLES
// ─────────────────────────────────────────────────────────────

// Después
@secure()
param vmAdminUsername string = ''

@secure()
param vmAdminPassword string = ''

// ─────────────────────────────────────────────────────────────
// VARIABLES
// ─────────────────────────────────────────────────────────────

var namingPrefix      = '${projectName}-${environment}'
var resourceGroupName = 'rg-${namingPrefix}'

// ─────────────────────────────────────────────────────────────
// RESOURCE GROUP
// ─────────────────────────────────────────────────────────────

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ─────────────────────────────────────────────────────────────
// MÓDULOS — en orden de dependencia
// ─────────────────────────────────────────────────────────────

module networking './modules/networking.bicep' = {
  name: 'deploy-networking'
  scope: rg
  params: {
    location:           location
    namingPrefix:       namingPrefix
    vnetAddressPrefix:  vnetAddressPrefix
    avdSubnetPrefix:    avdSubnetPrefix
    tags:               tags
  }
}

module keyVault './modules/keyvault.bicep' = {
  name: 'deploy-keyvault'
  scope: rg
  params: {
    location:     location
    namingPrefix: namingPrefix
    kvNetworkDefaultAction:   kvNetworkDefaultAction
    enablePurgeProtection:    enablePurgeProtection
    tags:         tags
  }
}

module monitoring './modules/monitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: rg
  params: {
    location:         location
    namingPrefix:     namingPrefix
    retentionInDays:  retentionInDays
    dailyQuotaGb:     dailyQuotaGb
    tags:             tags
  }
}


module hostPool './modules/avd-hostpool.bicep' = {
  name: 'deploy-hostpool'
  scope: rg
  params: {
    location:                location
    namingPrefix:            namingPrefix
    hostPoolType:            hostPoolType
    loadBalancerType:        loadBalancerType
    maxSessionLimit:         maxSessionLimit
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags:                    tags
  }
}

// Application Group de Desktop
module appGroupDesktop './modules/avd-appgroup-desktop.bicep' = {
  name: 'deploy-appgroup-desktop'
  scope: rg
  params: {
    location:     location
    namingPrefix: namingPrefix
    hostPoolId:   hostPool.outputs.hostPoolId
    tags:         tags
  }
}

module workspace './modules/avd-workspace.bicep' = {
  name: 'deploy-workspace'
  scope: rg
  params: {
    location:    location
    namingPrefix: namingPrefix
    appGroupIds: [
      appGroupDesktop.outputs.appGroupId
    ]
    tags: tags
  }
}

module sessionHosts './modules/avd-sessionhosts.bicep' = {
  name: 'deploy-sessionhosts'
  scope: rg
  params: {
    location:                location
    namingPrefix:            namingPrefix
    sessionHostCount:        sessionHostCount
    vmSize:                  vmSize
    osDiskType:              osDiskType
    imageOffer:              imageOffer
    imageSku:                imageSku
    avdSubnetId:             networking.outputs.avdSubnetId
    hostPoolName:            hostPool.outputs.hostPoolName
    hostPoolToken:           hostPool.outputs.registrationToken
    vmAdminUsername:         vmAdminUsername
    vmAdminPassword:         vmAdminPassword
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    tags:                    tags
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

output resourceGroupName    string = rg.name
output hostPoolName         string = hostPool.outputs.hostPoolName
output workspaceName        string = workspace.outputs.workspaceName
output desktopAppGroupName  string = appGroupDesktop.outputs.appGroupName
output vnetName             string = networking.outputs.vnetName
