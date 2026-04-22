// =============================================================
// avd-workspace.bicep
// Crea: Workspace — el portal que ven las PDA
// =============================================================

param location string
param namingPrefix string
param appGroupIds array   // array de IDs de Application Groups
param tags object

// ─────────────────────────────────────────────────────────────
// WORKSPACE
// ─────────────────────────────────────────────────────────────

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2025-10-10' = {
  name: 'ws-${namingPrefix}'
  location: location
  tags: tags
  properties: {

    // Lista de Application Groups que aparecen en este Workspace
    applicationGroupReferences: appGroupIds

    friendlyName: 'AVD Almacén — ${toUpper(namingPrefix)}'
    description:  'Workspace para operarios de almacén'

    // Accesible desde internet — necesario para las PDAs
    publicNetworkAccess: 'Enabled'
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

output workspaceId   string = workspace.id
output workspaceName string = workspace.name
