param([Parameter(Mandatory)][ValidateSet('Spring','Frontend','Stub','Worker')][string]$Service,
      [Parameter(Mandatory)][guid]$Instance)
$ErrorActionPreference = 'Stop'
Add-Type -Path (Join-Path $PSScriptRoot 'launcher-supervisor.cs')
exit [LauncherSupervisor]::Run($env:RASTREIO_EXECUTABLE, $env:RASTREIO_ARGUMENTS,
    $env:RASTREIO_DIRECTORY, $env:RASTREIO_LOG, $Instance.ToString(), $Service)
