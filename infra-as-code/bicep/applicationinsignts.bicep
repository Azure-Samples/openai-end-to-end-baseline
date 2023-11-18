@description('This is the base name for each Azure resource name (6-12 chars)')
param baseName string

@description('The resource group location')
param location string = resourceGroup().location

@description('Existing Log Analytics workspace name used for this workload.')
param logWorkspaceName string

// Existing resources

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logWorkspaceName
}

// New resources

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-${baseName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    Flow_Type: 'Bluefield'
  }
}

output applicationInsightsName string = applicationInsights.name
