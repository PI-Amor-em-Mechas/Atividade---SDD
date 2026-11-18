# Validação - Mock API de Rastreamento

## Ambiente

- `mock-api/db.json` (versionado)
- `mock-api/routes.json` (mapeia `/api/envios` → `/envios`)
- `mock-api/package.json` (json-server 0.17.4, porta 3001)
- Comando: `npm start` → `json-server --watch db.json --routes routes.json --port 3001`

## Critérios de aceite

| Critério | Status |
|---|---|
| JSON Server configurado | Concluído |
| db.json versionado | Concluído |
| Cenário EM_TRANSITO disponível | Concluído (AM000000001BR) |
| Cenário ENTREGUE disponível | Concluído (AM000000002BR) |
| Código inexistente disponível | Concluído (HTTP 404) |
| Worker integrado ao mock | Concluído (PATCH/PUT `/api/envios/:id`) |
| Fluxo de cadastro validado | Concluído (POST → 201) |
| Fluxo de listagem validado | Concluído (GET → 200) |
| Atualização automática validada | Concluído (PATCH → 200) |
| Cenário de entrega validado | Concluído (ENTREGUE) |
| Tratamento de erro validado | Concluído (404 / rede indisponível) |
| Critérios da spec revisados | Concluído |
| Resultado da validação documentado | Concluído |

## Resultados dos cenários (curl)

| # | Cenário | Requisição | Resultado |
|---|---|---|---|
| 1 | Listagem | `GET /api/envios` | `200` + array com 2 encomendas |
| 2 | EM_TRANSITO | `GET /api/envios/1` | `200` status `EM_TRANSITO` |
| 3 | ENTREGUE | `GET /api/envios/2` | `200` status `ENTREGUE` |
| 4 | Código inexistente | `GET /api/envios/999` | `404` |
| 5 | Cadastro correto | `POST /api/envios` | `201` + recurso criado |
| 6 | Código duplicado | `POST` com `AM000000001BR` | `201` (json-server não impõe unicidade; regra de negócio cabe ao backend real) |
| 7 | Mudança de status | `PATCH /api/envios/1` | `200` status alterado |
| 8 | API indisponível | Servidor parado | Erro de rede (kind `network`) no frontend |

## Observações

- O frontend consome `VITE_API_BASE_URL=http://localhost:3001` com endpoint `/api/envios`, atendido pelo mock via `routes.json`.
- Não há framework de testes automatizado; validação feita por `curl` contra o mock em pé.
- Não há alteração no código fonte do frontend.
