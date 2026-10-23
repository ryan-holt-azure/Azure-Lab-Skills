// =============================================================================
// Lab 07 — Chicago HQ <-> Azure hub site-to-site VPN
// -----------------------------------------------------------------------------
// Stage 1 (default): build the two VPN gateways only (30-45 minutes).
//   You then create the local network gateways + connections and the
//   gateway-transit peering settings yourself in the portal (Lab 07 Tasks 3-5).
//
// Stage 2 (optional, "codify it"): redeploy with
//   deployConnections=true configurePeeringTransit=true
//   to make the template match what you built by hand.
//
// 💲 Each gateway bills hourly. Delete both at the end of Lab 07:
//   az network vnet-gateway delete -g rg-hlg-hub-eus     -n vgw-hlg-hub-eus
//   az network vnet-gateway delete -g rg-hlg-onprem-chi  -n vgw-hlg-onprem-chi
//
// Deploy:
//   export HLG_VPN_PSK="$(openssl rand -hex 20)"
//   az deployment sub create --name hlg-vpn --location eastus \
//     --template-file iac/bicep/hybrid-vpn.bicep --parameters iac/bicep/hybrid-vpn.bicepparam
// =============================================================================

targetScope = 'subscription'

param owner string
param costCenter string = 'CC-1001'

param onpremLocation string = 'northcentralus'
param hubLocation string = 'eastus'

@description('Zones for the hub gateway public IP. East US supports zones.')
param hubZones array = [ '1', '2', '3' ]

@description('Zones for the Chicago gateway public IP. North Central US has no availability zones today, so leave empty.')
param onpremZones array = []

@description('VPN gateway SKU. Non-AZ VpnGw1-5 SKUs can no longer be created.')
param gatewaySku string = 'VpnGw1AZ'

@secure()
@minLength(16)
param sharedKey string

param deployConnections bool = false
param configurePeeringTransit bool = false

var tags = {
  Project: 'az104-hybrid'
  Company: 'Halsted Logistics'
  CostCenter: costCenter
  Environment: 'lab'
  Owner: owner
}

// What each side "sees" of the other. The Chicago-side local network gateway
// must list the hub AND both spokes, or Chicago won't route traffic to the spokes.
var chicagoPrefixes = [ '10.10.0.0/16' ]
var azurePrefixes = [ '10.20.0.0/16', '10.30.0.0/16', '10.40.0.0/16' ]

resource rgHub 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-hub-eus'
}
resource rgOnprem 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-onprem-chi'
}
resource rgSpokeEu 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-spoke-weu'
}
resource rgSpokeApac 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-spoke-sea'
}

module hubGw 'modules/vpn-gateway.bicep' = {
  name: 'vgw-hlg-hub-eus'
  scope: rgHub
  params: {
    name: 'vgw-hlg-hub-eus'
    location: hubLocation
    vnetName: 'vnet-hlg-hub-eus'
    sku: gatewaySku
    zones: hubZones
    tags: tags
  }
}

module chiGw 'modules/vpn-gateway.bicep' = {
  name: 'vgw-hlg-onprem-chi'
  scope: rgOnprem
  params: {
    name: 'vgw-hlg-onprem-chi'
    location: onpremLocation
    vnetName: 'vnet-hlg-onprem-chi'
    sku: gatewaySku
    zones: onpremZones
    tags: tags
  }
}

// Hub side: "Chicago is over there" (LNG = the on-prem VPN device + its prefixes)
module hubToChicago 'modules/vpn-site-link.bicep' = if (deployConnections) {
  name: 'cn-hub-to-chicago'
  scope: rgHub
  params: {
    location: hubLocation
    localNetworkGatewayName: 'lng-hlg-chicago-hq'
    remoteGatewayIp: chiGw.outputs.publicIp
    remotePrefixes: chicagoPrefixes
    virtualNetworkGatewayId: hubGw.outputs.gatewayId
    connectionName: 'cn-hlg-hub-to-chicago'
    sharedKey: sharedKey
    tags: tags
  }
}

// Chicago side: "Azure is over there"
module chicagoToHub 'modules/vpn-site-link.bicep' = if (deployConnections) {
  name: 'cn-chicago-to-hub'
  scope: rgOnprem
  params: {
    location: onpremLocation
    localNetworkGatewayName: 'lng-hlg-azure-hub'
    remoteGatewayIp: hubGw.outputs.publicIp
    remotePrefixes: azurePrefixes
    virtualNetworkGatewayId: chiGw.outputs.gatewayId
    connectionName: 'cn-hlg-chicago-to-hub'
    sharedKey: sharedKey
    tags: tags
  }
}

// Gateway transit: hub shares its gateway; spokes use it.
// These overwrite the peerings from main.bicep (same names), flipping two flags.
module peerHubToEu 'modules/peering.bicep' = if (configurePeeringTransit) {
  name: 'transit-hub-to-weu'
  scope: rgHub
  params: {
    localVnetName: 'vnet-hlg-hub-eus'
    peeringName: 'peer-hub-to-weu'
    remoteVnetId: resourceId(subscription().subscriptionId, rgSpokeEu.name, 'Microsoft.Network/virtualNetworks', 'vnet-hlg-spoke-weu')
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
  dependsOn: [ hubGw ]
}

module peerHubToApac 'modules/peering.bicep' = if (configurePeeringTransit) {
  name: 'transit-hub-to-sea'
  scope: rgHub
  params: {
    localVnetName: 'vnet-hlg-hub-eus'
    peeringName: 'peer-hub-to-sea'
    remoteVnetId: resourceId(subscription().subscriptionId, rgSpokeApac.name, 'Microsoft.Network/virtualNetworks', 'vnet-hlg-spoke-sea')
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
  dependsOn: [ hubGw, peerHubToEu ]
}

module peerEuToHub 'modules/peering.bicep' = if (configurePeeringTransit) {
  name: 'transit-weu-to-hub'
  scope: rgSpokeEu
  params: {
    localVnetName: 'vnet-hlg-spoke-weu'
    peeringName: 'peer-weu-to-hub'
    remoteVnetId: resourceId(subscription().subscriptionId, rgHub.name, 'Microsoft.Network/virtualNetworks', 'vnet-hlg-hub-eus')
    allowForwardedTraffic: true
    useRemoteGateways: true
  }
  dependsOn: [ peerHubToEu ]
}

module peerApacToHub 'modules/peering.bicep' = if (configurePeeringTransit) {
  name: 'transit-sea-to-hub'
  scope: rgSpokeApac
  params: {
    localVnetName: 'vnet-hlg-spoke-sea'
    peeringName: 'peer-sea-to-hub'
    remoteVnetId: resourceId(subscription().subscriptionId, rgHub.name, 'Microsoft.Network/virtualNetworks', 'vnet-hlg-hub-eus')
    allowForwardedTraffic: true
    useRemoteGateways: true
  }
  dependsOn: [ peerHubToApac ]
}

output hubGatewayPublicIp string = hubGw.outputs.publicIp
output chicagoGatewayPublicIp string = chiGw.outputs.publicIp
