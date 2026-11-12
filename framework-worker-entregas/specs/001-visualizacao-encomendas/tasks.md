# Tasks: Visualização de Encomendas e Status

**Input**: Design documents from `/specs/001-visualizacao-encomendas/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Não há framework de testes no projeto; a validação será feita por lint, build e cenários manuais do quickstart.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirmar estrutura e contrato existentes

- [X] T001 Verificar estrutura do projeto e cliente HTTP existente em `src/api/enviosApi.js`
- [X] T002 Confirmar configuração de ambiente em `.env.example` e scripts em `package.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Base de dados e apresentação compartilhada pelos estados da tela

- [X] T003 Criar normalização de encomendas e tratamento de erros em `src/hooks/useEnvios.js`
- [X] T004 [P] Criar configuração visual dos status em `src/components/StatusBadge.jsx` e `src/components/StatusBadge.module.css`

**Checkpoint**: Base pronta para implementar as histórias

---

## Phase 3: User Story 1 - Consultar encomendas e status (Priority: P1) 🎯 MVP

**Goal**: Listar encomendas com código de rastreio, destinatário, status e última atualização.

**Independent Test**: Com dados disponíveis, abrir a tela principal e conferir os quatro campos e a distinção visual dos quatro status.

- [X] T005 [P] [US1] Criar tabela semântica em `src/components/EnvioTable.jsx` e `src/components/EnvioTable.module.css`
- [X] T006 [US1] Implementar carga inicial e estados derivados em `src/hooks/useEnvios.js`
- [X] T007 [US1] Criar composição da tela em `src/pages/EnviosPage.jsx` e `src/pages/EnviosPage.module.css`
- [X] T008 [US1] Integrar a página em `src/App.jsx`

**Checkpoint**: US1 funcional e testável isoladamente

---

## Phase 4: User Story 2 - Acompanhar atualizações (Priority: P2)

**Goal**: Refletir alterações de dados por polling e por ação manual.

**Independent Test**: Alterar um registro na fonte e verificar atualização em até 30s ou após clicar em "Atualizar".

- [X] T009 [US2] Implementar polling de 30s e atualização manual em `src/hooks/useEnvios.js`
- [X] T010 [US2] Implementar botão "Atualizar" e indicador de atualização em `src/pages/EnviosPage.jsx`
- [X] T011 [US2] Adicionar proteção contra respostas fora de ordem e atualizações concorrentes em `src/hooks/useEnvios.js`

**Checkpoint**: US1 e US2 funcionando

---

## Phase 5: User Story 3 - Estados de loading, vazio e erro (Priority: P3)

**Goal**: Cobrir todos os estados da interface com mensagens claras e recuperação.

**Independent Test**: Simular resposta lenta, lista vazia, erro inicial e erro após carga bem-sucedida.

- [X] T012 [US3] Implementar estado de loading acessível em `src/pages/EnviosPage.jsx` e `src/pages/EnviosPage.module.css`
- [X] T013 [US3] Implementar estado vazio com ação de atualização em `src/pages/EnviosPage.jsx`
- [X] T014 [US3] Implementar estado de erro inicial com nova tentativa em `src/pages/EnviosPage.jsx`
- [X] T015 [US3] Implementar aviso não bloqueante para falha de atualização em `src/pages/EnviosPage.jsx`

**Checkpoint**: Todos os estados da interface funcionais

---

## Phase 6: Polish & Cross-Cutting Concerns

- [X] T016 [P] Adicionar estilos responsivos, tema escuro e foco visível em `src/pages/EnviosPage.module.css`, `src/components/EnvioTable.module.css` e `src/components/StatusBadge.module.css`
- [X] T017 Executar `npm run lint`
- [X] T018 Executar `npm run build`
- [X] T019 Validar cenários do `quickstart.md` que não dependem de backend real (build, lint, renderização estática)

---

## Dependencies & Execution Order

- Setup → Foundational → US1 → US2 → US3 → Polish
- US2 depende da carga inicial de US1
- US3 depende da máquina de estados de US1/US2
- T004 e T005 são independentes entre si

## Notes

- Nenhuma dependência nova foi adicionada.
- Nenhum teste automatizado foi incluído por não haver framework instalado e por não ter sido solicitado na especificação.
