targetScope = 'resourceGroup'

// Make sure the resource group has a few key Azure Policies applied to it. These could also be applied at the subscription
// or management group level.  Applying locally to the resource group is useful for testing and development purposes.

// This is just a sampling of the types of policy you could apply to your resource group.  Please make sure your production deployment
// has all policies applied that are relevant to your workload.  Most of these policies can be applied in 'Deny' mode, but in case you
// need to troubleshoot some of the resources, we've left them in 'Audit' mode for now.

@description('This is the base name for each Azure resource name (6-8 chars). It\'s used as a prefix in Azure Policy assignments')
@minLength(6)
@maxLength(8)
param baseName string

// Existing built-in policy definitions
@description('Policy definition for ensuring Azure AI Services resources have key access disabled to improve security posture.')
resource aiServicesKeyAccessPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '71ef260a-8f18-47b7-abcb-62d0673d94dc'
  scope: tenant()
}

@description('Policy definition for restricting network access to Azure AI Services resources to prevent unauthorized access.')
resource aiServicesNetworkAccessPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '037eea7a-bd0a-46c5-9a66-03aea78705d3'
  scope: tenant()
}

@description('Policy definition for ensuring Cosmos DB accounts are configured with zone redundancy for high availability.')
resource cosmosDbZoneRedundantPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '44c5a1f9-7ef6-4c38-880c-273e8f7a3c24'
  scope: tenant()
}

@description('Policy definition for ensuring Cosmos DB accounts use private endpoints for secure connectivity.')
resource cosmosDbPrivateLinkPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '58440f8a-10c5-4151-bdce-dfbaad4a20b7'
  scope: tenant()
}

@description('Policy definition for disabling local authentication methods on Cosmos DB accounts to improve security.')
resource cosmosDbDisableLocalAuthPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '5450f5bd-9c72-4390-a9c4-a7aba4edfdd2'
  scope: tenant()
}

@description('Policy definition for disabling public network access on Cosmos DB accounts to enhance security.')
resource cosmosDbDisablePublicNetworkPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '797b37f7-06b8-444c-b1ad-fc62867f335a'
  scope: tenant()
}

@description('Policy definition for disabling public network access on Azure AI Search services to enhance security.')
resource searchDisablePublicNetworkPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: 'ee980b6d-0eca-4501-8d54-f6290fd512c3'
  scope: tenant()
}

@description('Policy definition for ensuring Azure AI Search services are configured with zone redundancy for high availability.')
resource searchZoneRedundantPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '90bc8109-d21a-4692-88fc-51419391da3d'
  scope: tenant()
}

@description('Policy definition for disabling local authentication methods on Azure AI Search services to improve security.')
resource searchDisableLocalAuthPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '6300012e-e9a4-4649-b41f-a85f5c43be91'
  scope: tenant()
}

@description('Policy definition for disabling public network access on Storage accounts to enhance security.')
resource storageDisablePublicNetworkPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: 'b2982f36-99f2-4db5-8eff-283140c09693'
  scope: tenant()
}

@description('Policy definition for preventing shared key access on Storage accounts to improve security posture.')
resource storageDisableSharedKeyPolicy 'Microsoft.Authorization/policyDefinitions@2025-01-01' existing = {
  name: '8c6a50c6-9ffd-4ae7-986f-5fa6111f9a54'
  scope: tenant()
}

// ---- New resources (Policy assignments) ----

@description('Policy assignment to audit Azure AI Services resources and ensure key access is disabled for enhanced security.')
resource aiServicesKeyAccessAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, aiServicesKeyAccessPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${aiServicesKeyAccessPolicy.properties.displayName}'
    description: aiServicesKeyAccessPolicy.properties.description
    policyDefinitionId: aiServicesKeyAccessPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit and restrict network access for Azure AI Services resources to improve security posture.')
resource aiServicesNetworkAccessAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, aiServicesNetworkAccessPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${aiServicesNetworkAccessPolicy.properties.displayName}'
    description: aiServicesNetworkAccessPolicy.properties.description
    policyDefinitionId: aiServicesNetworkAccessPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Cosmos DB accounts and ensure zone redundancy is configured for high availability.')
resource cosmosDbZoneRedundantAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, cosmosDbZoneRedundantPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${cosmosDbZoneRedundantPolicy.properties.displayName}'
    description: cosmosDbZoneRedundantPolicy.properties.description
    policyDefinitionId: cosmosDbZoneRedundantPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Cosmos DB accounts and ensure they use private endpoints for secure connectivity.')
resource cosmosDbPrivateLinkAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, cosmosDbPrivateLinkPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${cosmosDbPrivateLinkPolicy.properties.displayName}'
    description: cosmosDbPrivateLinkPolicy.properties.description
    policyDefinitionId: cosmosDbPrivateLinkPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Cosmos DB accounts and ensure local authentication methods are disabled for improved security.')
resource cosmosDbDisableLocalAuthAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, cosmosDbDisableLocalAuthPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${cosmosDbDisableLocalAuthPolicy.properties.displayName}'
    description: cosmosDbDisableLocalAuthPolicy.properties.description
    policyDefinitionId: cosmosDbDisableLocalAuthPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Cosmos DB accounts and ensure public network access is disabled to enhance security.')
resource cosmosDbDisablePublicNetworkAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, cosmosDbDisablePublicNetworkPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${cosmosDbDisablePublicNetworkPolicy.properties.displayName}'
    description: cosmosDbDisablePublicNetworkPolicy.properties.description
    policyDefinitionId: cosmosDbDisablePublicNetworkPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Azure AI Search services and ensure public network access is disabled for enhanced security.')
resource searchDisablePublicNetworkAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, searchDisablePublicNetworkPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${searchDisablePublicNetworkPolicy.properties.displayName}'
    description: searchDisablePublicNetworkPolicy.properties.description
    policyDefinitionId: searchDisablePublicNetworkPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Azure AI Search services and ensure zone redundancy is configured for high availability.')
resource searchZoneRedundantAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, searchZoneRedundantPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${searchZoneRedundantPolicy.properties.displayName}'
    description: searchZoneRedundantPolicy.properties.description
    policyDefinitionId: searchZoneRedundantPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Azure AI Search services and ensure local authentication methods are disabled for improved security.')
resource searchDisableLocalAuthAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, searchDisableLocalAuthPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${searchDisableLocalAuthPolicy.properties.displayName}'
    description: searchDisableLocalAuthPolicy.properties.description
    policyDefinitionId: searchDisableLocalAuthPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Storage accounts and ensure public network access is disabled for enhanced security.')
resource storageDisablePublicNetworkAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, storageDisablePublicNetworkPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${storageDisablePublicNetworkPolicy.properties.displayName}'
    description: storageDisablePublicNetworkPolicy.properties.description
    policyDefinitionId: storageDisablePublicNetworkPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}

@description('Policy assignment to audit Storage accounts and ensure shared key access is prevented for improved security posture.')
resource storageDisableSharedKeyAssignment 'Microsoft.Authorization/policyAssignments@2025-01-01' = {
  name: guid(resourceGroup().id, storageDisableSharedKeyPolicy.id)
  scope: resourceGroup()
  properties: {
    displayName: '${baseName} - ${storageDisableSharedKeyPolicy.properties.displayName}'
    description: storageDisableSharedKeyPolicy.properties.description
    policyDefinitionId: storageDisableSharedKeyPolicy.id
    enforcementMode: 'Default'
    parameters: {
      effect: {
        value: 'Audit'
      }
    }
  }
}
