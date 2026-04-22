using '../main.bicep'

// ─── GENERAL ─────────────────────────────────────────────────
param environment   = 'prod'
param location      = 'westeurope'
param projectName   = 'avd'

param tags = {
  environment: 'prod'
  project:     'avd'
  managedBy:   'Bicep'
  deployedBy:  'GitHub Actions'
  costCenter:  'IT-PROD'
}

// ─── RED ─────────────────────────────────────────────────────
param vnetAddressPrefix = '10.20.0.0/16'   // rango diferente a dev
param avdSubnetPrefix   = '10.20.1.0/24'

// ─── AVD ─────────────────────────────────────────────────────
param hostPoolType     = 'Pooled'
param loadBalancerType = 'BreadthFirst'
param maxSessionLimit  = 7
param sessionHostCount = 3              // 3 VMs para 20 operarios
param vmSize           = 'Standard_D4s_v5'
param osDiskType       = 'Premium_LRS'
param imageOffer       = 'office-365'
param imageSku         = 'win11-23h2-avd-m365'

// ─── MONITORING ──────────────────────────────────────────────
param retentionInDays = 90
param dailyQuotaGb    = 5

// ─── KEY VAULT ───────────────────────────────────────────────
param kvNetworkDefaultAction = 'Deny'

// ─── CREDENCIALES ────────────────────────────────────────────
// No se definen aquí — vienen de GitHub Secrets en el pipeline
// param vmAdminUsername = ...
// param vmAdminPassword = ...
