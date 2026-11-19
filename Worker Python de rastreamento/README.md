# Worker de rastreamento

Valide as tabelas `envios` e `envio_historico` conforme a
[migration manual](../api-envios/sql/README.md). Configure o Worker com o
mesmo `DB_HOST`, `DB_PORT`, `DB_NAME` e `DB_USER` do Spring. Os padrões
são `localhost`, `3306`, `amor_em_mechas` e `rastreamento_app`.
Forneça a mesma `DB_PASSWORD` externamente. A conta do Worker precisa
ler as duas tabelas, atualizar `envios` e inserir em `envio_historico`.

## Provider local

O checkout contém apenas um contrato sintético de teste. Ative o stub
explicitamente, em outro terminal, com `python -B tests/provider_stub.py`.
O modo aceita apenas a rota `/rastreamento` em loopback com porta explícita.
Exporte as variáveis do exemplo no shell. O Worker lê o ambiente.

```powershell
python -m pip install -r requirements.txt
$env:TRACKING_PROVIDER = 'stub'
$env:TRACKING_API_BASE_URL = 'http://127.0.0.1:8081/rastreamento'
$env:POLL_INTERVAL_SECONDS = '0'
python -B main.py
```

O stub recebe `GET /rastreamento/{codigo}`, com código no path, e devolve
`200 application/json` com um objeto como
`{"status":"EM_TRANSITO","descricao":"Objeto em transferência"}`.
`descricao` pode ser omitida ou nula. Os códigos `AGUARDANDO`,
`EM_TRANSITO`, `ENTREGUE`, `404`, `408`, `429`, `500`, `TIMEOUT`,
`JSON_INVALIDO`, `SEM_STATUS` e qualquer texto de status desconhecido
acionam seus respectivos cenários. `TRACKING_API_TOKEN` é opcional e só
serve para exercitar o cabeçalho `Authorization: Bearer` do cliente no teste.

| Variável | Padrão | Efeito |
|---|---|---|
| `TRACKING_PROVIDER` | vazio | Use `stub` explicitamente. |
| `TRACKING_API_BASE_URL` | vazio | URL do stub com a rota. Substitui `TRACKING_API_URL`. |
| `TRACKING_TIMEOUT_SECONDS` | 10 | Timeout finito de conexão e de leitura. Substitui `API_TIMEOUT_SECONDS`. |
| `TRACKING_MAX_RETRIES` | 0 | Retries adicionais, de 0 a 5. |
| `TRACKING_RETRY_BACKOFF_SECONDS` | 1 | Base de backoff exponencial, até 30 s, com jitter de até 0,25 s e espera total por retry limitada a 30 s. |
| `POLL_INTERVAL_SECONDS` | 0 | Zero executa um ciclo. Valor positivo define a espera entre ciclos. |
| `LOG_LEVEL` | INFO | Use DEBUG para ver tentativa, HTTP e duração por ID interno. |

Retries são elegíveis em falhas transitórias de conexão, timeout,
`408`, `429`, `500`, `502`, `503` e `504`. Payload inválido, status
sem mapeamento, redirecionamento, TLS inválido e outros HTTP terminam
a consulta. `Retry-After` aceita segundos ou data HTTP. Se a espera
exceder 30 s, a consulta atual falha e o cliente adia novas chamadas
até o prazo. Após `429`, mesmo se os retries acabarem, o mesmo processo
respeita o prazo informado ou o backoff quando o cabeçalho estiver ausente.

O fluxo é sequencial. Para `N` envios elegíveis e `R` retries, o limite
por ciclo é `N × (1 + R)`, com até uma chamada por envio na configuração
padrão. O limite de produção ainda depende da documentação do provider.
O contrato sintético retorna um status único por resposta.

## Persistência

- Estados aceitos do cliente de rastreamento: `AGUARDANDO`, `EM_TRANSITO`,
  `ENTREGUE` e `ERRO`. Somente `ENTREGUE` grava a flag de entrega.
  Falhas HTTP e respostas inválidas preservam o estado anterior.
- O Worker bloqueia o envio durante a transição, compara os dados atuais
  com os lidos antes da consulta HTTP e anexa o evento na mesma transação.
  O histórico do Spring começa em `ordem=0`; cada novo evento usa a
  posição seguinte ao maior índice existente.
- O evento textual tem formato `STATUS|DATA_ISO|DESCRICAO`. A descrição
  pode ficar vazia. Quebras de linha viram espaços, caracteres NUL são
  removidos e `%` e `|` são codificados como `%25` e `%7C`.
  Decodifique a descrição após separar os três campos. O texto completo
  tem até 500 caracteres.
- O instante da transição é calculado em `America/Sao_Paulo`. As colunas
  `DATETIME` recebem a hora local sem offset e o evento recebe a hora
  ISO 8601 com offset. Execute a JVM com
  `-Duser.timezone=America/Sao_Paulo` para que os callbacks com
  `LocalDateTime.now()` usem o mesmo fuso. O Worker preserva `criado_em`
  e só altera `data_atualizacao` e `atualizado_em` em transições gravadas.

## Testes MySQL

Use um schema descartável e vazio com nome terminado em `_test`. Aplique
as duas instruções da migration em uma cópia ajustada apenas para apontar
para esse schema de teste. O Hibernate usa validação.
A conta de testes também precisa inserir e remover os próprios registros
em `envios` e remover o histórico desses registros.

```powershell
$env:DB_NAME = 'rastreio_worker_test'
$env:WORKER_MYSQL_TESTS = '1'
python -B -m unittest discover -s tests -v
```

O mesmo comando, sem `WORKER_MYSQL_TESTS=1`, executa a suíte HTTP local
e pula a suíte MySQL. Nenhum teste depende de um provider externo.
