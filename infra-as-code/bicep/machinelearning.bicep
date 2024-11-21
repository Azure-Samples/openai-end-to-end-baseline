/*
  Deploy machine learning workspace, private endpoints and compute resources
*/

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

// existing resource name params 
param vnetName string

@description('The name of the existing subnet within the identified vnet that will contains all private endpoints for this workload.')
param privateEndpointsSubnetName string

param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param aiStudioStorageAccountName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

param openAiResourceName string

@maxLength(36)
@minLength(36)
param yourPrincipalId string

// ---- Variables ----
var workspaceName = 'mlw-${baseName}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' existing = {
  name: containerRegistryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource aiStudioStorageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: aiStudioStorageAccountName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiResourceName
}

@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

@description('Built-in Role: [Storage File Data Privileged Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor)')
resource storageFileDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  scope: subscription()
}

@description('Built-in Role: [Cognitive Services OpenAI User](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#cognitive-services-openai-user)')
resource cognitiveServicesOpenAiUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  scope: subscription()
}

@description('Built-in Role: [Azure Machine Learning Workspace Connection Secrets Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource amlWorkspaceSecretsReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
  scope: subscription()
}

// ---- New Resources ----

@description('Assign your user the ability to manage files in storage. This is needed to use the prompt flow editor in the Azure AI Foundry portal.')
resource storageFileDataContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, yourPrincipalId, storageFileDataContributorRole.id)
  properties: {
    roleDefinitionId: storageFileDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId  // Production readiness change: Users shouldn't be using the prompt flow developer portal in production, so this role
                                  // assignment would only be needed in pre-production environments.
  }
}

@description('Assign your user the ability to manage prompt flow state files from blob storage. This is needed to execute the prompt flow from within in the Azure AI Foundry portal.')
resource blobStorageContributorForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, yourPrincipalId, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'User'
    principalId: yourPrincipalId  // Production readiness change: Users shouldn't be using the prompt flow developer portal in production, so this role
                                  // assignment would only be needed in pre-production environments. In pre-production, use conditions on this assignment
                                  // to restrict access to just the blob containers used by the project.

  }
}

@description('Assign your user the ability to invoke models in Azure OpenAI. This is needed to execute the prompt flow from within in the Azure AI Foundry portal.')
resource cognitiveServicesOpenAiUserForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, yourPrincipalId, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'User'
    principalId: yourPrincipalId
  }
}

// ---- Azure AI Foundry resources ----

@description('A hub provides the hosting environment for this AI workload. It provides security, governance controls, and shared configurations.')
resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-07-01-preview' = {
  name: 'aihub-${baseName}'
  location: location
  kind: 'Hub'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is automatically assigned priviledge access to ACR, Storage, Key Vault, and Application Insights.
                            // Since the priveleges are granted at the project/hub level have elevated access to the resources, it is recommended to isolate these resources
                            // to a resource group that only contains the project/hub and relevant resources.
  }
  properties: {
    friendlyName: 'Azure OpenAI Chat Hub'
    description: 'Hub to support the Microsoft Learn Azure OpenAI baseline chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-openai-e2e-chat'
    publicNetworkAccess: 'Disabled'
    allowPublicAccessWhenBehindVnet: false
    ipAllowlist: []
    serverlessComputeSettings: null // This reference implementation uses a managed virtual network instead of a BYO subnet
    enableServiceSideCMKEncryption: false
    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
      // Cost optimization, firewall rules in the managed virtual network are a signifcant part of the cost of this solution.
      outboundRules: {
        wikipedia: {
          type: 'FQDN'
          destination: 'en.wikipedia.org'
          category: 'UserDefined'
          status: 'Active'
        }
        OpenAI: {
          type: 'PrivateEndpoint'
          destination: {
            serviceResourceId: openAiAccount.id
            subresourceTarget: 'account'
            sparkEnabled: false
            sparkStatus: 'Inactive'
          }
          status: 'Active'
        }
      }
      status: {
        sparkReady: false
        status: 'Active'
      }
    }
    allowRoleAssignmentOnRG: false // Require role assignments at the resource level.
    v1LegacyMode: false
    workspaceHubConfig: {
      defaultWorkspaceResourceGroup: resourceGroup().id  // Setting this to the same resource group as the workspace
    }

    // Default settings for projects
    storageAccount: aiStudioStorageAccount.id
    containerRegistry: containerRegistry.id
    systemDatastoresAuthMode: 'identity'
    enableSoftwareBillOfMaterials: true
    enableDataIsolation: true
    keyVault: keyVault.id
    applicationInsights: applicationInsights.id
    hbiWorkspace: false
    imageBuildCompute: null
  }

  resource aoaiConnection 'connections' = {
    name: 'aoai'
    properties: {
      authType: 'AAD'
      category: 'AzureOpenAI'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'Required'
      sharedUserList: []
      metadata: {
        ApiType: 'Azure'
        ResourceId: openAiAccount.id
      }
      target: openAiAccount.properties.endpoint
    }
  }
}

@description('Azure Diagnostics: Azure AI Foundry hub - allLogs')
resource aiHubDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiHub
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs' // All logs is a good choice for production on this resource.
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('This is a container for the chat project.')
resource chatProject 'Microsoft.MachineLearningServices/workspaces@2024-04-01' = {
  name: 'aiproj-chat'
  location: location
  kind: 'Project'
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'  // This resource's identity is automatically assigned priviledge access to ACR, Storage, Key Vault, and Application Insights. 
                            // Since the priveleges are granted at the project/hub level have elevated access to the resources, it is recommended to isolate these resources
                            // to a resource group that only contains the project/hub.
  }
  properties: {
    friendlyName: 'Chat with Wikipedia project'
    description: 'Project to contain the "Chat with Wikipedia" example prompt flow that is used as part of the Microsoft Learn Azure OpenAI baseline chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-openai-e2e-chat'
    v1LegacyMode: false
    publicNetworkAccess: 'Disabled'
    allowPublicAccessWhenBehindVnet: false
    enableDataIsolation: true
    hubResourceId: aiHub.id
  }

  resource endpoint 'onlineEndpoints' = {
    name: 'ept-chat-${baseName}'
    location: location
    kind: 'Managed'
    identity: {
      type: 'SystemAssigned' // This resource's identity is automatically assigned AcrPull access to ACR, Storage Blob Data Contributor, and AML Metrics Writer on the project. It is also assigned two additional permissions below.
                             // Given the permissions assigned to the identity, it is recommended only include deployments in the Azure OpenAI service that are trusted to be invoked from this endpoint.

    }
    properties: {
      description: 'This is the /score endpoint for the "Chat with Wikipedia" example prompt flow deployment. Called by the UI hosted in Web Apps.'
      authMode: 'Key' // Ideally this should be based on Microsoft Entra ID access. This sample however uses a key stored in Key Vault.
      publicNetworkAccess: 'Disabled'
    }

    // Note: If you reapply this Bicep after an AI Foundry managed compute deployment has happened in this endpoint, the traffic routing reverts to 0% to all existing deployments. You'll need to set that back to 100% to your desired deployment.
  }
}

// Many role assignments are automatically managed by Azure for system managed identities, but the following two were needed to be added
// manually specifically for the endpoint.

@description('Assign the online endpoint the ability to interact with the secrets of the parent project. This is needed to execute the prompt flow from the managed endpoint.')
resource projectSecretsReaderForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: chatProject
  name: guid(chatProject.id, chatProject::endpoint.id, amlWorkspaceSecretsReaderRole.id)
  properties: {
    roleDefinitionId: amlWorkspaceSecretsReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Assign the online endpoint the ability to invoke models in Azure OpenAI. This is needed to execute the prompt flow from the managed endpoint.')
resource projectOpenAIUserForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, chatProject::endpoint.id, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Azure Diagnostics: AI Foundry chat project - allLogs')
resource chatProjectDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: chatProject
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs' // Production readiness change: In production, all logs are probably excessive. Please tune to just the log streams that add value to your workload's operations.
                                 // This this scenario, the logs of interest are mostly found in AmlComputeClusterEvent, AmlDataSetEvent, AmlEnvironmentEvent, and AmlModelsEvent
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Azure Diagnostics: AI Foundry chat project online endpoint - allLogs')
resource chatProjectOnlineEndpointDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: chatProject::endpoint
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs' // All logs is a good choice for production on this resource.
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// Production readiness change: Client applications that run from compute on Azure should use managed identities instead of
// pre-shared keys. This sample implementation uses a pre-shared key, and should be rewritten to use the managed identity
// provided by Azure Web Apps.
@description('Key Vault Secret: The Managed Online Endpoint key to be referenced from the Chat UI app.')
resource managedEndpointPrimaryKeyEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'chatApiKey'
  properties: {
    value: chatProject::endpoint.listKeys().primaryKey // This key is technically already in Key Vault, but it's name is not something that is easy to reference.
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: 'pep-${workspaceName}'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: 'pep-${workspaceName}'
        properties: {
          groupIds: [
            'amlworkspace'  // Inbound access to the workspace
          ]
          privateLinkServiceId: aiHub.id
        }
      }
    ]
    subnet: {
      id: vnet::privateEndpointsSubnet.id
    }
  }

  resource privateEndpointDns 'privateDnsZoneGroups' = {
    name: 'amlworkspace-PrivateDnsZoneGroup'
    properties: {
      privateDnsZoneConfigs: [
        {
          name: 'privatelink.api.azureml.ms'
          properties: {
            privateDnsZoneId: amlPrivateDnsZone.id
          }
        }
        {
          name: 'privatelink.notebooks.azure.net'
          properties: {
            privateDnsZoneId: notebookPrivateDnsZone.id
          }
        }
      ]
    }
  }
}

resource amlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.api.azureml.ms'
  location: 'global'

  resource amlPrivateDnsZoneVnetLink 'virtualNetworkLinks' = {
    name: '${amlPrivateDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

// Notebook
resource notebookPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.notebooks.azure.net'
  location: 'global'

  resource notebookPrivateDnsZoneVnetLink 'virtualNetworkLinks' = {
    name: '${notebookPrivateDnsZone.name}-link'
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: vnet.id
      }
    }
  }
}

output managedOnlineEndpointResourceId string = chatProject::endpoint.id
