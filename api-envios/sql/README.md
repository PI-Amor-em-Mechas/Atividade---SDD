# Preparação manual do banco de rastreamento

Para uma instalação acadêmica, use [setup-professor.sql](setup-professor.sql).
O arquivo cria `amor_em_mechas` se necessário e contém o mesmo DDL de
[001-rastreamento.sql](001-rastreamento.sql). A migration avulsa pressupõe
que o banco existe. [rastreamento-app.sql.example](rastreamento-app.sql.example)
permite provisionar a conta depois que as tabelas existirem.

- As tabelas usam InnoDB, `utf8mb4` e `utf8mb4_unicode_ci` para
  compatibilidade entre MySQL 8 e MariaDB 11. A comparação de códigos
  ignora caixa e acentos.
- `envios` usa `BIGINT AUTO_INCREMENT`, datas `DATETIME(6)`, flag
  `BIT(1)` e índice único `uk_envio_codigo` em `codigo_rastreio`.
- `envio_historico` usa PK composta `(envio_id, ordem)`. A FK
  `FKllrc1qtfdi3mdnbgqwyvb00o9` aponta para `envios(id)`.
- A conta recebe `SELECT`, `INSERT`, `UPDATE` e `DELETE` diretamente em
  cada tabela. Uma conta que já existia conserva a senha e os privilégios
  anteriores. Confira `SHOW GRANTS` antes de reutilizá-la. Use uma conta
  dedicada para evitar herdar acesso às tabelas de outros módulos.

Use uma sessão administrativa autorizada e substitua o marcador de senha
em uma cópia do SQL. Para um banco remoto, ajuste a parte de host da conta
ao endereço de origem do cliente visto pelo servidor.

`IF NOT EXISTS` preserva tabelas já criadas. Compare o resultado de
`SHOW CREATE TABLE` com a migration se houver divergência. Spring valida
o schema na inicialização. Em caso de falha parcial de DDL, confira o
estado do banco e corrija a causa antes de repetir o script.

O teste descartável para MariaDB pode ser executado no Linux com
`sh scripts/tests/setup-professor-test.sh api-envios/sql/setup-professor.sql`.
Ele usa um diretório temporário e um socket local independente.
