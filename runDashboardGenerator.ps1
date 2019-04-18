param(
    [CmdletBinding()]
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$armEndpoint = "https://adminmanagement.redmond.ext-v.masd.stbtest.microsoft.com/"
)

Write-Host $armEndpoint

# logon admin user with user name and password
# $adminUser = "username"
# $adminPhrase = "password"
# $adminPassword = ConvertTo-SecureString -String $adminPhrase -AsPlainText -Force
# $adminCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminUser, $adminPassword

# logon admin user interactively
$adminCredential = Get-Credential

# logon AzureRMAccount, change armEndpoint to yours
$envName = "AzureStackAdmin"
Add-AzureRMEnvironment -Name $envName -ArmEndpoint $armEndpoint -ErrorAction Stop -Verbose
$mProfile = Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" -Credential $adminCredential

import-module .\GetVolumesDashboardJson.psm1 -ArgumentList "Default Provider Subscription" 

# default json save to spedified location
Save-AzureStackVolumesPerformanceDashboardJson -timeGrain "PT15M" -outputLocation '.'

# data of last week with 1 hour interval
Save-AzureStackVolumesPerformanceDashboardJson -duration "P7D" -timeGrain "PT1H"

Logout-AzureRmAccount

# date from 4/1 to 4/8 with 1hr interval 
Save-AzureStackVolumesPerformanceDashboardJson -startTime (Get-date("2019-04-01")) -endTime (Get-date("2019-04-08")) -timeGrain "PT1H" -DefaultProfile $mProfile



Remove-Module GetVolumesDashboardJson