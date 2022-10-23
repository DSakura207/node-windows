# Impersonate as an automated updater, configure autocrlf
Start-Process -FilePath "git" -ArgumentList "config", "user.name", "AutoUpdater" -NoNewWindow -Wait
Start-Process -FilePath "git" -ArgumentList "config", "user.email", "<>" -NoNewWindow -Wait
Start-Process -FilePath "git" -ArgumentList "config", "core.autocrlf", "true" -NoNewWindow -Wait

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
    Start-Process -FilePath "git" -ArgumentList "add", "." -NoNewWindow -Wait
    Start-Process -FilePath "git" -ArgumentList "commit", "-m", "`"Update release files`"" -NoNewWindow -Wait
    Start-Process -FilePath "git" -ArgumentList "push" -NoNewWindow -Wait
    Write-Host "New changes checked in:"
    Write-Host $gitStatus
    Add-Content -Value "DO_BUILD=true" -Path $env:GITHUB_OUTPUT
}
else {
    Write-Host "No new release detected."
    Add-Content -Value "DO_BUILD=false" -Path $env:GITHUB_OUTPUT
}