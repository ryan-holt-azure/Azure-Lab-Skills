<#
.SYNOPSIS
  Teardown — deletes the HLG lab users and groups created in Lab 01.
  Deleted users stay in "Deleted users" for 30 days; add -Purge to remove them now.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$Domain,
  [string]$CsvPath = (Join-Path $PSScriptRoot 'hlg-staff.csv'),
  [switch]$Purge
)
$ErrorActionPreference = 'Stop'
Connect-MgGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All','Directory.ReadWrite.All' -NoWelcome
if (-not $Domain) { $Domain = (Get-MgDomain | Where-Object IsDefault).Id }

foreach ($s in Import-Csv $CsvPath) {
  $upn = "$($s.Alias)@$Domain"
  $u = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
  if ($u -and $PSCmdlet.ShouldProcess($upn, 'Delete user')) {
    Remove-MgUser -UserId $u.Id
    if ($Purge) { Remove-MgDirectoryDeletedItem -DirectoryObjectId $u.Id }
    Write-Host "  - $upn"
  }
}
Get-MgGroup -Filter "startswith(displayName,'grp-hlg-')" -All | ForEach-Object {
  if ($PSCmdlet.ShouldProcess($_.DisplayName, 'Delete group')) {
    Remove-MgGroup -GroupId $_.Id
    Write-Host "  - group $($_.DisplayName)"
  }
}
