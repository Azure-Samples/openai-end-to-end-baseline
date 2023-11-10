@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-12 chars)')
@minLength(6)
@maxLength(12)
param baseName string

@description('Optional. When true will deploy a cost-optimised environment for development purposes. Note that when this param is true, the deployment is not suitable or recommended for Production environments. Default = false.')
param developmentEnvironment bool = false

@description('Domain name to use for App Gateway')
param customDomainName string = 'contoso.com'

@description('The certificate data for app gateway TLS termination. The value is base64 encoded')
@secure()
param appGatewayListenerCertificate string

@description('The name of the web deploy file. The file should reside in a deploy container in the storage account. Defaults to SimpleWebApp.zip')
param publishFileName string = 'chatui.zip'

// ---- Availability Zones ----
var availabilityZones = [ '1', '2', '3' ]
var logWorkspaceName = 'log-${baseName}'

// ---- Log Analytics workspace ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Deploy vnet with subnets and NSGs
module networkModule 'network.bicep' = {
  name: 'networkDeploy'
  params: {
    location: location
    baseName: baseName
    developmentEnvironment: developmentEnvironment
  }
}

// Deploy storage account with private endpoint and private DNS zone
module storageModule 'storage.bicep' = {
  name: 'storageDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
    // createPrivateEndpoints: true
  }
}

// Deploy key vault with private endpoint and private DNS zone
module keyVaultModule 'keyvault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    createPrivateEndpoints: true
    appGatewayListenerCertificate: appGatewayListenerCertificate
    apiKey: 'key'
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy container registry with private endpoint and private DNS zone
module acrModule 'acr.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    createPrivateEndpoints: true
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy application insights and log analytics workspace
module appInsightsModule 'applicationinsignts.bicep' = {
  name: 'appInsightsDeploy'
  params: {
    location: location
    baseName: baseName
  }
}

// Deploy machine learning workspace with private endpoint and private DNS zone
module mlwModule 'machinelearning.bicep' = {
  name: 'mlwDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    applicationInsightsName: appInsightsModule.outputs.applicationInsightsName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    mlStorageAccountName: storageModule.outputs.mlDeployStorageName
    containerRegistryName: 'cr${baseName}'
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy azure openai service with private endpoint and private DNS zone
module openaiModule 'openai.bicep' = {
  name: 'openaiDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
    keyVaultName: keyVaultModule.outputs.keyVaultName
  }
}

//Deploy an Azure Application Gateway with WAF v2 and a custom domain name.
module gatewayModule 'gateway.bicep' = {
  name: 'gatewayDeploy'
  params: {
    location: location
    baseName: baseName
    developmentEnvironment: developmentEnvironment
    availabilityZones: availabilityZones
    customDomainName: customDomainName
    appName: webappModule.outputs.appName
    vnetName: networkModule.outputs.vnetNName
    appGatewaySubnetName: networkModule.outputs.appGatewaySubnetName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    gatewayCertSecretUri: keyVaultModule.outputs.gatewayCertSecretUri
    logWorkspaceName: logWorkspace.name
   }
}

// Deploy the web apps for the front end demo ui and the containerised promptflow endpoint
module webappModule 'webapp.bicep' = {
  name: 'webappDeploy'
  params: {
    location: location
    baseName: baseName
    developmentEnvironment: developmentEnvironment
    publishFileName: publishFileName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    storageName: storageModule.outputs.appDeployStorageName
    vnetName: networkModule.outputs.vnetNName
    appServicesSubnetName: networkModule.outputs.appServicesSubnetName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
   }
   dependsOn: [
    openaiModule
    acrModule
  ]
}



