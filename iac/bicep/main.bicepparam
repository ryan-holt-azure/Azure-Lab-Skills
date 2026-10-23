using './main.bicep'

// Change this to your name/alias before deploying.
param owner = 'your-alias'

param costCenter = 'CC-1001'
param environment = 'lab'

// Regions. If West Europe rejects new deployments in your subscription,
// switch spokeEuLocation to 'northeurope' or 'swedencentral'.
param onpremLocation = 'northcentralus'
param hubLocation = 'eastus'
param spokeEuLocation = 'westeurope'
param spokeApacLocation = 'southeastasia'

param workloadDefaultOutbound = true
