<#
.SYNOPSIS
    Starts Docker Compose services with optional build enforcement.
#>
param(
    [Parameter(Mandatory = $false)]
    [switch]$ForceBuild
)

$ErrorActionPreference = 'Stop'

try {
    # Check if Docker engine is running
    if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue) -and -not (docker info -f '{{.ServerVersion}}' 2>$null)) {
        Write-Error "Docker engine is not running. Please start Docker and try again."
    }

    if ($ForceBuild) {
        Write-Host "🚀 Starting services with a fresh build..." -ForegroundColor Cyan
        docker compose up -d --build --force-recreate
    }
    else {
        Write-Host "🚀 Starting services..." -ForegroundColor Cyan
        docker compose up -d
    }

    Write-Host "✅ Services are up and running!" -ForegroundColor Green
}
catch {
    Write-Error "Failed to start services: $($_.Exception.Message)"
}
