# Links the repo's mod/ folder into Starbound's mods directory as a junction,
# so edits in the repo (and bridge-written cache files) are what the game loads.
# Run once per machine. Re-running is safe.
#
# Usage: pwsh scripts/deploy-mod.ps1 [-StarboundDir <path>]

param(
	[string]$StarboundDir = 'C:\Program Files (x86)\Steam\steamapps\common\Starbound'
)

$ErrorActionPreference = 'Stop'

$repoMod = Join-Path (Split-Path $PSScriptRoot -Parent) 'mod'
$modsDir = Join-Path $StarboundDir 'mods'
$link = Join-Path $modsDir 'starbound-mmo'

if (-not (Test-Path (Join-Path $StarboundDir 'assets'))) {
	throw "Starbound not found at $StarboundDir (no assets folder). Pass -StarboundDir."
}
if (-not (Test-Path $repoMod)) {
	throw "Repo mod folder not found at $repoMod"
}

New-Item -ItemType Directory -Force $modsDir | Out-Null

$existing = Get-Item $link -ErrorAction SilentlyContinue
if ($existing) {
	if ($existing.LinkType -eq 'Junction' -and $existing.Target -contains $repoMod) {
		Write-Host "Junction already in place: $link -> $repoMod"
		exit 0
	}
	if ($existing.LinkType -eq 'Junction') {
		Write-Host "Replacing junction that pointed at $($existing.Target)"
		$existing.Delete()
	} else {
		throw "$link exists and is a real folder, not a junction. Move it aside first."
	}
}

New-Item -ItemType Junction -Path $link -Target $repoMod | Out-Null
Write-Host "Linked $link -> $repoMod"

# The bridge writes player/market cache files here at runtime; make sure it exists
New-Item -ItemType Directory -Force (Join-Path $repoMod 'cache') | Out-Null
