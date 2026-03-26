<#
.SYNOPSIS
    Opens an interactive shell in the dev container.
.PARAMETER Shell
    The shell to launch. Defaults to zsh.
.PARAMETER Command
    Optional command to run instead of an interactive shell.
.EXAMPLE
    .\dc-exec.ps1                        # Interactive zsh
    .\dc-exec.ps1 -Shell bash            # Interactive bash
    .\dc-exec.ps1 -Command "java -version"  # Run a one-off command
#>
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("zsh", "bash")]
    [string]$Shell = "zsh",

    [Parameter(Mandatory = $false)]
    [string]$Command
)

$ErrorActionPreference = 'Stop'

try {
    # Check if Docker engine is running
    if (-not (Get-Process "Docker Desktop" -ErrorAction SilentlyContinue) -and -not (docker info -f '{{.ServerVersion}}' 2>$null)) {
        Write-Error "Docker engine is not running. Please start Docker and try again."
    }

    # Check if the dev container is running
    $status = docker compose ps --status running --format "{{.Name}}" 2>$null | Select-String "dev-env"
    if (-not $status) {
        Write-Error "Dev container is not running. Start it first with .\dc-up.ps1"
    }

    if ($Command) {
        Write-Host "⚡ Running command in dev container..." -ForegroundColor Cyan
        docker compose exec dev bash -c $Command
    }
    else {
        Write-Host "🐚 Attaching to dev container ($Shell)..." -ForegroundColor Cyan
        docker compose exec dev $Shell
    }
}
catch {
    Write-Error "Failed to exec into container: $($_.Exception.Message)"
}