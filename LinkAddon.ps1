# LinkAddon.ps1
# Links the addon from this dev folder into WoW Forever's AddOns folder (junction).
# Run as Administrator.
#
# Usage: .\LinkAddon.ps1                       (links DungeonQuestTracker)
#        .\LinkAddon.ps1 -AddonName Other -WowRoot "D:\Games\World of Warcraft"

param(
    [string]$AddonName = "DungeonQuestTracker",
    [string]$WowRoot   = "C:\Program Files (x86)\World of Warcraft"
)

$devPath    = Join-Path $PSScriptRoot $AddonName
$addonsPath = Join-Path $WowRoot "_forever_\Interface\AddOns"
$wowPath    = Join-Path $addonsPath $AddonName

if (-not (Test-Path $devPath)) {
    Write-Error "Dev folder not found: $devPath"
    exit 1
}
if (-not (Test-Path $addonsPath)) {
    Write-Error "WoW Forever AddOns folder not found: $addonsPath`nPass -WowRoot if WoW is installed elsewhere."
    exit 1
}
if (Test-Path $wowPath) {
    Write-Error "Already exists in AddOns: $wowPath`nRemove it first if you want to re-link."
    exit 1
}

New-Item -ItemType Junction -Path $wowPath -Target $devPath | Out-Null
Write-Host "Linked: $wowPath -> $devPath" -ForegroundColor Green
