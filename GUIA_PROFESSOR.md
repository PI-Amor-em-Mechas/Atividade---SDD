# Execução da demonstração

## 1. Pré-requisitos

- Windows com PowerShell 5.1+.
- JDK 17+ e Maven no PATH ou Maven Wrapper no módulo da API.
- Python 3.10+, com acesso às dependências do Worker na primeira execução.
- Node.js com npm compatível com Vite 8. Use Node 20.19+ na série 20 ou 22.12+.
- MySQL 8+ ou MariaDB 11+ iniciado, local ou alcançável pela rede. Use uma conta administrativa da sua instalação para preparar o banco.

## 2. Preparar o banco

1. Extraia ou clone o projeto e dê duplo clique em `run_app.bat`.
2. No menu principal, escolha **4 — Configurar ou validar MySQL**. O assistente diagnostica o endpoint configurado. Para usar uma VM ou outra porta, escolha **5 — Alterar host, porta, usuário ou banco** no assistente.
3. Se faltar o banco, as tabelas ou a conta, use **1 — Mostrar**, **2 — Copiar** ou **3 — Abrir** o [SQL de preparação](api-envios/sql/setup-professor.sql). Trabalhe em uma cópia ou cole no editor SQL do cliente. Substitua `<SENHA_FORTE_AQUI>` por uma senha local forte.
4. Execute o SQL no Workbench, no DBeaver ou no cliente de linha de comando com a conta administrativa. No Linux, se sua conta tiver sudo para administrar o banco, você pode usar `sudo mariadb < setup-professor.sql` com a cópia editada. Para banco remoto, troque `localhost` no SQL pelo IP ou nome de origem do cliente Windows visto pelo servidor. Use `%` apenas se a demonstração exigir.
5. Use a mesma senha no launcher. A entrada é mascarada. Você pode manter a configuração só durante a sessão ou salvar em `launcher.env`, arquivo local ignorado pelo Git. Se optar por salvar, mantenha o arquivo privado.

## 3. Iniciar

Volte ao assistente e escolha **4 — MySQL configurado — validar e continuar**. Ao ver **MYSQL CONFIGURADO**, escolha **2 — Iniciar demonstração completa**. Spring, stub local, Worker e frontend iniciam e o navegador padrão abre. Cadastre `EM_TRANSITO` para observar uma atualização do Worker.

A demonstração usa stub local. O provider de produção segue em `PROVIDER_AGUARDANDO_CONTRATO`.

## 4. Encerrar

Dê duplo clique em `stop_app.bat` ou escolha **6 — Parar serviços iniciados pelo launcher** no menu principal. O banco externo continua ativo.

## 5. Problemas comuns

| Sintoma | Ação |
|---|---|
| Porta 3306 fechada ou ocupada por outro serviço | Confira se o MySQL/MariaDB está iniciado e se host e porta correspondem ao endpoint do banco. |
| Usuário ou senha inválidos | Confira a conta de aplicação, a origem permitida no SQL e a senha. Use a opção 5 do assistente para corrigir. |
| Ausência de `amor_em_mechas`, `envios` ou `envio_historico` | Execute o SQL de preparação e valide novamente. |
| Grants insuficientes | Aplique os grants diretos nas duas tabelas com a conta administrativa. Se a conta já existia, confira também os privilégios anteriores. |
| Java, Python ou Node ausente | Instale o pré-requisito, confira o PATH e abra um novo launcher. A opção 5 do menu principal mostra as dependências encontradas. |
