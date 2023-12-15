@description('This is the base name for each Azure resource name (6-8 chars)')
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

  @description('Fairly aggressive filter that attempts to block prompts and completions that are likely unprofessional. Tune to your specific requirements.')
  resource blockingFilter 'raiPolicies' = {
    name: 'blocking-filter'
    properties: {
      #disable-next-line BCP037
      type: 'UserManaged'
      basePolicyName: 'Microsoft.Default'
      mode: 'Default'
      contentFilters: [
        /* PROMPT FILTERS */
        {
          #disable-next-line BCP037
          name: 'hate'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          #disable-next-line BCP037
          name: 'sexual'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          #disable-next-line BCP037
          name: 'selfharm'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          #disable-next-line BCP037
          name: 'violence'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Prompt'
        }
        {
          #disable-next-line BCP037
          name: 'jailbreak'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        {
          #disable-next-line BCP037
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Prompt'
        }
        /* COMPLETION FILTERS */
        {
          #disable-next-line BCP037
          name: 'hate'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          #disable-next-line BCP037
          name: 'sexual'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          #disable-next-line BCP037
          name: 'selfharm'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          #disable-next-line BCP037
          name: 'violence'
          blocking: true
          enabled: true
          allowedContentLevel: 'Low'
          source: 'Completion'
        }
        {
          #disable-next-line BCP037
          name: 'profanity'
          blocking: true
          enabled: true
          source: 'Completion'
        }
      ]
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
