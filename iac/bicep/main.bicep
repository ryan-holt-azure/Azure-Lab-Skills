// =============================================================================
// Halsted Logistics Group (HLG) — AZ-104 Hybrid Lab Foundation
// -----------------------------------------------------------------------------
// Deploys (subscription scope):
//   - Resource groups (tagged to satisfy the Lab 02 tag policy)
//   - 4 virtual networks: simulated Chicago on-prem, East US hub, 2 spokes
//   - NSGs on workload subnets (empty — you add rules in Lab 06)
//   - Hub <-> spoke global VNet peerings (Chicago is NOT peered: it connects
//     only through the site-to-site VPN in Lab 07, like a real branch office)
//
// Deploy:
//   az deployment sub create --name hlg-foundation --location eastus \
//     --template-file iac/bicep/main.bicep --parameters iac/bicep/main.bicepparam
//
// DRIFT RULE: after Lab 05 you will change subnets in the portal (route tables,
// service endpoints, NSG links). Redeploying this file afterwards would reset
// those subnet properties to what is written here. Either codify your portal
// changes in this file first, or don't redeploy it. (Lab 03 explains why.)
// =============================================================================

targetScope = 'subscription'

@description('Your name or alias. Used for the Owner tag.')
param owner string

@description('Cost center tag value. Lab 02 policy requires this tag on every resource group.')
param costCenter string = 'CC-1001'

@description('Environment tag value.')
param environment string = 'lab'

@description('Region for the simulated Chicago on-premises datacenter. North Central US is in Illinois.')
param onpremLocation string = 'northcentralus'

@description('Region for the hub virtual network.')
param hubLocation string = 'eastus'

@description('Region for the European spoke. Fallbacks if blocked for new customers: northeurope, swedencentral.')
param spokeEuLocation string = 'westeurope'

@description('Region for the Asia-Pacific spoke.')
param spokeApacLocation string = 'southeastasia'

@description('Leave default outbound internet access ON for workload subnets (lab convenience). Lab 05 shows what happens when it is OFF.')
param workloadDefaultOutbound bool = true

// -----------------------------------------------------------------------------
// Variables
// -----------------------------------------------------------------------------
var tags = {
  Project: 'az104-hybrid'
  Company: 'Halsted Logistics'
  CostCenter: costCenter
  Environment: environment
  Owner: owner
}

var rg = {
  onprem: 'rg-hlg-onprem-chi'
  hub: 'rg-hlg-hub-eus'
  spokeEu: 'rg-hlg-spoke-weu'
  spokeApac: 'rg-hlg-spoke-sea'
  mgmt: 'rg-hlg-mgmt-eus'
  data: 'rg-hlg-data-eus'
  apps: 'rg-hlg-apps'
  sandbox: 'rg-hlg-sandbox'
}

// Address plan (non-overlapping — required for peering and VPN routing)
//   Chicago on-prem 10.10.0.0/16 | Hub 10.20.0.0/16 | EU 10.30.0.0/16 | APAC 10.40.0.0/16
var networks = {
  onprem: {
    name: 'vnet-hlg-onprem-chi'
    site: 'chi'
    addressPrefixes: [ '10.10.0.0/16' ]
    subnets: [
      { name: 'snet-servers', prefix: '10.10.1.0/24', nsg: true, delegation: '', workload: true }
      { name: 'GatewaySubnet', prefix: '10.10.255.0/27', nsg: false, delegation: '', workload: false }
    ]
  }
  hub: {
    name: 'vnet-hlg-hub-eus'
    site: 'hub'
    addressPrefixes: [ '10.20.0.0/16' ]
    subnets: [
      { name: 'GatewaySubnet', prefix: '10.20.0.0/27', nsg: false, delegation: '', workload: false }
      { name: 'AzureBastionSubnet', prefix: '10.20.1.0/26', nsg: false, delegation: '', workload: false }
      { name: 'snet-shared', prefix: '10.20.2.0/24', nsg: true, delegation: '', workload: true }
      { name: 'snet-pe', prefix: '10.20.3.0/24', nsg: false, delegation: '', workload: false }
      { name: 'snet-nva', prefix: '10.20.4.0/24', nsg: true, delegation: '', workload: true }
    ]
  }
  spokeEu: {
    name: 'vnet-hlg-spoke-weu'
    site: 'weu'
    addressPrefixes: [ '10.30.0.0/16' ]
    subnets: [
      { name: 'snet-app', prefix: '10.30.1.0/24', nsg: true, delegation: '', workload: true }
      { name: 'snet-web', prefix: '10.30.2.0/24', nsg: true, delegation: '', workload: true }
      { name: 'snet-appsvc-int', prefix: '10.30.3.0/26', nsg: false, delegation: 'Microsoft.Web/serverFarms', workload: false }
      { name: 'snet-pe', prefix: '10.30.4.0/24', nsg: false, delegation: '', workload: false }
    ]
  }
  spokeApac: {
    name: 'vnet-hlg-spoke-sea'
    site: 'sea'
    addressPrefixes: [ '10.40.0.0/16' ]
    subnets: [
      { name: 'snet-app', prefix: '10.40.1.0/24', nsg: true, delegation: '', workload: true }
      // LAB 03 — MODIFY EXERCISE: add a subnet named 'snet-data' (10.40.2.0/24) with an NSG here.
    ]
  }
}

// -----------------------------------------------------------------------------
// Resource groups
// -----------------------------------------------------------------------------
resource rgOnprem 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.onprem
  location: onpremLocation
  tags: tags
}

resource rgHub 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.hub
  location: hubLocation
  tags: tags
}

resource rgSpokeEu 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.spokeEu
  location: spokeEuLocation
  tags: tags
}

resource rgSpokeApac 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.spokeApac
  location: spokeApacLocation
  tags: tags
}

// Supporting resource groups — empty for now, used in later labs.
resource rgMgmt 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.mgmt
  location: hubLocation
  tags: tags
}

resource rgData 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.data
  location: hubLocation
  tags: tags
}

resource rgApps 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.apps
  location: hubLocation
  tags: tags
}

resource rgSandbox 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rg.sandbox
  location: hubLocation
  tags: tags
}

// -----------------------------------------------------------------------------
// Virtual networks
// -----------------------------------------------------------------------------
module vnetOnprem 'modules/vnet.bicep' = {
  name: 'vnet-onprem'
  scope: rgOnprem
  params: {
    name: networks.onprem.name
    location: onpremLocation
    site: networks.onprem.site
    addressPrefixes: networks.onprem.addressPrefixes
    subnets: networks.onprem.subnets
    workloadDefaultOutbound: workloadDefaultOutbound
    tags: tags
  }
}

module vnetHub 'modules/vnet.bicep' = {
  name: 'vnet-hub'
  scope: rgHub
  params: {
    name: networks.hub.name
    location: hubLocation
    site: networks.hub.site
    addressPrefixes: networks.hub.addressPrefixes
    subnets: networks.hub.subnets
    workloadDefaultOutbound: workloadDefaultOutbound
    tags: tags
  }
}

module vnetSpokeEu 'modules/vnet.bicep' = {
  name: 'vnet-spoke-weu'
  scope: rgSpokeEu
  params: {
    name: networks.spokeEu.name
    location: spokeEuLocation
    site: networks.spokeEu.site
    addressPrefixes: networks.spokeEu.addressPrefixes
    subnets: networks.spokeEu.subnets
    workloadDefaultOutbound: workloadDefaultOutbound
    tags: tags
  }
}

module vnetSpokeApac 'modules/vnet.bicep' = {
  name: 'vnet-spoke-sea'
  scope: rgSpokeApac
  params: {
    name: networks.spokeApac.name
    location: spokeApacLocation
    site: networks.spokeApac.site
    addressPrefixes: networks.spokeApac.addressPrefixes
    subnets: networks.spokeApac.subnets
    workloadDefaultOutbound: workloadDefaultOutbound
    tags: tags
  }
}

// -----------------------------------------------------------------------------
// Hub-and-spoke peerings (each peering is one-directional; you need both sides)
// allowForwardedTraffic = true so the hub NVA in Lab 05 can route spoke<->spoke.
// Gateway transit is OFF here; Lab 07 turns it on after the VPN gateway exists.
// -----------------------------------------------------------------------------
module peerHubToEu 'modules/peering.bicep' = {
  name: 'peer-hub-to-weu'
  scope: rgHub
  params: {
    localVnetName: networks.hub.name
    peeringName: 'peer-hub-to-weu'
    remoteVnetId: vnetSpokeEu.outputs.vnetId
    allowForwardedTraffic: true
  }
  dependsOn: [ vnetHub ]
}

module peerEuToHub 'modules/peering.bicep' = {
  name: 'peer-weu-to-hub'
  scope: rgSpokeEu
  params: {
    localVnetName: networks.spokeEu.name
    peeringName: 'peer-weu-to-hub'
    remoteVnetId: vnetHub.outputs.vnetId
    allowForwardedTraffic: true
  }
  dependsOn: [ vnetSpokeEu ]
}

module peerHubToApac 'modules/peering.bicep' = {
  name: 'peer-hub-to-sea'
  scope: rgHub
  params: {
    localVnetName: networks.hub.name
    peeringName: 'peer-hub-to-sea'
    remoteVnetId: vnetSpokeApac.outputs.vnetId
    allowForwardedTraffic: true
  }
  dependsOn: [ vnetHub, peerHubToEu ] // serialize hub peerings: concurrent writes to one VNet can conflict
}

module peerApacToHub 'modules/peering.bicep' = {
  name: 'peer-sea-to-hub'
  scope: rgSpokeApac
  params: {
    localVnetName: networks.spokeApac.name
    peeringName: 'peer-sea-to-hub'
    remoteVnetId: vnetHub.outputs.vnetId
    allowForwardedTraffic: true
  }
  dependsOn: [ vnetSpokeApac ]
}

// -----------------------------------------------------------------------------
// Outputs
// -----------------------------------------------------------------------------
output resourceGroups object = rg
output onpremVnetId string = vnetOnprem.outputs.vnetId
output hubVnetId string = vnetHub.outputs.vnetId
output spokeEuVnetId string = vnetSpokeEu.outputs.vnetId
output spokeApacVnetId string = vnetSpokeApac.outputs.vnetId
