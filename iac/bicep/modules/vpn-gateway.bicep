// Route-based VPN gateway with a Standard static public IP.
// Scope: resource group of the virtual network.

param name string
param location string
param vnetName string
param sku string = 'VpnGw1AZ'
param zones array = []
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' existing = {
  parent: vnet
  name: 'GatewaySubnet' // exact name required; /27 or larger recommended; no NSG
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${name}'
  location: location
  tags: tags
  zones: empty(zones) ? null : zones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation1'
    sku: {
      name: sku
      tier: sku
    }
    activeActive: false
    enableBgp: false
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnet.id
          }
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

output gatewayId string = gateway.id
output publicIp string = pip.properties.ipAddress
