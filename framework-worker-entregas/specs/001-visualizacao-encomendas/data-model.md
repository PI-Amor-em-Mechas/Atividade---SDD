# Modelo de apresentação de envios

| Campo | Tipo | Apresentação |
|---|---|---|
| `id` | inteiro | Identidade e chave React da linha. |
| `codigoRastreio`, `nomeDestinatario` | string | Código e destinatário. São os únicos campos enviados pelo formulário. |
| `ultimoStatus` | string ou null | Badge com `AGUARDANDO`, `EM_TRANSITO`, `ENTREGUE`, `ERRO` ou fallback. |
| `entregue` | boolean | Flag que permite detectar divergência com o status. |
| `dataAtualizacao` | ISO ou null | Última mudança logística. |
| `atualizadoEm`, `criadoEm` | ISO ou null | Datas de auditoria. A primeira é fallback visual quando a data logística está ausente. |
| `historico` | array de strings | Eventos em ordem, exibidos a partir dos dados da listagem. Ausência ou null vira `[]`. |

Datas sem offset preservam a hora local de São Paulo. Datas com offset são
exibidas em `America/Sao_Paulo`. Eventos podem ser simples ou seguir
`STATUS|DATA_ISO|DESCRICAO`. A descrição restaura `%25` e `%7C` em uma
única passada de decodificação.

A interface preserva a última lista válida em falhas transitórias. As
consultas periódicas acontecem a cada 30 segundos enquanto a página estiver visível.
