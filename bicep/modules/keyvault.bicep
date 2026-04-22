// =============================================================
// keyvault.bicep
// Crea: Key Vault con RBAC, soft delete y purge protection
// =============================================================

@description('Allow = abierto (dev) | Deny = solo VNet y Azure Services (prod)')
@allowed(['Allow', 'Deny'])
param kvNetworkDefaultAction string = 'Allow'
param location string
param namingPrefix string
param tags object

@description('Purge protection — activar solo en prod')
param enablePurgeProtection bool = true

// ─────────────────────────────────────────────────────────────
// VARIABLES
// Key Vault tiene restricciones de nombre:
//   - Máximo 24 caracteres
//   - Solo letras, números y guiones
//   - Globalmente único en Azure
//
// uniqueString() genera un hash determinista basado en el ID
// del Resource Group — siempre genera el mismo valor para el
// mismo RG, pero diferente entre RGs distintos.
// ─────────────────────────────────────────────────────────────

var suffix  = uniqueString(resourceGroup().id, location)
var kvName  = 'kv-${take(replace(namingPrefix, '-', ''), 10)}-${take(suffix, 6)}'
//            ↑ 'kv-'  ↑ máx 10 chars del prefix  ↑ 6 chars únicos
//            Resultado ejemplo: kv-avddev-a3f9b2

// ─────────────────────────────────────────────────────────────
// KEY VAULT
// ─────────────────────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2025-05-01' = {
  name: kvName
  location: location
  tags: tags
  properties: {

    sku: {
      family: 'A'
      name:   'standard'  // standard es suficiente
    }

    tenantId: subscription().tenantId

    // Usamos Azure RBAC en lugar de Access Policies
    // Más moderno, más consistente con el resto de Azure
    enableRbacAuthorization: true

    // Soft delete: el KV es recuperable 90 días tras borrado
    enableSoftDelete:            true
    softDeleteRetentionInDays:   90

    // Purge protection: nadie puede eliminarlo permanentemente
    // durante el periodo de retención
    enablePurgeProtection: enablePurgeProtection

    // Permite que las VMs lean secretos durante el despliegue
    // (por ejemplo para recuperar contraseñas en extensiones)
    enabledForDeployment:         true

    // Permite que las plantillas ARM/Bicep lean secretos
    enabledForTemplateDeployment: true

    // El cifrado de discos lo gestiona Azure directamente con claves de plataforma
    enabledForDiskEncryption: false

    networkAcls: {
      bypass:        'AzureServices' // los servicios de Azure pueden acceder siempre
      defaultAction: kvNetworkDefaultAction
                                     // en prod cambiamos esto a 'Deny'
    }

    publicNetworkAccess: 'Enabled'
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

// El ID lo usaríamos si otros módulos necesitan referenciar el KV
output keyVaultId   string = keyVault.id
output keyVaultName string = keyVault.name

// La URI es la dirección para leer secretos desde las VMs o apps
// Formato: https://kv-avddev-a3f9b2.vault.azure.net/
output keyVaultUri  string = keyVault.properties.vaultUri
