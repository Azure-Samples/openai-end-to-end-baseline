targetScope = 'resourceGroup'

@description('The region in which this architecture is deployed. Should match the region of the resource group.')
@minLength(1)
param location string = resourceGroup().location

@description('The existing Azure AI Foundry account. This project will become a child resource of this account.')
@minLength(2)
param existingAiFoundryName string

@description('The existing CosmosDB account that is going to be used as the Azure AI Agent thread storage database (dependency).')
@minLength(3)
param existingCosmosDbAccountName string

@description('The existing Azure Storage account that is going to be used as the Azure AI Agent blob store (dependency).')
@minLength(3)
param existingStorageAccountName string

@description('The existing Azure AI Search account that is going to be used as the Azure AI Agent vector store (dependency).')
@minLength(1)
param existingAISearchAccountName string

/*** EXISTING RESOURCES ***/

var workspaceId = aiFoundry::project.properties.internalId
var workspaceIdAsGuid = '${substring(workspaceId, 0, 8)}-${substring(workspaceId, 8, 4)}-${substring(workspaceId, 12, 4)}-${substring(workspaceId, 16, 4)}-${substring(workspaceId, 20, 12)}'

var scopeUserContainerId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDbAccount.name}/dbs/enterprise_memory/colls/${workspaceIdAsGuid}-thread-message-store'
var scopeSystemContainerId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDbAccount.name}/dbs/enterprise_memory/colls/${workspaceIdAsGuid}-system-thread-message-store'
var scopeEntityContainerId = '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${cosmosDbAccount.name}/dbs/enterprise_memory/colls/${workspaceIdAsGuid}-agent-entity-store'

resource cosmosDbAccount 'Microsoft.DocumentDB/databaseAccounts@2024-11-15' existing = {
  name: existingCosmosDbAccountName

  resource writer 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }

  resource projectUserThreadContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, 'enterprise_memory', 'user')
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: scopeUserContainerId
    }
    dependsOn: [
      aiFoundry::project::aiAgentService
    ]
  }

  resource projectSystemThreadContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, 'enterprise_memory', 'system')
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: scopeSystemContainerId
    }
    dependsOn: [
      cosmosDbAccount::projectUserThreadContainerWriter
      aiFoundry::project::aiAgentService
    ]
  }

  resource projectEntityContainerWriter 'sqlRoleAssignments' = {
    name: guid(aiFoundry::project.id, cosmosDbAccount::writer.id, 'enterprise_memory', 'entities')
    properties: {
      roleDefinitionId: cosmosDbAccount::writer.id
      principalId: aiFoundry::project.identity.principalId
      scope: scopeEntityContainerId
    }
    dependsOn: [
      cosmosDbAccount::projectSystemThreadContainerWriter
      aiFoundry::project::aiAgentService
    ]
  }
}

resource agentStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = {
  name: existingStorageAccountName
}

resource azureAISearchService 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: existingAISearchAccountName
}

resource azureAISearchServiceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: subscription()
}

resource azureAISearchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: subscription()
}

// Storage Blob Data Contributor
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-05-01-preview' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

// Storage Blob Data Owner Role
resource storageBlobDataOwnerRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  scope: subscription()
}

resource cosmosDbOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '230815da-be43-4aae-9cb4-875f7bd000aa'
  scope: subscription()
}

/*** NEW RESOURCES ***/

resource aiFoundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing  = {
  name: existingAiFoundryName

  resource model 'deployments' existing = {
    name: 'gpt-4o'
  }

  resource project 'projects' = {
    name: 'projchat'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      description: 'Project description'
      displayName: 'ProjectDisplayName'
    }

    // Create project connection to CosmosDB (thread storage), dependency for Azure AI Agent Service
    resource threadStorageConnection 'connections' = {
      name: cosmosDbAccount.name
      properties: {
        authType: 'AAD'
        category: 'CosmosDb'
        target: cosmosDbAccount.properties.documentEndpoint
        metadata: {
          ApiType: 'Azure'
          ResourceId: cosmosDbAccount.id
          location: cosmosDbAccount.location
        }
      }
      dependsOn: [
        projectDbCosmosDbOperatorAssignment
      ]
    }

    // Create project connection to Azure Storage Account, dependency for Azure AI Agent Service
    resource storageConnection 'connections' = {
      name: agentStorageAccount.name
      properties: {
        authType: 'AAD'
        category: 'AzureStorageAccount'
        target: agentStorageAccount.properties.primaryEndpoints.blob
        metadata: {
          ApiType: 'Azure'
          ResourceId: agentStorageAccount.id
          location: agentStorageAccount.location
        }
      }
      dependsOn: [
        projectBlobDataContributorAssignment
        projectBlobDataOwnerConditionalAssignment
        threadStorageConnection // Single thread these connections, else conflict errors tend to happen
      ]
    }

    // Create project connection to Azure AI Search, dependency for Azure AI Agent Service
    resource aiSearchConnection 'connections' = {
      name: azureAISearchService.name
      properties: {
        category: 'CognitiveSearch'
        target: azureAISearchService.properties.endpoint
        authType: 'AAD'
        metadata: {
          ApiType: 'Azure'
          ResourceId: azureAISearchService.id
          location: azureAISearchService.location
        }
      }
      dependsOn: [
        projectAISearchIndexDataContributorAssignment
        projectAISearchContributorAssignment
        storageConnection // Single thread these connections, else conflict errors tend to happen
      ]
    }

    resource aiAgentService 'capabilityHosts' = {
      name: 'projectagents'
      properties: {
        capabilityHostKind: 'Agents'
        vectorStoreConnections: ['${aiSearchConnection.name}']
        storageConnections: ['${storageConnection.name}']
        threadStorageConnections: ['${threadStorageConnection.name}']
      }
    }
  }
}

// Role assignments

resource projectDbCosmosDbOperatorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, cosmosDbOperatorRole.id, cosmosDbAccount.id)
  scope: cosmosDbAccount
  properties: {
    roleDefinitionId: cosmosDbOperatorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectBlobDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, storageBlobDataContributorRole.id, agentStorageAccount.id)
  scope: agentStorageAccount
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectBlobDataOwnerConditionalAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, storageBlobDataOwnerRole.id, agentStorageAccount.id)
  scope: agentStorageAccount  
  properties: {
    principalId: aiFoundry::project.identity.principalId
    roleDefinitionId: storageBlobDataOwnerRole.id
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'})  AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND  !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${workspaceIdAsGuid}\'))'
  }
}

resource projectAISearchContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, azureAISearchServiceContributorRole.id, azureAISearchService.id)
  scope: azureAISearchService
  properties: {
    roleDefinitionId: azureAISearchServiceContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource projectAISearchIndexDataContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundry::project.id, azureAISearchIndexDataContributorRole.id, azureAISearchService.id)
  scope: azureAISearchService
  properties: {
    roleDefinitionId: azureAISearchIndexDataContributorRole.id
    principalId: aiFoundry::project.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Deployment script that just waits for 1 minute to ensure the agent host is ready
/*
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'wait-for-agent-host'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.52.0'
    scriptContent: 'sleep 60'
    retentionInterval: 'PT1H'
  }

  dependsOn: [
    aiFoundry::project::threadStorageConnection
    aiFoundry::project::storageConnection
    aiFoundry::project::aiSearchConnection
  ]
}*/
