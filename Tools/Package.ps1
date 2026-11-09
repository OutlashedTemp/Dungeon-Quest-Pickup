# Package.ps1
# Builds Releases\DungeonQuestTracker-<version>.zip, ready to upload to CurseForge / Wago.
# The zip contains only the addon folder (plus LICENSE, README, CHANGELOG inside it).
#
# Usage: .\Tools\Package.ps1

$root      = Split-Path $PSScriptRoot -Parent
$addonName = "DungeonQuestTracker"
$addonPath = Join-Path $root $addonName
$tocPath   = Join-Path $addonPath "$addonName.toc"

$versionLine = Select-String -Path $tocPath -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) {
    Write-Error "No '## Version:' line in $tocPath"
    exit 1
}
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$staging = Join-Path ([System.IO.Path]::GetTempPath()) "dqt-package-$version"
$releases = Join-Path $root "Releases"
$zipPath = Join-Path $releases "$addonName-$version.zip"

if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $staging $addonName) | Out-Null
New-Item -ItemType Directory -Path $releases -Force | Out-Null

Copy-Item -Path (Join-Path $addonPath "*") -Destination (Join-Path $staging $addonName) -Recurse
foreach ($doc in "LICENSE", "README.md", "CHANGELOG.md") {
    Copy-Item -Path (Join-Path $root $doc) -Destination (Join-Path $staging $addonName)
}

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path (Join-Path $staging $addonName) -DestinationPath $zipPath
Remove-Item $staging -Recurse -Force

Write-Host "Built: $zipPath" -ForegroundColor Green
