$projectRoot = $script:Root
$failures = 0
$count = 0
function Assert-Launcher($condition, [string]$message) {
    if (-not $condition) { throw $message }
}
function Test-Case([string]$Name, [scriptblock]$Body) {
    $script:count++
    try { & $Body; Write-Host "[OK] $Name" }
    catch { $script:failures++; Write-Host "[ERRO] $Name - $($_.Exception.Message)" }
}

Test-Case 'raiz calculada pelo script' {
    Assert-Launcher (Test-Path -LiteralPath (Join-Path $script:Root 'run_app.bat')) 'Raiz incorreta.'
}
$script:Root = Join-Path ([IO.Path]::GetTempPath()) ("Rastreio testes São Paulo " + [guid]::NewGuid().ToString('N'))
$script:Runtime = Join-Path $script:Root '.launcher'
$script:Logs = Join-Path $script:Runtime 'logs'
$script:StateFile = Join-Path $script:Runtime 'state.json'
$null = New-Item -ItemType Directory -Path $script:Logs -Force

Test-Case 'caminho com espaços e acentos e parsing seguro de configuração' {
    $envFile = Join-Path $script:Root 'launcher.env'
    Set-Content -Encoding UTF8 -LiteralPath $envFile -Value @('# teste', 'DB_NAME=local', 'DB_PASSWORD="x=y # demo"')
    $read = Read-LocalConfiguration $envFile
    Assert-Launcher ($read.DB_NAME -eq 'local' -and $read.DB_PASSWORD -eq 'x=y # demo') 'Parsing incorreto.'
}
Test-Case 'precedência do ambiente' {
    Use-Environment @{ DB_NAME = 'processo' } {
        $config = Get-LauncherConfiguration
        Assert-Launcher ($config.DB_NAME -eq 'processo') 'Ambiente não teve precedência.'
    }
}
Test-Case 'segredos mascarados no log' {
    $script:Secrets = @('senha-sintetica', 'token-sintetico')
    Write-LauncherLog 'DB_PASSWORD=senha-sintetica TRACKING_API_TOKEN=token-sintetico'
    $log = Get-Content -Raw -Encoding UTF8 -LiteralPath (Join-Path $script:Logs 'launcher.log')
    Assert-Launcher ($log -notmatch 'senha-sintetica|token-sintetico' -and $log -match '\*\*\*') 'Log contém valor sensível.'
}
Test-Case 'Java em formatos de java e OpenJDK, incluindo stderr combinado' {
    Assert-Launcher ((Get-JavaMajor 'openjdk version "17.0.9"') -eq 17) 'Java 17 não identificado.'
    Assert-Launcher ((Get-JavaMajor 'java version "1.8.0_401"') -eq 8) 'Java antigo mal classificado.'
    Assert-Launcher ((Get-JavaMajor 'openjdk 21.0.1 2023-10-17') -eq 21) 'Java sem version não identificado.'
}
Test-Case 'Node compatível com a faixa do Vite e npm executável' {
    Assert-Launcher ((Test-NodeVersion 'v20.19.0') -and (Test-NodeVersion 'v22.12.0') -and
        -not (Test-NodeVersion 'v21.9.0') -and -not (Test-NodeVersion 'v22.11.0')) 'Faixa incorreta.'
    $npm = Find-Tool @('npm.cmd', 'npm.exe')
    if ($npm) { Assert-Launcher ((Invoke-Tool $npm @('--version')).Code -eq 0) 'npm encontrado não iniciou.' }
}
Test-Case 'preferência por py -3 quando a versão é válida' {
    function Find-Tool($Names) { return $Names[0] }
    function Invoke-Tool($Path, $Arguments) {
        if ($Path -eq 'py.exe' -and ($Arguments -join ' ') -eq '-3 --version') { return @{ Code=0; Text='Python 3.12.1' } }
        return @{ Code=1; Text='' }
    }
    $python = Find-Python
    Assert-Launcher ($python.Path -eq 'py.exe' -and $python.Prefix[0] -eq '-3') 'Selecionou Python incorreto.'
}
Test-Case 'rejeição de alias Python que não entrega versão executável' {
    function Find-Tool($Names) { return $Names[0] }
    function Invoke-Tool($Path, $Arguments) { return @{ Code=1; Text='Microsoft Store' } }
    Assert-Launcher (-not (Find-Python)) 'Alias aceito indevidamente.'
}
Test-Case 'preferência por Maven Wrapper' {
    $path = Join-Path $script:Root 'mvnw.cmd'
    Set-Content -LiteralPath $path -Value '@exit /b 0'
    Assert-Launcher ((Find-Maven $script:Root) -eq $path) 'Wrapper ignorado.'
}
Test-Case 'porta em uso detectada sem afetar o listener' {
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    try {
        $port = $listener.LocalEndpoint.Port
        Assert-Launcher (Test-TcpPort '127.0.0.1' $port) 'Porta ocupada foi considerada livre.'
        try { $null = Test-ReuseService Spring $port @{}; throw 'Não informou conflito.' }
        catch { if ($_.Exception.Message -notmatch 'indisponível') { throw } }
        Assert-Launcher (Test-TcpPort '127.0.0.1' $port) 'Listener alheio foi afetado.'
    } finally { $listener.Stop() }
}
Test-Case 'estado inexistente e stop repetido' {
    Assert-Launcher ((Read-State).Count -eq 0) 'Estado ausente retornou registros.'
    Assert-Launcher ((Stop-Launcher 1) -and (Stop-Launcher 1)) 'Stop não idempotente.'
}
Test-Case 'estado com PID encerrado é descartado' {
    $state = @{ Spring = @{ Service='Spring'; Pid=123456789; StartTicks='638000000000000000'; Instance=[guid]::NewGuid().ToString() } }
    Save-State $state
    Assert-Launcher (Stop-Launcher 1) 'Stop falhou com processo inexistente.'
    Assert-Launcher (-not (Test-Path -LiteralPath $script:StateFile)) 'Estado obsoleto persistiu.'
}
Test-Case 'PID reciclado não é tratado como gerenciado' {
    $entry = @{ Pid=$PID; StartTicks='638000000000000000' }
    Assert-Launcher (-not (Get-ManagedProcess $entry)) 'PID conhecido com outro início foi aceito.'
}
Test-Case 'processo alheio com PID e horário coincidentes continua ativo sem evento' {
    $foreign = Start-Process -FilePath $script:PowerShellExe -ArgumentList '-NoProfile -Command "Start-Sleep -Seconds 20"' -WindowStyle Hidden -PassThru
    try {
        $state = @{ Spring = @{ Service='Spring'; Pid=$foreign.Id; StartTicks=[string]$foreign.StartTime.ToUniversalTime().Ticks; Instance=[guid]::NewGuid().ToString() } }
        Save-State $state
        Assert-Launcher (-not (Stop-Launcher 1)) 'Stop tratou processo alheio como próprio.'
        Assert-Launcher (-not $foreign.HasExited) 'Processo alheio foi encerrado.'
        Save-State @{}
    } finally { if (-not $foreign.HasExited) { $foreign.Kill() }; $foreign.Dispose() }
}
Test-Case 'URL do stub restrita a loopback e porta reservada rejeitada' {
    Assert-Launcher ((Get-StubUrl 8081) -ceq 'http://127.0.0.1:8081/rastreamento') 'Host incorreto.'
    try { $null = Get-StubUrl 8080; throw 'Porta do Spring aceita.' }
    catch { if ($_.Exception.Message -notmatch 'diferente de 8080') { throw } }
}
Test-Case '.venv com interpretador inexistente ou quebrado' {
    $venv = Join-Path $script:Root '.venv'
    Assert-Launcher (-not (Test-WorkerVenv (Join-Path $venv 'Scripts\python.exe') $venv)) '.venv ausente foi aceita.'
    function Invoke-Tool($Path, $Arguments) { return @{ Code=1; Text='No Python at ...' } }
    Assert-Launcher (-not (Test-WorkerVenv $script:PowerShellExe $venv)) '.venv quebrada foi aceita.'
}
Test-Case 'frontend sem node_modules instala via npm ci quando há lockfile' {
    Set-Content -LiteralPath (Join-Path $script:Root 'package.json') -Value '{}'
    Assert-Launcher ((Get-FrontendInstallPlan $script:Root $false).Action -eq 'install') 'Fallback npm install incorreto.'
    Set-Content -LiteralPath (Join-Path $script:Root 'package-lock.json') -Value '{}'
    Assert-Launcher ((Get-FrontendInstallPlan $script:Root $false).Action -eq 'ci') 'npm ci não escolhido.'
}
Test-Case 'causas MySQL classificadas sem incluir detalhes brutos' {
    Assert-Launcher ((Get-MySqlFailure 'Access denied for user') -match 'acesso negado') 'Autenticação mal classificada.'
    Assert-Launcher ((Get-MySqlFailure 'Unknown database') -match 'banco inexistente') 'Banco ausente mal classificado.'
    Assert-Launcher ((Get-MySqlFailure 'CONNECTION_FAILED') -match 'expirou') 'Conexão mal classificada.'
}
Test-Case 'health check aceita a lista Spring vazia e o modelo canônico' {
    Assert-Launcher (Test-ApiResponse @{ Type='application/json'; Body='[]' }) 'API vazia não foi aceita.'
    Assert-Launcher (Test-ApiResponse @{ Type='application/json'; Body='[{"codigoRastreio":"TESTE","ultimoStatus":null}]' }) 'Lista válida não foi aceita.'
    Assert-Launcher (-not (Test-ApiResponse @{ Type='application/json'; Body='[{"status":"AGUARDANDO"}]' })) 'Contrato antigo aceito.'
}
Test-Case 'o estado pode ser atualizado atomicamente' {
    Save-State @{ Spring = @{ Service='Spring'; Pid=123456789; StartTicks='638000000000000000'; Instance=[guid]::NewGuid().ToString() } }
    try {
        $state = Read-State
        $state.Spring.Pid = 123456788
        Save-State $state
        Assert-Launcher ((Read-State).Spring.Pid -eq 123456788) 'Novo estado não foi persistido.'
    } finally { Save-State @{} }
}
Test-Case 'timeout real do health check e encerramento de supervisor próprio' {
    $state = @{}
    $socket = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $socket.Start()
    $freePort = $socket.LocalEndpoint.Port
    $socket.Stop()
    try {
        Start-ManagedProcess $state Spring $script:PowerShellExe '-NoProfile -Command "Start-Sleep -Seconds 25"' $script:Root $freePort @{} 'fixture temporária'
        $deadline = (Get-Date).AddSeconds(8)
        $safe = $null
        do {
            if ([Threading.EventWaitHandle]::TryOpenExisting("Local\Rastreio-$($state.Spring.Instance)", [ref]$safe)) { break }
            Start-Sleep -Milliseconds 100
        } while ((Get-Date) -lt $deadline)
        Assert-Launcher $safe 'Supervisor não disponibilizou canal de parada.'
        $safe.Dispose()
        try { Wait-Service Spring $freePort $state.Spring 1; throw 'Health check informou falso sucesso.' }
        catch { if ($_.Exception.Message -notmatch 'falhou após') { throw } }
        Assert-Launcher (Stop-Launcher 3) 'Parada de processo gerenciado falhou.'
        Assert-Launcher (-not (Test-Path -LiteralPath $script:StateFile)) 'Estado do supervisor permaneceu.'
    } finally { if (Test-Path -LiteralPath $script:StateFile) { $null = Stop-Launcher 2 } }
}

Test-Case 'descoberta usa host explícito, porta local configurada' {
    $items = @(Get-DatabaseCandidates @{
        DB_HOST='192.0.2.20'; DB_PORT=3330; DB_HOST_SOURCE='ambiente'
        DB_FILE_HOST='192.0.2.40'; DB_FILE_PORT=3331
    })
    Assert-Launcher (($items | ForEach-Object { "$($_.Host):$($_.Port)" }) -join ',' -eq '192.0.2.20:3330,192.0.2.40:3331,localhost:3330') 'Ordem ou escopo de busca incorreto.'
    $local = @(Get-DatabaseCandidates @{ DB_HOST='localhost'; DB_PORT=3306; DB_HOST_SOURCE='padrão' })
    Assert-Launcher ($local.Count -eq 1) 'Candidato local duplicado.'
}
Test-Case 'localhost pode ser MySQL sem serviço Windows e sem mysql.exe' {
    function Show-LocalDatabaseInfo($Port) { }
    function Show-DatabaseResult($Config, $Result) { }
    function Invoke-DatabaseProbe($Config, $Python, [switch]$AllowInstall) {
        return @{ Tcp=$true; Codes=@('MYSQL_PROTOCOLO_OK','MYSQL_AUTENTICACAO_OK','MYSQL_DATABASE_OK','MYSQL_MOTOR_MARIADB','MYSQL_OK') }
    }
    $selected = Resolve-Database @{DB_HOST='localhost'; DB_PORT=3306; DB_HOST_SOURCE='padrão'} @{}
    Assert-Launcher ($selected.DB_HOST -eq 'localhost') 'Servidor local não selecionado.'
    Assert-Launcher ($selected.DB_JDBC_VENDOR -eq 'mariadb') 'Spring não receberia o driver JDBC do MariaDB.'
}
Test-Case 'credencial inválida e banco inexistente no host explícito impedem fallback' {
    $attempts = New-Object 'System.Collections.Generic.List[string]'
    function Show-DatabaseResult($Config, $Result) { }
    function Invoke-DatabaseProbe($Config, $Python, [switch]$AllowInstall) {
        $attempts.Add($Config.DB_HOST)
        return @{ Tcp=$true; Codes=@('MYSQL_PROTOCOLO_OK', $failure) }
    }
    foreach ($failure in 'MYSQL_CREDENCIAL_INVALIDA','MYSQL_DATABASE_AUSENTE','MYSQL_USUARIO_SEM_PERMISSAO') {
        $attempts.Clear()
        $selected = Resolve-Database @{DB_HOST='192.0.2.40'; DB_PORT=3306; DB_HOST_SOURCE='ambiente'} @{}
        Assert-Launcher (-not $selected -and $attempts.Count -eq 1) 'Falha de credencial/banco tentou outro destino.'
    }
}
Test-Case 'fallback local exige confirmação e não envia senha no diagnóstico' {
    $calls = New-Object 'System.Collections.Generic.List[object]'
    $answers = New-Object 'System.Collections.Generic.Queue[string]'
    function Read-Host($Prompt) { return $answers.Dequeue() }
    function Show-LocalDatabaseInfo($Port) { }
    function Show-DatabaseResult($Config, $Result) { }
    function Invoke-DatabaseProbe($Config, $Python, [switch]$AllowInstall) {
        $calls.Add(@{Host=$Config.DB_HOST; Password=[bool]$Config.DB_PASSWORD})
        $codes = switch ($Config.DB_HOST) {
            '192.0.2.20' { 'MYSQL_TIMEOUT' }
            default { if ($Config.DB_PASSWORD) { 'MYSQL_PROTOCOLO_OK'; 'MYSQL_OK' } else { 'MYSQL_PROTOCOLO_OK'; 'MYSQL_ENCONTRADO_SEM_CREDENCIAIS' } }
        }
        return @{Tcp=($codes.Count -gt 1); Codes=@($codes)}
    }
    $config = @{DB_HOST='192.0.2.20';DB_PORT=3306;DB_HOST_SOURCE='ambiente';DB_USER='teste';DB_PASSWORD='sintetica'}
    Assert-Launcher (-not (Resolve-Database $config @{} -Diagnostic)) 'Diagnóstico selecionou VM sem consentimento.'
    Assert-Launcher ($calls.Count -eq 2 -and -not $calls[1].Password) 'Descoberta enviou senha à VM.'
    $answers.Enqueue('s'); $answers.Enqueue('1')
    $selected = Resolve-Database $config @{} -Interactive
    Assert-Launcher ($selected.DB_HOST -eq 'localhost' -and $config.DB_HOST -eq '192.0.2.20') 'Não isolou a seleção para a execução.'
}
Test-Case 'porta aberta com protocolo incompatível, timeout ou SELECT negativo não libera startup' {
    function Show-LocalDatabaseInfo($Port) { }
    function Show-DatabaseResult($Config, $Result) { }
    function Invoke-DatabaseProbe($Config, $Python, [switch]$AllowInstall) {
        return @{ Tcp=($failure -ne 'MYSQL_TIMEOUT'); Codes=@($failure) }
    }
    foreach ($failure in 'MYSQL_PROTOCOLO_INVALIDO','MYSQL_TIMEOUT','MYSQL_SELECT_FALHOU','MYSQL_ENCONTRADO_SEM_CREDENCIAIS') {
        Assert-Launcher (-not (Resolve-Database @{DB_HOST='localhost';DB_PORT=3306;DB_HOST_SOURCE='padrão'} @{})) 'Liberou endpoint sem SELECT 1.'
    }
}
Test-Case 'probe diferencia TCP, falta de credenciais e autenticação' {
    function Get-TcpStatus($HostName, $Port, $Milliseconds) { return $tcp }
    function Test-WorkerVenv($Executable,$Directory) { return $false }
    function Invoke-Tool($Path,$Arguments) {
        $code = if (-not $env:DB_USER -or -not $env:DB_PASSWORD) { 'MYSQL_ENCONTRADO_SEM_CREDENCIAIS' } else { 'MYSQL_CREDENCIAL_INVALIDA' }
        return @{Code=0; Text="MYSQL_PROTOCOLO_OK\n$code".Replace('\n',[Environment]::NewLine)}
    }
    $config = @{DB_HOST='192.0.2.40'; DB_PORT=3306; DB_NAME='amor_em_mechas'; DB_USER=''; DB_PASSWORD=''}
    $python = @{Path='python.exe'; Prefix=@()}
    $tcp = 'Closed'
    Assert-Launcher ('MYSQL_NAO_ENCONTRADO' -in (Invoke-DatabaseProbe $config $python).Codes) 'Confundiu porta fechada.'
    $tcp = 'Open'
    Assert-Launcher ('MYSQL_ENCONTRADO_SEM_CREDENCIAIS' -in (Invoke-DatabaseProbe $config $python).Codes) 'Usuário vazio não diagnosticado.'
    $config.DB_USER = 'teste'
    Assert-Launcher ('MYSQL_ENCONTRADO_SEM_CREDENCIAIS' -in (Invoke-DatabaseProbe $config $python).Codes) 'Senha vazia não diagnosticada.'
    $config.DB_PASSWORD = 'sintetica'
    Assert-Launcher ('MYSQL_CREDENCIAL_INVALIDA' -in (Invoke-DatabaseProbe $config $python).Codes) 'Falha de autenticação não diagnosticada.'
}
Test-Case 'configuração assistida salva a senha somente sob autorização' {
    $file = Join-Path $script:Root 'launcher.env'
    [IO.File]::Delete($file)
    Set-Content -LiteralPath (Join-Path $script:Root 'launcher.env.example') -Value 'FRONTEND_PORT=5179'
    $answers = New-Object 'System.Collections.Generic.Queue[string]'
    foreach ($value in '1','192.0.2.40','','','usuario','1','192.0.2.40','','','usuario','2') { $answers.Enqueue($value) }
    function Read-Host($Prompt,[switch]$AsSecureString) {
        if ($AsSecureString) { return ConvertTo-SecureString 'senha-teste-wizard' -AsPlainText -Force }
        return $answers.Dequeue()
    }
    $config = Get-LauncherConfiguration $file
    $config.DB_HOST_SOURCE = 'padrão'
    $selected = Request-DatabaseConfiguration $config
    $fromFile = Read-LocalConfiguration $file
    Assert-Launcher ($selected.DB_PASSWORD -eq 'senha-teste-wizard' -and -not $fromFile.ContainsKey('DB_PASSWORD')) 'Senha de sessao foi persistida.'
    $selected = Request-DatabaseConfiguration $config
    $fromFile = Read-LocalConfiguration $file
    Assert-Launcher ($fromFile.DB_PASSWORD -eq 'senha-teste-wizard') 'Senha autorizada nao foi persistida.'
    Assert-Launcher ($selected.DB_HOST -eq '192.0.2.40' -and $fromFile.FRONTEND_PORT -eq '5179') 'Criação do arquivo incorreta.'
    Assert-Launcher ((Get-Content -Raw -LiteralPath (Join-Path $script:Logs 'launcher.log')) -notmatch 'senha-teste-wizard') 'Senha apareceu no log.'
}
Test-Case 'Spring e Worker partem das mesmas variáveis e stop não gerencia o MySQL' {
    $db = Get-DatabaseEnvironment @{DB_HOST='192.0.2.40'; DB_PORT=3306; DB_NAME='amor_em_mechas'; DB_USER='teste'; DB_PASSWORD='sintetica'}
    $spring = $db.Clone()
    $worker = $db.Clone()
    $worker.TRACKING_PROVIDER = 'stub'
    foreach ($key in 'DB_HOST','DB_PORT','DB_NAME','DB_USER','DB_PASSWORD') {
        Assert-Launcher ($spring[$key] -ceq $worker[$key]) "Contrato divergente: $key"
    }
    Assert-Launcher ('MySQL' -notin $script:Services) 'Banco remoto apareceu na lista de parada.'
}
Test-Case 'bloqueadores listam apenas dependências realmente ausentes' {
    $available = @{Java='ok';Maven='ok';Python='ok';Node='ok'}
    Assert-Launcher ((@(Get-StartupBlockers $available $true) -join ',') -ceq 'npm') 'Indicou dependência saudável como ausente.'
    Assert-Launcher (-not @(Get-StartupBlockers $available $false).Count) 'Backend exigiu npm.'
}
Test-Case 'demo recusa reutilizar apenas um dos dois consumidores do banco' {
    Assert-DatabaseReuse $true $false $false
    Assert-DatabaseReuse $true $true $true
    foreach ($spring in $true,$false) {
        try { Assert-DatabaseReuse $true $spring (-not $spring); throw 'Aceitou combinação não verificável.' }
        catch { if ($_.Exception.Message -notmatch 'mesma configuração') { throw } }
    }
}
Test-Case 'modelo SQL completo, portável e sem operações destrutivas' {
    $sqlFiles = Join-Path $projectRoot 'api-envios\sql'
    $ddl = (Get-Content -LiteralPath (Join-Path $sqlFiles '001-rastreamento.sql') -Raw).Trim()
    $sql = Get-Content -LiteralPath (Join-Path $sqlFiles 'setup-professor.sql') -Raw -Encoding UTF8
    Assert-Launcher ($sql.Contains($ddl)) 'Setup e migration divergiram.'
    Assert-Launcher ($sql -match "IDENTIFIED BY '<SENHA_FORTE_AQUI>'") 'Senha versionada ou marcador ausente.'
    Assert-Launcher (@([regex]::Matches($sql, '(?im)^CREATE TABLE IF NOT EXISTS ')).Count -eq 2) 'DDL extrapolou o módulo.'
    Assert-Launcher ($sql -notmatch '(?im)^\s*(DROP|TRUNCATE|ALTER)\b|ON\s+[^\r\n]+\.\*') 'Comando destrutivo ou grant amplo.'
    Assert-Launcher ($sql -match 'utf8mb4_unicode_ci' -and $sql -match 'ENGINE=InnoDB') 'DDL sem engine e collation portáveis.'
}
Test-Case 'clipboard recebe somente o modelo e abertura usa relativo com fallback' {
    $path = 'api-envios\sql\setup-professor.sql'
    $file = Join-Path $script:Root $path
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $file) -Force
    Copy-Item -LiteralPath (Join-Path $projectRoot $path) -Destination $file
    $observed = @{}
    $opens = [System.Collections.Generic.List[object]]::new()
    function Set-Clipboard($Value) { $observed.Copy = $Value }
    function Start-Process($FilePath, $ArgumentList, $WorkingDirectory, $ErrorAction) {
        $opens.Add(@{ Path=$FilePath; Args=$ArgumentList; Directory=$WorkingDirectory })
        if ($opens.Count -eq 1) { throw 'Sem associação de .sql' }
    }
    Use-Environment @{DB_PASSWORD='segredo-exclusivo-de-teste'} {
        Invoke-SetupSql Copy
        Invoke-SetupSql Open
    }
    Assert-Launcher ($observed.Copy -ceq (Get-Content -LiteralPath $file -Raw -Encoding UTF8)) 'Clipboard divergiu do modelo.'
    Assert-Launcher ($observed.Copy.Contains('<SENHA_FORTE_AQUI>') -and $observed.Copy -notmatch 'segredo-exclusivo-de-teste') 'Clipboard expôs segredo.'
    Assert-Launcher ($opens.Count -eq 2 -and $opens[0].Path -eq ".\$path" -and $opens[0].Directory -eq $script:Root) 'Abertura inicial não é relativa à raiz.'
    Assert-Launcher ($opens[1].Path -eq 'notepad.exe' -and $opens[1].Args -eq ('"{0}"' -f $path) -and $opens[1].Directory -eq $script:Root) 'Fallback do Notepad incorreto.'
}
Test-Case 'opção MySQL configurado revalida e retoma o modo no mesmo processo' {
    $answers = [System.Collections.Generic.Queue[string]]::new()
    foreach ($value in '99','4','4','88','') { $answers.Enqueue($value) }
    $attempts = [System.Collections.Generic.List[string]]::new()
    function Read-Host($Prompt) { $answers.Dequeue() }
    function Find-Python { return @{ Path='python.exe' } }
    function Use-LauncherLock([scriptblock]$Action) { & $Action }
    function Resolve-Database($Config, $Python, [switch]$Interactive, [switch]$PromptCredentials) {
        $attempts.Add($Config.DB_HOST)
        if ($attempts.Count -eq 2) { return $Config }
    }
    $config = @{ DB_HOST='192.0.2.10'; DB_PORT=3306; DB_NAME='amor_em_mechas'; DB_USER='rastreamento_app' }
    $result = Show-MySqlAssistant $config Demo
    Assert-Launcher ($attempts.Count -eq 2 -and $result.Mode -eq 'Demo' -and $result.Config.DB_HOST -eq $config.DB_HOST) 'Assistente não retomou com a configuração validada.'
}
Test-Case 'Spring valida o schema e compartilha o contrato DB com o Worker' {
    $properties = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'api-envios\src\main\resources\application.properties')
    Assert-Launcher ($properties -match '(?m)^spring.jpa.hibernate.ddl-auto=validate\r?$') 'Hibernate deve validar o DDL.'
    Assert-Launcher ($properties -notmatch 'createDatabaseIfNotExist') 'JDBC voltou a criar schema.'
    $launcher = Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'scripts\run_app.ps1')
    Assert-Launcher ($launcher -match '\$springEnv = \$db\.Clone\(\)' -and $launcher -match '\$workerEnv = \$db\.Clone\(\)') 'Processos devem herdar a mesma configuração.'
}
Test-Case 'probe Python verifica tabelas e grants sem executar escrita' {
    $python = Find-Python
    Assert-Launcher $python 'Instale Python 3.10+ para executar os testes do probe.'
    $result = Invoke-Tool $python.Path ($python.Prefix + @('-B', (Join-Path $projectRoot 'scripts\tests\test_mysql_probe.py')))
    Assert-Launcher ($result.Code -eq 0) $result.Text
}
Write-Host "$($count - $failures)/$count verificações concluídas. Logs temporários: $script:Logs"
if ($failures) { exit 1 }
