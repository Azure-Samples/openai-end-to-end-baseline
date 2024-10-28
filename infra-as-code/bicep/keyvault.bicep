/*
  Deploy key vault with private endpoint and private DNS zone
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('The certificate data for app gateway TLS termination. The value is base64 encoded')
@secure()
param appGatewayListenerCertificate string

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

//variables
var keyVaultName = 'kv-${baseName}'
var keyVaultPrivateEndpointName = 'pep-${keyVaultName}'
var keyVaultDnsGroupName = '${keyVaultPrivateEndpointName}/default'
var keyVaultDnsZoneName = 'privatelink.vaultcore.azure.net' //Cannot use 'privatelink${environment().suffixes.keyvaultDns}', per https://github.com/Azure/bicep/issues/9708

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

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices' // Required for AppGW communication
    }
    publicNetworkAccess: 'Disabled'

    tenantId: subscription().tenantId

    enableRbacAuthorization: true       // Using RBAC
    enabledForDeployment: true          // VMs can retrieve certificates
    enabledForTemplateDeployment: true  // ARM can retrieve values
    enabledForDiskEncryption: false

    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    createMode: 'default'               // Creating or updating the key vault (not recovering)
  }

  resource kvsGatewayPublicCert 'secrets' = {
    name: 'gateway-public-cert'
    properties: {
      value: appGatewayListenerCertificate
      contentType: 'application/x-pkcs12'
    }
  }
}

//Key Vault diagnostic settings
resource keyVaultDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${keyVault.name}-diagnosticSettings'
  scope: keyVault
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

resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: keyVaultPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: keyVaultPrivateEndpointName
        properties: {
          groupIds: [
            'vault'
          ]
          privateLinkServiceId: keyVault.id
        }
      }
    ]
  }
}

resource keyVaultDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: keyVaultDnsZoneName
  location: 'global'
  properties: {}

  resource keyVaultDnsZoneLink 'virtualNetworkLinks' = {
    name: '${keyVaultDnsZoneName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: keyVaultDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: keyVaultDnsZoneName
        properties: {
          privateDnsZoneId: keyVaultDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    keyVaultPrivateEndpoint
  ]
}

@description('The name of the key vault.')
output keyVaultName string = keyVault.name

@description('Name of the secret holding the cert.')
output gatewayCertSecretKey string = keyVault::kvsGatewayPublicCert.name
