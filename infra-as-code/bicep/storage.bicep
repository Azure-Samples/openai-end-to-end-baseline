/*
  Deploy storage account with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params
param vnetName string
param privateEndpointsSubnetName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

@maxLength(36)
@minLength(36)
param yourPrincipalId string

// variables
var appDeployStorageName = 'st${baseName}'
var appDeployStoragePrivateEndpointName = 'pep-${appDeployStorageName}'

var mlStorageName = 'stml${baseName}'
var mlBlobStoragePrivateEndpointName = 'pep-blob-${mlStorageName}'
var mlFileStoragePrivateEndpointName = 'pep-file-${mlStorageName}'

var agentsThreadStorageName = 'cosmos-ml${baseName}'
var agentsThreadStoragePrivateEndpointName = 'pep-${agentsThreadStorageName}'

var agentsVectorStoreName = 'aisearch-ml${baseName}'
var agentsVectorStorePrivateEndpointName = 'pep-${agentsVectorStoreName}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

@description('Built-in Role: [Storage Blob Data Owner](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner)')
resource storageBlobDataOwner 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  scope: resourceGroup()
}

@description('Built-in Role: [Storage Queue Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-queue-data-contributor)')
resource storageQueueDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  scope: resourceGroup()
}

// ---- Storage resources ----
resource appDeployStorage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: appDeployStorageName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowedCopyScope: 'AAD'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    allowCrossTenantReplication: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false // This app service code host doesn't require double encryption, but if your scenario does, please enable.
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_2'
    isHnsEnabled: false
    isSftpEnabled: false
    defaultToOAuthAuthentication: true
    isLocalUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
  }
  resource blobService 'blobServices' = {
    name: 'default'

    // Storage container in which the Chat UI App's "Run from Zip" will be sourced
    resource deployContainer 'containers' = {
      name: 'deploy'
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

// Enable App Service deployment Storage Account blob diagnostic settings
resource appDeployStorageDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: appDeployStorage::blobService
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
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

@description('Assign your user the ability to manage prompt flow state files from blob storage. This is needed to execute the prompt flow from within in the Azure AI Foundry portal.')
resource blobStorageContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: appDeployStorage::blobService::deployContainer
  name: guid(appDeployStorage::blobService::deployContainer.id, yourPrincipalId, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId // Part of the deployment guide requires you to upload the web app to this storage container. Assigning that data plane permission here.
  }
}

resource appDeployStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: appDeployStoragePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: appDeployStoragePrivateEndpointName
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: appDeployStorage.id
        }
      }
    ]
  }
}

resource mlStorage 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: mlStorageName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    allowedCopyScope: 'AAD'
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    isSftpEnabled: false
    isHnsEnabled: false
    allowCrossTenantReplication: false
    defaultToOAuthAuthentication: true
    isLocalUserEnabled: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false // In this scenario, this account for Azure AI Foundry doesn't require double encryption, but if your scenario does, please enable.
      services: {
        blob: {
          enabled: true
          keyType: 'Account'
        }
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
    supportsHttpsTrafficOnly: true
  }
  resource Blob 'blobServices' existing = {
    name: 'default'
  }
  resource File 'fileServices' existing = {
    name: 'default'
  }
}

// Enable Machine Learning Storage Account blob diagnostic settings
resource mlStorageBlobDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: mlStorage::Blob
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
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

// Enable Machine Learning Storage Account file diagnostic settings
resource mlStorageFileDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: mlStorage::File
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'StorageRead'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageWrite'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'StorageDelete'
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

@description('Azure Machine Learning Blob Storage Private Endpoint')
resource mlBlobStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: mlBlobStoragePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: mlBlobStoragePrivateEndpointName
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: mlStorage.id
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: blobStorageDnsZone.name
          properties: {
            privateDnsZoneId: blobStorageDnsZone.id
          }
        }
      ]
    }
  }
}

@description('Azure Machine Learning File Storage Private Endpoint')
resource mlFileStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: mlFileStoragePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: mlFileStoragePrivateEndpointName
        properties: {
          groupIds: [
            'file'
          ]
          privateLinkServiceId: mlStorage.id
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: fileStorageDnsZone.name
          properties: {
            privateDnsZoneId: fileStorageDnsZone.id
          }
        }
      ]
    }
  }
}

@description('Azure Storage - Blob private DNS zone.')
resource blobStorageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  @description('Link private DNS zone to our workload virtual network')
  resource vnetLink 'virtualNetworkLinks' = {
    name: '${blobStorageDnsZone.name}-to-${vnet.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

@description('Azure Storage - File private DNS zone.')
resource fileStorageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  properties: {}

  @description('Link private DNS zone to our workload virtual network')
  resource vnetLink 'virtualNetworkLinks' = {
    name: '${fileStorageDnsZone.name}-to-${vnet.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource appDeployStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: 'default'
  parent: appDeployStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobStorageDnsZone.name
        properties: {
          privateDnsZoneId: blobStorageDnsZone.id
        }
      }
    ]
  }
}

@description('The thread storage Cosmos DB account. Agent will save chat sessions in there.')
resource agentsCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' = {
  name: agentsThreadStorageName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    publicNetworkAccess: 'Disabled'        // Block public access
    disableLocalAuth: true
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    enableFreeTier: false
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
}

@description('The thread storage Cosmos DB account diagnostic settings.')
resource agentsCosmosDbDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: agentsCosmosDb
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'QueryRuntimeStatistics'
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

@description('Azure Machine Learning Cosmos Db Private Endpoint')
resource agentsCosmosDbPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: agentsThreadStoragePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: agentsThreadStoragePrivateEndpointName
        properties: {
          groupIds: [
            'Sql'
          ]
          privateLinkServiceId: agentsCosmosDb.id
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: cosmosDbDnsZone.name
          properties: {
            privateDnsZoneId: cosmosDbDnsZone.id
          }
        }
      ]
    }
  }
}

@description('Azure Cosmos Db - private DNS zone.')
resource cosmosDbDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
  properties: {}

  @description('Link private DNS zone to our workload virtual network')
  resource vnetLink 'virtualNetworkLinks' = {
    name: '${cosmosDbDnsZone.name}-to-${vnet.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource agentsAiSearch 'Microsoft.Search/searchServices@2025-02-01-preview' = {
  name: agentsVectorStoreName
  location: location
  identity: {
    type: 'SystemAssigned'                               // Use managed identity for authentication
  }
  properties: {
    disableLocalAuth: true                               // Allow Entra ID only. API key auth is not allowed
    authOptions: null
    encryptionWithCmk: {
      enforcement: 'Unspecified'                          // Default encryption mode
    }
    hostingMode: 'default'                                // Standard hosting mode
    partitionCount: 1                                     // Number of search partitions
    publicNetworkAccess: 'Disabled'                       // Force private endpoint access
    replicaCount: 1                                       // Number of search replicas
    semanticSearch: 'disabled'                            // Semantic search capability
  }
  sku: {
    name: 'standard'                                      // Production-grade SKU
  }
}

@description('The vector store Azure AI Search service index diagnostic settings.')
resource agentsAiSearchDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: agentsAiSearch
  properties: {
    workspaceId: logWorkspace.id
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
    logAnalyticsDestinationType: null
  }
}

@description('The vector store Azure AI Search service index Private Endpoint')
resource agentsAiSearchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: agentsVectorStorePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: agentsVectorStorePrivateEndpointName
        properties: {
          groupIds: [
            'searchService'
          ]
          privateLinkServiceId: agentsAiSearch.id
        }
      }
    ]
  }

  resource dnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: aiSearchDnsZone.name
          properties: {
            privateDnsZoneId: aiSearchDnsZone.id
          }
        }
      ]
    }
  }
}

@description('Azure AI Search service - private DNS zone.')
resource aiSearchDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'
  properties: {}

  @description('Link private DNS zone to our workload virtual network')
  resource vnetLink 'virtualNetworkLinks' = {
    name: '${aiSearchDnsZone.name}-to-${vnet.name}'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource storageBlobDataOwnerForAISearchRoleAssignment  'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(agentsAiSearch.id, mlStorage.id, storageBlobDataOwner.id)
  properties: {
    roleDefinitionId: storageBlobDataOwner.id
    principalType: 'ServicePrincipal'
    principalId: agentsAiSearch.identity.principalId
  }
}

resource storageQueueDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: mlStorage
  name: guid(agentsAiSearch.id, mlStorage.id, storageQueueDataContributor.id)
  properties: {
    roleDefinitionId: storageQueueDataContributor.id
    principalType: 'ServicePrincipal'
    principalId: agentsAiSearch.identity.principalId
  }
}

@description('The name of the appDeploy storage account.')
output appDeployStorageName string = appDeployStorage.name

@description('The name of the ML storage account.')
output mlDeployStorageName string = mlStorage.name

@description('The name of the Azure AI Foundry Project agents vector store.')
output agentsVectorStoreName string = agentsAiSearch.name

@description('The name of the Azure AI Foundry Project agents thread storage Cosmos Db.')
output agentsThreadStorageCosmosDbName string = agentsCosmosDb.name
