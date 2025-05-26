/*
  Deploy machine learning workspace, private endpoints and compute resources
*/

// existing resource name params
param vnetName string

@description('The name of the existing subnet within the identified vnet that will contains all the agents hosted for this workload.')
param agentsSubnetName string

// @description('The name of the Azure AI Foundry hub.')
// param aiHubName string

@description('The name of the Azure AI Foundry hub.')
param openAiResourceName string

@description('The name of the Azure AI Foundry project.')
param chatProjectName string

@description('The workspace id of the Azure AI Foundry project.')
param chatProjectWorkspaceId string

@description('The name of the Azure AI Foundry project connection to Azure Storage Account.')
param stoConnectionName string

@description('The name of the Azure AI Foundry project connection to Azure AI Services.')
param aoaiConnectionName string

@description('The name of the Azure AI Foundry project connection to Azure AI Search.')
param aaisConnectionName string

@description('The name of the Azure AI Foundry project connection to Azure CosmosDb.')
param cdbConnectionName string

@description('The name of the (BYO) AI Search index resource that act as the vector store.')
param agentsVectorStoreName string

@description('The name of the (BYO) Azure Cosmos DB for NoSQL account that act as the thread storage. This Cosmos Db store all the messages and conversation history.')
param agentsThreadStorageCosmosDbName string

// ---- Existing resources ----

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName

  resource agentsSubnet 'subnets' existing = {
    name: agentsSubnetName
  }
}

@description('The vector store Azure AI search resource.')
resource agentsVectorStore 'Microsoft.Search/searchServices@2025-02-01-preview' existing = {
  name: agentsVectorStoreName
}

@description('The thread storage Cosmos DB account. Agent will save chat sessions in there.')
#disable-next-line BCP081
resource agentsThreadStorageCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: agentsThreadStorageCosmosDbName

  #disable-next-line BCP081
  resource enterpriseMemoryDb 'sqlDatabases' existing = {
    name: 'enterprise_memory'

    #disable-next-line BCP081
    resource agentEntityStoreContainer 'containers' existing = {
      name: '${chatProjectWorkspaceId}-agent-entity-store'
    }

    #disable-next-line BCP081
    resource systemMessageStoreContainer 'containers' existing = {
      name: '${chatProjectWorkspaceId}-system-thread-message-store'
    }

    #disable-next-line BCP081
    resource userMessageStoreContainer 'containers' existing = {
      name: '${chatProjectWorkspaceId}-thread-message-store'
    }
  }

  #disable-next-line BCP081
  resource dataContributorSqlRoleDefinition 'sqlRoleDefinitions' existing = {
    name: '00000000-0000-0000-0000-000000000002'
  }
}

resource searchIndexDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8ebe5a00-799e-43f5-93ac-243d3dce84a7'
  scope: resourceGroup()
}

resource searchServiceContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  scope: resourceGroup()
}

resource cosmosDBOperatorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '230815da-be43-4aae-9cb4-875f7bd000aa'
  scope: resourceGroup()
}

// ---- Azure AI Foundry existing resources ----

@description('This is Azure AI Foundry hub.')
resource openAiAccount 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: openAiResourceName
}

@description('This is Azure AI Foundry chat project.')
resource chatProject 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: openAiAccount
  name: chatProjectName
}

// ---- Role Assignments ----

@description('[Vector Store] Assign the AI Foundry project the index contributor role for Azure AI Search.')
resource projectSearchIndexDataContributorForAgentsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: agentsVectorStore
  name: guid(chatProject.id, searchIndexDataContributorRole.id, agentsVectorStore.id)
  properties: {
    roleDefinitionId: searchIndexDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('[Vector Store] Assign the AI Foundry project the contributor role for Azure AI Search.')
resource projectSearchServiceContributorForAgentsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: agentsVectorStore
  name: guid(chatProject.id, searchServiceContributorRole.id, agentsVectorStore.id)
  properties: {
    roleDefinitionId: searchServiceContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

@description('[Thread Storage] Assign the AI Foundry project with the Azure Cosmos Db account Operators role.')
resource projectCosmosDBOperatorForAgentsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: agentsThreadStorageCosmosDb
  name: guid(chatProject.id, cosmosDBOperatorRole.id, agentsThreadStorageCosmosDb.id)
  properties: {
    roleDefinitionId: cosmosDBOperatorRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject.identity.principalId
  }
}

// ---- Capability Hosts ----

// resource hubAgentsCapabilityHost 'Microsoft.MachineLearningServices/workspaces/capabilityHosts@2025-01-01-preview' = {
//   parent: aiHub
//   name: 'HubAgents'
//   properties: {
//     capabilityHostKind: 'Agents'
//     customerSubnet: vnet::agentsSubnet.id
//   }
// }

resource chatProjectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  parent: chatProject
  name: 'ProjectAgents'
  properties: {
    capabilityHostKind: 'Agents'
    aiServicesConnections: ['${aoaiConnectionName}']
    vectorStoreConnections: ['${aaisConnectionName}']
    storageConnections: ['${stoConnectionName}']
    threadStorageConnections: ['${cdbConnectionName}']
  }
  dependsOn: [
    // hubAgentsCapabilityHost
    projectSearchIndexDataContributorForAgentsRoleAssignment
    projectSearchServiceContributorForAgentsRoleAssignment
    projectCosmosDBOperatorForAgentsRoleAssignment
  ]
}

// ---- Sql Role Assignments (data plane) ----

@description('[Agent store] Assign the AI Foundry project the Sql role to read/write the Azure Cosmos Db agent entity store container.')
resource projectContainerAgentEntityStoreForAgentsContainerSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-12-01-preview' = {
  parent: agentsThreadStorageCosmosDb
  name: guid(chatProject.id, agentsThreadStorageCosmosDb::enterpriseMemoryDb::agentEntityStoreContainer.id, agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id)
  properties: {
    roleDefinitionId: agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id
    principalId: chatProject.identity.principalId
    scope: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${agentsThreadStorageCosmosDb.name}/dbs/enterprise_memory/colls/${agentsThreadStorageCosmosDb::enterpriseMemoryDb::agentEntityStoreContainer.name}'
  }
  dependsOn:[
    chatProjectCapabilityHost
  ]
}

@description('[System message store] Assign the AI Foundry project the Sql role to read/write the Azure Cosmos Db system messsages container.')
resource projectContainerSystemMessageStoreForAgentsContainerSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-12-01-preview' = {
  parent: agentsThreadStorageCosmosDb
  name: guid(chatProject.id, agentsThreadStorageCosmosDb::enterpriseMemoryDb::systemMessageStoreContainer.id, agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id)
  properties: {
    roleDefinitionId: agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id
    principalId: chatProject.identity.principalId
    scope: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${agentsThreadStorageCosmosDb.name}/dbs/enterprise_memory/colls/${agentsThreadStorageCosmosDb::enterpriseMemoryDb::systemMessageStoreContainer.name}'
  }
  dependsOn:[
    chatProjectCapabilityHost
  ]
}

@description('[Agent assistant/User role - Message/Thread store] Assign the AI Foundry project the Sql role to read/write the Azure Cosmos Db user messsages container.')
resource projectContainerUserMessageStoreForAgentsContainerSqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2024-12-01-preview' = {
  parent: agentsThreadStorageCosmosDb
  name: guid(chatProject.id, agentsThreadStorageCosmosDb::enterpriseMemoryDb::userMessageStoreContainer.id, agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id)
  properties: {
    roleDefinitionId: agentsThreadStorageCosmosDb::dataContributorSqlRoleDefinition.id
    principalId: chatProject.identity.principalId
    scope: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${agentsThreadStorageCosmosDb.name}/dbs/enterprise_memory/colls/${agentsThreadStorageCosmosDb::enterpriseMemoryDb::userMessageStoreContainer.name}'
  }
  dependsOn:[
    chatProjectCapabilityHost
  ]
}
