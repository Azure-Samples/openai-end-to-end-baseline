targetScope = 'resourceGroup'

@description('This is the base name for each Azure resource name (6-8 chars)')
@minLength(6)
@maxLength(8)
param baseName string

@description('The region in which this architecture is deployed.')
@minLength(1)
param location string = resourceGroup().location

@description('The name of the virtual network in this resource group.')
@minLength(1)
param virtualNetworkName string

@description('The name of the Log Analytics Workspace used as the workload\'s common log sink.')
@minLength(4)
param logAnalyticsWorkspaceName string

@description('Specifies the name of the administrator account on the Windows jump box. Cannot end in "."\n\nDisallowed values: "administrator", "admin", "user", "user1", "test", "user2", "test1", "user3", "admin1", "1", "123", "a", "actuser", "adm", "admin2", "aspnet", "backup", "console", "david", "guest", "john", "owner", "root", "server", "sql", "support", "support_388945a0", "sys", "test2", "test3", "user4", "user5".\n\nDefault: vmadmin')
@minLength(4)
@maxLength(20)
param jumpBoxAdminName string = 'vmadmin'

@description('Specifies the password of the administrator account on the Windows jump box.\n\nComplexity requirements: 3 out of 4 conditions below need to be fulfilled:\n- Has lower characters\n- Has upper characters\n- Has a digit\n- Has a special character\n\nDisallowed values: "abc@123", "P@$$w0rd", "P@ssw0rd", "P@ssword123", "Pa$$word", "pass@word1", "Password!", "Password1", "Password22", "iloveyou!"')
@secure()
@minLength(8)
@maxLength(123)
param jumpBoxAdminPassword string

// ---- Variables ----

var bastionHostName = 'ab-${baseName}'
var jumpBoxName = 'jmp-${baseName}'

// ---- Existing resources ----

@description('Existing virtual network for the solution.')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: virtualNetworkName

  resource jumpBoxSubnet 'subnets' existing = {
    name: 'snet-jumpbox'
  }

  resource bastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

@description('Existing Log Analyitics workspace, used as the common log sink for the workload.')
resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' existing = {
  name: logAnalyticsWorkspaceName
}

// New resources

@description('Required public IP for the Azure Bastion service, used for jump box access.')
resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${bastionHostName}'
  location: location
  zones: pickZones('Microsoft.Network', 'publicIPAddresses', location, 3)
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    ddosSettings: {
      ddosProtectionPlan: null
      protectionMode: 'VirtualNetworkInherited'
    }
    deleteOption: 'Delete'
    dnsSettings: {
      domainNameLabel: bastionHostName
    }
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
  }
}

@description('Deploys Azure Bastion for secure access to the jump box.')
resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: bastionHostName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    disableCopyPaste: false
    enableFileCopy: false
    enableIpConnect: false
    enableKerberos: false
    enableShareableLink: false
    enableTunneling: false
    enableSessionRecording: false
    scaleUnits: 2
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPublicIp.id
          }
          subnet: {
            id: virtualNetwork::bastionSubnet.id
          }
        }
      }
    ]
  }
}

@description('Diagnostics settings for Azure Bastion')
resource bastionDiagnosticsSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: bastion
  properties: {
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'BastionAuditLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

@description('Default VM Insights DCR rule, to be applied to the jump box.')
resource virtualMachineInsightsDcr 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'dcr-${jumpBoxName}'
  location: location
  kind: 'Windows'
  properties: {
    description: 'Standard data collection rule for VM Insights'
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers: [
            '\\VMInsights\\DetailedMetrics'
          ]
        }
      ]
      extensions: [
        {
          name: 'DependencyAgentDataSource'
          extensionName: 'DependencyAgent'
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionSettings: {}
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: logWorkspace.name
          workspaceResourceId: logWorkspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
          'Microsoft-ServiceMap'
        ]
        destinations: [
          logWorkspace.name
        ]
      }
    ]
  }
}

@description('VM will only receive a private IP.')
resource jumpBoxPrivateNic 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'nic-${jumpBoxName}'
  location: location
  properties: {
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
    enableIPForwarding: false
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'primary'
        properties: {
          primary: true
          subnet: {
            id: virtualNetwork::jumpBoxSubnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: null
          applicationSecurityGroups: []
        }
      }
    ]
  }
}

@description('The Azure ML and Azure OpenAI portal experiences are only able to be accessed from the virtual network, this jump box gives you access to those UIs.')
resource jumpBoxVirtualMachine 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-${jumpBoxName}'
  location: location
  zones: pickZones('Microsoft.Compute', 'virtualMachines', location, 1)
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    additionalCapabilities: {
      hibernationEnabled: false
      ultraSSDEnabled: false
    }
    applicationProfile: null
    availabilitySet: null
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: null
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    licenseType: 'Windows_Client'
    networkProfile: {
      networkInterfaces: [
        {
          id: jumpBoxPrivateNic.id
        }
      ]
    }
    osProfile: {
      computerName: jumpBoxName
      adminUsername: jumpBoxAdminName
      adminPassword: jumpBoxAdminPassword
      allowExtensionOperations: true
      windowsConfiguration: {
        enableAutomaticUpdates: true
        enableVMAgentPlatformUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
          assessmentMode: 'ImageDefault'
        }
        provisionVMAgent: true
      }
    }
    priority: 'Regular'
    scheduledEventsProfile: {
      osImageNotificationProfile: {
        enable: true
      }
      terminateNotificationProfile: {
        enable: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    storageProfile: {
      dataDisks: []
      diskControllerType: 'SCSI'
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadOnly'
        deleteOption: 'Delete'
        diffDiskSettings: null
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        encryptionSettings: {
          enabled: false
        }
        osType: 'Windows'
        diskSizeGB: 127
      }
      imageReference: {
        offer: 'windows-11'
        publisher: 'MicrosoftWindowsDesktop'
        sku: 'win11-24h2-pro'
        version: 'latest'
      }
    }
  }

  @description('Support remote admin password changes.')
  resource vmAccessExtension 'extensions' = {
    name: 'enablevmAccess'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      publisher: 'Microsoft.Compute'
      type: 'VMAccessAgent'
      typeHandlerVersion: '2.0'
      settings: {}
    }
  }

  @description('Enable Azure Monitor Agent for observability though VM Insights.')
  resource amaExtension 'extensions' = {
    name: 'AzureMonitorWindowsAgent'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
      publisher: 'Microsoft.Azure.Monitor'
      type: 'AzureMonitorWindowsAgent'
      typeHandlerVersion: '1.21'
    }
  }

  @description('Dependency Agent for service map support in Azure Monitor Agent.')
  resource amaDependencyAgent 'extensions' = {
    name: 'DependencyAgentWindows'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: true
      publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
      type: 'DependencyAgentWindows'
      typeHandlerVersion: '9.10'
      settings: {
        enableAMA: 'true'
      }
    }
  }
}

@description('Associate jump box with Azure Monitor Agent VM Insights DCR.')
resource jumpBoxDcrAssociation 'Microsoft.Insights/dataCollectionRuleAssociations@2022-06-01' = {
  name: 'dcra-vminsights'
  scope: jumpBoxVirtualMachine
  properties: {
    dataCollectionRuleId: virtualMachineInsightsDcr.id
    description: 'VM Insights DCR association with the jump box.'
  }
  dependsOn: [
    jumpBoxVirtualMachine::amaDependencyAgent
  ]
}
