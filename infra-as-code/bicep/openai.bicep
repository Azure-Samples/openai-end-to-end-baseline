@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params
param vnetName string
param privateEndpointsSubnetName string
param keyVaultName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

//variables
var openaiName = 'oai-${baseName}'
var openaiPrivateEndpointName = 'pep-${openaiName}'
var openaiDnsGroupName = '${openaiPrivateEndpointName}/default'
var openaiDnsZoneName = 'privatelink.openai.azure.com'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2022-11-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2024-06-01-preview' = {
  name: openaiName
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: 'oai${baseName}'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
    disableLocalAuth: true
    restrictOutboundNetworkAccess: true
    allowedFqdnList: []
  }

  @description('Fairly aggressive filter that attempts to block prompts and completions that are likely unprofessional. Tune to your specific requirements.')
  resource blockingFilter 'raiPolicies' = {
    name: 'blocking-filter'
    properties: {
#disable-next-line BCP073
      type: 'UserManaged'
      basePolicyName: 'Microsoft.Default'
      mode: 'Default'
      contentFilters: [
        /* PROMPT FILTERS */
        {
          name: 'hate'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'sexual'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'selfharm'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'violence'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Prompt'
        }
        {
          name: 'jailbreak'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        {
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        /* COMPLETION FILTERS */
        {
          name: 'hate'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'sexual'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'selfharm'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'violence'
          blocking: true
          enabled: true
          severityThreshold: 'Low'
          source: 'Completion'
        }
        {
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Completion'
        }
      ]
    }
  }

  @description('Add a gpt-4o turbo deployment.')
  resource gpt4o 'deployments' = {
    name: 'gpt-4o-mini'
    sku: {
      name: 'GlobalStandard'
      capacity: 50
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-4o-mini'
        version: '2024-07-18' // If your selected region doesn't support this version, please change it.
                              // az cognitiveservices model list -l $LOCATION --query "sort([?model.name == 'gpt-4o-mini' && kind == 'OpenAI'].model.version)" -o tsv
      }
      raiPolicyName: openAiAccount::blockingFilter.name
      versionUpgradeOption: 'NoAutoUpgrade' // Always pin your dependencies, be intentional about updates.
    }
  }
}

//OpenAI diagnostic settings
resource openAIDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: openAiAccount
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'Audit'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'RequestResponse'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'AzureOpenAIRequestUsage'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
      {
        category: 'Trace'
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

resource openaiPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-11-01' = {
  name: openaiPrivateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: openaiPrivateEndpointName
        properties: {
          groupIds: [
            'account'
          ]
          privateLinkServiceId: openAiAccount.id
        }
      }
    ]
  }
  dependsOn: [
    openAiAccount::blockingFilter
    openAiAccount::gpt4o
  ]
}

resource openaiDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: openaiDnsZoneName
  location: 'global'
  properties: {}

  resource openaiDnsZoneLink 'virtualNetworkLinks' = {
    name: '${openaiDnsZoneName}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

resource openaiDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-11-01' = {
  name: openaiDnsGroupName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: openaiDnsZoneName
        properties: {
          privateDnsZoneId: openaiDnsZone.id
        }
      }
    ]
  }
  dependsOn: [
    openaiPrivateEndpoint
  ]
}

@description('Key Vault Secret: The Azure AI Services deployment model name.')
resource defaultModelName 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'defaultModelName'
  properties: {
    value: openAiAccount::gpt4o.properties.model.name
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

// ---- Outputs ----

output openAiResourceName string = openAiAccount.name
