using './hybrid-vpn.bicep'

param owner = 'your-alias'
param costCenter = 'CC-1001'

param onpremLocation = 'northcentralus'
param hubLocation = 'eastus'
param hubZones = [ '1', '2', '3' ]
param onpremZones = []

param gatewaySku = 'VpnGw1AZ'

//   export HLG_VPN_PSK="$(openssl rand -hex 20)"   (hex avoids characters some VPN devices reject)
param sharedKey = readEnvironmentVariable('HLG_VPN_PSK')

// Stage 2 ("codify it") — flip both to true after you've built them by hand.
param deployConnections = false
param configurePeeringTransit = false
