param(
    [CmdletBinding()]
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$envName = "AzureStackAdmin",
    [Parameter(Position = 1, Mandatory = $false)]
    [string]$adminSubscriptionName = "Default Provider Subscription" ,
    [Parameter(Position = 2, Mandatory = $false)]
    [string]$jsonTemplateLocation = "." 
)

<#
.SYNOPSIS
    Generate json used in Azure Stack portal to show volumes performances.
.Description
    This function is used to generate dashboard jsons, which can be uploaded on Azure Stack Dashboard to create related dashboards.
    You can use this function without parameters to create jsons, showing last 1 day metrics, at the current folder.
    To set time range, you can define duration or pair of startTime and endTime.
.Inputs
    Charts' Time range and granularity settings. Json output location setting.
.Outputs
    Three jsons represent count, latency and throughput performance respectively.
.Parameter timeGrain
    The timespan defines the time granularity in charts, in ISO 8601 duration format.
.Parameter outputLocation
    The location to expose generated jsons.
.Parameter duration
    The timespan defines the time range of volume metrics, in ISO 8601 duration format.
.Parameter startTime
    The start time of time range shown on dashboard.
.Parameter endTime
    The start time of time range shown on dashboard.
.Example
    # default json save to spedified location
    Save-AzureStackVolumesPerformanceDashboardJson -outputLocation 'D:\dashboardJsons'
.Example
    # data of last day with 15min interval
    Save-AzureStackVolumesPerformanceDashboardJson -duration "P1D" -timeGrain "PT15M"
.Example
    # date from 4/1 to 4/8 with 1hr interval 
    Save-AzureStackVolumesPerformanceDashboardJson -startTime (Get-date("2019-04-01")) -endTime (Get-date("2019-04-08")) -timeGrain "PT1H"
.Notes
    Author: Azure Stack Azure Monitor Team
    To developers: You can export inner functions in this psm1 file for advanced usage.
#>
function Save-AzureStackVolumesPerformanceDashboardJson {
    [CmdletBinding(DefaultParameterSetName="relativeTime")]
    param (
        [Parameter(ParameterSetName="relativeTime")]
        [ValidateSet('PT30M', 'PT4H', 'PT12H', 'P1D', 'P2D', 'P3D', 'P7D', 'P30D')]
        [string]$duration = 'P1D',
        [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the start time of time range you want to see.")]
        [datetime]$startTime,
        [Parameter(Mandatory=$True, ParameterSetName="absoluteTime", HelpMessage="Please enter the end time of time range you want to see.")]
        [datetime]$endTime,
        [Parameter(Mandatory = $false)]
        [ValidateSet('Automatic', 'PT1M', 'PT1H', 'P1D', 'PT5M', 'PT15M', 'PT30M', 'PT6H', 'PT12H')]
        [string]$timeGrain = 'Automatic',
        [Parameter(Mandatory = $false)]
        [string]$outputLocation = '.'
    )

    if ((Test-Path -Path $outputLocation) -eq $false) {
        throw "Output location not exist."
    }
    
    $resourceId = Get-AzureStackResourceId
    $volumes = Get-AzureStackVolumes -resourceId $resourceId

    if ($timeGrain -eq 'Automatic') {
        if ($PSCmdlet.ParameterSetName -eq "absoluteTime") {
            $timeRange = $endTime - $startTime
        }
        else {
            $timeRange = [System.Xml.XmlConvert]::ToTimeSpan($duration)
        }
        
        if ($timeRange -le (New-TimeSpan -Hours 4)) {
            $timeGrain = "PT1M"
        }
        if ($timeRange -lt (New-TimeSpan -Days 1)) {
            $timeGrain = "PT5M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 1)) {
            $timeGrain = "PT15M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 3)) {
            $timeGrain = "PT30M"
        }
        elseif ($timeRange -le (New-TimeSpan -Days 7)) {
            $timeGrain = "PT1H"
        }
        else {
            $timeGrain = "PT6H"
        }
    }
    $description = "timeGrain: $timeGrain;  `n"

    if ($PSCmdlet.ParameterSetName -eq "absoluteTime") {
        if ($startTime -gt $endTime) {
            throw ("StartTime should less than EndTime!")
        }
        if ($startTime -gt $(Get-Date)) {
            throw ("StartTime should less than Now!")
        }
        $description += "startTime: $($startTime.ToString('o'));  `nendTime: $($endTime.ToString('o'));  `n"
        @("Throughput", "Count", "Latency") | ForEach-Object {
            Get-DashboardVolumesJson -metricType $_ -startTime $startTime.ToString('o') -endTime $endTime.ToString('o') -timeGrain $timeGrain -description $description -resourceId $resourceId -volumes $volumes |
                ConvertTo-Json -Depth 100 > $($outputLocation.TrimEnd('\') + '\' + $_ + "VolumesDashboard_customTime.json")
        }
    }
    else {
        $description += "duration: $duration;  `n"
        $durationTotalMilliseconds = ([System.Xml.XmlConvert]::ToTimeSpan($duration)).TotalMilliseconds
        @("Throughput", "Count", "Latency") | ForEach-Object {
            Get-DashboardVolumesJson -metricType $_ -duration $durationTotalMilliseconds -timeGrain $timeGrain -description $description -resourceId $resourceId -volumes $volumes |
                ConvertTo-Json -Depth 100 > $($outputLocation.TrimEnd('\') + '\' + $_ + "VolumesDashboard_"  + $duration + ".json")
        }
    }
}

function Send-Request()
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$endpoint
    )
    $tokens = @()
    $tokens += try { [Microsoft.IdentityModel.Clients.ActiveDirectory.TokenCache]::DefaultShared.ReadItems()        } catch {}
    $tokens += try { [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.TokenCache.ReadItems() } catch {}
    $token = $tokens |
        Where-Object DisplayableId -eq $context.Account.Id |
        Sort-Object ExpiresOn |
        Select-Object -Last 1

    $header = @{
            'Content-Type'='application\json'
            'Authorization'="Bearer " + $token.AccessToken
    }
    
    $armEndpoint =  $env.Resourcemanagerurl 
    $url = $armEndpoint + $endpoint
    return Invoke-WebRequest -Uri $url -Headers $header -Method Get
}

function Get-AzureStackResourceId {
    [CmdletBinding()]
    param (
    )
    try {
        Write-Host "Getting resource Id from AzureRmSubscription."
        $tenantId = (Get-AzureRmTenant | Where-Object { ([System.Uri]$env.ActiveDirectoryServiceEndpointResourceId).Host.Contains($_.Diretory) } | Select-Object -first 1).Id
        $adminSubscription = Get-AzureRmSubscription -SubscriptionName $adminSubscriptionName -TenantId $tenantId -ErrorAction Stop -Verbose
        $adminSubscription | Select-AzureRmSubscription -ErrorAction Stop | Out-Host
        $location = Get-AzureRmLocation -ErrorAction Stop -Verbose
    }
    catch {
        Write-Error $_
        throw "Please login in AzureRm account. If still happens, check your environment settings in psm1 file."
    }
    "subscriptions/$($adminSubscription.Id)/resourceGroups/System.$($location.location)/providers/Microsoft.Fabric.Admin/fabricLocations/$($location.location)"
}

function Get-AzureStackVolumes {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$resourceId = ( Get-AzureStackResourceId )
    )
    try {
        Write-Host "Getting volumes data from ARM."
        $res = Send-Request $resourceId/scaleUnits/?api-version=2016-05-01
        $scaleUnits = $($res.Content | ConvertFrom-Json).value

        $res = Send-Request $resourceId/scaleUnits/$($scaleUnits.name.Split('/')[-1])/storageSubSystems?api-version=2018-10-01
        $subsystems = $($res.Content | ConvertFrom-Json).value

        $res = Send-Request $resourceId/scaleUnits/$($scaleUnits.name.Split('/')[-1])/storageSubSystems/$($subsystems.name.Split('/')[-1])/volumes?api-version=2018-10-01
        $volumes = $($res.Content | ConvertFrom-Json).value
    }
    catch {
        Write-Error $_.ToString()
        Write-Error "Cannot fetch data from ARM."
    }
    $volumes
}

function Get-volumesByType {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$resourceId = ( Get-AzureStackResourceId ),
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [array]$volumes = ( Get-AzureStackVolumes -resourceId $resourceId ),
        [Parameter(Mandatory = $false)]
        [array]$volumeTypes = @("ObjStore", "Infrastructure", "VmTemp")
    )
    if ($volumes.Count -eq 0) {
        return
    }

    $volumesByType = @{}

    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = New-Object 'Collections.Generic.List[Tuple[String,String]]'
    }

    $volumes | ForEach-Object {
        $labelPrefix = [regex]::match($_.properties.volumeLabel, '(.*)_.*').Groups[1].Value
        if ($volumeTypes.Contains($labelPrefix)) {
            $volumeLocalName = [regex]::match($_.properties.volumeLocalName, '.*\/(.*)').Groups[1].Value
            $volumesByType.$labelPrefix.add([Tuple]::Create($volumeLocalName, $_.properties.volumeLabel))
        }
    }

    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = $volumesByType.$_ | Sort-Object Item2
    }

    $volumesByType
}

function Get-DashboardVolumesJson {
    [CmdletBinding(DefaultParameterSetName="relativeTime")]
    param (
        [Parameter(Mandatory = $false)]
        [string]$resourceId = ( Get-AzureStackResourceId ),
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [array]$volumes = ( Get-AzureStackVolumes -resourceId $resourceId ),
        [Parameter(Mandatory = $false)]
        [array]$volumeTypes = @("ObjStore", "Infrastructure", "VmTemp"),
        [Parameter(ParameterSetName="relativeTime")]
        [Double]$duration = 86400000,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$startTime,
        [Parameter(ParameterSetName="absoluteTime")]
        [string]$endTime,
        [Parameter(Mandatory = $false)]
        [string]$timeGrain = "PT15M",
        [Parameter(Mandatory = $false)]
        [ValidateSet("Throughput", "Count", "Latency")]
        [string]$metricType = "Throughput",
        [Parameter(Mandatory = $false)]
        [string]$description = ""
    )

    if ($volumes.Count -eq 0) {
        return
    }

    $volumesByType = @{}

    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = New-Object 'Collections.Generic.List[Tuple[String,String]]'
    }

    $volumes | ForEach-Object {
        $labelPrefix = [regex]::match($_.properties.volumeLabel, '(.*)_.*').Groups[1].Value
        if ($volumeTypes.Contains($labelPrefix)) {
            $volumeLocalName = [regex]::match($_.properties.volumeLocalName, '.*\/(.*)').Groups[1].Value
            $volumesByType.$labelPrefix.add([Tuple]::Create($volumeLocalName, $_.properties.volumeLabel))
        }
    }

    $volumeTypes | ForEach-Object {
        $volumesByType.$_ = $volumesByType.$_ | Sort-Object Item2
    }

    Write-Host "Generating dashboard json."

    # change dashboard title/name 
    $dashboardBody = $Script:dashboardBody.Replace("<resourceIdToBeReplaced>", '/' + $resourceId) | ConvertFrom-Json
    $dashboardBody.name = $dashboardBody.tags."hidden-title" = "Volumes Operation " + $metricType

    #size of tile
    $tileColSpan = 6
    $tileRowSpan = 4

    $tileTemplate = $Script:tileTemplate.Replace("<resourceIdToBeReplaced>", '/' + $resourceId) | ConvertFrom-Json
    # set tile size
    $tileTemplate.position.colSpan = $tileColSpan
    $tileTemplate.position.rowSpan = $tileRowSpan

    $templateChart = $tileTemplate.metadata.inputs[0].value.charts[0]

    # set time range
    $templateChart.timeContext.psobject.properties.remove("relative")
    $templateChart.timeContext.psobject.properties.remove("absolute")
    if ($PSCmdlet.ParameterSetName -eq "relativeTime") {
        $templateChart.timeContext | Add-Member -MemberType NoteProperty -Name "relative" -Value ([psCustomObject]@{'duration'=$duration})
    }
    else {
        $templateChart.timeContext | Add-Member -MemberType NoteProperty -Name "absolute" -Value ([psCustomObject]@{'startTime'=$startTime; 'endTime'=$endTime})
    }

    # set time granularity
    $chartGrainMap = @{'Automatic' = 1; 'PT1M' = 2; 'PT1H' = 3; 'P1D' = 4; 'PT5M' = 7; 'PT15M' = 8; 'PT30M' = 9; 'PT6H' = 10; 'PT12H' = 11}
    $templateChart.itemDataModel.appliedISOGrain = $templateChart.timeContext.options.appliedISOGrain = $timeGrain
    $templateChart.timeContext.options.grain = $chartGrainMap.$timeGrain


    #change aggregation type
    $aggregationTypeofMetric = @{'Throughput' = 'Sum'; 'Count' = 'Sum'; 'Latency' = 'Avg'}
    $aggregationType = $aggregationTypeofMetric.$metricType
    if ($aggregationType -eq "Sum") {
        $templateChart.metrics | ForEach-Object { $_.aggregationType = 4 }
        $templateChart.itemDataModel.metrics | ForEach-Object {$_.metricAggregation = 1 }
    }
    else {
        $templateChart.metrics | ForEach-Object { $_.aggregationType = 1 }
        $templateChart.itemDataModel.metrics | ForEach-Object {$_.metricAggregation = 4 }
    }

    #change metrics name 
    $templateChart.metrics[0].name = $templateChart.itemDataModel.metrics[0].id.name.id = "VolumeOperations" + $( if ($metricType -eq "Count") {""} else {$metricType} ) + "Read"
    $templateChart.metrics[1].name = $templateChart.itemDataModel.metrics[1].id.name.id = "VolumeOperations" + $( if ($metricType -eq "Count") {""} else {$metricType} ) + "Write"
    $templateChart.itemDataModel.metrics[0].id.name.displayName = $metricType + "Read"
    $templateChart.itemDataModel.metrics[1].id.name.displayName = $metricType + "Write"

    # set markDown board content
    $dashboardBody.properties.lenses."0".parts."0".metadata.settings.content.settings.content += $aggregationType + " Volume Operations " + $metricType + " by  `n" + $description

    # the tile of total performance
    $tileJson = $tileTemplate | ConvertTo-Json -depth 100 | ConvertFrom-Json
    $tileJson.metadata.inputs[0].value.charts[0].itemDataModel.psobject.properties.remove("filters")
    $dashboardBody.properties.lenses."0".parts | Add-Member -MemberType NoteProperty -Name "1" -Value $tileJson

    # create tiles
    for ($($rowNum = 0; $tileNum = 2); $rowNum -lt $volumeTypes.Count; $rowNum++) {   
        $tileTemplate.position.x = $tileColSpan * ($rowNum + 1)
        for ($colNum = 0; $colNum -lt $volumesByType.($volumeTypes[$rowNum]).Count; $colNum++) {
            $tileName = $volumesByType.($volumeTypes[$rowNum])[$colNum].Item2
            $tileJson = $tileTemplate | ConvertTo-Json -depth 100 | ConvertFrom-Json
            $tileJson.position.y = $tileRowSpan * $colNum
            $chart = $tileJson.metadata.inputs[0].value.charts[0]
            $chart.title = $chart.itemDataModel.title = $tileName
            $chart.itemDataModel.filters.OperandFilters[0].OperandSelectedValues[0] = $volumesByType.($volumeTypes[$rowNum])[$colNum].Item1         
            $dashboardBody.properties.lenses."0".parts | Add-Member -MemberType NoteProperty -Name $tileNum -Value $tileJson
            $tileNum++
        }        
    }
    $dashboardBody 
}

function Save-DashboardVolumesJson {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$resourceId =  (Get-AzureStackResourceId) ,
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [array]$volumes = (Get-AzureStackVolumes -resourceId $resourceId),
        [Parameter(Mandatory = $false)]
        [string]$OutputFileName = "VolumesDashboard.json"
    )
    Write-Host $resourceId
    Get-DashboardVolumesJson -volumes $volumes | ConvertTo-Json -Depth 100 > $OutputFileName
}

#========Module Initalize========#
$env = Get-AzureRmEnvironment -Name $envName
$context = Get-AzureRmContext 

if (!((Test-Path -Path ($jsonTemplateLocation.TrimEnd('\') + '\dashboardBody.json'))  -and  (Test-Path -Path ($jsonTemplateLocation.TrimEnd('\') + '\tileTemplate.json' )))) {
    throw "Output location not exist."
}
$dashboardBody = Get-Content ($jsonTemplateLocation.TrimEnd('\') + '\dashboardBody.json') | Out-String 
$tileTemplate = Get-Content ($jsonTemplateLocation.TrimEnd('\') + '\tileTemplate.json') | Out-String 

# if user hadn't added and login to AzureRmEnvironment, exit
if ($null -eq $context.Account) {
    throw "Please login in AzureRm account first."
}

Export-ModuleMember Save-AzureStackVolumesPerformanceDashboardJson