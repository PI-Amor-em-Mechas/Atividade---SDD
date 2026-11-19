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

O projeto utiliza o SpecKit como framework de Specification-Driven Development (SDD).

O SpecKit foi escolhido por permitir estruturar o desenvolvimento a partir da especificação, passando pelo planejamento, definição das tarefas e implementação.

## Tecnologias

- React
- Vite
- Spring Boot
- MySQL/MariaDB
- Python
- JSON Server
- SpecKit

## Inicialização rápida no Windows

Siga o [Guia do Professor](GUIA_PROFESSOR.md) para preparar o banco e
executar a demonstração. Dê duplo clique em `run_app.bat` e selecione
**4 — Configurar ou validar MySQL**. O assistente mostra, copia ou abre o
[SQL de preparação](api-envios/sql/setup-professor.sql) com um marcador de
senha para preencher em uma cópia. Após executar o SQL no seu banco,
escolha **4 — MySQL configurado — validar e continuar** no assistente.

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
O assistente aceita alterações na sessão atual e salva a senha no `.env`,
ignorado pelo Git, somente se você selecionar essa opção. O launcher passa
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
| Java não encontrado | Instale JDK 17+, configure PATH e `JAVA_HOME` e rode `java -version` e `mvn --version`. |
| Python aponta para outro computador ou `No Python at ...` | Instale Python local. O launcher arquiva uma `.venv` inválida em `.launcher/` e cria outra. Para recriá-la manualmente, pare o launcher, renomeie a pasta `.venv` do Worker e rode a demonstração novamente. |
| pip ou npm retornou erro | Abra o log `worker-setup.log` ou `frontend-setup.log`, confira acesso ao registro e repita com `-ForceDependencies`. |
| Porta 8080 ou 5173 ocupada | Confira o PID exibido. Reuse a instância somente se for do mesmo projeto ou altere a porta no `.env` da raiz. |
| MySQL não responde | Confirme `DB_HOST`, `DB_PORT` e se o servidor está ouvindo na interface apropriada. |
| `Access denied for user` | Revise usuário, senha e permissões da conta no schema de desenvolvimento. |
| `Unknown database` | Execute o SQL de preparação para criar `amor_em_mechas`. |
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
