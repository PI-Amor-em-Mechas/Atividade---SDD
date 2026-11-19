# Painel de Rastreamento de Envios

## Projeto e integrantes

O **Painel de Rastreamento de Envios** é uma aplicação para cadastro e acompanhamento automático de encomendas, permitindo visualizar o status atual de cada envio e seu histórico de atualizações.

O projeto busca centralizar o acompanhamento das encomendas e reduzir a necessidade de consultas manuais. Para isso, a solução integra uma interface web, uma API, um banco de dados e um Worker responsável pela atualização automática dos rastreamentos.

### Integrantes

- Artur Alves Munhoz Assis
- Daniela Gomes de Carvalho
- Felipe de Carvalho Ferraz
- Gabriel Gonçalves Pereira
- Giovanna Prado Andrade
- Leonardo Monteiro

---

## Framework utilizado

O projeto utiliza o **SpecKit** como framework de Specification-Driven Development (SDD).

Escolhemos o SpecKit principalmente pela nossa **familiaridade com Git** e pela forma como o framework organiza especificação, planejamento e tarefas em arquivos que podem ser versionados junto com o código.

Isso se encaixou bem no fluxo de trabalho do grupo, pois permitiu manter as decisões do projeto registradas no próprio repositório.

Em vez de partir diretamente para a implementação, utilizamos a especificação como referência para definir o comportamento esperado da funcionalidade. Depois disso, avançamos para o planejamento, divisão das tarefas, implementação e validação.

O fluxo adotado foi:

```text
Especificação
      ↓
Planejamento
      ↓
Tarefas
      ↓
Implementação
      ↓
Validação
```

Essa abordagem ajudou a evitar que decisões importantes sobre o funcionamento e a arquitetura do sistema fossem tomadas automaticamente pelo agente durante a implementação.

---

## Tecnologias

- React
- Vite
- Spring Boot
- MySQL/MariaDB
- Python
- JSON Server / Stub local
- SpecKit
- Git
- GitHub

---

## Arquitetura da solução

A solução separa as responsabilidades entre interface, API, persistência e atualização automática dos rastreamentos.

```text
Usuário
   |
   v
React / Vite
   |
   | HTTP /api
   v
Spring Boot
   |
   v
MySQL / MariaDB
   ^
   |
Worker Python
   |
   v
Provider de rastreamento / Stub local
```

### Front-end

O front-end foi desenvolvido com **React e Vite**.

Ele é responsável por:

- apresentar a listagem de envios;
- exibir o status atual;
- permitir o cadastro de encomendas;
- apresentar o histórico;
- informar erros ao usuário;
- atualizar as informações exibidas quando houver alterações.

### API

O backend foi desenvolvido com **Spring Boot**.

Ele é responsável por:

- disponibilizar a API HTTP;
- cadastrar encomendas;
- listar os envios existentes;
- disponibilizar informações de histórico;
- validar os dados recebidos;
- realizar a comunicação com o banco de dados.

### Worker

O Worker foi desenvolvido em **Python** e é executado separadamente da aplicação web.

Sua responsabilidade é realizar o acompanhamento automático dos rastreamentos.

O fluxo principal do Worker consiste em:

1. consultar os envios que precisam ser atualizados;
2. consultar o provider de rastreamento ou o stub local;
3. interpretar a resposta;
4. identificar alterações no status;
5. atualizar o envio;
6. registrar as mudanças no histórico.

A separação do Worker da API foi importante porque a atualização periódica dos rastreamentos possui um ciclo de execução diferente das requisições HTTP realizadas pelo usuário.

### Banco de dados

O projeto utiliza **MySQL/MariaDB**.

O schema utilizado é:

```text
amor_em_mechas
```

Para a funcionalidade de rastreamento, são utilizadas principalmente as tabelas:

```text
envios
envio_historico
```

A tabela `envios` mantém as informações e o estado atual das encomendas, enquanto `envio_historico` permite registrar as mudanças ocorridas ao longo do rastreamento.

---

## Funcionalidades implementadas

### Listagem dos envios

A aplicação permite consultar os envios cadastrados e visualizar seus respectivos status.

A interface apresenta os dados retornados pela API e trata estados de carregamento, ausência de registros e falhas de comunicação.

As datas logísticas são apresentadas no fuso `America/Sao_Paulo`. A tabela utiliza `dataAtualizacao` e recorre a `atualizadoEm` quando o primeiro campo não está disponível.

### Cadastro de encomendas

O usuário pode cadastrar uma nova encomenda para que ela passe a ser acompanhada pelo sistema.

O cadastro é enviado para a API Spring Boot, validado e persistido no banco de dados. Depois de cadastrado, o envio fica disponível na listagem e também pode ser processado pelo Worker.

### Atualização automática pelo Worker

O Worker consulta periodicamente os envios disponíveis para atualização. Quando encontra uma alteração de status, atualiza os dados do envio e registra a mudança em seu histórico.

O intervalo de execução pode ser configurado por meio das variáveis do ambiente.

### Mock / Stub de rastreamento

Como o provider de produção ainda depende de um contrato externo, o projeto possui um mecanismo local para simular respostas de rastreamento.

O stub permite executar a demonstração completa sem depender de uma API externa real. Ele pode simular diferentes respostas conforme o código utilizado, permitindo validar alterações de status, diferentes estados do envio, respostas válidas, cenários de erro e o comportamento do Worker.

O provider de produção permanece identificado como:

```text
PROVIDER_AGUARDANDO_CONTRATO
```

O stub é utilizado exclusivamente para demonstração e validação.

---

## Como rodar

### Inicialização rápida no Windows

A maneira recomendada de executar o projeto no Windows é utilizar:

```bat
run_app.bat
```

Ao abrir o launcher, é apresentado o seguinte menu:

| Opção | O que faz |
|---|---|
| 1 — Iniciar aplicação web | Inicia Spring e Vite após validar o MySQL |
| 2 — Iniciar demonstração completa | Inicia Spring, stub local, Worker e Vite |
| 3 — Somente backend | Inicia o Spring |
| 4 — Configurar ou validar MySQL | Abre o assistente de configuração e validação |
| 5 — Verificar ambiente | Exibe versões, compatibilidade e diagnóstico do MySQL |
| 6 — Parar serviços iniciados pelo launcher | Encerra os processos registrados pelo launcher |
| 0 — Sair | Fecha o menu |

Para a primeira execução, recomendamos utilizar:

```text
4 — Configurar ou validar MySQL
```

Após a validação do ambiente e do banco, para executar a demonstração completa utilize:

```text
2 — Iniciar demonstração completa
```

Esse modo inicia Spring Boot, stub local, Worker Python e React/Vite.

### Configuração do ambiente

Na primeira execução, o launcher cria o arquivo `.env` na raiz do projeto a partir do arquivo de exemplo.

A senha pode ser salva no `.env` quando essa opção for escolhida. O arquivo `.env` é ignorado pelo Git e não deve conter credenciais versionadas no repositório.

Spring e Worker reutilizam a mesma configuração de banco validada pelo launcher.

### Configuração padrão

| Configuração | Padrão |
|---|---|
| `DB_HOST` | `localhost` |
| `DB_PORT` | `3306` |
| `DB_NAME` | `amor_em_mechas` |
| `SPRING_PORT` | `8080` |
| `FRONTEND_PORT` | `5173` |
| `STUB_PORT` | `8081` |
| `STARTUP_TIMEOUT_SECONDS` | `180` |
| `STOP_TIMEOUT_SECONDS` | `12` |
| `TRACKING_TIMEOUT_SECONDS` | `10` |
| `POLL_INTERVAL_SECONDS` | `5` na demonstração |

### Validação do banco

Antes de iniciar todos os serviços, o launcher valida:

- conectividade TCP;
- protocolo do banco;
- autenticação;
- execução de `SELECT 1`;
- acesso ao schema `amor_em_mechas`;
- leitura das tabelas utilizadas;
- permissões necessárias para execução.

O Spring utiliza:

```text
ddl-auto=validate
```

Dessa forma, a estrutura esperada é validada sem criação automática das tabelas pelo Hibernate.

### Executando o front-end manualmente

```bash
cd framework-worker-entregas
npm install
npm run dev
```

O front-end utiliza por padrão `http://localhost:5173`.

Durante o desenvolvimento, o Vite encaminha `/api` para o Spring Boot, disponível por padrão em `http://localhost:8080`.

Se o Spring estiver sendo executado em outro endereço, é possível configurar `API_PROXY_TARGET`. Quando front-end e backend forem publicados em origens diferentes, pode ser utilizado `VITE_API_BASE_URL`.

### Banco em VM ou servidor remoto

Para utilizar um MySQL/MariaDB remoto, devem ser configurados:

```text
DB_HOST
DB_PORT
DB_NAME
DB_USER
DB_PASSWORD
```

Para verificar a conectividade no Windows:

```powershell
Test-NetConnection -ComputerName <host> -Port 3306
```

Spring e Worker devem utilizar os mesmos parâmetros de conexão.

### Ambiente Python do Worker

O launcher utiliza uma `.venv` própria para o Worker.

As dependências são reaproveitadas enquanto a configuração e as importações estiverem válidas. Caso seja detectado um ambiente virtual incompatível ou criado em outra máquina, ele pode ser descartado e recriado.

### Logs

Os logs ficam armazenados em:

```text
.launcher/logs/
```

Entre os principais arquivos estão:

```text
spring.log
frontend.log
worker.log
stub.log
launcher.log
worker-setup.log
frontend-setup.log
```

Os processos iniciados pelo launcher são registrados em:

```text
.launcher/state.json
```

### Execução automatizada

```bat
run_app.bat -Mode Web
run_app.bat -Mode Demo
run_app.bat -Mode Backend
run_app.bat -Mode Check
```

Outras opções disponíveis incluem:

```text
-NoBrowser
-ReuseExisting
-ForceDependencies
```

O autoteste do launcher pode ser executado com:

```bat
run_app.bat -SelfTest
```

---

## Artefatos do SpecKit

Os artefatos do processo SDD foram mantidos junto com o projeto para que as decisões tomadas durante especificação, planejamento e implementação também fossem versionadas.

Os principais documentos utilizados no processo são:

```text
spec.md
plan.md
tasks.md
```

Eles representam o seguinte fluxo:

```text
spec.md
   ↓
plan.md
   ↓
tasks.md
   ↓
Código
   ↓
Validação
```

A `spec.md` registra os requisitos e o comportamento esperado da funcionalidade. A `plan.md` transforma os requisitos em uma proposta técnica de implementação. A `tasks.md` divide o plano em atividades executáveis pelos integrantes.

---

## Divisão das tarefas

A divisão abaixo foi consolidada a partir do trabalho realizado e do histórico de commits do projeto.

| Integrante | Responsabilidade principal |
|---|---|
| **Artur Alves Munhoz Assis** | Estrutura React e integração HTTP; integração entre front-end, Spring e Worker; integração dos merges; launcher; configuração assistida do MySQL/MariaDB; geração e leitura do `.env`. |
| **Daniela Gomes de Carvalho** | Inicialização do projeto Worker; desenvolvimento do front-end da listagem e dos status dos envios; atualização da documentação. |
| **Felipe de Carvalho Ferraz** | Desenvolvimento da API de envios utilizada pela aplicação e pelo Worker. |
| **Gabriel Gonçalves Pereira** | Desenvolvimento do Worker de rastreamento em Python e ajustes de documentação relacionados aos integrantes. |
| **Giovanna Prado Andrade** | Configuração da mock API; criação dos cenários iniciais de envios; documentação da validação do mock. |
| **Leonardo Monteiro** | Desenvolvimento do cadastro de encomendas. |

A especificação e o planejamento foram discutidos pelo grupo. As responsabilidades acima representam principalmente as implementações identificadas no histórico do projeto e não excluem a participação coletiva nas revisões e integrações.

---

## Validação

A validação considerou não apenas o funcionamento isolado da interface, mas o fluxo entre os diferentes componentes da solução.

```text
Usuário cadastra envio
        ↓
React envia requisição
        ↓
Spring valida e persiste
        ↓
MySQL/MariaDB
        ↓
Worker identifica o envio
        ↓
Worker consulta Stub/Provider
        ↓
Status é atualizado
        ↓
Histórico é registrado
        ↓
Interface apresenta atualização
```

Também foram considerados cenários de erro e problemas relacionados à preparação do ambiente.

---

## Reflexão

### Que decisão o agente teria tomado sozinho e a spec evitou?

Uma das principais decisões que a especificação evitou deixar exclusivamente para o agente foi **como dividir as responsabilidades entre o front-end, o Spring Boot e o Worker**.

Sem uma especificação anterior à implementação, seria possível concentrar a lógica de atualização dos rastreamentos diretamente no front-end ou no backend responsável pelas requisições da interface.

A especificação permitiu manter essas responsabilidades separadas. O front-end ficou responsável pela interação com o usuário, o Spring Boot pela API e persistência, enquanto o Worker ficou responsável pelo processamento periódico das atualizações de rastreamento.

Essa separação foi importante porque o Worker possui um ciclo de execução diferente de uma requisição comum. Ele precisa consultar periodicamente os rastreamentos e registrar alterações independentemente de uma ação imediata do usuário.

Assim, a spec ajudou a impedir que uma decisão arquitetural importante fosse tomada somente com base na solução mais conveniente sugerida pelo agente.

### Que inconsistência a validação encontrou? Estava na spec ou no código?

A principal inconsistência encontrada durante a validação estava na **configuração do ambiente**.

Os componentes estavam implementados, mas a execução integrada ainda poderia falhar porque Spring, Worker e launcher nem sempre recebiam a mesma configuração de banco. Também existiam dependências de configurações presentes apenas na máquina utilizada durante o desenvolvimento.

Entre os problemas identificados estavam:

- ausência ou leitura inconsistente do arquivo `.env`;
- credenciais de banco não centralizadas;
- possibilidade de diferenças entre as configurações utilizadas pelo Spring e pelo Worker;
- dificuldade para preparar o MySQL/MariaDB em outro computador;
- ambiente virtual Python inválido ou associado a outra máquina;
- portas utilizadas por processos anteriores;
- dificuldade para identificar qual serviço havia falhado durante a inicialização.

A inconsistência estava principalmente no **código de inicialização e na preparação do ambiente**, e não na especificação funcional.

A especificação previa o funcionamento integrado dos componentes, porém a implementação ainda dependia excessivamente das configurações locais da máquina utilizada no desenvolvimento.

Para resolver isso, implementamos:

- launcher com configuração assistida;
- criação e leitura do `.env`;
- arquivo de configuração de exemplo;
- validação do MySQL/MariaDB;
- validação das credenciais;
- validação do schema e das tabelas;
- compartilhamento da mesma configuração entre Spring e Worker;
- preparação da `.venv`;
- diagnóstico de portas;
- controle dos processos iniciados;
- logs separados por serviço;
- stub local para execução da demonstração.

Essa etapa mostrou que uma funcionalidade não pode ser considerada completamente validada apenas porque funciona na máquina de quem a desenvolveu. O ambiente também precisava ser reproduzível para os demais integrantes e para o professor durante a execução.

### Como o framework ajudou ou atrapalhou a coordenação do grupo?

O SpecKit ajudou principalmente porque o grupo já possuía familiaridade com **Git**.

Manter a especificação, o planejamento e as tarefas em arquivos versionados tornou o processo natural para o grupo.

Em vez de deixar decisões importantes somente em conversas com o agente ou em mensagens entre os integrantes, conseguimos manter uma referência no próprio projeto.

A sequência `Spec → Plan → Tasks → Implementação → Validação` ajudou a organizar o desenvolvimento e a separar melhor o momento de decidir **o que deveria ser feito** do momento de decidir **como aquilo seria implementado**.

Essa organização passou a ser ainda mais importante quando começamos a integrar React/Vite, Spring Boot, Python, MySQL/MariaDB e o stub de rastreamento.

Por outro lado, o uso do framework adiciona algumas etapas antes da implementação. Para funcionalidades pequenas, inicialmente pode parecer mais rápido começar diretamente pelo código. No nosso caso, conforme o número de integrações aumentou, os artefatos passaram a ser úteis para reduzir ambiguidades e retrabalho.

### O que faríamos diferente com outro framework?

Se repetíssemos a atividade utilizando outro framework, experimentaríamos uma abordagem baseada em diferentes papéis de agentes, como o **BMAD**.

O SpecKit funcionou bem para o grupo porque sua estrutura possui bastante relação com um processo baseado em Git e documentação versionada.

Entretanto, seria interessante comparar essa experiência com um framework no qual análise, produto, arquitetura e desenvolvimento possuem agentes ou responsabilidades mais explicitamente separados.

Também melhoraríamos ainda mais a rastreabilidade entre:

```text
Requisito
   ↓
Spec
   ↓
Plano
   ↓
Tarefa
   ↓
Integrante
   ↓
Commit
   ↓
Validação
```

Dessa forma, seria mais fácil identificar diretamente qual requisito originou cada implementação, quem ficou responsável por ela e qual validação comprovou seu funcionamento.

---

## Problemas comuns

| Mensagem ou sintoma | O que fazer |
|---|---|
| Java não encontrado | Instale JDK 17+, configure `PATH` e `JAVA_HOME` e valide com `java -version` e `mvn --version`. |
| Python aponta para outro computador ou apresenta `No Python at ...` | Recrie a `.venv` local do Worker. |
| `pip` ou `npm` apresenta erro | Consulte `worker-setup.log` ou `frontend-setup.log` e repita a configuração se necessário. |
| Porta `8080` ou `5173` ocupada | Confira o PID apresentado e encerre a instância anterior ou altere a porta no `.env`. |
| MySQL não responde | Confira `DB_HOST`, `DB_PORT` e se o servidor está acessível. |
| `Access denied for user` | Revise usuário, senha e permissões sobre o schema. |
| `Unknown database` | Execute o SQL de preparação para criar `amor_em_mechas`. |
| Spring inicia e encerra | Consulte `spring.log` e confira Maven, banco e porta. |
| Worker não inicia | Consulte `worker.log` e `worker-setup.log`. |
| Front-end não abre | Consulte `frontend.log` e verifique a disponibilidade do Spring. |
| ExecutionPolicy | Utilize o `.bat`, que aplica Bypass somente ao processo necessário. |
| Processos continuam ativos | Utilize `stop_app.bat`. |

---

## Conclusão

O desenvolvimento do **Painel de Rastreamento de Envios** mostrou na prática a diferença entre simplesmente utilizar um agente para gerar código e utilizar uma abordagem baseada em Specification-Driven Development.

Com o SpecKit, primeiro definimos o comportamento esperado, depois planejamos a solução, dividimos o trabalho em tarefas e então avançamos para a implementação e validação.

A especificação funcionou como uma referência para aquilo que havia sido decidido pelo grupo e para aquilo que efetivamente deveria ser implementado.

Durante a validação percebemos que não bastava garantir que cada componente funcionasse isoladamente. Era necessário tornar a execução integrada reproduzível em outro ambiente.

Os problemas encontrados na configuração contribuíram para a criação do launcher, centralização das variáveis de ambiente, validação do banco, preparação automática do Worker e organização dos logs.

O principal aprendizado da atividade foi entender que SDD não serve apenas para produzir documentação antes do código. A especificação também funciona como uma forma de manter controle sobre as decisões tomadas durante um desenvolvimento assistido por IA e verificar posteriormente se a implementação realmente corresponde ao que foi acordado pelo grupo.

---

## Repositório

[Atividade — SDD](https://github.com/PI-Amor-em-Mechas/Atividade---SDD.git)
