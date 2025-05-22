targetScope = 'resourceGroup'

@description('The region in which this architecture is deployed. Should match the region of the resource group.')
@minLength(1)
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The name of the workload\'s existing Log Analytics workspace.')
@minLength(4)
param logAnalyticsWorkspaceName string

@description('The resource ID for the subnet that private endpoints in the workload should surface in.')
@minLength(1)
param privateEndpointSubnetResourceId string

@description('Assign your user some roles to support access to the Azure AI Agent dependencies for troubleshooting post deployment')
@maxLength(36)
@minLength(36)
param debugUserPrincipalId string

// ---- Existing resources ----

resource aiSearchLinkedPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.search.windows.net'
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource azureAISearchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: subscription()
}

// ---- New resources ----

resource azureAiSearchService 'Microsoft.Search/searchServices@2025-02-01-preview' = {
  name: 'ais-ai-agent-vector-store-${baseName}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'standard'
  }
  properties: {
    disableLocalAuth: true
    authOptions: null
    hostingMode: 'default'
    partitionCount: 1
    replicaCount: 1
    semanticSearch: 'disabled'
    publicNetworkAccess: 'disabled'
    networkRuleSet: {
      bypass: 'None'
      ipRules: []
    }
  }
}

// Role assignments

resource debugUserAISearchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(debugUserPrincipalId, azureAISearchIndexDataContributorRole.id, azureAiSearchService.id)
  scope: azureAiSearchService
  properties: {
    roleDefinitionId: azureAISearchIndexDataContributorRole.id
    principalId: debugUserPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Azure diagnostics

resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: azureAiSearchService
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Private endpoints

resource aiSearchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-ai-agent-search'
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnetResourceId
    }
    privateLinkServiceConnections: [
      {
        name: 'ai-agent-search'
        properties: {
          privateLinkServiceId: azureAiSearchService.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
  }

  resource dnsGroup 'privateDnsZoneGroups' = {
    name: 'ai-agent-search'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'ai-agent-search'
          properties: {
            privateDnsZoneId: aiSearchLinkedPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

// ---- Outputs ----

output aiSearchName string = azureAiSearchService.name
