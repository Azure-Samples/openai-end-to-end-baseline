@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('Optional. When true will deploy a cost-optimised environment for development purposes. Note that when this param is true, the deployment is not suitable or recommended for Production environments. Default = false.')
param developmentEnvironment bool = false

@description('Domain name to use for App Gateway')
param customDomainName string = 'contoso.com'

@description('The certificate data for app gateway TLS termination. The value is base64 encoded')
@secure()
param appGatewayListenerCertificate string

@description('The name of the web deploy file. The file should reside in a deploy container in the storage account. Defaults to chatui.zip')
param publishFileName string = 'chatui.zip'

@description('Specifies the password of the administrator account on the Windows jump box.\n\nComplexity requirements: 3 out of 4 conditions below need to be fulfilled:\n- Has lower characters\n- Has upper characters\n- Has a digit\n- Has a special character\n\nDisallowed values: "abc@123", "P@$$w0rd", "P@ssw0rd", "P@ssword123", "Pa$$word", "pass@word1", "Password!", "Password1", "Password22", "iloveyou!"')
@secure()
@minLength(8)
@maxLength(123)
param jumpBoxAdminPassword string

// ---- Existing Private DNS Zones Configuration ----
@description('The ID of the existing DNS zone for the Azure Container Registry. If not provided, a new private DNS zone will be created.')
param acrExistingDnsZoneId string = ''
param kvExistingDnsZoneId string = ''
param openAiExistingDnsZoneId string =''
param existingPrivateDnsZoneBlob string = ''
param existingPrivateDnsZoneFile string = ''
param paramDnsServers array = []
param existingApiAzureMlDnsZone string = ''
param existingNotebookDnsZone string= ''
param paramFirewallNVAIpAddress string =''
param existingPrivateZoneAppService string =''
param deployJumpbox bool =false
// ---- Parameters required to set to make it non availability zone compliant ----
param paramStorageSKU string = 'Standard_ZRS'
param paramAcrSku string = 'Premium'
param availabilityZones array = [ '1', '2', '3' ]
param paramZoneRedundancy string = 'Disabled'

// ---- Log Analytics workspace ----
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${baseName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Deploy vnet with subnets and NSGs
module networkModule 'network.bicep' = {
  name: 'networkDeploy'
  params: {
    location: location
    baseName: baseName
    developmentEnvironment: developmentEnvironment
    dnsServers: paramDnsServers
    paramFirewallNVAIpAddress: paramFirewallNVAIpAddress
  }
}

@description('Deploys Azure Bastion and the jump box, which is used for private access to the Azure ML and Azure OpenAI portals.')
module jumpBoxModule 'jumpbox.bicep' = {
  name: 'jumpBoxDeploy'
  params: {
    location: location
    baseName: baseName
    virtualNetworkName: networkModule.outputs.vnetNName
    logWorkspaceName: logWorkspace.name
    jumpBoxAdminName: 'vmadmin'
    jumpBoxAdminPassword: jumpBoxAdminPassword
    deployJumpbox: deployJumpbox
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
    paramStorageSKU: paramStorageSKU
    existingPrivateDnsZoneBlob:existingPrivateDnsZoneBlob
    existingPrivateDnsZoneFiles:existingPrivateDnsZoneFile
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
    existingPrivateDNSZONE: kvExistingDnsZoneId
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
    existingDnsZoneId: acrExistingDnsZoneId
    paramAcrSku: paramAcrSku
    zoneRedundancy: paramZoneRedundancy
  }
}

// Deploy application insights and log analytics workspace
module appInsightsModule 'applicationinsignts.bicep' = {
  name: 'appInsightsDeploy'
  params: {
    location: location
    baseName: baseName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure OpenAI service with private endpoint and private DNS zone
module openaiModule 'openai.bicep' = {
  name: 'openaiDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: networkModule.outputs.vnetNName
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
    keyVaultName: keyVaultModule.outputs.keyVaultName
    createPrivateEndpoints:true
    existingPrivateDnsZone:openAiExistingDnsZoneId
  }
}

// Deploy the gpt 3.5 model within the Azure OpenAI service deployed above.
module openaiModels 'openai-models.bicep' = {
  name: 'openaiModelsDeploy'
  params: {
    openaiName: openaiModule.outputs.openAiResourceName
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
    openAiResourceName: openaiModule.outputs.openAiResourceName
    existingApiAzureMlDnsZone:existingApiAzureMlDnsZone
    existingNotebookDnsZone:existingNotebookDnsZone
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
    existingPrivateZoneAppService: existingPrivateZoneAppService
    privateEndpointsSubnetName: networkModule.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
  
  }
  dependsOn: [
    openaiModule
    acrModule
  ]
}
