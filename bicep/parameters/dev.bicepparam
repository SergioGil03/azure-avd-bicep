using '../main.bicep'

// ─── GENERAL ─────────────────────────────────────────────────
param environment   = 'dev'
param location      = 'francecentral'
param projectName   = 'avd'

param tags = {
  environment: 'dev'
  project:     'avd'
  managedBy:   'Bicep'
  deployedBy:  'GitHub Actions'
  costCenter:  'IT-DEV'
}

// ─── RED ─────────────────────────────────────────────────────
param vnetAddressPrefix = '10.10.0.0/16'
param avdSubnetPrefix   = '10.10.1.0/24'

// ─── AVD ─────────────────────────────────────────────────────
param hostPoolType     = 'Pooled'
param loadBalancerType = 'BreadthFirst'
param maxSessionLimit  = 5
param sessionHostCount = 1              // 1 sola VM en dev para ahorrar coste
param vmSize           = 'Standard_D2s_v5'
param osDiskType       = 'StandardSSD_LRS'
param imageOffer       = 'office-365'
param imageSku         = 'win11-23h2-avd-m365'

// ─── MONITORING ──────────────────────────────────────────────
param retentionInDays = 30
param dailyQuotaGb    = 2

// ─── KEY VAULT ───────────────────────────────────────────────
param kvNetworkDefaultAction = 'Allow'

// ─── CREDENCIALES ────────────────────────────────────────────
// No se definen aquí — vienen de GitHub Secrets en el pipeline
// param vmAdminUsername = ...
// param vmAdminPassword = ...
