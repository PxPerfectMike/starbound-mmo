# Starbound MMO Log Debugger
# Finds and displays relevant log entries from Starbound

$possibleLogPaths = @(
    "C:\Program Files (x86)\Steam\steamapps\common\Starbound\storage\starbound.log",
    "C:\Program Files\Steam\steamapps\common\Starbound\storage\starbound.log",
    "D:\Steam\steamapps\common\Starbound\storage\starbound.log",
    "D:\SteamLibrary\steamapps\common\Starbound\storage\starbound.log",
    "E:\Steam\steamapps\common\Starbound\storage\starbound.log",
    "E:\SteamLibrary\steamapps\common\Starbound\storage\starbound.log",
    "$env:USERPROFILE\Documents\Starbound\storage\starbound.log"
)

$logFile = $null

foreach ($path in $possibleLogPaths) {
    if (Test-Path $path) {
        $logFile = $path
        Write-Host "Found Starbound log at: $path" -ForegroundColor Green
        break
    }
}

if (-not $logFile) {
    Write-Host "Could not find Starbound log file. Checked:" -ForegroundColor Red
    foreach ($path in $possibleLogPaths) {
        Write-Host "  - $path" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Please provide the path to your Starbound installation:" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "=== Last 100 lines of Starbound log ===" -ForegroundColor Cyan
Get-Content $logFile -Tail 100

Write-Host ""
Write-Host "=== MMO Market specific entries ===" -ForegroundColor Cyan
Select-String -Path $logFile -Pattern "MMO Market|mmo_market|market\.lua|marketui" -AllMatches | Select-Object -Last 50

Write-Host ""
Write-Host "=== Recent Errors ===" -ForegroundColor Cyan
Select-String -Path $logFile -Pattern "Error|Exception|failed|cannot" -AllMatches | Select-Object -Last 30

Write-Host ""
Write-Host "=== Script/Lua Errors ===" -ForegroundColor Cyan
Select-String -Path $logFile -Pattern "lua|script|ScriptPane" -AllMatches | Select-Object -Last 30
