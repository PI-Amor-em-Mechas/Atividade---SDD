# Contrato da API Spring

- `GET /api/envios` retorna `200` com um array JSON sem envelope. `[]` representa ausência de envios.
- `GET /api/envios/{id}` retorna `200` com o mesmo modelo ou `404`. O histórico da tela vem da listagem.
- `POST /api/envios` recebe `codigoRastreio` e `nomeDestinatario`, strings obrigatórias com até 50 e 150 caracteres, e retorna `201` com o envio e `Location`.

```json
{
  "id": 1,
  "codigoRastreio": "AB123456789BR",
  "nomeDestinatario": "Maria Silva",
  "ultimoStatus": "AGUARDANDO",
  "entregue": false,
  "criadoEm": "2026-11-18T14:00:00",
  "atualizadoEm": "2026-11-18T14:00:00",
  "dataAtualizacao": "2026-11-18T14:00:00",
  "historico": ["AGUARDANDO"]
}
```

O Spring controla estado inicial e timestamps. Em erros, `mensagem` contém
o texto e `campos` pode conter validações por campo para HTTP 400. HTTP 409
informa duplicidade. Erros 5xx recebem mensagem genérica na interface.

A URL padrão do cliente é relativa. O proxy Vite encaminha `/api` para o
Spring em desenvolvimento. A listagem envia `Accept: application/json`; o
cadastro também envia `Content-Type: application/json`. Timeout de 10 s.
