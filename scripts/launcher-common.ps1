$script:Root = Split-Path -Parent $PSScriptRoot
$script:Folders = @{
    Spring = Join-Path $script:Root 'api-envios'
    Frontend = Join-Path $script:Root 'framework-worker-entregas'
    Worker = Join-Path $script:Root 'Worker Python de rastreamento'
}
$script:Runtime = Join-Path $script:Root '.launcher'
$script:Logs = Join-Path $script:Runtime 'logs'
$script:StateFile = Join-Path $script:Runtime 'state.json'
$script:Supervisor = Join-Path $PSScriptRoot 'launcher-supervisor.ps1'
$script:PowerShellExe = Join-Path $PSHOME 'powershell.exe'
$script:Services = @('Worker', 'Frontend', 'Stub', 'Spring')
$script:Secrets = @()

function Read-LocalConfiguration([string]$Path) {
    $values = @{}
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $number = 0
        foreach ($line in Get-Content -Encoding UTF8 -LiteralPath $Path) {
            $number++
            if ($line -match '^\s*(#|$)') { continue }
            if ($line -notmatch '^\s*([A-Z][A-Z0-9_]*)\s*=(.*)$') {
                throw "launcher.env: linha $number inválida (use CHAVE=valor)."
            }
            $value = $Matches[2].Trim()
            if ($value.Length -ge 2 -and ($value[0] -in "'", '"') -and $value[0] -eq $value[-1]) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $values[$Matches[1]] = $value
        }
    }
    return $values
}

function Get-LauncherConfiguration([string]$Path = (Join-Path $script:Root 'launcher.env')) {
    $values = Read-LocalConfiguration $Path
    $defaults = @{
        DB_HOST = 'localhost'; DB_PORT = '3306'; DB_NAME = 'amor_em_mechas'; DB_USER = 'rastreamento_app'; DB_PASSWORD = ''
        SPRING_PORT = '8080'; FRONTEND_PORT = '5173'; STUB_PORT = '8081'
        STARTUP_TIMEOUT_SECONDS = '180'; STOP_TIMEOUT_SECONDS = '12'
        TRACKING_TIMEOUT_SECONDS = '10'; POLL_INTERVAL_SECONDS = '5'; TRACKING_API_TOKEN = ''
    }
    $result = @{}
    foreach ($key in $defaults.Keys) {
        $fromEnv = [Environment]::GetEnvironmentVariable($key, 'Process')
        $endpointKey = $key -in 'DB_HOST','DB_PORT'
        $result[$key] = if ($null -ne $fromEnv -and (-not $endpointKey -or $fromEnv.Trim())) { $fromEnv }
            elseif ($values.ContainsKey($key) -and (-not $endpointKey -or $values[$key].Trim())) { $values[$key] } else { $defaults[$key] }
    }
    $result.DB_HOST_SOURCE = if (([string][Environment]::GetEnvironmentVariable('DB_HOST', 'Process')).Trim()) { 'ambiente' }
        elseif ($values.DB_HOST) { 'launcher.env' } else { 'padrão' }
    if ($values.DB_HOST) {
        $result.DB_FILE_HOST = $values.DB_HOST
        $result.DB_FILE_PORT = if ($values.DB_PORT) { $values.DB_PORT } else { $defaults.DB_PORT }
    }
    if (-not $result.DB_HOST) { $result.DB_HOST = 'localhost' }
    if (-not $result.DB_PORT) { $result.DB_PORT = '3306' }
    $script:Secrets = @($result.DB_PASSWORD, $result.TRACKING_API_TOKEN)
    Test-LauncherConfiguration $result
    return $result
}

function Test-LauncherConfiguration($Result) {
    foreach ($key in 'DB_PORT', 'SPRING_PORT', 'FRONTEND_PORT', 'STUB_PORT') {
        if ($result[$key] -notmatch '^\d{1,5}$' -or [int]$result[$key] -lt 1 -or [int]$result[$key] -gt 65535) {
            throw "$key deve ser uma porta entre 1 e 65535."
        }
    }
    foreach ($key in 'STARTUP_TIMEOUT_SECONDS', 'STOP_TIMEOUT_SECONDS', 'TRACKING_TIMEOUT_SECONDS', 'POLL_INTERVAL_SECONDS') {
        if ($result[$key] -notmatch '^\d{1,4}$' -or [int]$result[$key] -lt 1) {
            throw "$key deve ser um número inteiro positivo em segundos."
        }
    }
    if ($result.DB_HOST -notmatch '^[A-Za-z0-9][A-Za-z0-9.-]*$' -or $result.DB_NAME -notmatch '^[A-Za-z0-9_-]+$') {
        throw 'Use um hostname ou IPv4 para DB_HOST e um nome simples para DB_NAME.'
    }
}

function Mask-Secret([string]$Text) {
    foreach ($secret in $script:Secrets) {
        if ($secret) { $Text = $Text.Replace($secret, '***') }
    }
    $Text = $Text -replace '(?i)(\b(?:DB_PASSWORD|TRACKING_API_TOKEN)\s*[=:]\s*|\bBearer\s+)\S+', '$1***'
    return $Text -replace '(https?://)[^/\s@]+@', '$1***@'
}

function Write-LauncherLog([string]$Message, [string]$Tag = 'INFO') {
    $safe = Mask-Secret $Message
    Write-Host "[$Tag] $safe"
    if (-not (Test-Path -LiteralPath $script:Logs)) { return }
    $file = Join-Path $script:Logs 'launcher.log'
    if ((Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -ge 1048576) {
        Move-Item -LiteralPath $file -Destination "$file.1" -Force
    }
    Add-Content -Encoding UTF8 -LiteralPath $file -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$Tag] $safe"
}

function Use-Environment([hashtable]$Values, [scriptblock]$Action) {
    $previous = @{}
    try {
        foreach ($name in $Values.Keys) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $Values[$name], 'Process')
        }
        & $Action
    } finally {
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    }
}

function Invoke-Tool([string]$Path, [string[]]$Arguments) {
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $Path @Arguments 2>&1)
        return @{ Code = $LASTEXITCODE; Text = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine }
    } catch {
        return @{ Code = 1; Text = 'Falha ao executar a ferramenta.' }
    }
}

function Find-Tool([string[]]$Names) {
    foreach ($name in $Names) {
        $cmd = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source -notmatch '\\WindowsApps\\') { return $cmd.Source }
    }
}

function Find-Maven([string]$Directory) {
    $wrapper = Join-Path $Directory 'mvnw.cmd'
    if (Test-Path -LiteralPath $wrapper -PathType Leaf) { return $wrapper }
    Find-Tool @('mvn.cmd', 'mvn.exe', 'mvn')
}

function Get-JavaMajor([string]$Text) {
    if ($Text -match '(?:java|openjdk)\s+(?:version\s+)?["]?(?:1\.)?(\d+)') { return [int]$Matches[1] }
    return 0
}

function Test-NodeVersion([string]$Text) {
    if ($Text -notmatch 'v(\d+)\.(\d+)\.(\d+)') { return $false }
    $major = [int]$Matches[1]; $minor = [int]$Matches[2]
    return ($major -eq 20 -and $minor -ge 19) -or ($major -eq 22 -and $minor -ge 12) -or $major -ge 23
}

function Find-Python {
    foreach ($candidate in 'py.exe', 'python.exe', 'python3.exe') {
        $path = Find-Tool @($candidate)
        if (-not $path) { continue }
        $prefix = if ($candidate -eq 'py.exe') { @('-3') } else { @() }
        $version = Invoke-Tool $path (@($prefix | Where-Object { $_ }) + @('--version'))
        if ($version.Code -eq 0 -and $version.Text -match 'Python 3\.(\d+)\.\d+' -and [int]$Matches[1] -ge 10) {
            return @{ Path = $path; Prefix = @($prefix | Where-Object { $_ }); Version = $version.Text.Trim() }
        }
    }
}

function Get-TcpStatus([string]$HostName, [int]$Port, [int]$Milliseconds = 1200) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $pending = $client.ConnectAsync($HostName, $Port)
        if (-not $pending.Wait($Milliseconds)) { return 'Timeout' }
        if ($client.Connected) { return 'Open' }
        return 'Unavailable'
    } catch {
        $cause = $_.Exception.GetBaseException()
        if ($cause -is [Net.Sockets.SocketException]) {
            if ($cause.SocketErrorCode -eq [Net.Sockets.SocketError]::ConnectionRefused) { return 'Closed' }
            if ($cause.SocketErrorCode -eq [Net.Sockets.SocketError]::TimedOut) { return 'Timeout' }
        }
        return 'Unavailable'
    } finally { $client.Dispose() }
}

function Test-TcpPort([string]$HostName, [int]$Port, [int]$Milliseconds = 1200) {
    return (Get-TcpStatus $HostName $Port $Milliseconds) -eq 'Open'
}

function Get-PortOwner([int]$Port) {
    $entry = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($entry) { return [int]$entry.OwningProcess }
    try {
        foreach ($line in (netstat.exe -ano -p TCP)) {
            if ($line -match "^\s*TCP\s+\S+:$Port\s+\S+:0\s+\S+\s+(\d+)\s*$") { return [int]$Matches[1] }
        }
    } catch { return 0 }
    return 0
}

function Get-StubUrl([int]$Port) {
    if ($Port -eq 8080 -or $Port -lt 1 -or $Port -gt 65535) { throw 'STUB_PORT deve ser válida e diferente de 8080.' }
    return "http://127.0.0.1:$Port/rastreamento"
}

function Get-LocalHttp([string]$Url) {
    $response = $null
    $reader = $null
    try {
        $uri = [uri]$Url
        if ($uri.Scheme -ne 'http' -or $uri.Host -ne '127.0.0.1') { return }
        $request = [Net.HttpWebRequest]::Create($uri)
        $request.Proxy = $null
        $request.AllowAutoRedirect = $false
        $request.Timeout = 1200
        $request.ReadWriteTimeout = 1500
        $response = $request.GetResponse()
        if ([int]$response.StatusCode -ne 200) { return }
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        return @{ Body = $reader.ReadToEnd(); Type = $response.ContentType }
    } catch { return } finally {
        if ($reader) { $reader.Dispose() }
        if ($response) { $response.Dispose() }
    }
}

function Test-ApiResponse($Response) {
    if (-not $Response -or $Response.Type -notmatch '^application/json' -or $Response.Body.TrimStart() -notmatch '^\[') { return $false }
    try {
        $items = ConvertFrom-Json -InputObject $Response.Body -ErrorAction Stop
        foreach ($item in $items) {
            if ($null -eq $item -or -not $item.PSObject.Properties['ultimoStatus'] -or -not $item.PSObject.Properties['codigoRastreio']) { return $false }
        }
        return $true
    } catch { return $false }
}

function Test-ServiceHttp([string]$Service, [int]$Port) {
    $url = "http://127.0.0.1:$Port"
    switch ($Service) {
        Spring { return Test-ApiResponse (Get-LocalHttp "$url/api/envios") }
        Frontend {
            $page = Get-LocalHttp "$url/"
            return ($page -and $page.Body -match '/src/main\.jsx' -and
                $page.Body -match 'framework-worker-entregas' -and (Test-ApiResponse (Get-LocalHttp "$url/api/envios")))
        }
        Stub {
            $sample = Get-LocalHttp "$url/rastreamento/EM_TRANSITO"
            if (-not $sample -or $sample.Type -notmatch '^application/json') { return $false }
            try {
                $data = ConvertFrom-Json -InputObject $sample.Body -ErrorAction Stop
                return $data.status -ceq 'EM_TRANSITO' -and $data.descricao -ceq 'Objeto em transferência'
            } catch { return $false }
        }
    }
    return $false
}

function Read-State {
    if (-not (Test-Path -LiteralPath $script:StateFile -PathType Leaf)) { return @{} }
    $data = Get-Content -Raw -Encoding UTF8 -LiteralPath $script:StateFile | ConvertFrom-Json
    if ($null -eq $data -or $data -is [array] -or $data -is [string]) { throw 'state.json inválido. Nenhum processo foi encerrado.' }
    $result = @{}
    foreach ($property in $data.PSObject.Properties) {
        $entry = $property.Value
        if ($property.Name -notin $script:Services -or $entry.Service -ne $property.Name -or
            [string]$entry.Instance -notmatch '^[a-fA-F0-9-]{36}$' -or
            [string]$entry.Pid -notmatch '^[1-9]\d{0,9}$' -or [string]$entry.StartTicks -notmatch '^\d{16,19}$') {
            throw 'state.json inválido. Nenhum processo foi encerrado.'
        }
        $result[$property.Name] = $entry
    }
    return $result
}

function Save-State([hashtable]$State) {
    if ($State.Count -eq 0) {
        if (Test-Path -LiteralPath $script:StateFile) { [IO.File]::Delete($script:StateFile) }
        return
    }
    $tempFile = $script:StateFile + '.tmp'
    [IO.File]::WriteAllText($tempFile, (ConvertTo-Json -InputObject $State -Depth 5), (New-Object Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($script:StateFile)) { [IO.File]::Replace($tempFile, $script:StateFile, [NullString]::Value) }
    else { [IO.File]::Move($tempFile, $script:StateFile) }
}

function Use-LauncherLock([scriptblock]$Action) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $id = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:Root.ToUpperInvariant()))).Replace('-', '') }
    finally { $sha.Dispose() }
    $mutex = New-Object Threading.Mutex($false, "Local\RastreioLauncher-$id")
    $acquired = $false
    try {
        try { $acquired = $mutex.WaitOne(3000) } catch [Threading.AbandonedMutexException] { $acquired = $true }
        if (-not $acquired) { throw 'Outra operação do launcher está em andamento. Aguarde e tente novamente.' }
        & $Action
    } finally {
        if ($acquired) { $mutex.ReleaseMutex() }
        $mutex.Dispose()
    }
}

function Get-ManagedProcess($Entry) {
    if (-not $Entry) { return }
    $processo = Get-Process -Id ([int]$Entry.Pid) -ErrorAction SilentlyContinue
    if (-not $processo) { return }
    try {
        $null = $processo.Handle
        if (-not $processo.HasExited -and $processo.ProcessName -eq 'powershell' -and
            [string]$processo.StartTime.ToUniversalTime().Ticks -ceq [string]$Entry.StartTicks) {
            return $processo
        }
    } catch [System.InvalidOperationException] { }
    catch [System.ComponentModel.Win32Exception] { }
    $processo.Dispose()
}

function Start-ManagedProcess([hashtable]$State, [string]$Service, [string]$Executable, [string]$Arguments,
        [string]$Directory, [int]$Port, [hashtable]$Environment, [string]$DisplayCommand, [string]$Settings = '') {
    $instance = [guid]::NewGuid().ToString()
    $file = Join-Path $script:Logs ($Service.ToLowerInvariant() + '.log')
    if (Test-Path -LiteralPath $file) { Move-Item -LiteralPath $file -Destination "$file.1" -Force }
    $envForChild = $Environment.Clone()
    $envForChild.RASTREIO_EXECUTABLE = $Executable
    $envForChild.RASTREIO_ARGUMENTS = $Arguments
    $envForChild.RASTREIO_DIRECTORY = $Directory
    $envForChild.RASTREIO_LOG = $file
    $processo = Use-Environment $envForChild {
        Start-Process -FilePath $script:PowerShellExe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File ""$script:Supervisor"" -Service $Service -Instance $instance" -WindowStyle Hidden -PassThru
    }
    try {
        $started = $processo.StartTime.ToUniversalTime()
        $State[$Service] = @{
            Service = $Service; Instance = $instance; Pid = $processo.Id
            StartTicks = [string]$started.Ticks; StartedAt = $started.ToString('o')
            Port = $Port; Command = $DisplayCommand; Log = $file; Settings = $Settings
        }
        Save-State $State
    } catch {
        if (-not $processo.HasExited) { $processo.Kill() }
        throw
    } finally { $processo.Dispose() }

    Write-LauncherLog "$Service iniciado. Log: $file"
}

function Stop-ManagedService([hashtable]$State, [string]$Service, [int]$Timeout) {
    $entry = $State[$Service]
    if (-not $entry) { return $true }
    $processo = Get-ManagedProcess $entry
    if (-not $processo) {
        Write-LauncherLog "$Service sem processo correspondente. Registro descartado."
        $State.Remove($Service)
        Save-State $State
        return $true
    }
    $event = $null
    try {
        $limit = [Diagnostics.Stopwatch]::StartNew()
        do {
            if ([Threading.EventWaitHandle]::TryOpenExisting("Local\Rastreio-$($entry.Instance)", [ref]$event)) { break }
            if ($processo.WaitForExit(200)) { break }
        } while ($limit.Elapsed.TotalSeconds -lt $Timeout)
        if ($event) {
            $null = $event.Set()
            if (-not $processo.WaitForExit($Timeout * 1000)) {
                Write-LauncherLog "$Service não encerrou no prazo. Encerrando a árvore gerenciada." 'AVISO'
                $processo.Kill()
                if (-not $processo.WaitForExit(3000)) { return $false }
            }
        } elseif (-not $processo.HasExited) {
            Write-LauncherLog "$Service sem canal de parada verificável. Registro mantido; processo não encerrado." 'ERRO'
            return $false
        }
        $State.Remove($Service)
        Save-State $State
        Write-LauncherLog "$Service encerrado." 'OK'
        return $true
    } finally {
        if ($event) { $event.Dispose() }
        $processo.Dispose()
    }
}

function Stop-Launcher([int]$Timeout = 12) {
    Use-LauncherLock {
        $state = Read-State
        if ($state.Count -eq 0) { Write-LauncherLog 'Nenhum serviço gerenciado ativo.' 'OK'; return $true }
        $success = $true
        foreach ($service in $script:Services) {
            if (-not (Stop-ManagedService $state $service $Timeout)) { $success = $false }
        }
        return $success
    }
}

function Get-ConfiguredStopTimeout {
    try { return [int](Get-LauncherConfiguration).STOP_TIMEOUT_SECONDS }
    catch { return 12 }
}
