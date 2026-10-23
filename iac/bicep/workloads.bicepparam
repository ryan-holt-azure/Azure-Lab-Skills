using './workloads.bicep'

param owner = 'your-alias'
param costCenter = 'CC-1001'
param environment = 'lab'

param vmSize = 'Standard_B1s'
param adminUsername = 'hlgadmin'

// Read from your shell so the password never lands in Git:
//   export HLG_ADMIN_PASSWORD='<strong password, 12+ chars>'
param adminPassword = readEnvironmentVariable('HLG_ADMIN_PASSWORD')

param deployChicagoServer = true
param deployNva = true
param deploySpokeVms = true
