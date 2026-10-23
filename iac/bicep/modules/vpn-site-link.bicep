// Local network gateway (represents the OTHER side's VPN device + prefixes)
// and the IPsec connection from this side's virtual network gateway to it.
// Scope: resource group of the local virtual network gateway.

param location string
param localNetworkGatewayName string
param remoteGatewayIp string
param remotePrefixes array
param virtualNetworkGatewayId string
param connectionName string

@secure()
param sharedKey string

param tags object = {}

resource lng 'Microsoft.Network/localNetworkGateways@2024-05-01' = {
  name: localNetworkGatewayName
  location: location
  tags: tags
  properties: {
    gatewayIpAddress: remoteGatewayIp
    localNetworkAddressSpace: {
      addressPrefixes: remotePrefixes
    }
  }
}

resource connection 'Microsoft.Network/connections@2024-05-01' = {
  name: connectionName
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    connectionProtocol: 'IKEv2'
    enableBgp: false
    sharedKey: sharedKey
    virtualNetworkGateway1: {
      id: virtualNetworkGatewayId
      properties: {}
    }
    localNetworkGateway2: {
      id: lng.id
      properties: {}
    }
  }
}

output connectionId string = connection.id
