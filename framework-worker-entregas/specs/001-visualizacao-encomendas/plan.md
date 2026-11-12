# Implementation Plan: Visualização de Encomendas e Status

**Branch**: `001-visualizacao-encomendas` | **Date**: 2026-11-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-visualizacao-encomendas/spec.md`

## Summary

Criar a tela principal de visualização de encomendas, consumindo a fonte oficial de dados já integrada (`listarEnvios`) e apresentando código de rastreio, destinatário, status e data da última atualização. A interface cobre loading inicial, lista carregada, lista vazia, erro com nova tentativa e falha de atualização não bloqueante. Os dados são atualizados por botão manual e por polling de 30 segundos, com proteção contra respostas fora de ordem.

## Technical Context

**Language/Version**: JavaScript ES2023 + JSX

**Primary Dependencies**: React 19.3.1, React DOM 19.3.1, Vite 8.3.6

**Storage**: N/A (dados obtidos da API de encomendas)

**Testing**: Sem framework de testes instalado; validação por `oxlint`, `vite build` e cenários manuais do quickstart

**Target Platform**: Navegadores web modernos (desktop e mobile)

**Project Type**: Frontend SPA

**Performance Goals**: Refletir alterações em até 30s; lista responsiva para dezenas a centenas de registros

**Constraints**: Não adicionar dependências; reutilizar `src/api/enviosApi.js`; CSS Modules; interface em pt-BR

**Scale/Scope**: Uma tela, quatro status, sem paginação/filtros nesta entrega

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

A constituição em `.specify/memory/constitution.md` ainda é o template não preenchido (placeholders), sem princípios ou gates executáveis. Nenhuma violação identificada.

## Project Structure

### Documentation (this feature)

```text
specs/001-visualizacao-encomendas/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── envios-api.md
│   └── ui-components.md
├── checklists/
│   └── requirements.md
└── tasks.md
```

### Source Code (repository root)

```text
src/
├── api/
│   └── enviosApi.js              # existente, sem alteração
├── components/
│   ├── EnvioTable.jsx            # novo
│   ├── EnvioTable.module.css     # novo
│   ├── StatusBadge.jsx           # novo
│   └── StatusBadge.module.css    # novo
├── hooks/
│   └── useEnvios.js              # novo: carga, normalização, polling e concorrência
├── pages/
│   ├── EnviosPage.jsx            # novo
│   └── EnviosPage.module.css     # novo
├── App.jsx                       # modificado
├── App.css                       # mantido (não utilizado pela nova tela)
├── index.css                     # reutilizado
└── main.jsx                      # inalterado
```

**Structure Decision**: Projeto único de frontend React/Vite. A lógica de dados fica em `src/hooks/useEnvios.js`; os componentes de apresentação em `src/components/`; a composição da tela em `src/pages/`.

## Phase 0: Outline & Research

Ver [research.md](./research.md). Decisões principais:

- Hook próprio com `useState`/`useEffect`/`useRef`, sem dependências novas.
- Polling de 30s + atualização manual.
- Erro inicial em tela cheia; erro de atualização como aviso não bloqueante.
- Normalização defensiva e formatação de data com `Intl.DateTimeFormat('pt-BR')`.
- CSS Modules com as variáveis de `src/index.css`.

## Phase 1: Design & Contracts

- Entidades e regras em [data-model.md](./data-model.md).
- Contrato da API em [contracts/envios-api.md](./contracts/envios-api.md).
- Contrato dos componentes em [contracts/ui-components.md](./contracts/ui-components.md).
- Cenários de validação em [quickstart.md](./quickstart.md).

### Post-Design Constitution Check

Sem princípios executáveis na constituição; nenhuma violação. Estrutura alinhada ao projeto existente, sem novas dependências e com escopo restrito à tela de visualização.

## Complexity Tracking

Nenhuma violação de constituição a justificar.
