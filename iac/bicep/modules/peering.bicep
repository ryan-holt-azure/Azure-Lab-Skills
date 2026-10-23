// One direction of a VNet peering. Deploy twice (A->B and B->A) for a working peering.
// Scope: resource group of the LOCAL virtual network.

param localVnetName string
param peeringName string
param remoteVnetId string

@description('Let the local VNet accept traffic that did not originate in the remote VNet (needed for NVA / hub routing).')
param allowForwardedTraffic bool = false

@description('Hub side only: let the remote VNet use this VNet\'s VPN/ExpressRoute gateway.')
param allowGatewayTransit bool = false

@description('Spoke side only: send on-prem traffic through the remote VNet\'s gateway. The remote gateway must already exist.')
param useRemoteGateways bool = false

resource localVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: localVnetName
}

resource peering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  parent: localVnet
  name: peeringName
  properties: {
    remoteVirtualNetwork: {
      id: remoteVnetId
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: allowForwardedTraffic
    allowGatewayTransit: allowGatewayTransit
    useRemoteGateways: useRemoteGateways
  }
}

output peeringState string = peering.properties.peeringState
