$adminCredential = $adminCredential = Get-Credential

$envName = "AzureStackAdmin"
$armEndpoint =  "https://adminmanagement.redmond.ext-v.masd.stbtest.microsoft.com/"
Add-AzureRMEnvironment -Name $envName -ArmEndpoint $armEndpoint -ErrorAction Stop -Verbose
Login-AzureRmAccount -EnvironmentName "AzureStackAdmin" -Credential $adminCredential


import-module .\GetVolumesDashboardJson.psm1 -ArgumentList "AzureStackAdmin","Default Provider Subscription" 

Save-AzureStackVolumesPerformanceDashboardJson

Save-AzureStackVolumesPerformanceDashboardJson -duration "P2D" -timeGrain "PT30M"

Save-AzureStackVolumesPerformanceDashboardJson -startTime (Get-date("2019-04-01")) -endTime (Get-date("2019-04-08")) -timeGrain "PT1H"

# $duration = "P2D"
# Save-AzureStackVolumesPerformanceDashboardJson -duration $duration

# $timeGrain = "PT30M"
# $duration = "P2D"
# Save-AzureStackVolumesPerformanceDashboardJson -timegrain $timeGrain -duration $duration

# $startTime = (get-date).AddHours(-2)
# $endTime = (get-date)
# Save-AzureStackVolumesPerformanceDashboardJson -startTime $startTime -endTime $endTime -timegrain $timeGrain

# $duration = New-TimeSpan -Hours 4
# $timeGrain = New-TimeSpan -Minutes 30
# Save-AzureStackVolumesPerformanceDashboardJson -duration $duration -timegrain $timeGrain


Remove-Module GetVolumesDashboardJson