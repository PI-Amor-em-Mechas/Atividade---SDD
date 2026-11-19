[CmdletBinding()]
param([ValidateRange(1, 9999)][int]$TimeoutSeconds = 0)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
try {
    if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = Get-ConfiguredStopTimeout }
    if (-not (Stop-Launcher $TimeoutSeconds)) { exit 1 }
} catch {
    Write-LauncherLog $_.Exception.Message 'ERRO'
    exit 1
}
