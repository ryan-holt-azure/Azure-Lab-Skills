// =============================================================================
// HLG lab workloads — small Ubuntu VMs used to test routing, NSGs, DNS, LB,
// monitoring and backup. None of them has a public IP.
//
//   vm-hlg-chi-srv01   10.10.1.4  Chicago "on-prem" server      (deployChicagoServer)
//   vm-hlg-hub-nva01   10.20.4.4  Hub router / NVA, IP forwarding (deployNva)
//   vm-hlg-weu-app01   10.30.1.4  EU app server                  (deploySpokeVms)
//   vm-hlg-sea-app01   10.40.1.4  APAC app server                (deploySpokeVms)
//
// Each web VM serves http://<ip>/ showing its hostname and site — no package
// installs needed, so it works even on private subnets.
//
// Deploy (after main.bicep):
//   export HLG_ADMIN_PASSWORD='<a strong password>'
//   az deployment sub create --name hlg-workloads --location eastus \
//     --template-file iac/bicep/workloads.bicep --parameters iac/bicep/workloads.bicepparam
// =============================================================================

targetScope = 'subscription'

param owner string
param costCenter string = 'CC-1001'
param environment string = 'lab'

param onpremLocation string = 'northcentralus'
param hubLocation string = 'eastus'
param spokeEuLocation string = 'westeurope'
param spokeApacLocation string = 'southeastasia'

@description('VM size for every lab VM. Must be allowed by the Lab 02 "Allowed virtual machine size SKUs" policy.')
param vmSize string = 'Standard_B1s'

param adminUsername string = 'hlgadmin'

@secure()
@minLength(12)
@description('Local admin password. Supply it from an environment variable — never commit it.')
param adminPassword string

param deployChicagoServer bool = true
param deployNva bool = true
param deploySpokeVms bool = true

var tags = {
  Project: 'az104-hybrid'
  Company: 'Halsted Logistics'
  CostCenter: costCenter
  Environment: environment
  Owner: owner
}

var webCloudInit = loadTextContent('cloudinit/web.yaml')
var nvaCloudInit = loadTextContent('cloudinit/nva.yaml')

resource rgOnprem 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-onprem-chi'
}
resource rgHub 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-hub-eus'
}
resource rgSpokeEu 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-spoke-weu'
}
resource rgSpokeApac 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: 'rg-hlg-spoke-sea'
}

module chiSrv 'modules/linux-vm.bicep' = if (deployChicagoServer) {
  name: 'vm-hlg-chi-srv01'
  scope: rgOnprem
  params: {
    name: 'vm-hlg-chi-srv01'
    location: onpremLocation
    tags: tags
    subnetId: resourceId(subscription().subscriptionId, rgOnprem.name, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-hlg-onprem-chi', 'snet-servers')
    privateIp: '10.10.1.4'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    customData: replace(webCloudInit, '__SITE__', 'Chicago HQ datacenter (simulated on-prem)')
  }
}

module hubNva 'modules/linux-vm.bicep' = if (deployNva) {
  name: 'vm-hlg-hub-nva01'
  scope: rgHub
  params: {
    name: 'vm-hlg-hub-nva01'
    location: hubLocation
    tags: tags
    subnetId: resourceId(subscription().subscriptionId, rgHub.name, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-hlg-hub-eus', 'snet-nva')
    privateIp: '10.20.4.4'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    customData: nvaCloudInit
    enableIpForwarding: true // Azure-side IP forwarding; cloud-init enables Linux-side forwarding
  }
}

module weuApp 'modules/linux-vm.bicep' = if (deploySpokeVms) {
  name: 'vm-hlg-weu-app01'
  scope: rgSpokeEu
  params: {
    name: 'vm-hlg-weu-app01'
    location: spokeEuLocation
    tags: tags
    subnetId: resourceId(subscription().subscriptionId, rgSpokeEu.name, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-hlg-spoke-weu', 'snet-app')
    privateIp: '10.30.1.4'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    customData: replace(webCloudInit, '__SITE__', 'EU Operations - West Europe spoke')
  }
}

module seaApp 'modules/linux-vm.bicep' = if (deploySpokeVms) {
  name: 'vm-hlg-sea-app01'
  scope: rgSpokeApac
  params: {
    name: 'vm-hlg-sea-app01'
    location: spokeApacLocation
    tags: tags
    subnetId: resourceId(subscription().subscriptionId, rgSpokeApac.name, 'Microsoft.Network/virtualNetworks/subnets', 'vnet-hlg-spoke-sea', 'snet-app')
    privateIp: '10.40.1.4'
    vmSize: vmSize
    adminUsername: adminUsername
    adminPassword: adminPassword
    customData: replace(webCloudInit, '__SITE__', 'APAC Operations - Southeast Asia spoke')
  }
}
