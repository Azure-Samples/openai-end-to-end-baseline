/*
  Deploy storage account with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-12 chars)')
@minLength(6)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string
param logWorkspaceName string

// variables
var blobStorageDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'

var appDeployStorageName = 'st${baseName}'
var appDeployStoragePrivateEndpointName = 'pep-${appDeployStorageName}'

var mlStorageName = 'stml${baseName}'
var mlStoragePrivateEndpointName = 'pep-${mlStorageName}'

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

// ---- Storage resources ----
resource appDeployStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: appDeployStorageName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    allowCrossTenantReplication: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
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
    supportsHttpsTrafficOnly: true
  }
  resource blobService 'blobServices' = {
    name: 'default'

    // Storage container in which the Chat UI App's "Run from Zip" will be sourced
    resource deployContainer 'containers' = {
      name: 'deploy'
      properties: {
        publicAccess: 'None'
        denyEncryptionScopeOverride: false
      }
    }
  }
}

// Enable App Service deployment Storage Account blob diagnostic settings
resource appDeployStorageDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appDeployStorage.name}-diagnosticSettings'
  scope: appDeployStorage::blobService
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
    logAnalyticsDestinationType: null
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

resource mlStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: mlStorageName
  location: location
  sku: {
    name: 'Standard_ZRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    allowCrossTenantReplication: false
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
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
  name: '${mlStorage.name}-blobdiagnosticSettings'
  scope: mlStorage::Blob
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
    logAnalyticsDestinationType: null
  }
}

// Enable Machine Learning Storage Account file diagnostic settings
resource mlStorageFileDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${mlStorage.name}-filediagnosticSettings'
  scope: mlStorage::File
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
    logAnalyticsDestinationType: null
  }
}

resource mlStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: mlStoragePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: mlStoragePrivateEndpointName
        properties: {
          groupIds: [
            'blob'
          ]
          privateLinkServiceId: mlStorage.id
        }
      }
    ]
  }
}

resource storageDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: blobStorageDnsZoneName
  location: 'global'
  properties: {}
}

resource storageDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: storageDnsZone
  name: '${blobStorageDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource appDeployStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: 'default'
  parent: appDeployStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobStorageDnsZoneName
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

resource mlStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: 'default'
  parent: mlStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: blobStorageDnsZoneName
        properties: {
          privateDnsZoneId: storageDnsZone.id
        }
      }
    ]
  }
}

@description('The name of the appDeploy storage account.')
output appDeployStorageName string = appDeployStorage.name

@description('The name of the ML storage account.')
output mlDeployStorageName string = mlStorage.name
