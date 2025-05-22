targetScope = 'resourceGroup'

/*
  Deploy a web app with a managed identity, diagnostic, and a private endpoint
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The region in which this architecture is deployed. Should match the region of the resource group.')
@minLength(1)
param location string = resourceGroup().location

@minLength(1)
param publishFileName string

@description('The name of the existing virtual network that this Web App instance will be deployed into for egress and a private endpoint for ingress.')
@minLength(1)
param virtualNetworkName string

param appServicesSubnetName string

@description('The name for the subnet that private endpoints in the workload should surface in.')
@minLength(1)
param privateEndpointsSubnetName string

param storageName string

@description('The name of the workload\'s existing Log Analytics workspace.')
@minLength(4)
param logAnalyticsWorkspaceName string

// variables
var appName = 'app-${baseName}'

// ---- Existing resources ----

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: 'appi-${baseName}'
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName

  resource appServicesSubnet 'subnets' existing = {
    name: appServicesSubnetName
  }
  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource webAppStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: storageName
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

@description('Built-in Role: [Storage Blob Data Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader)')
resource blobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

@description('Built-in Role: [Cognitive Services OpenAI User](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#cognitive-services-openai-user)')
resource cognitiveServicesOpenAiUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: subscription()
}

resource appServiceExistingPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' existing = {
  name: 'privatelink.azurewebsites.net'
}

// ---- New resources ----

@description('Managed Identity for App Service')
resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: 'id-${appName}'
  location: location
}

@description('Grant the App Service managed identity storage data reader role permissions')
resource blobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: webAppStorageAccount
  name: guid(resourceGroup().id, appServiceManagedIdentity.name, blobDataReaderRole.id)
  properties: {
    roleDefinitionId: blobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: appServiceManagedIdentity.properties.principalId
  }
}

//App service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'asp-${appName}${uniqueString(subscription().subscriptionId)}'
  location: location
  kind: 'linux'
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 3
  }
  properties: {
    zoneRedundant: true
    reserved: true
  }
}

@description('This is the web app that contains the UI application.')
resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  kind: 'app'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: virtualNetwork::appServicesSubnet.id
    httpsOnly: true
    vnetContentShareEnabled: true
    vnetImagePullEnabled: true
    publicNetworkAccess: 'Disabled'
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    vnetRouteAllEnabled: true
    hostNamesDisabled: false
    siteConfig: {
      vnetRouteAllEnabled: true
      http20Enabled: true
      publicNetworkAccess: 'Disabled'
      alwaysOn: true
      linuxFxVersion: 'DOTNETCORE|8.0'
      netFrameworkVersion: null
      windowsFxVersion: null
    }
  }
  dependsOn: [
    blobDataReaderRoleAssignment
  ]

  resource appsettings 'config' = {
    name: 'appsettings'
    properties: {
      WEBSITE_RUN_FROM_PACKAGE: '${webAppStorageAccount.properties.primaryEndpoints.blob}deploy/${publishFileName}'
      WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: appServiceManagedIdentity.id
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
      AZURE_CLIENT_ID: appServiceManagedIdentity.properties.clientId
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
    }
  }
}

@description('Enable App Service Azure Diagnostic')
resource azureDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: webApp
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        enabled: true
      }
    ]
  }
}

resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-front-end-web-app'
  location: location
  properties: {
    subnet: {
      id: virtualNetwork::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: 'front-end-web-app'
        properties: {
          privateLinkServiceId: webApp.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource appServiceDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'front-end-web-app'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'web-app'
          properties: {
            privateDnsZoneId: appServiceExistingPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

// App service plan auto scale settings
resource appServicePlanAutoScaleSettings 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: '${appServicePlan.name}-autoscale'
  location: location
  properties: {
    enabled: true
    targetResourceUri: appServicePlan.id
    profiles: [
      {
        name: 'Scale out condition'
        capacity: {
          maximum: '5'
          default: '3'
          minimum: '3'
        }
        rules: [
          {
            scaleAction: {
              type: 'ChangeCount'
              direction: 'Increase'
              cooldown: 'PT5M'
              value: '1'
            }
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricNamespace: 'microsoft.web/serverfarms'
              operator: 'GreaterThan'
              timeAggregation: 'Average'
              threshold: 70
              metricResourceUri: appServicePlan.id
              timeWindow: 'PT10M'
              timeGrain: 'PT1M'
              statistic: 'Average'
            }
          }
        ]
      }
    ]
  }
  dependsOn: [
    webApp
  ]
}

// ---- Outputs ----

@description('The name of the app service plan.')
output appServicePlanName string = appServicePlan.name

@description('The name of the web app.')
output appName string = webApp.name
