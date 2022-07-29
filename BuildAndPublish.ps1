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
        [void]$buildList.Add($lifecycleTag, [int]$version)
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
$node_full_ver = $versionTags[$node_major_ver]
$arguments = @(
    "build"
    "--build-arg BASE_IMAGE_NAME=$env:BASE_IMAGE_NAME"
    "--build-arg BASE_IMAGE_TAG=$env:BASE_IMAGE_TAG"
    "--build-arg NODE_VERSION=$node_full_ver"
    "-t $env:DOCKER_HUB_USERNAME/$env:REPO_NAME:$env:NODE_VERSION-$env:BASE_IMAGE_TAG"
    "-t $env:DOCKER_HUB_USERNAME/$env:REPO_NAME:$node_major_ver-$env:BASE_IMAGE_TAG"
    "-t $env:DOCKER_HUB_USERNAME/$env:REPO_NAME:$node_full_ver-$env:BASE_IMAGE_TAG"
    "."
)

Start-Process -FilePath docker.exe -ArgumentList $arguments -Wait -NoNewWindow -ErrorAction Stop

Write-Host "Publish to Docker Hub ..."

$loginArgs = @(
    "login"
    "--username"
    $env:DOCKER_HUB_USERNAME
    "--password"
    $env:DOCKER_HUB_PASSWORD
)

Start-Process -FilePath docker.exe -ArgumentList $loginArgs -Wait -NoNewWindow -ErrorAction Stop

$pushArgs = @(
    "image"
    "push"
    "--all-tags"
    "$env:DOCKER_HUB_USERNAME/$env:REPO_NAME"
)

Start-Process -FilePath docker.exe -ArgumentList $pushArgs -Wait -NoNewWindow -ErrorAction Stop
