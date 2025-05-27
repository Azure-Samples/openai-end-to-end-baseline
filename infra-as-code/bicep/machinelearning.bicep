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

@description('The name of the existing subnet within the identified vnet that will contains all the agents hosted for this workload.')
param agentsSubnetName string

param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param aiStudioStorageAccountName string

@description('The name of the (BYO) AI Search index resource that act as the vector store.')
param agentsVectorStoreName string

@description('The name of the (BYO) Azure Cosmos DB for NoSQL account that act as the thread storage. This Cosmos Db store all the messages and conversation history.')
param agentsThreadStorageCosmosDbName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

param openAiResourceName string

@maxLength(36)
@minLength(36)
param yourPrincipalId string

// ---- Variables ----

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }

  resource agentsSubnet 'subnets' existing = {
    name: agentsSubnetName
  }
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-08-01-preview' existing = {
  name: containerRegistryName
}

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' existing = {
  name: keyVaultName
}

resource aiStudioStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: aiStudioStorageAccountName
}

@description('The vector store Azure AI search resource.')
resource agentsVectorStore 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: agentsVectorStoreName
}

@description('The thread storage Cosmos DB account. Agent will save chat sessions in there.')
#disable-next-line BCP081
resource agentsThreadStorageCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: agentsThreadStorageCosmosDbName
}

resource openAiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: openAiResourceName
}

@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
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
    principalId: yourPrincipalId // Production readiness change: Users shouldn't be using the prompt flow developer portal in production, so this role
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
    principalId: yourPrincipalId // Production readiness change: Users shouldn't be using the prompt flow developer portal in production, so this role
                                 // assignment would only be needed in pre-production environments. In pre-production, use conditions on this assignment
                                 // to restrict access to just the blob containers used by the project.

  }
}

#disable-next-line BCP053
var workspaceId = chatProject.properties.internalId
var workspaceIdAsGuid = '${substring(workspaceId, 0, 8)}-${substring(workspaceId, 8, 4)}-${substring(workspaceId, 12, 4)}-${substring(workspaceId, 16, 4)}-${substring(workspaceId, 20, 12)}'
resource blobStorageDataOwnerConditionalForUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(chatProject.id, storageBlobDataOwnerRole.id, aiStudioStorageAccount.id)
  scope: aiStudioStorageAccount  
  properties: {
    principalId: chatProject.identity.principalId
    roleDefinitionId: storageBlobDataOwnerRole.id
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${workspaceIdAsGuid}\'))'
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
#disable-next-line BCP081
resource agentsBingSearch 'Microsoft.Bing/accounts@2025-05-01-preview' = {
  name: 'bingsearch-${baseName}'
  location: 'global'
  kind: 'Bing.Grounding'
  sku: {
    name: 'G1'
  }
}

@description('This is a container for the chat project.')
resource chatProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  parent: openAiAccount
  name: 'aiproj-chat'
  location: location
  identity: {
    type: 'SystemAssigned' // This resource's identity is automatically assigned privileged access to ACR, Storage, Key Vault, and Application Insights.
                           // Since the privileges are granted at the project/hub level have elevated access to the resources, it is recommended to isolate these resources
                           // to a resource group that only contains the project/hub.
  }
  properties: {
    description: 'Project to contain the "Chat with Bing" example prompt flow that is used as part of the Microsoft Learn Azure OpenAI baseline chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-openai-e2e-chat'
    displayName: 'ProjectChatwithBing'
  }

  resource cdbConnection 'connections' = {
    name: agentsThreadStorageCosmosDb.name
    properties: {
      category: 'CosmosDB'
      target: 'https://${agentsThreadStorageCosmosDb.name}.documents.azure.com:443/'
      authType: 'AAD'
      metadata: {
        ApiType: 'Azure'
        ResourceId: agentsThreadStorageCosmosDb.id
        location: agentsThreadStorageCosmosDb.location
      }
    }
  }

  resource aoaiConnection 'connections' = {
    name: 'aoai'
    properties: {
      authType: 'AAD'
      category: 'AIServices'
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

  resource aaisConnection 'connections' = {
    name: 'aais'
    properties: {
      authType: 'AAD'
      category: 'CognitiveSearch'
      isSharedToAll: true
      useWorkspaceManagedIdentity: true
      peRequirement: 'Required'
      sharedUserList: []
      metadata: {
        ApiType: 'Azure'
        ResourceId: agentsVectorStore.id
      }
      target: agentsVectorStore.properties.endpoint
    }
  }

  resource bingGroundingConnection 'connections' = {
    name: 'bingGrounding'
    properties: {
      category: 'ApiKey'
      credentials: {
        key: agentsBingSearch.listKeys().key1
      }
      isSharedToAll: true
      metadata: {
        type: 'bing_grounding'
        ApiType: 'Azure'
        ResourceId: agentsBingSearch.id
        Location: agentsBingSearch.location
      }
      target: agentsBingSearch.properties.endpoint
      authType: 'ApiKey'
    }
  }

  resource storageConnection 'connections' = {
    name: aiStudioStorageAccount.name
    properties: {
      authType: 'AAD'
      category: 'AzureStorageAccount'
      target: aiStudioStorageAccount.properties.primaryEndpoints.blob
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiStudioStorageAccount.id
        location: aiStudioStorageAccount.location
      }
    }
    dependsOn: [
      blobStorageContributorForUserRoleAssignment
      blobStorageDataOwnerConditionalForUserRoleAssignment
      cdbConnection
    ]
  }
}

@description('Assign the AI Foundry project the ability to invoke assistant endpoints in Azure AI Agent Services. This is needed to inference from an agent on behalf of the user.')
resource projectAzAIUserForAgentsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, chatProject.id, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('The Azure Foundry AI project endpoint.')
output aiProjectEndpoint string = '${openAiAccount.properties.endpoints['AI Foundry API']}api/projects/${chatProject.name}'

@description('The Azure Foundry AI project workspace id.')
output chatProjectNameWorkspaceId string = workspaceIdAsGuid

@description('The name of the Azure AI Foundry project.')
output chatProjectName string = chatProject.name

@description('The name of the Azure AI Foundry project connection to Azure Storage Account.')
output stoConnectionName string = chatProject::storageConnection.name
@description('The name of the Azure AI Foundry project connection to Azure AI Services.')
output aoaiConnectionName string = chatProject::aoaiConnection.name
@description('The name of the Azure AI Foundry project connection to Azure AI Search.')
output aaisConnectionName string = chatProject::aaisConnection.name
@description('The name of the Azure AI Foundry project connection to Azure CosmosDb.')
output cdbConnectionName string = chatProject::cdbConnection.name
@description('The id of the Azure AI Foundry project connection to the Bing Search account.')
output bingConnectionId string = chatProject::bingGroundingConnection.id
