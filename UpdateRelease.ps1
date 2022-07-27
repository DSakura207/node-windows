# Impersonate as an automated updater
$nameArgs = @(
    "config",
    "user.name",
    "AutoUpdater"
)
$emailArgs = @(
    "config",
    "user.email",
    "<>"
)
Start-Process -FilePath git -ArgumentList $nameArgs
Start-Process -FilePath git -ArgumentList $emailArgs

# Remove old release schedule and version list, download new ones.
Remove-Item ./schedule.json -Force
Remove-Item ./index.json -Force
Invoke-WebRequest -Uri $env:NODE_RELEASE_SCHEDULE -UseBasicParsing -OutFile ./schedule.json
Invoke-WebRequest -Uri $env:NODE_RELEASE_VERSION -UseBasicParsing -OutFile ./index.json

# Get git status output.
# Empty means nothing updated.
$gitStatus = (git status --porcelain=v1)

# Update file and emit output for next job.
if ($gitStatus) {
    & "git add ."
    & "git commit -m `"Update release files`""
    & "git push"
    Write-Host "::set-output name=update_required::true"
}
else {
    Write-Host "::set-output name=update_required::false"
}