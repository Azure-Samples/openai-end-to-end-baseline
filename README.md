# OpenAI end-to-end baseline architecture

This repository contains the Bicep code to deploy an OpenAI chat baseline architecture with Azure ML and Azure App Services baseline. 

![Diagram of the app services baseline architecture.](docs/media/openai-end-to-end.png)

## Deploy

The following are prerequisites.

## Prerequisites

1. Ensure you have an [Azure Account](https://azure.microsoft.com/free/)
1. The deployment must be started by a user who has sufficient permissions to assign [roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles), such as a User Access Administrator or Owner.
1. Ensure you have the [Azure CLI installed](https://learn.microsoft.com/cli/azure/install-azure-cli)
1. Ensure you have the [az Bicep tools installed](https://learn.microsoft.com/azure/azure-resource-manager/bicep/install)

Use the following to deploy the infrastructure.

### Deploy the infrastructure

The following steps are required to deploy the infrastructure from the command line.

1. In your command-line tool where you have the Azure CLI and Bicep installed, navigate to the root directory of this repository (AppServicesRI)

1. Login and set subscription if it is needed

```bash
  az login
  az account set --subscription xxxxx
```

1. Obtain App gateway certificate
   Azure Application Gateway support for secure TLS using Azure Key Vault and managed identities for Azure resources. This configuration enables end-to-end encryption of the network traffic using standard TLS protocols. For production systems you use a publicly signed certificate backed by a public root certificate authority (CA). Here, we are going to use a self signed certificate for demonstrational purposes.

   - Set a variable for the domain that will be used in the rest of this deployment.

     ```bash
     export DOMAIN_NAME_APPSERV_BASELINE="contoso.com"
     ```

   - Generate a client-facing, self-signed TLS certificate.

     :warning: Do not use the certificate created by this script for actual deployments. The use of self-signed certificates are provided for ease of illustration purposes only. For your App Service solution, use your organization's requirements for procurement and lifetime management of TLS certificates, _even for development purposes_.

     Create the certificate that will be presented to web clients by Azure Application Gateway for your domain.

     ```bash
     openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=${DOMAIN_NAME_APPSERV_BASELINE}/O=Contoso" -addext "subjectAltName = DNS:${DOMAIN_NAME_APPSERV_BASELINE}" -addext "keyUsage = digitalSignature" -addext "extendedKeyUsage = serverAuth"
     openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:
     ```

   - Base64 encode the client-facing certificate.

     :bulb: No matter if you used a certificate from your organization or you generated one from above, you'll need the certificate (as `.pfx`) to be Base64 encoded for proper storage in Key Vault later.

     ```bash
     export APP_GATEWAY_LISTENER_CERTIFICATE_APPSERV_BASELINE=$(cat appgw.pfx | base64 | tr -d '\n')
     echo APP_GATEWAY_LISTENER_CERTIFICATE_APPSERV_BASELINE: $APP_GATEWAY_LISTENER_CERTIFICATE_APPSERV_BASELINE
     ```

1. Update the infra-as-code/parameters file

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "baseName": {
      "value": ""
    },
    "developmentEnvironment": {
      "value": true
    },
    "appGatewayListenerCertificate": {
      "value": "[base64 cert data from $APP_GATEWAY_LISTENER_CERTIFICATE_APPSERV_BASELINE]"
    }
  }
}
```

1. Run the following command to create a resource group and deploy the infrastructure. Make sure:

   - The location you choose [supports availability zones](https://learn.microsoft.com/azure/reliability/availability-zones-service-support)
   - The BASE_NAME contains only lowercase letters and is between 6 and 12 characters. All resources will be named given this basename.
   - You choose a valid resource group name

```bash
   LOCATION=eastus
   BASE_NAME=<base-resource-name (between 3 and 6 characters)>

   RESOURCE_GROUP=<resource-group-name>
   az group create --location $LOCATION --resource-group $RESOURCE_GROUP

   az deployment group create --template-file ./infra-as-code/bicep/main.bicep \
     --resource-group $RESOURCE_GROUP \
     --parameters @./infra-as-code/bicep/parameters.json \
     --parameters baseName=$BASE_NAME
```

1. TEMPORARY - Set public network access to 'All networks' for the Azure Container Registry and the machine learning Storage Account. There is a known bug that requires these to be accessible publicly.

## Create, test, and deploy a Prompt flow

1. Connect to the virtual network via Azure Bastion and a Virtual Machine jumpbox or through VNet peering. 'Windows 11 Pro, version 22H2 - x64 Gen2' is a suitable jumpbox VM image.

1. Open the [Machine Learning Workspace](https://ml.azure.com/) and choose your workspace. Ensure you have [enabled Prompt flow in your Azure Machine Learning workspace](https://learn.microsoft.com/azure/machine-learning/prompt-flow/get-started-prompt-flow?view=azureml-api-2#prerequisites-enable-prompt-flow-in-your-azure-machine-learning-workspace).

1. Create a new Prompt flow with a single python step and save the flow.  **Important: make sure the output name on the flow is 'answer'. The sample application is looking for that in the response.**

```python
from promptflow import tool

@tool
def process_search_result(search_result):
    
    try:
       return search_result+"Echo"
    except Exception as e:
        return "error"
```

1. Add runtime

   - Click Add runtime
   - Add compute instance runtime and give it a name
   - Choose the compute instance created by the Bicep
   - Accept the other defaults and click 'Create'

1. Test the flow

   - Wait for the runtime to be created
   - Select the runtime in the UI
   - Click on Chat
   - Enter a question
   - The response should echo your question with 'Echo' appended

## Create a deployment

1. Create a deployment in the UI

   - Click on 'Deploy' in the UI
   - Choose 'New' Endpoint
   - Choose 'Key-based authentication'
   - Choose 'User-assigned' Identity type
   - Choose the identity created by the deployment. It should start with 'id-mlw'. That identity has the correct role assignments listed in the UI.
   - Choose Next and name the deployment ept-<basename>, leaving the defaults on the Deployment screen. **Make sure you name the deployment ept-<basename>. An App Service environment variable is set, assuming that naming convention**
   - Choose Next, Next, Next
   - Choose a small Virtual Machine size for testing and set the number of instances.
   - Deploy

## Store the endpoint key in Key Vault

1. Wait for the deployment to complete
1. Click on 'Endpoints'
1. Get the key from the 'Consume' tab
1. Add the key as a secret to key vault with secret name: 'chatApiKey'


<!-- ## Update the App Service Environment variables

1. Open the App Service 'Environment variables' tab
1. Add a new environment variable
    1. name: chatApiEndpoint
    1. value: <REST endpoint from consume tab of endpoint>
1. Add a new environment variable
    1. name: chatApiKey
    1. value: @Microsoft.KeyVault(SecretUri=https://vault-name.vault.azure.net/secrets/chatApiKey) -->

### Publish the web app

The baseline architecture uses [run from zip file in App Services](https://learn.microsoft.com/azure/app-service/deploy-run-package). There are many benefits of using this approach, including eliminating file lock conflicts when deploying.

To use run from zip, you do the following:

1. Create a [project zip package](https://learn.microsoft.com/azure/app-service/deploy-run-package#create-a-project-zip-package) which is a zip file of your project.
1. Upload that zip file to a location that is accessible to your web site. This implementation uses private endpoints to securely connect to the storage account. The web app has a managed identity that is authorized to access the blob.
1. Set the environment variable `WEBSITE_RUN_FROM_PACKAGE` to the URL of the zip file.

In a production environment, you would likely use a CI/CD pipeline to:

1. Build your application
1. Create the project zip package
1. Upload the zip file to your storage account

The CI/CD pipeline would likely use a [self-hosted agent](https://learn.microsoft.com/azure/devops/pipelines/agents/agents?view=azure-devops&tabs=browser#install) that is able to connect to the storage account through a private endpoint to upload the zip. We have not implemented that here.

**Workaround**

Because we have not implemented a CI/CD pipeline with a self-hosted agent, we need a workaround to upload the file to the storage account. There are two workaround steps you need to do in order to manually upload the zip file using the portal.

1. The deployed storage account does not allow public access, so you will need to temporarily allow access public access from your IP address.
1. You need to give your user permissions to upload a blob to the storage account.

Run the following to:

- Allow public access from your IP address, g
- Give the logged in user permissions to upload a blob
- Create the `deploy` container
- Upload the zip file `./website/chatui.zip` to the `deploy` container
- Tell the web app to restart

```bash
CLIENT_IP_ADDRESS=<your-public-ip-address>

STORAGE_ACCOUNT_PREFIX=st
WEB_APP_PREFIX=app-
NAME_OF_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_PREFIX$BASE_NAME"
NAME_OF_WEB_APP="$WEB_APP_PREFIX$BASE_NAME"
LOGGED_IN_USER_ID=$(az ad signed-in-user show --query id -o tsv)
RESOURCE_GROUP_ID=$(az group show --resource-group $RESOURCE_GROUP --query id -o tsv)
STORAGE_BLOB_DATA_CONTRIBUTOR=ba92f5b4-2d11-453d-a403-e96b0029c9fe

az storage account network-rule add -g $RESOURCE_GROUP --account-name "$NAME_OF_STORAGE_ACCOUNT" --ip-address $CLIENT_IP_ADDRESS
az role assignment create --assignee-principal-type User --assignee-object-id $LOGGED_IN_USER_ID --role $STORAGE_BLOB_DATA_CONTRIBUTOR --scope $RESOURCE_GROUP_ID

az storage container create  \
  --account-name $NAME_OF_STORAGE_ACCOUNT \
  --auth-mode login \
  --name deploy

az storage blob upload -f ./website/chatui.zip \
  --account-name $NAME_OF_STORAGE_ACCOUNT \
  --auth-mode login \
  -c deploy -n chatui.zip

az webapp restart --name $NAME_OF_WEB_APP --resource-group $RESOURCE_GROUP
```

### Validate the web app

This section will help you to validate the workload is exposed correctly and responding to HTTP requests.

### Steps

1. Get the public IP address of Application Gateway.

   > :book: The app team conducts a final acceptance test to be sure that traffic is flowing end-to-end as expected, so they place a request against the Azure Application Gateway endpoint.

   ```bash
   # query the Azure Application Gateway Public Ip
   APPGW_PUBLIC_IP=$(az network public-ip show --resource-group $RESOURCE_GROUP --name "pip-$BASE_NAME" --query [ipAddress] --output tsv)
   echo APPGW_PUBLIC_IP: $APPGW_PUBLIC_IP
   ```

1. Create an `A` record for DNS.

   > :bulb: You can simulate this via a local hosts file modification. You're welcome to add a real DNS entry for your specific deployment's application domain name, if you have access to do so.

   Map the Azure Application Gateway public IP address to the application domain name. To do that, please edit your hosts file (`C:\Windows\System32\drivers\etc\hosts` or `/etc/hosts`) and add the following record to the end: `${APPGW_PUBLIC_IP} www.${DOMAIN_NAME_APPSERV_BASELINE}` (e.g. `50.140.130.120  www.contoso.com`)

1. Browse to the site (e.g. <https://www.contoso.com>).

   > :bulb: Remember to include the protocol prefix `https://` in the URL you type in the address bar of your browser. A TLS warning will be present due to using a self-signed certificate. You can ignore it or import the self-signed cert (`appgw.pfx`) to your user's trusted root store.

## Clean Up

After you are done exploring your deployed AppService reference implementation, you'll want to delete the created Azure resources to prevent undesired costs from accruing.

```bash
az group delete --name $RESOURCE_GROUP -y
az keyvault purge  -n kv-${BASE_NAME}
```