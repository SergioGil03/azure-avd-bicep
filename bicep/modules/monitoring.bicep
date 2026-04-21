// =============================================================
// monitoring.bicep
// Crea: Log Analytics Workspace + solución VMInsights
// Todos los demás módulos enviarán sus logs aquí
// =============================================================

param location string
param namingPrefix string
param tags object

@description('Días que se retienen los logs — más días = más coste')
param retentionInDays int = 30

@description('Límite diario de ingesta en GB — evita costes inesperados')
param dailyQuotaGb int = 5

// ─────────────────────────────────────────────────────────────
// LOG ANALYTICS WORKSPACE
// ─────────────────────────────────────────────────────────────

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: 'log-${namingPrefix}'
  location: location
  tags: tags
  properties: {

    sku: {
      // PerGB2018 = pagas por GB ingestado
      // Es el modelo más común y flexible
      name: 'PerGB2018'
    }

    retentionInDays: retentionInDays

    features: {
      // Los usuarios solo ven los logs de sus propios recursos
      // no los de toda la organización
      enableLogAccessUsingOnlyResourcePermissions: true
    }

    // Cap diario de ingesta
    // Si se supera Azure deja de ingestar logs ese día
    // 5 GB/día es suficiente para 3 VMs y 20 usuarios
    workspaceCapping: {
      dailyQuotaGb: dailyQuotaGb
    }

    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery:     'Enabled'
  }
}

// ─────────────────────────────────────────────────────────────
// SOLUCIÓN: VMInsights
// Añade monitorización detallada de VMs sobre el workspace
// - Mapa de procesos y dependencias
// - Métricas detalladas de rendimiento
// - Alertas automáticas de salud de VMs
// ─────────────────────────────────────────────────────────────

resource vmInsights 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  // El nombre DEBE seguir este formato exacto: SolutionName(WorkspaceName)
  name: 'VMInsights(${logAnalytics.name})'
  location: location
  tags: tags
  plan: {
    name:          'VMInsights(${logAnalytics.name})'
    publisher:     'Microsoft'
    product:       'OMSGallery/VMInsights'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalytics.id
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// El workspaceId lo necesitan casi todos los demás módulos
// para enviar sus diagnostic settings aquí
// ─────────────────────────────────────────────────────────────

// ID del recurso — para diagnostic settings de otros recursos
output workspaceId string = logAnalytics.id

// Nombre — para mostrarlo en el summary del pipeline
output workspaceName string = logAnalytics.name

// CustomerId — es el "Workspace ID" que ves en el portal de Azure
// Algunas extensiones de VM lo necesitan para saber dónde enviar logs
output workspaceCustomerId string = logAnalytics.properties.customerId
