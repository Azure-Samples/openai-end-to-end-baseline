/*
  Deploy a web app with a managed identity, diagnostic, and a private endpoint
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@minLength(1)
param publishFileName string

// existing resource name params

@description('The resource ID of the existing managed online endpoint. Used to retrieve the scoring URI.')
@minLength(40)
param managedOnlineEndpointResourceId string

@description('The name of the existing ACR instance that will be used to contain the web app container image.')
@minLength(6)
param acrName string

@description('The name of the existing Azure OpenAI instance that will be used from the prompt flow code.')
@minLength(6)
param openAIName string

param vnetName string
param appServicesSubnetName string
param privateEndpointsSubnetName string
param storageName string
param keyVaultName string
param logWorkspaceName string

// variables
var appName = 'app-${baseName}'
var appServicePrivateEndpointName = 'pep-${appName}'
var appServicePfPrivateEndpointName = 'pep-${appName}-pf'

// TODO (P5): Use secret resource reference to get URI to build this
var chatApiKey = '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/chatApiKey)'

// var openAIApiKey = '@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/openai-key)' TODO (P4): Why was this set?

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName

  resource appServicesSubnet 'subnets' existing = {
    name: appServicesSubnetName
  }
  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource azureOpenAI 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' existing ={
  name: openAIName
}

resource chatProj 'Microsoft.MachineLearningServices/workspaces@2024-04-01' existing = {
  name: split(managedOnlineEndpointResourceId, '/')[8]
  
  resource onlineEndpoint 'onlineEndpoints' existing = {
    name: split(managedOnlineEndpointResourceId, '/')[10]
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageName
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

// Built-in Azure RBAC role that is applied to a Key Vault to grant secrets content read permissions. 
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
  scope: subscription()
}

// Built-in Azure RBAC role that is applied to a Key storage to grant data reader permissions. 
resource blobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}

@description('Built-in Role: [AcrPull](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpull)')
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

// ---- Web App resources ----

// Managed Identity for App Service
resource appServiceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${appName}'
  location: location
}

// Grant the App Service managed identity key vault secrets role permissions
module appServiceSecretsUserRoleAssignmentModule './modules/keyvaultRoleAssignment.bicep' = {
  name: 'appServiceSecretsUserRoleAssignmentDeploy'
  params: {
    roleDefinitionId: keyVaultSecretsUserRole.id
    principalId: appServiceManagedIdentity.properties.principalId
    keyVaultName: keyVaultName
  }
}

// Grant the App Service managed identity storage data reader role permissions
resource blobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storage
  name: guid(resourceGroup().id, appServiceManagedIdentity.name, blobDataReaderRole.id)
  properties: {
    roleDefinitionId: blobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: appServiceManagedIdentity.properties.principalId
  }
}

//App service plan
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${appName}${uniqueString(subscription().subscriptionId)}'
  location: location
  kind: 'linux'
  sku: {
    name: 'P1v3'
    tier: 'PremiumV3'
    capacity: 3
  }
  properties: {
    zoneRedundant: false // TODO (P2 - Set back at end): My subscription doesn't have enough quota to set this to 'true', but before we ship this must go back to true.
    reserved: true
  }
}

@description('This is the web app that contains the UI application.')
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
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
    virtualNetworkSubnetId: vnet::appServicesSubnet.id
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    siteConfig: {
      vnetRouteAllEnabled: true
      http20Enabled: true
      publicNetworkAccess: 'Disabled'
      alwaysOn: true
      linuxFxVersion: 'DOTNETCORE|7.0'
      netFrameworkVersion: null
      windowsFxVersion: null
    }
  }
  dependsOn: [
    appServiceSecretsUserRoleAssignmentModule
    blobDataReaderRoleAssignment
  ]

  resource appsettings 'config' = {
    name: 'appsettings'
    properties: {
      WEBSITE_RUN_FROM_PACKAGE: '${storage.properties.primaryEndpoints.blob}/deploy/${publishFileName}'
      WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID: appServiceManagedIdentity.id
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'
      chatApiKey: chatApiKey
      chatApiEndpoint: chatProj::onlineEndpoint.properties.scoringUri
      chatInputName: 'question'
      chatOutputName: 'answer'
    }
  }
}


//Web App diagnostic settings
resource webAppDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webApp.name}-diagnosticSettings'
  scope: webApp
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appServicePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: appServicePrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: appServicePrivateEndpointName
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
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.azurewebsites.net'
          properties: {
            privateDnsZoneId: appServiceDnsZone.id
          }
        }
      ]
    }
  }
}

resource appServiceDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  properties: {}

  resource appServiceDnsZoneLink 'virtualNetworkLinks' = {
    name: '${appServiceDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
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

// create application insights resource
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appinsights-${appName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
    RetentionInDays: 90
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

/*Promptflow app service*/
// Web App
resource webAppPf 'Microsoft.Web/sites@2022-09-01' = {
  name: '${appName}-pf'
  location: location
  kind: 'linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appServiceManagedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: vnet::appServicesSubnet.id
    httpsOnly: false
    keyVaultReferenceIdentity: appServiceManagedIdentity.id
    hostNamesDisabled: false
    vnetImagePullEnabled: true
    siteConfig: {
      linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
      vnetRouteAllEnabled: true
      http20Enabled: true
      publicNetworkAccess: 'Disabled'
      alwaysOn: true
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: appServiceManagedIdentity.properties.clientId
    }
  }
  dependsOn: [
    appServiceSecretsUserRoleAssignmentModule
    blobDataReaderRoleAssignment
    containerRegistryPullRole
  ]

  resource appsettingsPf 'config' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.InstrumentationKey
      APPLICATIONINSIGHTS_CONNECTION_STRING: appInsights.properties.ConnectionString
      ApplicationInsightsAgent_EXTENSION_VERSION: '~2'    
      WEBSITES_CONTAINER_START_TIME_LIMIT: '1800'
      OPENAICONNECTION_API_BASE: azureOpenAI.properties.endpoint
      // OPENAICONNECTION_API_KEY: openAIApiKey  TODO (P4): Why was this set?
      WEBSITES_PORT: '8080'
    }
  }
}

//Web App diagnostic settings
resource webAppPfDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webAppPf.name}-diagnosticSettings'
  scope: webAppPf
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        categoryGroup: null
        enabled: true
      }
      {
        category: 'AppServicePlatformLogs'
        categoryGroup: null
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource appServicePrivateEndpointPf 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: appServicePfPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: appServicePfPrivateEndpointName
        properties: {
          privateLinkServiceId: webAppPf.id
          groupIds: [
            'sites'
          ]
        }
      }
    ]
  }

  resource appServicePfDnsZoneGroup 'privateDnsZoneGroups' = {
    name: 'default'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.azurewebsites.net'
          properties: {
            privateDnsZoneId: appServiceDnsZone.id
          }
        }
      ]
    }
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, appServiceManagedIdentity.id, containerRegistryPullRole.id)
  scope: containerRegistry
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: appServiceManagedIdentity.properties.principalId
  }
}

@description('The name of the app service plan.')
output appServicePlanName string = appServicePlan.name

@description('The name of the web app.')
output appName string = webApp.name
