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
param openAiResourceName string

// ---- Variables ----
var workspaceName = 'mlw-${baseName}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' existing = {
  name: containerRegistryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource mlStorage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: mlStorageAccountName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiResourceName
}

// ---- RBAC built-in role definitions and role assignments ----
@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

@description('Built-in Role: [Storage Account Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor)')
resource storageAccountContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  scope: subscription()
}

@description('Built-in Role: [Storage Table Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-table-data-contributor)')
resource storageTableDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  scope: subscription()
}

@description('Built-in Role: [Storage File Data Privileged Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor)')
resource storageFileDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  scope: subscription()
}

@description('Built-in Role: [AzureML Data Scientist](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azureml-data-scientist)')
resource azureMlDataScientistRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f6c7c914-8db3-469d-8ca1-694a8f32e121'
  scope: subscription()
}

@description('Built-in Role: [AcrPull](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpull)')
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

@description('Built-in Role: [Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor)')
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

@description('Built-in Role: [Key Vault Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-contributor)')
resource keyVaultContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f25e0fa2-a7c8-4377-a976-54943a77a395'
  scope: subscription()
}

@description('Built-in Role: [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)')
resource keyVaultAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  scope: subscription()
}

// ---- New Resources ----

@description('User managed identity to be used across the Azure Machine Learning workspace and its components.')
resource workspaceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${workspaceName}'
  location: location
}

@description('Assign AML Workspace\'s ID: Storage Blob Data Contributor to workload\'s storage account.')
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: Storage Account Contributor to workload\'s storage account.')
resource storageAccountContributorRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageAccountContributorRole.id)
  properties: {
    roleDefinitionId: storageAccountContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: Storage File Data Privileged Contributor to workload\'s storage account.')
resource storageFileDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageFileDataContributor.id)
  properties: {
    roleDefinitionId: storageFileDataContributor.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: Storage Table Data Contributor to workload\'s storage account.')
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, storageTableDataContributorRole.id)
  properties: {
    roleDefinitionId: storageTableDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: AcrPull to workload\'s container registry.')
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
@description('Assign AML Workspace\'s ID: AzureML Data Scientist to itself.')
resource azureMlDataScientistRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: machineLearning
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, azureMlDataScientistRole.id)
  properties: {
    roleDefinitionId: azureMlDataScientistRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: Key Vault Contributor to Key Vault.')
module workspaceKeyVaultContributorRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'workspaceKeyVaultContributorRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultContributorRole.id
    principalId: workspaceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

@description('Assign AML Workspace\'s ID: Key Vault Administrator to Key Vault.')
module workspaceKeyVaultAdministratorRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'workspaceKeyVaultAdministratorRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultAdministratorRole.id
    principalId: workspaceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

@description('Assign AML Workspace\'s ID: Contributor to this whole resource group.')
resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, workspaceManagedIdentity.name, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: workspaceManagedIdentity.properties.principalId
  }
}

// ---- Machine Learning Workspace assets ----

@description('The Azure Machine Learning Workspace.')
resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${workspaceManagedIdentity.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: workspaceName
    description: 'Azure Machine Learning workspace for this solution. Using platform-managed virtual network. Outbound access fully restricted.'
    hbiWorkspace: false
    primaryUserAssignedIdentity: workspaceManagedIdentity.id

    // dependent resources
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    keyVault: keyVault.id
    storageAccount: mlStorage.id

    // configuration for workspaces with private link endpoint
    imageBuildCompute: null
    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false

    allowPublicAccessWhenBehindVnet: false

    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
      outboundRules: {
        wikipedia: {
          type: 'FQDN'
          destination: 'en.wikipedia.org'
          category: 'UserDefined'
          status: 'Active'
        }
        OpenAI: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: openAiAccount.id
            subresourceTarget: 'account'
            sparkEnabled: false
            sparkStatus: 'Inactive'
          }
        }
      }
    }
  }
  dependsOn: [
    workspaceKeyVaultAdministratorRoleAssignmentModule
    workspaceKeyVaultContributorRoleAssignmentModule
    containerRegistryPullRoleAssignment
    contributorRoleAssignment
    storageAccountContributorRoleRoleAssignment
    storageBlobDataContributorRoleAssignment
    storageTableDataContributorRoleAssignment
    storageFileDataContributorRoleAssignment
  ]

  @description('Online endpoint for the /score API.')
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

  @description('Azure Machine Learning Compute Instance - Ideal for development and testing from the Azure Machine Learning Studio.')
  resource instanceCompute 'computes' = {
    name: 'amli-${baseName}'
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${workspaceManagedIdentity.id}': {}
      }
    }
    properties: {
      computeType: 'ComputeInstance'
      computeLocation: location
      description: 'Machine Learning compute instance'
      disableLocalAuth: true
      properties: {
        customServices: null
        enableNodePublicIp: false
        personalComputeInstanceSettings: null
        schedules: {
          computeStartStop: []
        }
        setupScripts: null
        applicationSharingPolicy: 'Personal'
        computeInstanceAuthorizationType: 'personal'
        sshSettings: {
          sshPublicAccess: 'Disabled'
        }
        vmSize: 'STANDARD_DS3_V2'
      }
    }
  }
}

@description('Azure Diagnostics: Machine Learning Workspace - audit')
resource machineLearningDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
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

@description('Azure Diagnostics: Online Endpoint - allLogs')
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

@description('Key Vault Secret: The Managed Online Endpoint key to be referenced from the Chat UI app.')
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

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pep-${workspaceName}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pep-${workspaceName}'
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

  resource privateEndpointDns 'privateDnsZoneGroups' = {
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
}

resource amlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.api.azureml.ms'
  location: 'global'

  resource amlPrivateDnsZoneVnetLink 'virtualNetworkLinks' = {
    name: '${amlPrivateDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

// Notebook
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.notebooks.azure.net'
  location: 'global'

  resource notebookPrivateDnsZoneVnetLink 'virtualNetworkLinks' = {
    name: '${notebookPrivateDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output machineLearningId string = machineLearning.id
