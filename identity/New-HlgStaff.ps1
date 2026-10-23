<#
.SYNOPSIS
  LAB 01 fast path — creates the Halsted Logistics staff, groups and managers
  with Microsoft Graph PowerShell. Idempotent: skips anything that exists.

.DESCRIPTION
  Do Lab 01 Tasks 1-3 in the PORTAL first (that's what the exam tests).
  Use this script for the remaining users, or to rebuild the tenant later.

  Writes generated passwords to identity/out/credentials.local.csv, which is
  git-ignored. NEVER commit that file or paste it into a screenshot.

.EXAMPLE
  ./identity/New-HlgStaff.ps1                    # default tenant domain
  ./identity/New-HlgStaff.ps1 -Domain contosolab.onmicrosoft.com

.NOTES
  Dynamic groups need Microsoft Entra ID P1 or P2 (the P2 trial from Lab 00 works).
  Works in Azure Cloud Shell (PowerShell), where Microsoft.Graph is preinstalled.
#>
[CmdletBinding()]
param(
  [string]$Domain,
  [string]$CsvPath = (Join-Path $PSScriptRoot 'hlg-staff.csv'),
  [string]$CompanyName = 'Halsted Logistics'
)

$ErrorActionPreference = 'Stop'

Connect-MgGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All','Directory.ReadWrite.All' -NoWelcome
if (-not $Domain) { $Domain = (Get-MgDomain | Where-Object IsDefault).Id }
Write-Host "Tenant domain: $Domain" -ForegroundColor Cyan

function New-LabPassword {
  $upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ'; $lower = 'abcdefghijkmnopqrstuvwxyz'
  $digit = '23456789';                 $sym   = '!@#%*-_'
  $all   = $upper + $lower + $digit + $sym
  $chars = @(
    $upper[(Get-Random -Maximum $upper.Length)],
    $lower[(Get-Random -Maximum $lower.Length)],
    $digit[(Get-Random -Maximum $digit.Length)],
    $sym[(Get-Random -Maximum $sym.Length)]
  )
  $chars += 1..12 | ForEach-Object { $all[(Get-Random -Maximum $all.Length)] }
  -join ($chars | Sort-Object { Get-Random })
}

$outDir = Join-Path $PSScriptRoot 'out'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$credFile = Join-Path $outDir 'credentials.local.csv'
$creds = @()

# ---------------------------------------------------------------- users
$staff = Import-Csv $CsvPath
$users = @{}
foreach ($s in $staff) {
  $upn = "$($s.Alias)@$Domain"
  $existing = Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue
  if ($existing) {
    Write-Host "  = $upn exists" -ForegroundColor DarkGray
    $users[$s.Alias] = $existing
    continue
  }
  $pw = New-LabPassword
  $u = New-MgUser -DisplayName "$($s.GivenName) $($s.Surname)" `
        -GivenName $s.GivenName -Surname $s.Surname `
        -UserPrincipalName $upn -MailNickname ($s.Alias -replace '\.', '') `
        -AccountEnabled -PasswordProfile @{ ForceChangePasswordNextSignIn = $true; Password = $pw } `
        -JobTitle $s.JobTitle -Department $s.Department -UsageLocation $s.UsageLocation `
        -City $s.City -Country $s.Country -OfficeLocation $s.OfficeLocation -CompanyName $CompanyName
  $users[$s.Alias] = $u
  $creds += [pscustomobject]@{ UserPrincipalName = $upn; TemporaryPassword = $pw }
  Write-Host "  + $upn" -ForegroundColor Green
}

# ---------------------------------------------------------------- managers
foreach ($s in $staff | Where-Object ManagerAlias) {
  $body = @{ '@odata.id' = "https://graph.microsoft.com/v1.0/users/$($users[$s.ManagerAlias].Id)" }
  Set-MgUserManagerByRef -UserId $users[$s.Alias].Id -BodyParameter $body
}
Write-Host "Managers set." -ForegroundColor Cyan

# ---------------------------------------------------------------- groups
function Get-OrNewGroup([string]$Name, [string]$Description, [string]$Rule) {
  $g = Get-MgGroup -Filter "displayName eq '$Name'" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($g) { Write-Host "  = group $Name exists" -ForegroundColor DarkGray; return $g }
  $params = @{
    DisplayName     = $Name
    Description     = $Description
    MailEnabled     = $false
    MailNickname    = ($Name -replace '[^a-zA-Z0-9]', '')
    SecurityEnabled = $true
  }
  if ($Rule) {
    $params.GroupTypes = @('DynamicMembership')
    $params.MembershipRule = $Rule
    $params.MembershipRuleProcessingState = 'On'
  }
  $g = New-MgGroup @params
  Write-Host "  + group $Name" -ForegroundColor Green
  return $g
}

$assigned = @{
  'grp-hlg-it-admins'     = @('priya.natarajan')
  'grp-hlg-network-ops'   = @('priya.natarajan','marcus.reyes')
  'grp-hlg-finance'       = @('dana.kowalski')
  'grp-hlg-auditors'      = @('grace.okafor')
  'grp-hlg-data-analysts' = @('elena.rossi')
  'grp-hlg-sspr-pilot'    = @('lotte.devries','weiling.tan','tom.brennan')
}
foreach ($name in $assigned.Keys) {
  $g = Get-OrNewGroup -Name $name -Description "HLG lab - assigned membership"
  $current = (Get-MgGroupMember -GroupId $g.Id -All).Id
  foreach ($alias in $assigned[$name]) {
    if ($current -notcontains $users[$alias].Id) {
      New-MgGroupMember -GroupId $g.Id -DirectoryObjectId $users[$alias].Id
    }
  }
}

Get-OrNewGroup -Name 'grp-hlg-eu-ops'   -Description 'HLG lab - dynamic: EU Operations'   -Rule '(user.department -eq "EU Operations")'   | Out-Null
Get-OrNewGroup -Name 'grp-hlg-apac-ops' -Description 'HLG lab - dynamic: APAC Operations' -Rule '(user.department -eq "APAC Operations")' | Out-Null
# Department is set on every staff member but not on your admin or break-glass account.
Get-OrNewGroup -Name 'grp-hlg-all-staff' -Description 'HLG lab - dynamic: all Halsted staff (members with a department)' `
  -Rule '(user.userType -eq "Member") -and (user.department -ne null)' | Out-Null

if ($creds.Count -gt 0) {
  $creds | Export-Csv -Path $credFile -NoTypeInformation -Append
  Write-Host "`nTemporary passwords written to $credFile (git-ignored)." -ForegroundColor Yellow
}
Write-Host "Dynamic group membership can take several minutes to populate." -ForegroundColor Cyan
