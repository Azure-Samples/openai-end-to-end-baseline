targetScope = 'resourceGroup'

@description('The location in which all resources should be deployed.')
param location string = resourceGroup().location

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

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

@description('Assign your user some roles to support fluid access when working in the Azure AI Foundry portal')
@maxLength(36)
@minLength(36)
param yourPrincipalId string

@description('Set to true to opt-out of deployment telemetry.')
param telemetryOptOut bool = false

// Customer Usage Attribution Id
var varCuaid = 'a52aa8a8-44a8-46e9-b7a5-189ab3a64409'

/*** NEW RESOURCES ***/

@description('This is the log sink for all Azure Diagnostics in the workload.')
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: 'log-${baseName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    forceCmkForQuery: false
    workspaceCapping: {
      dailyQuotaGb: 10 // Production readiness change: In production, tune this value to ensure operational logs are collected, but a reasonable cap is set.
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Deploy Virtual Network, with subnets, NSGs, and DDoS Protection.')
module deployVirtualNetwork 'network.bicep' = {
  params: {
    location: location
  }
}

@description('Control egress traffic through Azure Firewall restrictions.')
module deployAzureFirewall 'azure-firewall.bicep' = {
  params: {
    location: location
    logWorkspaceName: logWorkspace.name
    virtualNetworkName: deployVirtualNetwork.outputs.virtualNetworkName
    agentsEgressSubnetName: deployVirtualNetwork.outputs.agentsEgressSubnetName
    jumpBoxesSubnetName: deployVirtualNetwork.outputs.jumpBoxesSubnetName
  }
}

@description('Deploys Azure Bastion and the jump box, which is used for private access to Azure AI Foundry and its dependencies.')
module jumpBoxModule 'jumpbox.bicep' = {
  name: 'jumpBoxDeploy'
  params: {
    location: location
    baseName: baseName
    virtualNetworkName: deployVirtualNetwork.outputs.virtualNetworkName
    logWorkspaceName: logWorkspace.name
    jumpBoxAdminName: 'vmadmin'
    jumpBoxAdminPassword: jumpBoxAdminPassword
  }
}

// Deploy Azure Storage account with private endpoint and private DNS zone
module storageModule 'storage.bicep' = {
  name: 'storageDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
    yourPrincipalId: yourPrincipalId
  }
}

// Deploy Azure Key Vault with private endpoint and private DNS zone
module keyVaultModule 'keyvault.bicep' = {
  name: 'keyVaultDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    appGatewayListenerCertificate: appGatewayListenerCertificate
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure Container Registry with private endpoint and private DNS zone
module acrModule 'acr.bicep' = {
  name: 'acrDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    buildAgentSubnetName: deployVirtualNetwork.outputs.buildAgentsSubnetName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Application Insights and Log Analytics workspace
module appInsightsModule 'applicationinsights.bicep' = {
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
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy Azure AI Foundry with private networking
module aiStudioModule 'machinelearning.bicep' = {
  name: 'aiStudioDeploy'
  params: {
    location: location
    baseName: baseName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    applicationInsightsName: appInsightsModule.outputs.applicationInsightsName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    aiStudioStorageAccountName: storageModule.outputs.mlDeployStorageName
    containerRegistryName: 'cr${baseName}'
    logWorkspaceName: logWorkspace.name
    openAiResourceName: openaiModule.outputs.openAiResourceName
    yourPrincipalId: yourPrincipalId
  }
}

//Deploy an Azure Application Gateway with WAF v2 and a custom domain name.
module gatewayModule 'gateway.bicep' = {
  name: 'gatewayDeploy'
  params: {
    location: location
    baseName: baseName
    customDomainName: customDomainName
    appName: webappModule.outputs.appName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    appGatewaySubnetName: deployVirtualNetwork.outputs.appGatewaySubnetName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    gatewayCertSecretKey: keyVaultModule.outputs.gatewayCertSecretKey
    logWorkspaceName: logWorkspace.name
  }
}

// Deploy the web apps for the front end demo UI and the containerised promptflow endpoint
module webappModule 'webapp.bicep' = {
  name: 'webappDeploy'
  params: {
    location: location
    baseName: baseName
    managedOnlineEndpointResourceId: aiStudioModule.outputs.managedOnlineEndpointResourceId
    acrName: acrModule.outputs.acrName
    publishFileName: publishFileName
    openAIName: openaiModule.outputs.openAiResourceName
    keyVaultName: keyVaultModule.outputs.keyVaultName
    storageName: storageModule.outputs.appDeployStorageName
    vnetName: deployVirtualNetwork.outputs.virtualNetworkName
    appServicesSubnetName: deployVirtualNetwork.outputs.appServicesSubnetName
    privateEndpointsSubnetName: deployVirtualNetwork.outputs.privateEndpointsSubnetName
    logWorkspaceName: logWorkspace.name
  }
}

// Optional Deployment for Customer Usage Attribution
module customerUsageAttributionModule 'customerUsageAttribution/cuaIdResourceGroup.bicep' = if (!telemetryOptOut) {
  #disable-next-line no-loc-expr-outside-params // Only to ensure telemetry data is stored in same location as deployment. See https://github.com/Azure/ALZ-Bicep/wiki/FAQ#why-are-some-linter-rules-disabled-via-the-disable-next-line-bicep-function for more information
  name: 'pid-${varCuaid}-${uniqueString(resourceGroup().location)}'
  params: {}
}
