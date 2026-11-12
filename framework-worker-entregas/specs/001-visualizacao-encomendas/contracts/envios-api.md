# Contract: API de Encomendas

## Endpoint

`GET {VITE_API_BASE_URL}/api/envios`

- Cliente existente: `src/api/enviosApi.js` → `listarEnvios()`
- Header enviado: `Accept: application/json`
- Timeout: 10 segundos (padrão do cliente)

## Resposta de sucesso

Status: `200 OK`  
Content-Type: `application/json`

```json
[
  {
    "codigoRastreio": "BR123456789",
    "nomeDestinatario": "Maria Silva",
    "status": "EM_TRANSITO",
    "dataUltimaAtualizacao": "2026-11-12T14:30:00Z"
  }
]
```

### Regras

- O corpo MUST ser um array.
- Cada item MUST ser um objeto.
- `status` MUST ser um dos valores: `AGUARDANDO`, `EM_TRANSITO`, `ENTREGUE`, `ERRO`.
- `dataUltimaAtualizacao` SHOULD ser uma data ISO 8601 com fuso.
- Lista vazia (`[]`) é uma resposta válida e resulta no estado vazio da tela.

## Respostas de erro

O cliente converte falhas em `EnviosApiError` com `kind`:

| Situação | `kind` | Comportamento na tela |
|---|---|---|
| Sem conexão / DNS / CORS | `network` | Erro inicial ou aviso de atualização |
| Timeout > 10s | `timeout` | Erro inicial ou aviso de atualização |
| 4xx | `client` | Erro inicial ou aviso de atualização |
| 5xx | `server` | Erro inicial ou aviso de atualização |
| JSON inválido/forma inesperada | erro de contrato | Erro inicial ou aviso de atualização |

## Observações

- Não há paginação nesta entrega.
- A ordem exibida é a ordem retornada pela API.
- A tela não envia dados; é somente leitura.
