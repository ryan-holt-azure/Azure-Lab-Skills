// =============================================================================
// Azure Bastion (Basic SKU) in the hub. Basic supports VNet peering, so ONE
// Bastion in the hub reaches VMs in both spokes. (Developer SKU does not.)
//
// 💲 Bastion bills every hour it exists, used or not. Deploy it when a lab
//    needs it, delete it at the end of the session:
//    az network bastion delete -g rg-hlg-hub-eus -n bas-hlg-hub-eus
//    az network public-ip delete -g rg-hlg-hub-eus -n pip-bas-hlg-hub-eus
//
// Deploy:
//   az deployment group create -g rg-hlg-hub-eus --template-file iac/bicep/bastion.bicep \
//     --parameters owner=<your-alias>
// =============================================================================

param location string = resourceGroup().location
param owner string
param costCenter string = 'CC-1001'
param vnetName string = 'vnet-hlg-hub-eus'

@allowed([ 'Basic', 'Standard' ])
param skuName string = 'Basic'

var tags = {
  Project: 'az104-hybrid'
  Company: 'Halsted Logistics'
  CostCenter: costCenter
  Environment: 'lab'
  Owner: owner
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'AzureBastionSubnet' // exact name required; /26 or larger
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-bas-hlg-hub-eus'
  location: location
  tags: tags
  sku: {
    name: 'Standard' // Bastion requires a Standard, static public IP
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2024-05-01' = {
  name: 'bas-hlg-hub-eus'
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: bastionSubnet.id
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

output bastionName string = bastion.name
