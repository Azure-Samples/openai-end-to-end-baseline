# TODO items for OpenAI e2e baseline

- Add Bicep to deploy Runtime. Currently, the Bicep deploys a compute instance. This task will create the runtime that references the compute instance and allows for the testing of the flow in the UI.
- Create the endpoint and deployment via the CLI with public network access 'Disabled' - guidance here : https://learn.microsoft.com/en-us/azure/machine-learning/prompt-flow/how-to-deploy-to-code?view=azureml-api-2&tabs=managed.
  - Validate UI can access endpoint
  - Validate deployment can access required resources, including OpenAI
- Ensure we have minimum role assignments required for Managed Identity for Azure ML Workspace in machinelearning.bicep. 
- Determine if we should create separate Managed Identity for Endpoint/Deployment than the one used for the authoring. If so, create and update RI.
- Validate settings in machineLearningCLuster in machinelearningcompute.bicep to ensure it is locked down
  - Do we need to set isolateNetwork: true?
  - Do we need to set remoteLoginPortPublicAccess: 'Disabled'
  - Are we missing important settings?
- Validate settings in machineLearningComputeInstance to ensure it is locked down
  - Are we missing important settings?
- Add/update appropriate or missing NSGs in network.bicep
- Migrate DiagnosticSettings to storage retention. This was removed from the below templates Migrate diagnostic settings storage retention to Azure Storage lifecycle management - Azure Monitor | Microsoft Learn
  - gateway.bicep

    ``` Bicep

   // App Gateway diagnostics
    resource appGatewayDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
        name: '${appGateWay.name}-diagnosticSettings'
        scope: appGateWay
        properties: {
        workspaceId: logWorkspace.id
        logs: [
            {
            categoryGroup: 'allLogs'
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
        ]
        metrics: [
            {
            category: 'AllMetrics'
            enabled: true
            }
        ]
        }
    }

    ```

  - webapp.bicep

    ``` Bicep

    // App service plan diagnostic settings
    resource appServicePlanDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
        name: '${appServicePlan.name}-diagnosticSettings'
        scope: appServicePlan
        properties: {
        workspaceId: logWorkspace.id
        metrics: [
            {
            category: 'AllMetrics'
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
        ]
        }
    }
    //Web App diagnostic settings
    resource webAppDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
        name: '${webApp.name}-diagnosticSettings'
        scope: webApp
        properties: {
        workspaceId: logWorkspace.id
        logs: [
            {
            category: 'AppServiceHTTPLogs'
            categoryGroup: null
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
            {
            category: 'AppServiceConsoleLogs'
            categoryGroup: null
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
            {
            category: 'AppServiceAppLogs'
            categoryGroup: null
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
        ]
        metrics: [
            {
            category: 'AllMetrics'
            enabled: true
            retentionPolicy: {
                days: 7
                enabled: true
            }
            }
        ]
        }
    }

    ```