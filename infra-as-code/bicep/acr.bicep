/*
  Deploy container registry with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-12 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('Provide a tier of your Azure Container Registry.')
param acrSku string = 'Premium'

@description('Determines whether or not a private endpoint, DNS Zone, Zone Link and Zone Group is created for this resource.')
param createPrivateEndpoints bool = false

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string

//variables
var acrName = 'cr${baseName}'
var acrPrivateEndpointName = 'pep-${acrName}'
var acrDnsGroupName = '${acrPrivateEndpointName}/default'
var acrDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

resource acrResource 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Deny'
    }
    publicNetworkAccess: 'Disabled'
  }
}

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = if (createPrivateEndpoints) {
  name: acrPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: acrPrivateEndpointName
        properties: {
          groupIds: [
            'registry'
          ]
          privateLinkServiceId: acrResource.id
        }
      }
    ]
  }
}

resource acrDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = if (createPrivateEndpoints) {
  name: acrDnsZoneName
  location: 'global'
  properties: {}
}

resource acrDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (createPrivateEndpoints) {
  parent: acrDnsZone
  name: '${acrDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource acrDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = if (createPrivateEndpoints) {
  name: acrDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: acrDnsZoneName
        properties: {
          privateDnsZoneId: acrDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    acrPrivateEndpoint
  ]
}

@description('Output the login server property for later use')
output loginServer string = acrResource.properties.loginServer

