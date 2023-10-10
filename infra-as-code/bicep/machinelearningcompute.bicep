// Creates compute resources in the specified machine learning workspace
// Includes Compute Instance, Compute Cluster and attached Azure Kubernetes Service compute types
@description('This name of the compute cluster')
param computeClusterName string

@description('This name of the compute instance')
param computeInstanceName string

@description('Azure region of the deployment')
param location string = resourceGroup().location

@description('User Assigned Managed Identity ID')
param managedIdentityId string

@description('Bit indicating whether there is a public IP for the compute nodes')
param computeClusterHasPublicIp bool

@description('VM size for the default compute cluster')
param computeClusterVMSize string

@description('VM size for the default compute instance')
param computeInstanceVMSize string

resource machineLearningCluster 'Microsoft.MachineLearningServices/workspaces/computes@2022-05-01' = {
  name: computeClusterName 
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    computeType: 'AmlCompute'
    computeLocation: location
    description: 'Machine Learning cluster 001'
    disableLocalAuth: true
    properties: {
      vmPriority: 'Dedicated'
      vmSize: computeClusterVMSize
      enableNodePublicIp: computeClusterHasPublicIp
      // isolatedNetwork: false
      osType: 'Linux'
      // remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 5
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
    }
  }
}

resource machineLearningComputeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2022-10-01' = {
  name: computeInstanceName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
  properties: {
    computeType: 'ComputeInstance'
    computeLocation: location
    description: 'Machine Learning compute instance'
    disableLocalAuth: true
    properties: {
      applicationSharingPolicy: 'Personal'
      computeInstanceAuthorizationType: 'personal'
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      vmSize: computeInstanceVMSize      
    }
  }
}
