$InformationPreference = 'Continue'

Write-Information "Script Runner"
Write-Information "PowerShell➡️$($PSVersionTable.PSVersion)"
Write-Information "Edition➡️$($PSVersionTable.PSEdition)"
Write-Information "OS➡️$($PSVersionTable.OS)"
Write-Information "Platform➡️$($PSVersionTable.Platform)"

if ($false -eq (Test-Path .\schedule.json)) {
    Write-Error -Message "Unable to locate release schedule!" -ErrorAction Stop
}

if ($false -eq (Test-Path .\index.json)) {
    Write-Error -Message "Unable to locate release list!" -ErrorAction Stop
}

$today = Get-Date
$versionTable = ( Get-Content .\schedule.json | ConvertFrom-Json -AsHashtable )
$releaseArray = ( Get-Content .\index.json | ConvertFrom-Json )
$buildList = @{}
$versionTags = @{}

foreach ($key in $versionTable.Keys) {
    $item = $versionTable[$key]
    $startDate = [datetime]::ParseExact($item.start, 'yyyy-MM-dd', $null)
    $endDate = [datetime]::ParseExact($item.end, 'yyyy-MM-dd', $null)
    $version = $key -replace "[^0-9\.]" , ''
    Write-Information "Determine release status for $key"

    $isLts = $false
    $isMaintenance = $false
    
    if (($startDate -le $today) -and ($endDate -ge $today)) {
        if ($item.lts) {
            $ltsDate = [datetime]::ParseExact($item.lts, 'yyyy-MM-dd', $null)
            $isLts = $ltsDate -le $today
            if ($isLts) {
                Write-Information "✔️LTS since $ltsDate"
            }
            else {
                Write-Information "❌LTS before $ltsDate"
            }
        }

        if ($item.maintenance) {
            $maintenanceDate = [datetime]::ParseExact($item.maintenance, 'yyyy-MM-dd', $null)
            $isMaintenance = $maintenanceDate -le $today
            if ($isLts) {
                Write-Information "✔️Maintenance since $maintenanceDate"
            }
            else {
                Write-Information "❌Maintenance before $maintenanceDate"
            }
        }

        if ($isMaintenance) {
            $lifecycleTag = "maintenance"
            Write-Information "Release is maintenance"
        }
        elseif ($isLts) {
            $lifecycleTag = "lts"
            Write-Information "Release is lts"
        }
        else {
            $lifecycleTag = "current"
            Write-Information "Release is current"
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
        Write-Information "Current $lifecycleTag is $($buildList[$lifecycleTag])"
    }
}

Write-Information "Tag and version hashtable"
foreach ($tag in $buildList.Keys) {
    $ver = $buildList[$tag]
    Write-Information "$tag➡️$ver"
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

    Write-Information "Build INFO"
    Write-Information "Tag➡️$env:NODE_VERSION"
    Write-Information "Major➡️$node_major_ver"
    Write-Information "Full➡️$node_full_ver"

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

#    Start-Process -FilePath docker.exe -ArgumentList $buildArg -Wait -NoNewWindow -ErrorAction Stop

#    Add-Content -Value "DO_PUBLISH=true" -Path $env:GITHUB_OUTPUT
}
else {
#    Add-Content -Value "DO_PUBLISH=false" -Path $env:GITHUB_OUTPUT
}

