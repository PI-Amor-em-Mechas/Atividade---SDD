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
- A listagem mantém seu comportamento; o cadastro usa o endpoint descrito abaixo.

## Cadastro de encomenda

`POST {VITE_API_BASE_URL}/api/envios`

- Cliente existente: `src/api/enviosApi.js` → `cadastrarEnvio(envio)`
- Headers: `Accept: application/json` e `Content-Type: application/json`
- Corpo:

```json
{
  "codigoRastreio": "BR123456789",
  "nomeDestinatario": "Maria Silva"
}
```

### Contrato esperado do backend

O backend não está incluído neste repositório. Sua implementação deve:

- Validar os dois campos obrigatórios, rejeitando strings vazias ou só espaços
  com HTTP 400.
- Garantir unicidade de `codigoRastreio` na persistência, inclusive em cadastros
  simultâneos, e responder HTTP 409 para código já cadastrado.
- Responder HTTP 201 após persistir o envio; o frontend não depende do corpo
  da resposta de sucesso.
- Disponibilizar o novo envio no próximo `GET /api/envios`, incluindo os campos
  de status e data de atualização definidos no contrato de leitura.

### Feedback do frontend

| Resultado | Mensagem |
|---|---|
| Sucesso (2xx) | Envio cadastrado com sucesso. |
| HTTP 409 | Código de rastreio já cadastrado. |
| Demais falhas HTTP, timeout ou rede | Não foi possível cadastrar o envio. |

Após sucesso, o formulário é limpo e solicita uma atualização da listagem.
Falhas nessa atualização continuam sendo apresentadas pelo mecanismo já
existente na página, sem transformar um cadastro bem-sucedido em erro de cadastro.
