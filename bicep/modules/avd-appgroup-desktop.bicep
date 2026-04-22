// =============================================================
// avd-appgroup-desktop.bicep
// Crea: Desktop Application Group
// =============================================================

param location string
param namingPrefix string
param hostPoolId string
param tags object

// ─────────────────────────────────────────────────────────────
// DESKTOP APPLICATION GROUP
// ─────────────────────────────────────────────────────────────

resource desktopAppGroup 'Microsoft.DesktopVirtualization/applicationGroups@2025-10-10' = {
  name: 'dag-${namingPrefix}'
  location: location
  tags: tags
  properties: {
    // Desktop = escritorio Windows completo
    applicationGroupType: 'Desktop'

    // Vincula este grupo al Host Pool
    // Las VMs del Host Pool son las que sirven este escritorio
    hostPoolArmPath: hostPoolId

    friendlyName: 'Escritorio Completo — ${toUpper(namingPrefix)}'
    description:  'Fase 1: escritorio completo para validación de la app'
  }
}

// ─────────────────────────────────────────────────────────────
// OUTPUTS
// ─────────────────────────────────────────────────────────────

output appGroupId   string = desktopAppGroup.id
output appGroupName string = desktopAppGroup.name
