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
    Write-Debug "Determine release status for $version"
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
            Write-Debug "Release is maintenance"
        }
        elseif ($isLts) {
            $lifecycleTag = "lts"
            Write-Debug "Release is lts"
        }
        else {
            $lifecycleTag = "current"
            Write-Debug "Release is current"
        }
        if ($buildList.ContainsKey($lifecycleTag)) {
            [int]$curTagVersion = $buildList[$lifecycleTag]
            if ($curTagVersion -le [int]$version) {
                $buildList[$lifecycleTag] = [int]$version
            }
        }
        else {
            [void]$buildList.Add($lifecycleTag, [int]$version)
        }
    }
}

foreach ($item in $releaseArray) {
    $fullreleaseVer = [System.Management.Automation.SemanticVersion]::Parse($item.version.Substring(1))
    if ($buildList.ContainsValue($fullreleaseVer.Major)) {
        if ($versionTags.ContainsKey($fullreleaseVer.Major)) {
            if ($versionTags[$fullreleaseVer.Major] -lt $fullreleaseVer) {
                $versionTags.Add($fullreleaseVer.Major, $fullreleaseVer)
            }
        }
        else {
            $versionTags.Add($fullreleaseVer.Major, $fullreleaseVer)
        }
    }
}

$node_major_ver = $buildList[$env:NODE_VERSION]

# Sometimes a version tag cannot be matched to a version.
# Wrap build commands in an if block to prevent a null error.
if ($node_major_ver) {
    $node_full_ver = $versionTags[$node_major_ver]

    Write-Debug "===Build info==="
    Write-Debug "Version tag: $env:NODE_VERSION"
    Write-Debug "Major version: $node_major_ver"
    Write-Debug "Full version: $node_full_ver"

    $buildArg = @(
        "build"
        "--build-arg BASE_IMAGE_NAME=$env:BASE_IMAGE_NAME"
        "--build-arg BASE_IMAGE_TAG=$env:BASE_IMAGE_TAG"
        "--build-arg NODE_VERSION=$node_full_ver"
        "-t $env:DOCKER_HUB_USERNAME/$($env:REPO_NAME):$env:NODE_VERSION-$env:BASE_IMAGE_TAG"
        "-t $env:DOCKER_HUB_USERNAME/$($env:REPO_NAME):$node_major_ver-$env:BASE_IMAGE_TAG"
        "-t $env:DOCKER_HUB_USERNAME/$($env:REPO_NAME):$node_full_ver-$env:BASE_IMAGE_TAG"
        "."
    )

    Start-Process -FilePath docker.exe -ArgumentList $buildArg -Wait -NoNewWindow -ErrorAction Stop
}


