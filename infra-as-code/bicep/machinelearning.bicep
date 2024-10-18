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
param privateEndpointsSubnetName string
param applicationInsightsName string
param containerRegistryName string
param keyVaultName string
param aiStudioStorageAccountName string

@description('The name of the workload\'s existing Log Analytics workspace.')
param logWorkspaceName string

param openAiResourceName string

// ---- Variables ----
var workspaceName = 'mlw-${baseName}'

// ---- Existing resources ----
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: vnetName

  resource privateEndpointsSubnet 'subnets' existing = {
    name: privateEndpointsSubnetName
  }

  resource aiStudioServerlessComputeSubnet 'subnets' existing = {
    name: 'serverlesscompute'
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

// ---- RBAC built-in role definitions and role assignments ----
@description('Built-in Role: [Storage Blob Data Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-reader)')
resource storageBlobDataReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  scope: subscription()
}


@description('Built-in Role: [Storage Blob Data Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-contributor)')
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: subscription()
}

@description('Built-in Role: [Storage File Data Privileged Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor)')
resource storageFileDataContributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
  scope: subscription()
}

@description('Built-in Role: [AcrPull](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpull)')
resource containerRegistryPullRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  scope: subscription()
}

@description('Built-in Role: [AcrPush](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#acrpush)')
resource containerRegistryPushRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8311e382-0749-4cb8-b61a-304f252e45ec'
  scope: subscription()
}

@description('Built-in Role: [Contributor](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#contributor)')
resource contributorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  scope: subscription()
}

@description('Built-in Role: [Key Vault Administrator](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#key-vault-administrator)')
resource keyVaultAdministratorRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
  scope: subscription()
}
/*
@description('Built-in Role: [Azure Machine Learning Workspace Connection Secrets Reader](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)')
resource machineLearningConnetionSecretsReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'ea01e6af-a1c1-4350-9563-ad00f8c72ec5'
  scope: subscription()
}*/

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

/*
@description('User managed identity that represents the Azure Machine Learning workspace.')
resource azureMachineLearningWorkspaceManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlworkspace'
  location: location
}

@description('User managed identity that represents the Azure Machine Learning workspace\'s managed online endpoint.')
resource azureMachineLearningOnlineEndpointManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlonlineendpoint'
  location: location
}

@description('User managed identity that represents the Azure Machine Learning workspace\'s compute instance.')
resource azureMachineLearningInstanceComputeManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-amlinstancecompute'
  location: location
}*/

// ---- Azure Machine Learning Workspace role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#user-assigned-managed-identity

// AMLW -> Resource Group (control plane for all resources)
/*
@description('Assign AML Workspace\'s ID: Contributor to parent resource group.')
resource workspaceContributorToResourceGroupRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: resourceGroup()
  name: guid(resourceGroup().id, azureMachineLearningWorkspaceManagedIdentity.name, contributorRole.id)
  properties: {
    roleDefinitionId: contributorRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}
*/
// AMLW ->Give Endpoint identity access to read workspace connection secrets
/*
@description('Assign AML Workspace Azure Machine Learning Workspace Connection Secrets Reader to the endpoint managed identity.')
resource onlineEndpointSecretsReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: machineLearning
  name: guid(machineLearning.id, azureMachineLearningOnlineEndpointManagedIdentity.name, machineLearningConnetionSecretsReaderRole.id)

  properties: {
    roleDefinitionId: machineLearningConnetionSecretsReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}*/


// AMLW -> ML Storage data plane (blobs and files)
/*
@description('Assign AML Workspace\'s ID: Storage Blob Data Contributor to workload\'s storage account.')
resource storageBlobDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, azureMachineLearningWorkspaceManagedIdentity.name, storageBlobDataContributorRole.id)
  properties: {
    roleDefinitionId: storageBlobDataContributorRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s ID: Storage File Data Privileged Contributor to workload\'s storage account.')
resource storageFileDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, azureMachineLearningWorkspaceManagedIdentity.name, storageFileDataContributor.id)
  properties: {
    roleDefinitionId: storageFileDataContributor.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}

// AMLW -> Key Vault data plane (secrets)

@description('Assign AML Workspace\'s ID: Key Vault Administrator to Key Vault instance.')
resource keyVaultAdministratorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, azureMachineLearningWorkspaceManagedIdentity.name, keyVaultAdministratorRole.id)
  properties: {
    roleDefinitionId: keyVaultAdministratorRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}

// AMLW -> Azure Container Registry data plane (push and pull)

@description('Assign AML Workspace\'s ID: AcrPush to workload\'s container registry.')
resource containerRegistryPushRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningWorkspaceManagedIdentity.name, containerRegistryPushRole.id)
  properties: {
    roleDefinitionId: containerRegistryPushRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningWorkspaceManagedIdentity.properties.principalId
  }
}

// ---- Azure Machine Learning Workspace managed online endpoint role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-access-resources-from-endpoints-managed-identities#give-access-permission-to-the-managed-identity

@description('Assign AML Workspace\'s Managed Online Endpoint: AcrPull to workload\'s container registry.')
resource onlineEndpointContainerRegistryPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningOnlineEndpointManagedIdentity.name, containerRegistryPullRole.id)
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s Managed Online Endpoint: Storage Blob Data Reader to workload\'s ml storage account.')
resource onlineEndpointBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, azureMachineLearningOnlineEndpointManagedIdentity.name, storageBlobDataReaderRole.id)
  properties: {
    roleDefinitionId: storageBlobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningOnlineEndpointManagedIdentity.properties.principalId
  }
}

// ---- Azure Machine Learning Workspace compute instance role assignments ----
// Source: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#pull-docker-base-image-to-machine-learning-compute-cluster-for-training-as-is

@description('Assign AML Workspace\'s Managed Online Endpoint: AcrPull to workload\'s container registry.')
resource computeInstanceContainerRegistryPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, azureMachineLearningInstanceComputeManagedIdentity.name, containerRegistryPullRole.id)
  properties: {
    roleDefinitionId: containerRegistryPullRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningInstanceComputeManagedIdentity.properties.principalId
  }
}

@description('Assign AML Workspace\'s Managed Online Endpoint: Storage Blob Data Reader to workload\'s ml storage account.')
resource computeInstanceBlobDataReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: aiStudioStorageAccount
  name: guid(aiStudioStorageAccount.id, azureMachineLearningInstanceComputeManagedIdentity.name, storageBlobDataReaderRole.id)
  properties: {
    roleDefinitionId: storageBlobDataReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: azureMachineLearningInstanceComputeManagedIdentity.properties.principalId
  }
}*/

// ---- Azure AI Studio resources ----

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
  }
  properties: {
    friendlyName: 'Azure OpenAI Chat Hub'
    description: 'Hub to support the Microsoft Learn Azure OpenAI baseline chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-openai-e2e-chat'
    publicNetworkAccess: 'Disabled'
    allowPublicAccessWhenBehindVnet: false
    ipAllowlist: []
    serverlessComputeSettings: {
      serverlessComputeCustomSubnet: vnet::aiStudioServerlessComputeSubnet.id
      serverlessComputeNoPublicIP: true
    }

    enableServiceSideCMKEncryption: false
    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
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
        }
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

@description('Azure Diagnostics: Azure AI Studio Hub - allLogs')
resource aiHubDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: aiHub
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs' // Production readiness change: In production, this is probably excessive. Please tune to just the log streams that add value to your workload's operations.
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
  }
  properties: {
    friendlyName: 'Chat with Wikipedia project'
    description: 'Project to contain the "Chat with Wikipedia" example Prompt flow that is used as part of the Microsoft Learn Azure OpenAI baseline chat implementation. https://learn.microsoft.com/azure/architecture/ai-ml/architecture/baseline-openai-e2e-chat'
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
    }
    properties: {
      description: 'This is the /score endpoint for the "Chat with Wikipedia" example Prompt flow deployment. Called by the UI hosted in Web Apps.'
      authMode: 'Key' // Ideally this should be based on Microsoft Entra ID access. This sample however uses a key stored in Key Vault.
      publicNetworkAccess: 'Disabled'
    }

    // TODO: Noticed that traffic goes back to 0% if this is template redeployed after the Prompt flow
    // deplopyment is complete. How can we stop that?
  }
}

// Many role assignments are automatically managed by Azure for system managed identities, but the following two were needed to be added
// manually specifically for the endpoint.

@description('Assign the online endpoint the ability to interact with the secrets of the parent project. This is needed to execute the Prompt flow from the managed endpoint.')
resource projectSecretsReaderForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: chatProject
  name: guid(chatProject.id, chatProject::endpoint.id, amlWorkspaceSecretsReaderRole.id)
  properties: {
    roleDefinitionId: amlWorkspaceSecretsReaderRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Assign the online endpoint the ability to invoke models in Azure OpenAI. This is needed to execute the Prompt flow from the managed endpoint.')
resource projectOpenAIUserForOnlineEndpointRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: openAiAccount
  name: guid(openAiAccount.id, chatProject::endpoint.id, cognitiveServicesOpenAiUserRole.id)
  properties: {
    roleDefinitionId: cognitiveServicesOpenAiUserRole.id
    principalType: 'ServicePrincipal'
    principalId: chatProject::endpoint.identity.principalId
  }
}

@description('Azure Diagnostics: AI Studio chat project - allLogs')
resource chatProjectDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: chatProject
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'  // Production readiness change: In production, this is probably excessive. Please tune to just the log streams that add value to your workload's operations.
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
// TODO: Figure out if the key is something that's reliably predictable, if so, just use that instead of creating
//       a copy of it.
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


// ---- Machine Learning Workspace assets ----
/*
@description('The Azure Machine Learning Workspace.')
resource machineLearning 'Microsoft.MachineLearningServices/workspaces@2023-10-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${azureMachineLearningWorkspaceManagedIdentity.id}': {}
    }
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: workspaceName
    description: 'Azure Machine Learning workspace for this solution. Using platform-managed virtual network. Outbound access fully restricted.'
    hbiWorkspace: false
    primaryUserAssignedIdentity: azureMachineLearningWorkspaceManagedIdentity.id

    // dependent resources
    applicationInsights: applicationInsights.id
    containerRegistry: containerRegistry.id
    keyVault: keyVault.id
    storageAccount: aiStudioStorageAccount.id

    // configuration for workspaces with private link endpoint
    imageBuildCompute: null
    publicNetworkAccess: 'Disabled'
    v1LegacyMode: false

    allowPublicAccessWhenBehindVnet: false

    managedNetwork: {
      isolationMode: 'AllowOnlyApprovedOutbound'
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
        }
      }
    }
  }
  dependsOn: [
    // Role assignments: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#user-assigned-managed-identity
    workspaceContributorToResourceGroupRoleAssignment
    storageBlobDataContributorRoleAssignment
    storageFileDataContributorRoleAssignment
    keyVaultAdministratorRoleAssignment
    containerRegistryPushRoleAssignment
  ]
  
  @description('Managed online endpoint for the /score API.')
  resource onlineEndpoint 'onlineEndpoints' = {
    name: 'ept-${baseName}'
    location: location
    kind: 'Managed'
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${azureMachineLearningOnlineEndpointManagedIdentity.id}': {}
      }
    }
    properties: {
      authMode: 'Key'
      description: 'Managed online endpoint for the /score API, to be used by the Chat UI app.'
      publicNetworkAccess: 'Disabled'
    }
    dependsOn: [
      // Role requirements for the online endpoint: https://learn.microsoft.com/azure/machine-learning/how-to-access-resources-from-endpoints-managed-identities#give-access-permission-to-the-managed-identity
      onlineEndpointContainerRegistryPullRoleAssignment
      onlineEndpointBlobDataReaderRoleAssignment
      onlineEndpointSecretsReaderRoleAssignment 
    ]
  }

  @description('Azure Machine Learning Compute Instance - Ideal for development and testing from the Azure Machine Learning Studio.')
  resource instanceCompute 'computes' = {
    name: 'amli-${baseName}'
    location: location
    identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${azureMachineLearningInstanceComputeManagedIdentity.id}': {}
      }
    }
    properties: {
      computeType: 'ComputeInstance'
      computeLocation: location
      description: 'Machine Learning compute instance'
      disableLocalAuth: true
      properties: {
        customServices: null
        enableNodePublicIp: false
        personalComputeInstanceSettings: null
        schedules: {
          computeStartStop: []
        }
        setupScripts: null
        applicationSharingPolicy: 'Personal'
        computeInstanceAuthorizationType: 'personal'
        sshSettings: {
          sshPublicAccess: 'Disabled'
        }
        vmSize: 'STANDARD_DS3_V2' // Specifies the SKU of the compute instances. You'll need to have the required ML quota available. Adjust SKU choice if necessary.
      }
    }
    dependsOn: [
      // Role requirements for compute instance: https://learn.microsoft.com/azure/machine-learning/how-to-identity-based-service-authentication#pull-docker-base-image-to-machine-learning-compute-cluster-for-training-as-is
      computeInstanceContainerRegistryPullRoleAssignment
      computeInstanceBlobDataReaderRoleAssignment
    ]
  }
}

@description('Azure Diagnostics: Machine Learning Workspace - audit')
resource machineLearningDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: machineLearning
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        categoryGroup: 'audit'
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

@description('Azure Diagnostics: Online Endpoint - allLogs')
resource endpointDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: machineLearning::onlineEndpoint
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
  }
}


@description('Key Vault Secret: The Managed Online Endpoint key to be referenced from the Chat UI app.')
resource managedEndpointPrimaryKeyEntry 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'chatApiKey'
  properties: {
    value: machineLearning::onlineEndpoint.listKeys().primaryKey
    contentType: 'text/plain'
    attributes: {
      enabled: true
    }
  }
}
*/

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
