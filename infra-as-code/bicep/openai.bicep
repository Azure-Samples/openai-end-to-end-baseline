@description('This is the base name for each Azure resource name (6-12 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param vnetName string
param privateEndpointsSubnetName string
param logWorkspaceName string
param keyVaultName string

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

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyVaultName
  resource kvsGatewayPublicCert 'secrets' = {
    name: 'openai-key'
    properties: {
      value: openAiAccount.listKeys().key1
    }
  }
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: openaiName
  location: location
  kind: 'OpenAI'
  properties: {
    customSubDomainName: 'oai${baseName}'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
    }
  }
  sku: {
    name: 'S0'
  }

  @description('Fairly agressive filter that attempts to block prompts and completions that are likely unprofessional. Tune to your specific requirments.')
  resource blockingFilter 'raiPolicies' = {
    name: 'blocking-filter'
    properties: {
      basePolicyName: 'Microsoft.Default'
      contentFilters: [
        /* PROMPT FILTERS */
        {
          policyName: 'hate'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          policyName: 'sexual'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'

        }
        {
          policyName: 'selfharm'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          policyName: 'violence'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          policyName: 'jailbreak'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        {
          policyName: 'profanity'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        /* COMPLETETION FILTERS */
        {
          policyName: 'hate'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          policyName: 'sexual'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          policyName: 'selfharm'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          policyName: 'violence'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          policyName: 'profanity'
          blocking: true
          enabled: true
          source: 'Completion'
        }
      ]
      mode: 'Blocking'
    }
  }

  resource gpt35 'deployments' = {
    name: 'gpt35'
    sku: {
      name: 'Standard'
      capacity: 120
    }
    properties: {
      model: {
        format: 'OpenAI'
        name: 'gpt-35-turbo'
        version: '0613'
      }
      raiPolicyName: blockingFilter.name
      versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    }
  }
}

//OpenAI diagnostic settings
resource openAIDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${openAiAccount.name}-diagnosticSettings'
  scope: openAiAccount
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
}

resource openaiDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: openaiDnsZoneName
  location: 'global'
  properties: {}
}

resource openaiDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: openaiDnsZone
  name: '${openaiDnsZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
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

// ---- Outputs ----

output openAiResourceName string = openAiAccount.name
