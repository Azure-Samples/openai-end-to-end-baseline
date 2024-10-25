/*
  Deploy Azure Container Registry with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The name of the virtual network that this ACR instance will have a private endpoint in.')
param vnetName string

@description('The name of the subnet for the private endpoint. Must in in the provided virtual network.')
param privateEndpointsSubnetName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

// Variables
var acrName = 'cr${baseName}'
var acrPrivateEndpointName = 'pep-${acrName}'
var acrDnsZoneName = 'privatelink${environment().suffixes.acrLoginServer}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing =  {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }  
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

@description('The container registry used by Azure AI Studio to store prompt flow images.')
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: false
    dataEndpointEnabled: false
    networkRuleBypassOptions: 'None'
    networkRuleSet: {
      defaultAction: 'Deny'
      ipRules: []
    }
    publicNetworkAccess: 'Disabled'
    zoneRedundancy: 'Enabled'
  }

  // TODO (P2 - Jon): Add a build agent node connected to the virtual network, the image building subnet.
  // Then pushes will happen from within the network when following the instructions in the README.
  // TODO (P2 - Jon): I believe the user is going to need AcrPush in order to put the new image into ACR.

  //resource x 'agentPools@2019-06-01-preview' = {
  //  name: 'sdf'
  //  properties: {
  //    os: 'Linux'
  //    count: 1
  //    virtualNetworkSubnetResourceId: // TODO
  //  }


  //}
}

@description('Diagnostic settings for the Azure Container Registry instance.')
resource acrResourceDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${acrResource.name}-diagnosticSettings'
  scope: acrResource
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

resource acrPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
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

  resource acrDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
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
  }
}

resource acrDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: acrDnsZoneName
  location: 'global'
  properties: {}

  resource acrDnsZoneLink 'virtualNetworkLinks' = {
    name: '${acrDnsZoneName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      resolutionPolicy: 'Default'
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output acrName string = acrResource.name
