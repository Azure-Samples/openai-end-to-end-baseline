/*
  Deploy storage account with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-12 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string

// variables
var storageSkuName = 'Standard_LRS'
var blobStorageDnsZoneName = 'privatelink.blob.${environment().suffixes.storage}'


var appDeployStorageName = 'st${baseName}'
var appDeployStoragePrivateEndpointName = 'pep-${appDeployStorageName}'
var appDeployStorageDnsGroupName = '${appDeployStoragePrivateEndpointName}/default'


var mlStorageName = 'stml${baseName}'
var mlStoragePrivateEndpointName = 'pep-${mlStorageName}'
var mlStorageDnsGroupName = '${mlStoragePrivateEndpointName}/default'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

// ---- Storage resources ----
resource appDeployStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: appDeployStorageName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
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

resource mlStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: mlStorageName
  location: location
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    encryption: {
      keySource: 'Microsoft.Storage'
      requireInfrastructureEncryption: false
      services: {
        blob: {
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
  name: appDeployStorageDnsGroupName
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
  dependsOn: [
    appDeployStoragePrivateEndpoint
  ]
}

resource mlStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: mlStorageDnsGroupName
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
  dependsOn: [
    mlStoragePrivateEndpoint
  ]
}

@description('The name of the appDeploy storage account.')
output appDeployStorageName string = appDeployStorage.name

@description('The name of the ML storage account.')
output mlDeployStorageName string = mlStorage.name
