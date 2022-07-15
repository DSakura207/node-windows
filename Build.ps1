if ($false -eq (Test-Path .\schedule.json)) {
    Write-Error -Message "Unable to locate release schedule!" -ErrorAction Stop
}

if ($false -eq (Test-Path .\index.json)) {
    Write-Error -Message "Unable to locate release list!" -ErrorAction Stop
}

$today = Get-Date
$versionTable = ( Get-Content .\schedule.json | ConvertFrom-Json -AsHashtable)
$releaseArray = ( Get-Content .\index.json | ConvertFrom-Json )
$buildList = @{}
$versionTags = @{}

foreach ($item in $versionTable.GetEnumerator()) {
    $startDate = [datetime]::ParseExact($item.Value.start, 'yyyy-MM-dd', $null)
    $endDate = [datetime]::ParseExact($item.Value.end, 'yyyy-MM-dd', $null)
    $version = $item.Key -replace "[^0-9\.]" , ''
    if (($startDate -le $today) -and ($endDate -ge $today)) {
        if ($item.Value.lts) {
            $ltsDate = [datetime]::ParseExact($item.Value.lts, 'yyyy-MM-dd', $null)
            $isLts = $ltsDate -le $today
        }
        if ($item.Value.maintenance) {
            $maintenanceDate = [datetime]::ParseExact($item.Value.maintenance, 'yyyy-MM-dd', $null)
            $isMaintenance = $maintenanceDate -le $today
        }

        if ($isMaintenance) {
            $lifecycleTag = "maintenance"
        }
        elseif ($isLts) {
            $lifecycleTag = "lts"
        }
        else {
            $lifecycleTag = "current"
        }
        [void]$buildList.Add($lifecycleTag, $version)
    }
}

$releaseArray | Foreach-Object -ThrottleLimit 5 -Parallel {
    $bdList = $using:buildList
    $vList = $using:versionTags
    $pos = $_.version.IndexOf(".")
    $releaseVer = $_.version.Substring(0, $pos) -replace "[^0-9\.]" , ''
    $fullreleaseVer = [System.Management.Automation.SemanticVersion]($_.version -replace "[^0-9\.]" , '')
    if ($bdList.ContainsValue($releaseVer)) {
        if ($vList.ContainsKey($fullreleaseVer.Major)) {
            if ($vList[$fullreleaseVer.Major] -lt $fullreleaseVer) {
                $vList.Add($fullreleaseVer.Major, $fullreleaseVer)
            }
        }
        else {
            $vList.Add($fullreleaseVer.Major, $fullreleaseVer)
        }
    }
}

$node_major_ver = $buildList[$env:NODE_VERSION]
$node_full_ver = $versionTags[$node_major_ver]

Write-Host "Build commandline:"
Write-Host "docker build `
                    --build-arg BASE_IMAGE_NAME=$env:BASE_IMAGE_NAME `
                    --build-arg BASE_IMAGE_TAG=$env:BASE_IMAGE_TAG `
                    --build-arg NODE_VERSION=$node_full_ver `
                    -t node-windows:$env:NODE_VERSION `
                    -t node-windows:$node_major_ver `
                    -t node-windows:$node_full_ver ." 