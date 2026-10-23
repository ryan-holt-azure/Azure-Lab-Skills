// Small Ubuntu 24.04 VM with a static private IP and no public IP.
// Scope: resource group.

param name string
param location string
param tags object = {}
param subnetId string
param privateIp string
param vmSize string = 'Standard_B1s'
param adminUsername string

@secure()
param adminPassword string

@description('Plain-text cloud-init. Encoded to base64 here.')
param customData string = ''

@description('Azure-side IP forwarding on the NIC (required for an NVA).')
param enableIpForwarding bool = false

@description('Availability zone ("1", "2", "3") or "" for none.')
param zone string = ''

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: 'nic-${name}'
  location: location
  tags: tags
  properties: {
    enableIPForwarding: enableIpForwarding
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: privateIp
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: location
  tags: tags
  zones: empty(zone) ? null : [ zone ]
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
    osProfile: {
      computerName: take(replace(name, 'vm-', ''), 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: empty(customData) ? null : base64(customData)
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        name: 'osdisk-${name}'
        createOption: 'FromImage'
        deleteOption: 'Delete'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true // managed storage account — needed for Serial console
      }
    }
  }
}

output vmId string = vm.id
output privateIp string = privateIp
