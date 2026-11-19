# Painel de Rastreamento de Envios

## Projeto e integrantes

Aplicação para cadastro e acompanhamento automático de encomendas, permitindo visualizar o status atual de cada envio.

### Integrantes

- Artur Alves Munhoz Assis
- Daniela Gomes de Carvalho
- Felipe de Carvalho Ferraz
- Gabriel Gonçalves Pereira
- Giovanna Prado Andrade
- Leonardo Monteiro

## Framework utilizado

O projeto usa o SpecKit para organizar a especificação, o planejamento, as tarefas e a implementação seguindo Specification-Driven Development (SDD). [Especificação da interface de encomendas](framework-worker-entregas/specs/001-visualizacao-encomendas/spec.md)

## Tecnologias

- O frontend em React e Vite cadastra encomendas por código de rastreio e nome do destinatário e exibe a lista, o status e o histórico de cada envio. [Documentação do frontend](framework-worker-entregas/README.md)
- A API Spring Boot cadastra e lista os envios em `/api/envios`, permite consultar um envio por ID e persiste os dados no MySQL ou MariaDB. [Documentação da API](api-envios/README.md)
- O Worker Python consulta o serviço de rastreamento em ciclos e grava as mudanças de status e os eventos no mesmo banco usado pela API. [Documentação do Worker](Worker%20Python%20de%20rastreamento/README.md)
- O mock com JSON Server fornece cenários locais para testar a leitura da listagem no frontend. [Validação do mock](framework-worker-entregas/mock-api/VALIDACAO.md)

## Histórico do projeto

| Data | Principais entregas |
|---|---|
| 19/11/2026 | Assistente de configuração do banco e criação e leitura do `.env` da aplicação (`c956611`, `aa112ba`). Configuração automática do banco com uma conta administrativa e inclusão do Maven Wrapper (`56ecb1c`, `3678561`). |
| 18/11/2026 | Integração do cadastro, da API de envios e do mock ao projeto. Frontend, Spring e Worker passam a operar juntos no fluxo de rastreamento (`0436311`, `1203550`, `c0a0f8d`, `7e6fa68`, `69e4bde`, `e56307b`). |
| 16/11/2026 | Implementação do cadastro de encomendas e do Worker Python de rastreamento (`3db2c5a`, `b80e931`). Atualização da documentação e da lista de integrantes. |
| 15/11/2026 | Implementação da API de envios e configuração do mock com cenários iniciais e instruções de validação (`52cf2f4`, `e91c0c6`, `9c27a7e`, `2196628`). Atualização da lista de integrantes. |
| 12/11/2026 | Criação da interface de listagem e status dos envios (`1d4fbdb`). |
| 09/11/2026 | Estrutura inicial do projeto de entregas, com React e integração HTTP da US-01 (`fcc8126`, `cd76c61`). |
| 05/11/2026 | Criação do repositório (`5208433`). |

## Inicialização rápida no Windows

O launcher usa o Maven Wrapper `api-envios\mvnw.cmd` para executar a API.
O Wrapper baixa o Maven na primeira execução caso ele ainda não esteja no
cache. Os pré-requisitos da demonstração estão no [Guia do Professor](GUIA_PROFESSOR.md).

1. Com o MySQL ou MariaDB em execução, abra `run_app.bat` e escolha
   **4 — Configurar ou validar MySQL** no menu principal.
2. Para preparar o banco local, escolha **6 — Configurar banco automaticamente**
   dentro do assistente e informe as credenciais administrativas (`root` por
   padrão). O launcher cria o banco `amor_em_mechas` e as tabelas `envios` e
   `envio_historico` quando necessário. Ele gera uma senha para
   `rastreamento_app@localhost`, atualiza a senha se a conta já existir e
   salva a configuração da aplicação no `.env` da raiz. A senha administrativa
   é usada somente durante a configuração.
3. Após a validação, escolha **2 — Iniciar demonstração completa**. No painel,
   cadastre um envio com o código `EM_TRANSITO` e um nome de destinatário.
   Aguarde o Worker atualizar o status e abra o histórico do envio.

Para preparar o banco manualmente, use as opções **1**, **2** ou **3** do
assistente para mostrar, copiar ou abrir o [SQL de preparação](api-envios/sql/setup-professor.sql).
Substitua `<SENHA_FORTE_AQUI>` em uma cópia, execute o SQL e escolha
**4 — MySQL configurado — validar e continuar**. Esse caminho permite ajustar
a origem da conta para um banco em VM ou servidor remoto.

| Opção | O que faz |
|---|---|
| 1 — Iniciar aplicação web | Inicia Spring e Vite após validar o MySQL. |
| 2 — Iniciar demonstração completa | Inicia Spring, stub local, Worker e Vite. |
| 3 — Somente backend | Inicia Spring. |
| 4 — Configurar ou validar MySQL | Abre o assistente e permite retomar a execução após a validação. |
| 5 — Verificar ambiente | Exibe versões, compatibilidade e diagnóstico MySQL. |
| 6 — Parar serviços iniciados pelo launcher | Encerra os processos registrados pelo launcher. |
| 0 — Sair | Fecha o menu. Os serviços continuam ativos até a parada. |

Na primeira execução, o launcher cria o `.env` na raiz do projeto a partir
de `launcher.env.example`. Para cada chave, ele prioriza as variáveis do
processo, o `.env`, o `launcher.env` de instalações anteriores e os padrões.
Na configuração manual, o assistente permite manter as credenciais na sessão
atual ou salvá-las no `.env`, ignorado pelo Git. O launcher passa
a mesma configuração validada ao Spring e ao Worker. Ele valida TCP, protocolo,
autenticação, `SELECT 1`, acesso a `amor_em_mechas`, leitura das duas tabelas
e grants diretos de CRUD. A validação de grants consulta metadados, sem
gravar dados. O launcher seleciona o driver JDBC do motor identificado,
e o Spring usa `ddl-auto=validate`.

A primeira validação pode preparar as dependências Python na `.venv`
local. MySQL/MariaDB é instalado e administrado pelo responsável pelo banco.

| Configuração | Padrão |
|---|---|
| MySQL — `DB_HOST`, `DB_PORT`, `DB_NAME` | `localhost`, `3306`, `amor_em_mechas` |
| `SPRING_PORT`, `FRONTEND_PORT`, `STUB_PORT` | `8080`, `5173`, `8081` |
| `STARTUP_TIMEOUT_SECONDS`, `STOP_TIMEOUT_SECONDS` | `180`, `12` |
| `TRACKING_TIMEOUT_SECONDS`, `POLL_INTERVAL_SECONDS` | `10`, `5` na demonstração |

Spring, Vite e stub escutam em loopback. Para trocar a porta, ajuste a
variável correspondente e pare a instância anterior. O modo de
demonstração gera a URL local do stub e limpa o token no processo filho.
O stub simula respostas por código e serve exclusivamente para demonstração.
O provider de produção segue em `PROVIDER_AGUARDANDO_CONTRATO`.

Os logs ficam em `.launcher/logs/`, separados por serviço. `spring.log`,
`frontend.log`, `worker.log`, `stub.log` e `launcher.log` têm rotação
local. Os logs de preparação ficam em arquivos `*-setup.log`.
Os PIDs ficam em `.launcher/state.json`. Um serviço externo reutilizado
continua sob controle de seu proprietário. O MySQL mantém o ciclo de vida
do serviço de desenvolvimento.

Para automatizar, use `run_app.bat -Mode Web`, `-Mode Demo`,
`-Mode Backend` ou `-Mode Check`. Use `-NoBrowser` para evitar a abertura,
`-ReuseExisting` para confirmar conscientemente o reuso de uma instância
compatível e `-ForceDependencies` para repetir a preparação local.
O npm usa `npm ci` quando há lockfile. O Worker usa o Python da própria
`.venv` e reaproveita as dependências enquanto o hash de `requirements.txt`
e as importações estiverem válidos. O autoteste roda com
`run_app.bat -SelfTest`.

### Problemas comuns

| Mensagem ou sintoma | O que fazer |
|---|---|
| Java não encontrado | Instale o JDK 17 ou superior, configure `PATH` e `JAVA_HOME` e execute `java -version` e `.\api-envios\mvnw.cmd --version` a partir da raiz. |
| Python aponta para outro computador ou `No Python at ...` | Instale Python local. O launcher arquiva uma `.venv` inválida em `.launcher/` e cria outra. Para recriá-la manualmente, pare o launcher, renomeie a pasta `.venv` do Worker e rode a demonstração novamente. |
| pip ou npm retornou erro | Abra o log `worker-setup.log` ou `frontend-setup.log`, confira acesso ao registro e repita com `-ForceDependencies`. |
| Porta 8080 ou 5173 ocupada | Confira o PID exibido. Reuse a instância somente se for do mesmo projeto ou altere a porta no `.env` da raiz. |
| MySQL não responde | Confirme `DB_HOST`, `DB_PORT` e se o servidor está ouvindo na interface apropriada. |
| `Access denied for user` | Revise usuário, senha e permissões da conta no schema de desenvolvimento. |
| `Unknown database` | Use a configuração automática do assistente ou execute o SQL de preparação para criar `amor_em_mechas`. |
| Spring iniciou e encerrou | Abra `spring.log` e confira Maven, banco e porta. |
| Worker não iniciou | Abra `worker.log` e `worker-setup.log`. A opção 1 permite iniciar apenas a aplicação web. |
| Frontend não abriu | Confira `frontend.log` e a saúde do Spring. Se a associação do navegador falhar, abra a URL exibida no terminal. |
| ExecutionPolicy | Execute pelo `.bat`, que aplica Bypass somente ao processo atual. Se houver política corporativa mais restritiva, consulte o administrador. |
| Processos continuam ativos | Use `stop_app.bat`. O launcher tenta uma interrupção e, se necessário, encerra a árvore que conseguiu verificar. Serviços externos reutilizados e MySQL permanecem ativos. |

## Banco MySQL em VM ou servidor remoto

Informe o endereço do seu servidor na opção 5 do assistente ou em
`DB_HOST`, junto com `DB_PORT`. O endpoint padrão é `localhost:3306`.
O fallback para localhost na mesma porta testa o protocolo antes
de solicitar autorização para autenticar. Para verificar a rede no
Windows, use `Test-NetConnection -ComputerName <host> -Port 3306`.

O script SQL concede acesso apenas a `envios` e `envio_historico`.
Na VM, a parte de host da conta representa a origem do cliente conforme
vista pelo servidor. Use os mesmos cinco `DB_*` para Spring e Worker.
Para trocar de Aplicação web para Demonstração completa, pare a execução
anterior para que os dois processos recebam a configuração atual.

## Como rodar

### Frontend

```bash
cd framework-worker-entregas
npm install
npm run dev
```

Inicie o Spring em `localhost:8080` e deixe `VITE_API_BASE_URL` vazia para
usar os caminhos relativos `/api/envios`. O Vite encaminha `/api` para o Spring
em desenvolvimento. Defina `API_PROXY_TARGET` se o Spring usar outro endereço.

Para publicar o build na mesma origem, encaminhe `/api` ao Spring no servidor
que hospeda a interface. Se as origens forem separadas, defina
`VITE_API_BASE_URL` com a origem pública da API antes de `npm run build` e
autorize a origem da interface na configuração CORS do servidor.

As datas logísticas são exibidas em `America/Sao_Paulo`. A tabela usa
`dataAtualizacao` e recorre a `atualizadoEm` quando o primeiro campo está
ausente. O histórico é atualizado com a listagem, inclusive quando o diálogo
está aberto.
