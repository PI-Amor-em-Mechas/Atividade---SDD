function Invoke-SetupSql([string]$Action) {
    $path = 'api-envios\sql\setup-professor.sql'
    Push-Location -LiteralPath $script:Root
    try {
        if ($Action -in 'Show','Copy') {
            $sql = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            if ($sql -notmatch "(?im)^CREATE USER [^\r\n]+ IDENTIFIED BY '<SENHA_FORTE_AQUI>';\s*$") {
                throw 'Restaure o marcador de senha no modelo e use uma cópia para executar o SQL.'
            }
        }
        switch ($Action) {
            Show {
                Write-Host $path
                Write-Host $sql
                Write-Host @'
========================================
COMO EXECUTAR
========================================
Substitua <SENHA_FORTE_AQUI> por uma senha local forte.
No Linux, se você tiver sudo para administrar o banco:
  sudo mariadb (depois cole o SQL editado)
  sudo mariadb < setup-professor.sql (use uma cópia editada)
No MySQL Workbench ou DBeaver, abra a conexão administrativa,
carregue o arquivo, substitua o marcador e execute.
'@
                $null = Read-Host 'Pressione Enter para voltar'
            }
            Copy {
                Set-Clipboard -Value $sql
                Write-Host '[OK] SQL copiado. Substitua <SENHA_FORTE_AQUI> por uma senha local forte.'
            }
            Open {
                Write-Host 'Use uma cópia do SQL para preencher a senha antes de executar.'
                Use-Environment @{ DB_PASSWORD = $null; TRACKING_API_TOKEN = $null } {
                    try { Start-Process -FilePath ".\$path" -WorkingDirectory $script:Root -ErrorAction Stop }
                    catch { Start-Process -FilePath 'notepad.exe' -ArgumentList ('"{0}"' -f $path) -WorkingDirectory $script:Root }
                }
            }
        }
    } finally { Pop-Location }
}

function New-AppPassword {
    $chars = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
    $bytes = New-Object byte[] 20
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    # Prefix guarantees upper, lower, digit and symbol for MySQL validate_password.
    return 'Ra9!' + -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

function Invoke-AutomaticDatabaseSetup($Config) {
    Write-Host @'
========================================
CONFIGURAÇÃO AUTOMÁTICA DO BANCO
========================================
Será usada a conta administrativa do MySQL (normalmente root) para criar:
  - database amor_em_mechas
  - tabelas envios e envio_historico
  - usuário rastreamento_app (senha gerada e salva no .env da raiz)
A senha do administrador NÃO é salva.
'@
    $adminUser = Read-Host 'Usuário administrador [root]'
    if (-not $adminUser) { $adminUser = 'root' }
    $secret = Read-Host "Senha do $adminUser no MySQL" -AsSecureString
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secret)
    try { $adminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer); $secret.Dispose() }

    $proposal = $Config.Clone()
    $proposal.DB_NAME = 'amor_em_mechas'
    $proposal.DB_USER = 'rastreamento_app'
    $proposal.DB_PASSWORD = New-AppPassword
    $script:Secrets = @($adminPassword, $proposal.DB_PASSWORD, $Config.DB_PASSWORD, $Config.TRACKING_API_TOKEN)

    $python = Find-Python
    if (-not $python) { throw 'Instale Python 3.10+ para configurar o banco automaticamente.' }
    Write-LauncherLog 'Preparando Connector/Python (pode levar alguns segundos na primeira vez).'
    $venvExe = Prepare-Worker $python
    $setupScript = Join-Path $PSScriptRoot 'mysql-setup.py'
    $values = @{
        DB_HOST = $proposal.DB_HOST; DB_PORT = $proposal.DB_PORT
        DB_ADMIN_USER = $adminUser; DB_ADMIN_PASSWORD = $adminPassword
        DB_PASSWORD = $proposal.DB_PASSWORD; TRACKING_API_TOKEN = $null
    }
    $result = Use-Environment $values { Invoke-Tool $venvExe @('-B', $setupScript) }
    $adminPassword = $null
    $codes = @($result.Text -split '\r?\n' | Where-Object { $_ -cmatch '^SETUP_' })
    if ('SETUP_OK' -notin $codes) {
        $detail = switch -Regex ($codes -join ' ') {
            'SETUP_ADMIN_NEGADO' { "Senha do $adminUser incorreta (ou usuário inexistente)." }
            'SETUP_ADMIN_SEM_PERMISSAO' { "A conta $adminUser não pode criar banco/usuário. Use root." }
            'SETUP_POLITICA_SENHA' { 'A política de senha do MySQL recusou a senha gerada. Rode novamente.' }
            'SETUP_HOST_INACESSIVEL' { "MySQL não respondeu em $($proposal.DB_HOST):$($proposal.DB_PORT)." }
            'SETUP_DRIVER_AUSENTE' { 'Connector/Python ausente. Rode novamente para reinstalar.' }
            default { "Falha ao aplicar o SQL ($($codes -join ', '))." }
        }
        throw "Configuração automática falhou: $detail"
    }
    Write-LauncherLog 'Banco, tabelas e usuário rastreamento_app criados/atualizados.' 'OK'
    Save-DatabaseConfiguration $proposal
    return $proposal
}

function Show-MySqlAssistant($Config, [string]$PendingMode) {
    while ($true) {
        Write-Host @'
========================================
PREPARAÇÃO DO BANCO DE DADOS
========================================
Banco amor_em_mechas. Tabelas envios e envio_historico.

[1] Mostrar SQL de configuração
[2] Copiar SQL para a área de transferência
[3] Abrir arquivo SQL
[4] MySQL configurado — validar e continuar
[5] Alterar host, porta, usuário ou banco
[6] Configurar banco automaticamente (pede a senha do root)
[0] Voltar ao menu principal
'@
        $answer = Read-Host 'Escolha uma opção [0]'
        try {
            switch ($answer) {
                { $_ -in '', '0' } { return @{ Config = $Config } }
                '1' { Invoke-SetupSql Show }
                '2' { Invoke-SetupSql Copy }
                '3' { Invoke-SetupSql Open }
                '5' {
                    $proposal = Request-DatabaseConfiguration $Config
                    if ($proposal) { $Config = $proposal }
                }
                { $_ -in '4', '6' } {
                    if ($_ -eq '6') { $Config = Invoke-AutomaticDatabaseSetup $Config }
                    $python = Find-Python
                    $selected = Use-LauncherLock { Resolve-Database $Config $python -Interactive -PromptCredentials }
                    if (-not $selected) { break }
                    if ($selected.PendingConfig) {
                        $Config = $selected.PendingConfig
                        break
                    }
                    $Config = $selected
                    Write-Host @"
========================================
MYSQL CONFIGURADO
========================================
Servidor: $($Config.DB_HOST):$($Config.DB_PORT)
Database: $($Config.DB_NAME)
Usuário: $($Config.DB_USER)
Tabela envios: OK
Tabela envio_historico: OK
SELECT 1: OK
Spring: pronto para validar schema
Worker: pronto para iniciar

[1] Iniciar aplicação web
[2] Iniciar demonstração completa
[3] Somente backend
[0] Voltar ao menu
"@
                    $modes = @{ '1' = 'Web'; '2' = 'Demo'; '3' = 'Backend' }
                    do {
                        $prompt = if ($PendingMode) { 'Escolha uma opção [Enter retoma o modo anterior]' } else { 'Escolha uma opção' }
                        $choice = Read-Host $prompt
                        if (-not $choice -and $PendingMode) { return @{ Config = $Config; Mode = $PendingMode } }
                        if ($choice -in '', '0') { return @{ Config = $Config } }
                        if ($modes.ContainsKey($choice)) { return @{ Config = $Config; Mode = $modes[$choice] } }
                        Write-Host '[AVISO] Opção inválida.'
                    } while ($true)
                }
                default { Write-Host '[AVISO] Opção inválida.' }
            }
        } catch { Write-LauncherLog $_.Exception.Message 'ERRO' }
    }
}
