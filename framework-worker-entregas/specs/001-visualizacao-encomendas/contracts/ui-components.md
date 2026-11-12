# Contract: Componentes da Interface

## `EnviosPage`

**Arquivo**: `src/pages/EnviosPage.jsx`  
**Props**: nenhuma  
**Responsabilidade**: compor a tela, controlar estados visuais, acionar carga/atualização e renderizar tabela ou estados alternativos.

**Saída visual**:

| Estado | Elemento |
|---|---|
| `loading` | Painel com indicador e texto "Carregando encomendas…" (`role="status"`) |
| `error` | Painel com mensagem e botão "Tentar novamente" (`role="alert"`) |
| `empty` | Painel "Nenhuma encomenda encontrada" |
| `list` | Contagem + `EnvioTable` |
| `refreshing` | Lista atual + botão desabilitado + texto "Atualizando dados…" |
| `stale-error` | Lista atual + aviso não bloqueante |

## `EnvioTable`

**Arquivo**: `src/components/EnvioTable.jsx`  
**Props**:

| Prop | Tipo | Obrigatória | Descrição |
|---|---|---|---|
| `envios` | `Envio[]` | sim | Lista normalizada de encomendas |

**Responsabilidade**: renderizar uma tabela semântica com as colunas:
1. Código de rastreio
2. Destinatário
3. Status
4. Última atualização

**Regras**:
- Cada linha usa `id` como chave.
- Campos vazios exibem "—".
- A data é formatada em pt-BR; inválida/ausente exibe "—".
- A tabela tem rolagem horizontal interna em telas estreitas.

## `StatusBadge`

**Arquivo**: `src/components/StatusBadge.jsx`  
**Props**:

| Prop | Tipo | Obrigatória | Descrição |
|---|---|---|---|
| `status` | `string` | sim | Valor do status da encomenda |

**Responsabilidade**: exibir rótulo e indicador visual do status.

**Mapeamento**:

| Status | Rótulo | Classe |
|---|---|---|
| `AGUARDANDO` | Aguardando | `aguardando` |
| `EM_TRANSITO` | Em trânsito | `em-transito` |
| `ENTREGUE` | Entregue | `entregue` |
| `ERRO` | Erro | `erro` |
| outro | Desconhecido | `desconhecido` |

**Acessibilidade**: o texto do status é sempre renderizado; a cor é apenas reforço visual.
