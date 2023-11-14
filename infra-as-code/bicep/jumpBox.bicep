@description('This is the base name for each Azure resource name (6-12 chars)')
@minLength(6)
param baseName string

@description('The region in which this architecture is deployed.')
@minLength(1)
param location string = resourceGroup().location

@description('The name of the virtual network in this resource group.')
@minLength(1)
param virtualNetworkName string

// Variables

var bastionHostName = 'ab-${baseName}'
var jumpBoxName = 'jmp-${baseName}'

// Existing resources

@description('Existing virtual network for the solution.')
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {
  name: virtualNetworkName
  
  resource jumpBoxSubnet 'subnets' existing = {
    name: 'snet-jumpbox'
  }

  resource bastionSubnet 'subnets' existing = {
    name: 'AzureBastionSubnet'
  }
}

// New resources

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
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
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
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

@description('The managed identity for all backend virtual machines.')
resource miVmssBackend 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-vm-${jumpBoxName}'
  location: location
}

resource jumpBoxVm 'Microsoft.Compute/virtualMachines@2023-07-01' = {
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
      networkApiVersion: '2023-05-01'
      networkInterfaceConfigurations: [
        {
          name: 'nic-${jumpBoxName}'
          properties: {
            auxiliaryMode: 'None'
            auxiliarySku: 'None'
            deleteOption: 'Delete'
            enableAcceleratedNetworking: false
            enableIPForwarding: false
            enableFpga: false
            primary: true
            ipConfigurations: [
              {
                name: 'default'
                properties: {
                  primary: true
                  privateIPAddressVersion: 'IPv4'
                  publicIPAddressConfiguration: {
                    name: 'default-outbound'
                    sku: {
                      name: 'Standard'
                      tier: 'Regional'
                    }
                    properties: {
                      publicIPAddressVersion: 'IPv4'
                      publicIPAllocationMethod: 'Static'
                      deleteOption: 'Delete'
                    }
                  }
                  subnet: {
                    id: virtualNetwork::jumpBoxSubnet.id
                  }
                  applicationSecurityGroups: []
                }
              }
            ]
          }
        }
      ]
    }
    osProfile: {
      computerName: jumpBoxName
      adminUsername: 'vmadmin'
      adminPassword: ''
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
        caching: 'ReadWrite'
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
        sku: 'win11-23h2-pro'
        version: 'latest'
      }
    }
  }

  resource vmAccessExtension 'extensions' = {
    name: 'VMAccessAgent'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      publisher: 'Microsoft.Compute'
      type: 'VMAccessAgent'
      typeHandlerVersion: '2.4'
    }
  }

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

  resource amaChangeTracking 'extensions' = {
    name: 'ChangeTracking-Windows'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      publisher: 'Microsoft.Azure.ChangeTrackingAndInventory'
      type: 'ChangeTracking-Windows'
      typeHandlerVersion: '2.0'
      provisionAfterExtensions: [
        'AzureMonitorWindowsAgent'
      ]
    }
  }

  resource amaDependencyAgent 'extensions' = {
    name: 'DependencyAgentWindows'
    location: location
    properties: {
      autoUpgradeMinorVersion: true
      enableAutomaticUpgrade: false
      publisher: 'Microsoft.Azure.Monitoring.DependencyAgent'
      type: 'DependencyAgentWindows'
      typeHandlerVersion: '9.10'
      settings: {
        enableAMA: 'true'
      }
      provisionAfterExtensions: [
        'AzureMonitorWindowsAgent'
      ]
    }
  }
}
