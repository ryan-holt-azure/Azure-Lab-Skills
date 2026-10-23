// Virtual network with subnets, plus one empty NSG per subnet that asks for one.
// Scope: resource group.

@description('Virtual network name.')
param name string

param location string

@description('Short site code used in NSG names, e.g. weu, sea, hub, chi.')
param site string

param addressPrefixes array

@description('Array of { name, prefix, nsg (bool), delegation (string, "" for none), workload (bool) }.')
param subnets array

@description('Value for defaultOutboundAccess on workload subnets.')
param workloadDefaultOutbound bool = true

param tags object = {}

// One NSG per subnet that requested it. Created empty: the default rules apply until Lab 06.
resource nsgs 'Microsoft.Network/networkSecurityGroups@2024-05-01' = [for s in filter(subnets, sub => sub.nsg): {
  name: 'nsg-${s.name}-${site}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}]

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    // Subnets are declared inline. Redeploying this resource replaces the whole
    // subnet list and each subnet's properties — see the DRIFT RULE in main.bicep.
    subnets: [for s in subnets: {
      name: s.name
      properties: union(
        { addressPrefix: s.prefix },
        s.nsg ? { networkSecurityGroup: { id: resourceId('Microsoft.Network/networkSecurityGroups', 'nsg-${s.name}-${site}') } } : {},
        empty(s.delegation) ? {} : { delegations: [ { name: 'delegation', properties: { serviceName: s.delegation } } ] },
        s.workload ? { defaultOutboundAccess: workloadDefaultOutbound } : {}
      )
    }]
  }
  dependsOn: [ nsgs ]
}

output vnetId string = vnet.id
output vnetName string = vnet.name
