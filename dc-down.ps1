<#
.SYNOPSIS
    Stops and removes Docker Compose containers and networks.
#>
param(
    [Parameter(Mandatory = $false)]
    [switch]$WithVolumes
)

$ErrorActionPreference = 'Stop'

try {
    $cmdArgs = @("down", "--remove-orphans")

    if ($WithVolumes) {
        # Safety check for volume deletion
        $confirm = Read-Host "Are you sure you want to delete VOLUMES? This is destructive (y/N)"
        if ($confirm -eq 'y') {
            Write-Host "🧹 Cleaning up containers and volumes..." -ForegroundColor Yellow
            $cmdArgs += "-v"
        } else {
            Write-Host "Skipping volume deletion. Only removing containers..." -ForegroundColor Gray
        }
    } else {
        Write-Host "🛑 Stopping and removing containers..." -ForegroundColor Yellow
    }

    docker compose @cmdArgs
    Write-Host "✨ Cleanup complete." -ForegroundColor Green
}
catch {
    Write-Error "Failed to shut down services: $($_.Exception.Message)"
}