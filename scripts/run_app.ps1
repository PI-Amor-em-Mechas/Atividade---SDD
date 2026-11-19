[CmdletBinding()]
param(
    [ValidateSet('Menu','Web','Demo','Backend','Check','Stop')][string]$Mode = 'Menu',
    [switch]$NoBrowser, [switch]$ReuseExisting, [switch]$ForceDependencies, [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'launcher-common.ps1')
. (Join-Path $PSScriptRoot 'mysql-assistant.ps1')

function Get-EnvironmentReport {
    $rows = New-Object 'System.Collections.Generic.List[object]'
    function Add-Check($name, $state, $version, $action) {
        $rows.Add([pscustomobject]@{ Dependência = $name; Status = $state; Versão = $version; Ação = $action })
    }

    Add-Check 'Windows / PowerShell' 'OK' $PSVersionTable.PSVersion "Política efetiva: $(Get-ExecutionPolicy) (bypass só deste processo)"
    $java = Find-Tool @('java.exe')
    $javaVersion = if ($java) { Invoke-Tool $java @('-version') }
    if ($javaVersion -and $javaVersion.Code -eq 0 -and (Get-JavaMajor $javaVersion.Text) -ge 17) {
        Add-Check 'Java' 'OK' (($javaVersion.Text -split '\r?\n')[0]) '—'
    } else {
        $java = $null
        Add-Check 'Java' 'ERRO' '—' 'Instale JDK 17+ e valide com java -version.'
    }
    $maven = Find-Maven $script:Folders.Spring
    $mavenVersion = if ($maven -and $java) { Invoke-Tool $maven @('--version') }
    if ($mavenVersion -and $mavenVersion.Code -eq 0 -and $mavenVersion.Text -match 'Apache Maven ([\d.]+)') {
        Add-Check 'Maven' 'OK' $Matches[1] '—'
    } else {
        $maven = $null
        Add-Check 'Maven' 'ERRO' '—' 'Verifique mvnw.cmd ou instale Maven, configure JAVA_HOME e valide mvn --version.'
    }

    $python = Find-Python
    if ($python) { Add-Check 'Python' 'OK' $python.Version '—' }
    else { Add-Check 'Python' 'AUSENTE' '—' 'Demonstração: instale Python 3.10+ com PATH ou py -3.' }

    $node = Find-Tool @('node.exe')
    $nodeVersion = if ($node) { Invoke-Tool $node @('--version') }
    if ($nodeVersion -and $nodeVersion.Code -eq 0 -and (Test-NodeVersion $nodeVersion.Text)) {
        Add-Check 'Node' 'OK' $nodeVersion.Text '—'
    } else {
        $node = $null
        Add-Check 'Node' 'ERRO' '—' 'Instale Node.js LTS compatível com Vite 8 (20.19+ na série 20 ou 22.12+).'
    }
    $npm = Find-Tool @('npm.cmd', 'npm.exe')
    $npmVersion = if ($node -and $npm) { Invoke-Tool $npm @('--version') }
    if ($npmVersion -and $npmVersion.Code -eq 0 -and $npmVersion.Text -match '^\d+\.\d+\.\d+') {
        Add-Check 'npm' 'OK' $npmVersion.Text '—'
    } else {
        $npm = $null
        Add-Check 'npm' 'ERRO' '—' 'Instale Node.js LTS com npm e valide npm --version.'
    }

    $rows | Format-Table -AutoSize -Wrap | Out-Host
    return @{ Java = $java; Maven = $maven; Python = $python; Npm = $npm; Node = $node }
}

function Get-DatabaseEnvironment($Config) {
    return @{
        DB_HOST = $Config.DB_HOST; DB_PORT = $Config.DB_PORT; DB_NAME = $Config.DB_NAME
        DB_USER = $Config.DB_USER; DB_PASSWORD = $Config.DB_PASSWORD
        TRACKING_API_TOKEN = $null
    }
}

function Get-StartupBlockers($Tools, [bool]$Web) {
    if (-not $Tools.Java) { 'Java 17+' }
    if (-not $Tools.Maven) { 'Maven' }
    if (-not $Tools.Python) { 'Python 3.10+ para o probe MySQL' }
    if ($Web -and -not $Tools.Node) { 'Node.js compatível com Vite' }
    if ($Web -and -not $Tools.Npm) { 'npm' }
}

function Assert-DatabaseReuse([bool]$Demo, [bool]$Spring, [bool]$Worker) {
    if (($Worker -and -not $Spring) -or ($Demo -and $Spring -and -not $Worker)) {
        throw 'Pare a execução anterior antes de iniciar Spring e Worker juntos. Eles precisam receber a mesma configuração de banco.'
    }
}

function Show-EnvironmentDiagnostics($Config) {
    $tools = Get-EnvironmentReport
    $null = Resolve-Database $Config $tools.Python -Diagnostic
}

function Get-MySqlFailure([string]$Text) {
    if ($Text -match '(?i)Unknown database|UNKNOWN_DATABASE') {
        return 'MySQL: banco inexistente. Confirme DB_NAME com o responsável pelo servidor.'
    }
    if ($Text -match '(?i)Access denied|ACCESS_DENIED|authentication failure') {
        return 'MySQL: acesso negado. Confira DB_USER, DB_PASSWORD e as permissões no banco configurado.'
    }
    if ($Text -match '(?i)Communications link failure|CONNECTION_FAILED|MySQL.{0,70}timed?\s*out') {
        return 'MySQL: conexão expirou ou falhou após o teste TCP. Confira host, porta e servidor.'
    }
}

function Get-DatabaseCandidates($Config) {
    $candidates = @(
        @{ Host = $Config.DB_HOST; Port = [int]$Config.DB_PORT; Source = $Config.DB_HOST_SOURCE }
    )
    if ($Config.DB_FILE_HOST -match '^[A-Za-z0-9][A-Za-z0-9.-]*$' -and
        $Config.DB_FILE_PORT -match '^\d{1,5}$' -and
        [int]$Config.DB_FILE_PORT -ge 1 -and [int]$Config.DB_FILE_PORT -le 65535) {
        $candidates += @{ Host = $Config.DB_FILE_HOST; Port = [int]$Config.DB_FILE_PORT; Source = $Config.DB_FILE_SOURCE }
    }
    $candidates += @{ Host = 'localhost'; Port = [int]$Config.DB_PORT; Source = 'local' }
    $seen = @{}
    foreach ($candidate in $candidates) {
        $key = "$($candidate.Host):$($candidate.Port)"
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $candidate }
    }
}

function Show-LocalDatabaseInfo([int]$Port) {
    $services = @(Get-Service -Name '*mysql*','*maria*' -ErrorAction SilentlyContinue)
    if ($services.Count) {
        $services | Select-Object Name,Status,StartType | Format-Table -AutoSize | Out-Host
    } else { Write-LauncherLog 'Serviço MySQL/MariaDB no Windows: nenhum encontrado. Um servidor externo pode ser usado.' }
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        $ports = @(3306, $Port | Select-Object -Unique)
        $connections = @(Get-NetTCPConnection -LocalPort $ports -ErrorAction SilentlyContinue) +
            @(Get-NetTCPConnection -RemotePort 3306 -ErrorAction SilentlyContinue)
        if ($connections.Count) {
            $connections | Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess |
                Format-Table -AutoSize | Out-Host
        }
    }
}

function Invoke-DatabaseProbe($Config, $Python, [switch]$AllowInstall) {
    $tcp = Get-TcpStatus $Config.DB_HOST ([int]$Config.DB_PORT) 2500
    if ($tcp -ne 'Open') {
        return @{ Tcp = $false; Codes = @('MYSQL_NAO_ENCONTRADO') }
    }
    if (-not $Python) { return @{ Tcp = $true; Codes = @('MYSQL_PYTHON_AUSENTE') } }
    $probe = Join-Path $PSScriptRoot 'mysql-probe.py'
    $venv = Join-Path $script:Folders.Worker '.venv'
    $venvExe = Join-Path $venv 'Scripts\python.exe'
    $runner = if (Test-WorkerVenv $venvExe $venv) { @{ Path = $venvExe; Prefix = @() } } else { $Python }
    $envForProbe = Get-DatabaseEnvironment $Config
    $result = Use-Environment $envForProbe { Invoke-Tool $runner.Path ($runner.Prefix + @('-B', $probe)) }
    $codes = @($result.Text -split '\r?\n' | Where-Object { $_ -cmatch '^MYSQL_[A-Z_]+$' })
    if ('MYSQL_DRIVER_AUSENTE' -in $codes -and $runner.Path -ne $Python.Path) {
        $result = Use-Environment $envForProbe { Invoke-Tool $Python.Path ($Python.Prefix + @('-B', $probe)) }
        $codes = @($result.Text -split '\r?\n' | Where-Object { $_ -cmatch '^MYSQL_[A-Z_]+$' })
    }
    if ($AllowInstall -and 'MYSQL_DRIVER_AUSENTE' -in $codes) {
        $venvExe = Prepare-Worker $Python
        $result = Use-Environment $envForProbe { Invoke-Tool $venvExe @('-B', $probe) }
        $codes = @($result.Text -split '\r?\n' | Where-Object { $_ -cmatch '^MYSQL_[A-Z_]+$' })
    }
    if ($result.Code -ne 0 -or -not $codes.Count) { $codes = @('MYSQL_PROBE_FALHOU') }
    return @{ Tcp = $true; Codes = $codes }
}

function Show-DatabaseResult($Config, $Result, [switch]$Hint) {
    $address = "$($Config.DB_HOST):$($Config.DB_PORT)"
    $status = $Result.Codes[-1]
    if ($status -eq 'MYSQL_OK') {
        Write-LauncherLog "MYSQL_OK — $address/$($Config.DB_NAME)" 'OK'
        return
    }
    $detail = switch ($status) {
        MYSQL_NAO_ENCONTRADO {
            if ($Result.Tcp) { "A porta em $address respondeu sem confirmar o protocolo MySQL/MariaDB." }
            else { "Nenhum servidor MySQL/MariaDB respondeu em $address. Verifique se o serviço está iniciado e acessível." }
        }
        MYSQL_ENCONTRADO_SEM_CREDENCIAIS {
            Write-LauncherLog "MySQL encontrado em $address, mas a senha ainda não foi informada." 'AVISO'
            if ($Hint) {
                Write-Host 'Próximo passo: escolha [6] no menu abaixo e digite a senha do root do MySQL.'
                Write-Host 'O launcher cria banco, tabelas e usuário e salva a configuração sozinho.'
                Write-Host '(Se o usuário rastreamento_app já existe, informe a senha no .env da raiz ou use [4].)'
            }
            return
        }
        MYSQL_CREDENCIAL_INVALIDA { 'O servidor recusou a autenticação. Revise DB_USER e DB_PASSWORD na opção 5.' }
        MYSQL_DATABASE_AUSENTE { 'O database amor_em_mechas não foi encontrado. Use “Mostrar SQL de configuração”.' }
        MYSQL_SCHEMA_INCOMPLETO { 'O módulo de rastreamento ainda não foi preparado. Use “Mostrar SQL de configuração”.' }
        MYSQL_USUARIO_SEM_PERMISSAO { "A conta $($Config.DB_USER) não possui acesso suficiente. Aplique a seção GRANTS quando as duas tabelas existirem." }
        MYSQL_CONFIGURACAO_INVALIDA { 'Use o banco amor_em_mechas e uma conta da aplicação como rastreamento_app.' }
        MYSQL_PYTHON_AUSENTE { 'Instale Python 3.10+ para validar o MySQL.' }
        MYSQL_DRIVER_AUSENTE { 'O Connector/Python é preparado ao escolher a opção 4 do assistente.' }
        MYSQL_DRIVER_INCOMPATIVEL { 'Atualize mysql-connector-python para a versão em requirements.txt.' }
        default { "Falha na validação de $address. Confira o serviço e a configuração da conexão." }
    }
    Write-LauncherLog "$status — $detail" 'ERRO'
    foreach ($table in 'envios','envio_historico') {
        if ("MYSQL_AUSENTE_$($table.ToUpperInvariant())" -in $Result.Codes) { Write-Host "Ausente: $table" }
    }
}

function Save-DatabaseConfiguration($Config) {
    $file = Join-Path $script:Root '.env'
    $template = if (Test-Path -LiteralPath $file) { $file } else { Join-Path $script:Root 'launcher.env.example' }
    $keys = @('DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD')
    $lines = @(Get-Content -LiteralPath $template -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*DB_(HOST|PORT|NAME|USER|PASSWORD)\s*=' })
    foreach ($key in $keys) {
        $value = [string]$Config[$key]
        if ($value -match '[\r\n]') { throw '.env aceita um valor por linha.' }
        $lines += "$key=""$value"""
    }
    $temp = Join-Path $script:Runtime ("config-" + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllLines($temp, [string[]]$lines, (New-Object Text.UTF8Encoding($false)))
        if ([IO.File]::Exists($file)) { [IO.File]::Replace($temp, $file, [NullString]::Value) }
        else { [IO.File]::Move($temp, $file) }
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
    }
    Write-LauncherLog 'Configuração salva no .env da raiz. Variáveis do processo mantêm prioridade nas próximas execuções.' 'OK'
}

function Resolve-Database($Config, $Python, [switch]$Interactive, [switch]$Diagnostic, [switch]$PromptCredentials) {
    $attempt = 0
    foreach ($candidate in (Get-DatabaseCandidates $Config)) {
        $attempt++
        $selected = $Config.Clone()
        $selected.DB_HOST = $candidate.Host
        $selected.DB_PORT = $candidate.Port
        $selected.DB_HOST_SOURCE = $candidate.Source
        $fallback = $attempt -gt 1
        if ($Diagnostic -and $selected.DB_HOST -in 'localhost','127.0.0.1') { Show-LocalDatabaseInfo $selected.DB_PORT }
        $probeConfig = $selected.Clone()
        if ($fallback) {
            $probeConfig.DB_USER = ''
            $probeConfig.DB_PASSWORD = ''
            Write-LauncherLog 'Verificando candidato alternativo sem enviar credenciais.'
        }
        $result = Invoke-DatabaseProbe $probeConfig $Python -AllowInstall:(-not $Diagnostic -and -not $fallback)
        Show-DatabaseResult $probeConfig $result -Hint:$Diagnostic
        if ($PromptCredentials -and $result.Codes[-1] -eq 'MYSQL_ENCONTRADO_SEM_CREDENCIAIS') {
            $proposal = Request-DatabaseConfiguration $selected
            if (-not $proposal) { return }
            $verified = Resolve-Database $proposal $Python -Interactive
            if ($verified) { return $verified }
            return @{ PendingConfig = $proposal }
        }
        if ($fallback -and 'MYSQL_PROTOCOLO_OK' -in $result.Codes -and $Interactive -and -not $Diagnostic) {
            if ((Read-Host "Testar estas credenciais em $($selected.DB_HOST):$($selected.DB_PORT)? [s/N]") -notmatch '^(s|sim)$') { continue }
            $result = Invoke-DatabaseProbe $selected $Python -AllowInstall
            Show-DatabaseResult $selected $result
        }
        if ($result.Codes[-1] -eq 'MYSQL_OK') {
            $selected.DB_JDBC_VENDOR = if ('MYSQL_MOTOR_MARIADB' -in $result.Codes) { 'mariadb' } else { 'mysql' }
            if ($fallback) {
                $answer = Read-Host '[1] Usar nesta execução  [2] Usar e salvar no .env  [0] Cancelar'
                if ($answer -notin '1','2') { return }
                if ($answer -eq '2') { Save-DatabaseConfiguration $selected }
            }
            return $selected
        }
        # A validated protocol with denied credentials or schema must not send secrets elsewhere.
        if ('MYSQL_PROTOCOLO_OK' -in $result.Codes -and -not $fallback) { return }
    }
}

function Request-DatabaseConfiguration($Current) {
    $proposal = $Current.Clone()
    $defaultHost = $Current.DB_HOST
    $entered = Read-Host "Host do MySQL [$defaultHost]"
    $proposal.DB_HOST = if ($entered) { $entered.Trim() } else { $defaultHost }
    $proposal.DB_HOST_SOURCE = 'configuração assistida'
    $entered = Read-Host "Porta do MySQL [$($Current.DB_PORT)]"
    if ($entered) { $proposal.DB_PORT = $entered.Trim() }
    $entered = Read-Host "Nome do banco [$($Current.DB_NAME)]"
    if ($entered) { $proposal.DB_NAME = $entered.Trim() }
    $defaultUser = if ($Current.DB_USER -and $Current.DB_USER -ine 'root') { $Current.DB_USER } else { 'rastreamento_app' }
    $entered = Read-Host "Usuário da aplicação [$defaultUser]"
    $proposal.DB_USER = if ($entered) { $entered.Trim() } else { $defaultUser }
    if ($proposal.DB_NAME -cne 'amor_em_mechas' -or $proposal.DB_USER -ieq 'root') {
        throw 'Use o banco amor_em_mechas e uma conta da aplicação como rastreamento_app.'
    }
    Test-LauncherConfiguration $proposal
    $secret = Read-Host 'Senha MySQL' -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { $proposal.DB_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $secret.Dispose() }
    $script:Secrets = @($Current.DB_PASSWORD, $proposal.DB_PASSWORD, $Current.TRACKING_API_TOKEN)
    $answer = Read-Host '[1] Usar somente nesta execução  [2] Salvar no .env  [0] Cancelar'
    if ($answer -notin '1','2') { return }
    if ($answer -eq '2') { Save-DatabaseConfiguration $proposal }
    return $proposal
}

function Test-WorkerVenv([string]$Executable, [string]$Directory) {
    if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { return $false }
    $result = Invoke-Tool $Executable @('-I', '-c', 'import sys; print(sys.prefix); print(int(sys.version_info >= (3, 10)))')
    $lines = @($result.Text.Trim() -split '\r?\n')
    return $result.Code -eq 0 -and $lines.Count -eq 2 -and
        $lines[0] -ieq $Directory -and $lines[1] -eq '1'
}

function Invoke-DependencySetup([string]$Service, [string]$Executable, [string[]]$Arguments, [string]$Directory) {
    $line = "$(Split-Path -Leaf $Executable) $($Arguments -join ' ')"
    Write-LauncherLog "$Service preparando dependências com $line"
    Push-Location -LiteralPath $Directory
    try {
        $setup = Use-Environment @{ DB_PASSWORD = $null; TRACKING_API_TOKEN = $null; PYTHONPATH = $null; PYTHONHOME = $null } {
            Invoke-Tool $Executable $Arguments
        }
    } finally { Pop-Location }
    $file = Join-Path $script:Logs ($Service.ToLowerInvariant() + '-setup.log')
    Set-Content -Encoding UTF8 -LiteralPath $file -Value "$(Get-Date -Format 's') $line"
    # Preserve the most recent output without carrying an unbounded install log.
    $safe = Mask-Secret $setup.Text
    if ($safe.Length -gt 262144) { $safe = $safe.Substring($safe.Length - 262144) }
    Add-Content -Encoding UTF8 -LiteralPath $file -Value $safe
    if ($setup.Code -ne 0) {
        Get-Content -Encoding UTF8 -LiteralPath $file -Tail 8 | ForEach-Object { Write-Host $_ }
        throw "${Service}: $line falhou. Consulte $file."
    }
}

function Prepare-Worker($Python) {
    $directory = $script:Folders.Worker
    $venv = Join-Path $directory '.venv'
    $executable = Join-Path $venv 'Scripts\python.exe'
    if (-not (Test-WorkerVenv $executable $venv)) {
        if (Test-Path -LiteralPath $venv) {
            $actual = (Resolve-Path -LiteralPath $venv).Path
            if ($actual -ine $venv -or (Get-Item -LiteralPath $venv).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw '.venv usa um caminho redirecionado. Corrija o ambiente antes de continuar.'
            }
            $archive = Join-Path $script:Runtime ("venv-anterior-" + [guid]::NewGuid().ToString('N'))
            Move-Item -LiteralPath $actual -Destination $archive
            Write-LauncherLog "Ambiente Python inválido arquivado em $archive." 'AVISO'
        }
        Invoke-DependencySetup Worker $Python.Path ($Python.Prefix + @('-m', 'venv', '.venv')) $directory
        if (-not (Test-WorkerVenv $executable $venv)) { throw 'A nova .venv não iniciou com Python 3.10+.' }
    }
    $marker = Join-Path $venv '.launcher-requirements.sha256'
    $hash = (Get-FileHash -LiteralPath (Join-Path $directory 'requirements.txt')).Hash
    $check = Invoke-Tool $executable @('-I', '-c', "import requests, mysql.connector; from zoneinfo import ZoneInfo; ZoneInfo('America/Sao_Paulo')")
    if ($ForceDependencies -or $check.Code -ne 0 -or -not (Test-Path -LiteralPath $marker) -or
        (Get-Content -LiteralPath $marker -Raw).Trim() -ne $hash) {
        $install = @('-m', 'pip', 'install', '-r', 'requirements.txt')
        if ($ForceDependencies) { $install += '--force-reinstall' }
        Invoke-DependencySetup Worker $executable $install $directory
        $check = Invoke-Tool $executable @('-I', '-c', "import requests, mysql.connector; from zoneinfo import ZoneInfo; ZoneInfo('America/Sao_Paulo')")
        if ($check.Code -ne 0) { throw 'As dependências Python instaladas não passaram na verificação de importação.' }
        Set-Content -LiteralPath $marker -Encoding ASCII -Value $hash
    }
    return $executable
}

function Get-FrontendInstallPlan([string]$Directory, [bool]$Force) {
    $modules = Join-Path $Directory 'node_modules'
    $lockFile = Join-Path $Directory 'package-lock.json'
    $manifest = Join-Path $Directory 'package.json'
    $locked = Test-Path -LiteralPath $lockFile
    $marker = Join-Path $modules '.launcher-dependencies.sha256'
    $hash = (Get-FileHash -LiteralPath $(if ($locked) { $lockFile } else { $manifest })).Hash
    $valid = Test-Path -LiteralPath (Join-Path $modules 'vite\bin\vite.js')
    $prior = if (Test-Path -LiteralPath $marker) { (Get-Content -Raw -LiteralPath $marker).Trim() }
    return @{
        Hash = $hash; Marker = $marker
        Action = if ($Force -or -not $valid -or ($prior -and $prior -ne $hash)) {
            if ($locked) { 'ci' } else { 'install' }
        } elseif (-not $prior) { 'verify' } else { 'reuse' }
    }
}

function Prepare-Frontend([string]$Npm) {
    $directory = $script:Folders.Frontend
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $directory 'package.json') | ConvertFrom-Json
    foreach ($name in 'dev', 'build', 'test', 'test:e2e') {
        if (-not $manifest.scripts.PSObject.Properties[$name]) { throw "Script npm ausente: $name." }
    }
    $plan = Get-FrontendInstallPlan $directory $ForceDependencies.IsPresent
    if ($plan.Action -eq 'verify') {
        Push-Location -LiteralPath $directory
        try { $list = Invoke-Tool $Npm @('ls', '--depth=0', '--json') } finally { Pop-Location }
        if ($list.Code -ne 0) {
            $plan.Action = if (Test-Path -LiteralPath (Join-Path $directory 'package-lock.json')) { 'ci' } else { 'install' }
        }
    }
    if ($plan.Action -in 'ci', 'install') {
        Invoke-DependencySetup Frontend $Npm @($plan.Action, '--no-audit', '--no-fund') $directory
    }
    if ($plan.Action -ne 'reuse') { Set-Content -LiteralPath $plan.Marker -Encoding ASCII -Value $plan.Hash }
}

function Wait-Service([string]$Service, [int]$Port, $Entry, [int]$Seconds) {
    $endpoint = switch ($Service) {
        Spring { "http://127.0.0.1:$Port/api/envios" }
        Frontend { "http://127.0.0.1:$Port/ e /api/envios pelo proxy" }
        Stub { "$(Get-StubUrl $Port)/EM_TRANSITO" }
        Worker { 'primeiro ciclo no log' }
    }
    Write-LauncherLog "$Service em $endpoint (até $Seconds s)." 'AGUARDANDO'
    $watch = [Diagnostics.Stopwatch]::StartNew()
    do {
        $processo = Get-ManagedProcess $Entry
        if (-not $processo) { break }
        $processo.Dispose()
        $ready = if ($Service -eq 'Worker') {
            $tail = if (Test-Path -LiteralPath $Entry.Log) { Get-Content -Encoding UTF8 -LiteralPath $Entry.Log -Tail 50 }
            if ($tail -match '\[worker-error\]') { break }
            $watch.Elapsed.TotalSeconds -ge 2 -and [bool]($tail -match '\[worker-ready\]')
        } else { Test-ServiceHttp $Service $Port }
        if ($ready) { Write-LauncherLog "$Service pronto." 'OK'; return }
        Start-Sleep -Milliseconds 250
    } while ($watch.Elapsed.TotalSeconds -lt $Seconds)
    $lines = if (Test-Path -LiteralPath $Entry.Log) { Get-Content -Encoding UTF8 -LiteralPath $Entry.Log -Tail 20 }
    foreach ($line in $lines) { Write-Host (Mask-Secret $line) }
    $reason = Get-MySqlFailure ($lines -join ' ')
    if (-not $reason) { $reason = 'Processo terminou ou a verificação de saúde não respondeu.' }
    throw "$Service em $endpoint falhou após $([int]$watch.Elapsed.TotalSeconds) s. $reason Log: $($Entry.Log)"
}

function Test-ReuseService([string]$Service, [int]$Port, [hashtable]$State, [string]$Settings = '') {
    $entry = $State[$Service]
    $processo = Get-ManagedProcess $entry
    if ($processo) {
        $processo.Dispose()
        if ($entry.Port -eq $Port -and $entry.Settings -eq $Settings -and (Test-ServiceHttp $Service $Port)) {
            Write-LauncherLog "$Service do launcher já está saudável na porta $Port." 'OK'
            return $true
        }
        throw "$Service já é gerenciado com configuração diferente ou ainda não está saudável. Use stop_app.bat antes de iniciar novamente."
    }
    if ($entry) { $State.Remove($Service); Save-State $State }
    if (-not (Test-TcpPort '127.0.0.1' $Port 400) -and -not (Test-TcpPort '::1' $Port 400)) { return $false }
    $owner = Get-PortOwner $Port
    $name = if ($owner) { (Get-Process -Id $owner -ErrorAction SilentlyContinue).ProcessName }
    Write-LauncherLog "Porta $Port ocupada. PID: $owner. Processo: $name." 'AVISO'
    if (Test-ServiceHttp $Service $Port) {
        $reuse = $ReuseExisting.IsPresent
        if (-not $reuse -and $Mode -eq 'Menu') {
            $reuse = (Read-Host "Reutilizar $Service na porta $Port? Confirme que usa a configuração deste projeto [s/N]") -match '^(s|sim)$'
        }
        if ($reuse) { Write-LauncherLog "$Service externo reutilizado. Sua parada continua sob controle do proprietário." 'OK'; return $true }
    }
    throw "Porta $Port indisponível para $Service. Ajuste a porta no .env da raiz ou libere-a por conta própria."
}

function Start-Application([string]$SelectedMode, $Config) {
    $web = $SelectedMode -ne 'Backend'
    $demo = $SelectedMode -eq 'Demo'
    if ($demo) {
        Write-Host 'PROVIDER_AGUARDANDO_CONTRATO — demonstração com stub local'
        Write-Host 'NÃO UTILIZAR COMO INTEGRAÇÃO DE PRODUÇÃO'
    }
    $ports = @([int]$Config.SPRING_PORT)
    if ($web) { $ports += [int]$Config.FRONTEND_PORT }
    if ($demo) { $ports += [int]$Config.STUB_PORT; $stubUrl = Get-StubUrl $Config.STUB_PORT }
    if (@($ports | Select-Object -Unique).Count -ne $ports.Count) { throw 'Configure portas distintas para os serviços selecionados.' }

    Use-LauncherLock {
        $selected = Resolve-Database $Config (Find-Python) -Interactive:($Mode -eq 'Menu')
        if (-not $selected) {
            $failure = New-Object System.InvalidOperationException('INICIALIZAÇÃO BLOQUEADA — o MySQL não recebeu MYSQL_OK. Confira os resultados por endpoint.')
            $failure.Data['Database'] = $true
            throw $failure
        }
        $Config = $selected
        $tools = Get-EnvironmentReport
        $missing = @(Get-StartupBlockers $tools $web)
        if ($missing.Count) { throw ('INICIALIZAÇÃO BLOQUEADA — ' + ($missing -join ', ')) }
        $state = Read-State
        $databaseKey = "$($Config.DB_HOST):$($Config.DB_PORT)/$($Config.DB_NAME)"
        $databaseSettings = "$databaseKey | $($Config.DB_USER)"
        $proxyKey = [string]$Config.SPRING_PORT
        $existingSpring = Test-ReuseService Spring $Config.SPRING_PORT $state $databaseSettings
        if ($demo -and $existingSpring -and -not $state.Spring) {
            throw 'O banco do Spring externo não pode ser verificado. Use uma porta livre para iniciar Spring e Worker com o mesmo banco.'
        }
        $existingFront = $web -and (Test-ReuseService Frontend $Config.FRONTEND_PORT $state $proxyKey)
        $existingStub = $demo -and (Test-ReuseService Stub $Config.STUB_PORT $state)
        $existingWorker = $false
        if ($state.Worker) {
            $workerProcess = Get-ManagedProcess $state.Worker
            if ($workerProcess) {
                $workerProcess.Dispose()
                $existingWorker = $true
                if ($demo -and ($state.Worker.Port -ne [int]$Config.STUB_PORT -or $state.Worker.Settings -ne $databaseSettings)) {
                    throw 'Worker já ativo com outra configuração de banco ou stub. Use stop_app.bat.'
                }
            } else { $state.Remove('Worker'); Save-State $state }
        }
        Assert-DatabaseReuse $demo $existingSpring $existingWorker

        $db = Get-DatabaseEnvironment $Config
        Write-Host @"
========================================
CONFIGURAÇÃO DA APLICAÇÃO
========================================
Banco: $databaseKey
Usuário: $($Config.DB_USER)
Spring: mesma configuração
Worker: mesma configuração na demonstração
Senha: configurada e protegida
"@
        $started = New-Object 'System.Collections.Generic.List[string]'
        $complete = $false
        try {
            if ($web -and -not $existingFront) { Prepare-Frontend $tools.Npm }
            if ($demo -and -not $existingWorker) {
                $workerPython = Prepare-Worker $tools.Python
            }
            if (-not $existingSpring) {
                $springEnv = $db.Clone()
                $springEnv.SERVER_PORT = $Config.SPRING_PORT
                $springEnv.SERVER_ADDRESS = '127.0.0.1'
                # Keep the JDBC URL on the same DB_* contract as the Worker.
                $springEnv.DB_JDBC_VENDOR = $Config.DB_JDBC_VENDOR
                $springEnv.SPRING_DATASOURCE_URL = $null
                $springEnv.SPRING_DATASOURCE_DRIVER_CLASS_NAME = $null
                $springEnv.SPRING_DATASOURCE_USERNAME = $null
                $springEnv.SPRING_DATASOURCE_PASSWORD = $null
                $springEnv.SPRING_APPLICATION_JSON = $null
                $springEnv.SPRING_JPA_HIBERNATE_DDL_AUTO = 'validate'
                $springEnv.SPRING_SQL_INIT_MODE = 'never'
                $started.Add('Spring')
                Start-ManagedProcess $state Spring $tools.Maven 'spring-boot:run -Dspring-boot.run.jvmArguments=-Duser.timezone=America/Sao_Paulo' $script:Folders.Spring $Config.SPRING_PORT $springEnv 'mvn spring-boot:run' $databaseSettings
                try { Wait-Service Spring $Config.SPRING_PORT $state.Spring $Config.STARTUP_TIMEOUT_SECONDS }
                catch { throw "Spring para MySQL $databaseKey — $($_.Exception.Message)" }
            }
            $cleanEnv = @{ DB_PASSWORD = $null; TRACKING_API_TOKEN = $null; PYTHONPATH = $null; PYTHONHOME = $null; PYTHONIOENCODING = 'utf-8' }
            if ($demo -and -not $existingStub) {
                $stubPython = if ($workerPython) { $workerPython } else { Join-Path $script:Folders.Worker '.venv\Scripts\python.exe' }
                $started.Add('Stub')
                Start-ManagedProcess $state Stub $stubPython "-B tests/provider_stub.py --port $([int]$Config.STUB_PORT)" $script:Folders.Worker $Config.STUB_PORT $cleanEnv 'python -B tests/provider_stub.py'
                Wait-Service Stub $Config.STUB_PORT $state.Stub $Config.STARTUP_TIMEOUT_SECONDS
            }
            if ($demo -and -not $existingWorker) {
                $workerEnv = $db.Clone()
                $workerEnv.TRACKING_PROVIDER = 'stub'
                $workerEnv.TRACKING_API_BASE_URL = $stubUrl
                $workerEnv.TRACKING_TIMEOUT_SECONDS = $Config.TRACKING_TIMEOUT_SECONDS
                $workerEnv.POLL_INTERVAL_SECONDS = $Config.POLL_INTERVAL_SECONDS
                $workerEnv.LOG_LEVEL = 'INFO'
                $workerEnv.PYTHONPATH = $null
                $workerEnv.PYTHONHOME = $null
                $workerEnv.PYTHONIOENCODING = 'utf-8'
                $started.Add('Worker')
                Start-ManagedProcess $state Worker $workerPython '-B main.py' $script:Folders.Worker $Config.STUB_PORT $workerEnv 'python -B main.py (stub)' $databaseSettings
                Wait-Service Worker 0 $state.Worker $Config.STARTUP_TIMEOUT_SECONDS
            }
            if ($web -and -not $existingFront) {
                $frontEnv = $cleanEnv.Clone()
                $frontEnv.API_PROXY_TARGET = "http://127.0.0.1:$($Config.SPRING_PORT)"
                $frontEnv.VITE_API_BASE_URL = '/'
                $started.Add('Frontend')
                Start-ManagedProcess $state Frontend $tools.Npm "run dev -- --host 127.0.0.1 --port $([int]$Config.FRONTEND_PORT) --strictPort" $script:Folders.Frontend $Config.FRONTEND_PORT $frontEnv 'npm run dev' $proxyKey
                Wait-Service Frontend $Config.FRONTEND_PORT $state.Frontend $Config.STARTUP_TIMEOUT_SECONDS
            }
            $complete = $true
        } finally {
            if (-not $complete) {
                foreach ($service in $script:Services) {
                    if ($started.Contains($service)) { $null = Stop-ManagedService $state $service $Config.STOP_TIMEOUT_SECONDS }
                }
            }
        }

        $frontUrl = "http://127.0.0.1:$($Config.FRONTEND_PORT)"
        if ($web -and -not $NoBrowser -and -not $existingFront) {
            try {
                Use-Environment @{ DB_PASSWORD = $null; TRACKING_API_TOKEN = $null } { Start-Process $frontUrl }
                Write-LauncherLog 'Aplicação aberta no navegador padrão.' 'OK'
            }
            catch { Write-LauncherLog "Abra $frontUrl no navegador. A abertura automática falhou." 'AVISO' }
        }
        Write-Host '========================================'
        Write-Host 'APLICAÇÃO INICIADA'
        if ($web) { Write-Host "Frontend: $frontUrl" }
        Write-Host "Spring:   http://127.0.0.1:$($Config.SPRING_PORT)"
        Write-Host "MySQL:    $($Config.DB_HOST):$($Config.DB_PORT) / $($Config.DB_NAME)"
        $workerRunning = $demo -or $existingWorker
        $workerText = if ($workerRunning) { 'ativo' } else { 'inativo' }
        $providerText = if ($workerRunning) { 'stub local de demonstração' } else { 'não iniciado' }
        Write-Host "Worker:   $workerText"
        Write-Host "Provider: $providerText"
        Write-Host "Logs:     $script:Logs"
        if ($demo) { Write-Host 'Cadastre o código EM_TRANSITO para ver uma atualização pelo stub.' }
        Write-Host 'Use stop_app.bat para encerrar os serviços.'
        Write-Host '========================================'
    }
}

if ($SelfTest) {
    . (Join-Path $PSScriptRoot 'tests\launcher-selftest.ps1')
    exit 0
}

try {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT -or $PSVersionTable.PSVersion -lt [version]'5.1') {
        throw 'Use Windows e Windows PowerShell 5.1 ou superior.'
    }
    foreach ($path in $script:Folders.Values) {
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw 'Estrutura de módulos incompleta no checkout.' }
    }
    if (-not (Test-Path -LiteralPath $script:Logs)) { $null = New-Item -ItemType Directory -Path $script:Logs -Force }
    if ($Mode -eq 'Stop') { if (-not (Stop-Launcher (Get-ConfiguredStopTimeout))) { exit 1 }; exit 0 }
    Initialize-LauncherConfiguration
    if ($Mode -ne 'Menu') {
        $config = Get-LauncherConfiguration
        if ($Mode -eq 'Check') { Show-EnvironmentDiagnostics $config; exit 0 }
        Start-Application $Mode $config
        exit 0
    }
    $sessionConfig = $null
    while ($true) {
        Write-Host @'
========================================
RASTREAMENTO DE ENCOMENDAS
========================================
[1] Iniciar aplicação web
[2] Iniciar demonstração completa
[3] Somente backend
[4] Configurar ou validar MySQL
[5] Verificar ambiente
[6] Parar serviços iniciados pelo launcher
[0] Sair
'@
        $option = Read-Host 'Escolha uma opção [0]'
        if ($option -in '', '0') {
            if ((Read-State).Count) { Write-Host 'Os serviços continuam ativos. Use stop_app.bat para encerrar.' }
            break
        }
        try {
            if ($option -eq '6') { $null = Stop-Launcher (Get-ConfiguredStopTimeout); continue }
            if ($option -notin '1','2','3','4','5') { Write-Host '[AVISO] Opção inválida.'; continue }
            $config = if ($sessionConfig) { $sessionConfig } else { Get-LauncherConfiguration }
            if ($option -eq '5') { Show-EnvironmentDiagnostics $config; continue }
            $selectedMode = @{ '1' = 'Web'; '2' = 'Demo'; '3' = 'Backend' }[$option]
            if ($option -eq '4') {
                $null = Resolve-Database $config (Find-Python) -Diagnostic
                $assistant = Show-MySqlAssistant $config
                $sessionConfig = $config = $assistant.Config
                $selectedMode = $assistant.Mode
            }
            while ($selectedMode) {
                try { Start-Application $selectedMode $config; break }
                catch {
                    if (-not $_.Exception.Data['Database']) { throw }
                    Write-LauncherLog $_.Exception.Message 'ERRO'
                    $assistant = Show-MySqlAssistant $config $selectedMode
                    $sessionConfig = $config = $assistant.Config
                    $selectedMode = $assistant.Mode
                }
            }
        } catch {
            Write-LauncherLog $_.Exception.Message 'ERRO'
            if ($option -eq '2') { Write-Host 'O modo Aplicação web continua disponível no menu.' }
        }
    }
} catch {
    Write-LauncherLog $_.Exception.Message 'ERRO'
    exit 1
}
