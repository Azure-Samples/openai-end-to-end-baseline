/*
  Deploy machine learning workspace, private endpoints and compute resources
*/

@description('This is the base name for each Azure resource name (6-12 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string
param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param mlStorageAccountName string
param logWorkspaceName string

//variables
var workspaceName = 'mlw-${baseName}'
var workspacePrivateEndpointName = 'pep-${workspaceName}'
//var workspaceDnsGroupName = '${workspacePrivateEndpointName}/default'
var workspaceManagedIdentityName = 'id-${workspaceName}'
var notebookDnsZoneName = 'privatelink.notebooks.azure.net'
var workspaceDnsZoneName = 'privatelink.api.azureml.ms'

var clusterName = 'computeCluster1'
var computeClusterName = '${workspaceName}/${clusterName}'
var computeClusterHasPublicIP = true
var computeClusterVMSize = 'STANDARD_DS3_V2'

var instanceName = '${baseName}Instance'
var instanceVMSize = 'Standard_DS11_v2'

var computeInstanceName = '${workspaceName}/${instanceName}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
}

resource mlStorage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: mlStorageAccountName
}

// ---- User-assigned Managed Identity ----
// Managed Identity for App Service
resource workspaceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: workspaceManagedIdentityName
  location: location
}

// ---- RBAC built-in role definitions and role assignments ----
// Built-in Azure RBAC role that is applied to a Storage Account to grant blob contributor permissions. 
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

resource storageAccountContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Storage Account to grant table contributor permissions. 
resource storageTableDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to an Azure ML Workspace to grant Data Scientist permissions. 
resource azureMlDataScientistRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  scope: subscription()
}

resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

resource keyVaultContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f25e0fa2-a7c8-4377-a976-54943a77a395'
  scope: subscription()
}

resource keyVaultAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  scope: subscription()
}

// Grant the Azure ML Workspace managed identity storage blob data contributor role permissions
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// Grant the Azure ML Workspace managed identity storage account contributor role permissions
resource storageAccountContributorRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageAccountContributorRole.id)
  properties: {
    roleDefinitionId: storageAccountContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// Grant the Azure ML Workspace managed identity storage table data contributor role permissions
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageTableDataContributorRole.id)
  properties: {
    roleDefinitionId: storageTableDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// Grant the Azure ML Workspace managed identity acr pull role permissions
resource containerRegistryPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, containerRegistryPullRole.id)
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// Grant the Azure ML Workspace managed identity acr pull role permissions
resource azureMlDataScientistRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: machineLearning
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, azureMlDataScientistRole.id)
  properties: {
    roleDefinitionId: azureMlDataScientistRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// Grant the Azure ML Workspace managed identity key vault secrets role permissions
module workspaceKeyVaultContributorRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'workspaceKeyVaultContributorRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultContributorRole.id
    principalId: workspaceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

// Grant the Azure ML Workspace managed identity key vault key vault administrator role permissions
module workspaceKeyVaultAdministratorRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'workspaceKeyVaultAdministratorRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultAdministratorRole.id
    principalId: workspaceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

// Grant the Azure ML Workspace managed identity contributor role on the RG
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2022-03-01' existing = {
  name: 'oai-${baseName}'
}

// ---- Machine Learning Workspace assets ----

resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${workspaceManagedIdentity.id}': {}
    }
  }
  properties: {
    // workspace organization
    friendlyName: workspaceName
    description: workspaceName

    primaryUserAssignedIdentity: workspaceManagedIdentity.id

    // dependent resources
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    keyVault: keyVault.id
    storageAccount: mlStorage.id

    // configuration for workspaces with private link endpoint
    imageBuildCompute: clusterName
    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false

    allowPublicAccessWhenBehindVnet: false

    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
      outboundRules: {
        /* openai: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: resourceId('Microsoft.CognitiveServices/accounts', 'oai-${baseName}')
            subresourceTarget: 'registry'
            sparkEnabled: false
            sparkStatus: 'Inactive'
          }
          status: 'Active'
          category: 'Required'
        }*/
      }
    }
  }
  dependsOn: [
    openAiAccount
    workspaceKeyVaultAdministratorRoleAssignmentModule
    workspaceKeyVaultContributorRoleAssignmentModule
  ]

  resource onlineEndpoint 'onlineEndpoints' = {
    name: 'ept-${baseName}'
    location: location
    kind: 'Managed'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${workspaceManagedIdentity.id}': {}
      }
    }
    properties: {
      authMode: 'Key'
      description: 'Managed online endpoint for the /score API, to be used by the Chat UI app.'
      publicNetworkAccess: 'Enabled'
    }
  }
}

// Enable Machine Learning diagnostic settings
resource machineLearningDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${machineLearning.name}-diagnosticSettings'
  scope: machineLearning
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    logAnalyticsDestinationType: null
  }
}

// Enable Managed Online Endpoint diagnostics
resource endpointDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: machineLearning::onlineEndpoint
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Store the Managed Online Endpoint key in KeyVault to be referenced from the Chat UI app.
resource managedEndpointPrimaryKeyEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'chatApiKey'
  properties: {
    value: machineLearning::onlineEndpoint.listKeys().primaryKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: workspacePrivateEndpointName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: workspacePrivateEndpointName
        properties: {
          groupIds: [
            'amlworkspace'
          ]
          privateLinkServiceId: machineLearning.id
        }
      }
    ]
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
  }
}

resource amlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: workspaceDnsZoneName
  location: 'global'
}

resource amlPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: amlPrivateDnsZone
  name: '${amlPrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// Notebook
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: notebookDnsZoneName
  location: 'global'
}

resource notebookPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: notebookPrivateDnsZone
  name: '${notebookPrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: machineLearningPrivateEndpoint
  name: 'amlworkspace-PrivateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink.api.azureml.ms'
        properties: {
          privateDnsZoneId: amlPrivateDnsZone.id
        }
      }
      {
        name: 'privatelink.notebooks.azure.net'
        properties: {
          privateDnsZoneId: notebookPrivateDnsZone.id
        }
      }
    ]
  }
}

module machineLearningCompute 'machinelearningcompute.bicep' = {
  name: 'machineLearningComputes'
  scope: resourceGroup()
  params: {
    location: location
    computeClusterName: computeClusterName
    computeClusterVMSize: computeClusterVMSize
    computeClusterHasPublicIp: computeClusterHasPublicIP
    computeInstanceName: computeInstanceName
    computeInstanceVMSize: instanceVMSize
    managedIdentityId: workspaceManagedIdentity.id
  }
  dependsOn: [
    machineLearning
    machineLearningPrivateEndpoint
  ]
}

output machineLearningId string = machineLearning.id
