#!/bin/sh
# Run with a local MariaDB installation and a writable temporary directory.
set -eu
setup=${1:?Informe o caminho para setup-professor.sql}
site_packages=${2:-}
tmp=$(mktemp -d)
pid=
stage='inicialização do datadir'
cleanup() {
    status=$?
    if [ "$status" -ne 0 ]; then
        printf 'Falha durante %s.\n' "$stage" >&2
        for log in init server setup expected-error; do
            if [ -f "$tmp/$log.log" ]; then
                grep -Eo 'ERROR [0-9]+|\[ERROR\] [[:alnum:]_ -]*' "$tmp/$log.log" >&2 || true
            fi
        done
    fi
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; wait "$pid" || true; fi
    rm -rf -- "$tmp"
}
trap cleanup EXIT
trap 'exit 1' INT TERM
admin_user=$(id -un)
mariadb-install-db --no-defaults --datadir="$tmp/data" --skip-test-db \
    --auth-root-socket-user="$admin_user" >"$tmp/init.log" 2>&1
if [ -n "$site_packages" ]; then
    port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')
    set -- --bind-address=127.0.0.1 --port="$port"
else
    set -- --skip-networking
fi
stage='subida do servidor e conexão administrativa'
mariadbd --no-defaults --datadir="$tmp/data" --socket="$tmp/socket" \
    --pid-file="$tmp/pid" --user="$admin_user" --log-error="$tmp/server.log" "$@" &
pid=$!
admin() { mariadb --no-defaults --socket="$tmp/socket" -u "$admin_user" -NB "$@"; }
i=0
until admin -e 'SELECT 1' >/dev/null 2>&1; do
    i=$((i+1))
    if [ "$i" -ge 40 ] || ! kill -0 "$pid" 2>/dev/null; then
        echo 'MariaDB descartável não iniciou.' >&2
        if [ -f "$tmp/server.log" ]; then tail -n 12 "$tmp/server.log" >&2; fi
        exit 1
    fi
    sleep 1
done
secret=$(od -An -N24 -tx1 /dev/urandom | tr -d ' \n')
apply_setup() {
    sed "s/<SENHA_FORTE_AQUI>/$secret/g" "$setup" | admin >"$tmp/setup.log" 2>&1
}
app() {
    MYSQL_PWD="$secret" mariadb --no-defaults --socket="$tmp/socket" \
        -u rastreamento_app -NB amor_em_mechas "$@"
}
assert_failure() {
    if "$@" >"$tmp/expected-error.log" 2>&1; then
        echo 'Era esperada uma recusa do servidor.' >&2; exit 1
    fi
}
stage='primeira execução do SQL'
apply_setup
stage='segunda execução e comparação da tabela legada'
admin amor_em_mechas -e 'CREATE TABLE legado (id INT PRIMARY KEY); INSERT INTO legado VALUES (1);'
before=$(admin amor_em_mechas -e 'SHOW CREATE TABLE legado; SELECT * FROM legado;')
apply_setup
test "$before" = "$(admin amor_em_mechas -e 'SHOW CREATE TABLE legado; SELECT * FROM legado;')"
stage='leitura e escrita nas tabelas do módulo'
test "$(app -e 'SELECT 1')" = 1
app -e "INSERT INTO envios (id, atualizado_em, codigo_rastreio, criado_em, entregue, nome_destinatario)
VALUES (1, NOW(6), 'TESTE', NOW(6), b'0', 'Avaliador');
INSERT INTO envio_historico VALUES (1, 'evento', 0);
UPDATE envios SET entregue=b'1' WHERE id=1;
UPDATE envio_historico SET evento='atualizado' WHERE envio_id=1;
SELECT * FROM envios; SELECT * FROM envio_historico;" >/dev/null
stage='restrições e isolamento de privilégios'
assert_failure app -e "INSERT INTO envios SELECT 2, atualizado_em, codigo_rastreio, criado_em, data_atualizacao, entregue, nome_destinatario, ultimo_status FROM envios;"
grep -q 'ERROR 1062' "$tmp/expected-error.log"
assert_failure app -e "INSERT INTO envio_historico VALUES (1, 'duplicado', 0);"
grep -q 'ERROR 1062' "$tmp/expected-error.log"
assert_failure app -e "INSERT INTO envio_historico VALUES (9, 'órfão', 0);"
grep -q 'ERROR 1452' "$tmp/expected-error.log"
assert_failure app -e 'SELECT * FROM legado;'
grep -q 'ERROR 1142' "$tmp/expected-error.log"
assert_failure app -e 'INSERT INTO legado VALUES (2);'
assert_failure app -e 'UPDATE legado SET id=2;'
assert_failure app -e 'DELETE FROM legado;'
app -e 'DELETE FROM envio_historico WHERE envio_id=1; DELETE FROM envios WHERE id=1;'
stage='metadados das chaves e varredura dos logs'
test "$(app -e 'SELECT COUNT(*) FROM envios; SELECT COUNT(*) FROM envio_historico;')" = "$(printf '0\n0')"
indexes=$(admin amor_em_mechas -e "
SELECT CONCAT(TABLE_NAME, ':', INDEX_NAME, ':', COLUMN_NAME)
FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA='amor_em_mechas' AND TABLE_NAME IN ('envios','envio_historico') AND NON_UNIQUE=0;
" | LC_ALL=C sort)
expected=$(printf '%s\n' envio_historico:PRIMARY:envio_id envio_historico:PRIMARY:ordem envios:PRIMARY:id envios:uk_envio_codigo:codigo_rastreio)
if [ "$indexes" != "$expected" ]; then
    printf 'Índices encontrados:\n%s\n' "$indexes" >&2
    exit 1
fi
test "$(admin -e "SELECT COLUMN_NAME FROM information_schema.STATISTICS
WHERE TABLE_SCHEMA='amor_em_mechas' AND TABLE_NAME='envio_historico'
AND INDEX_NAME='PRIMARY' ORDER BY SEQ_IN_INDEX")" = "$(printf 'envio_id\nordem')"
if grep -Fq "$secret" "$tmp/"*.log; then
    echo 'Senha de teste encontrada em log.' >&2; exit 1
fi
admin -e 'SELECT VERSION();'
echo 'Migração aplicada duas vezes. PKs, UNIQUE, FK, CRUD, isolamento e logs verificados.'

if [ -n "$site_packages" ]; then
    stage='probe sobre TCP'
    export PYTHONPATH="$(cd "$site_packages" && pwd)"
    export DB_HOST=127.0.0.1 DB_PORT="$port" DB_NAME=amor_em_mechas
    export DB_USER=rastreamento_app DB_PASSWORD="$secret"
    expect_probe() {
        output=$(python3 -B scripts/mysql-probe.py)
        if [ "$(printf '%s\n' "$output" | tail -n 1)" != "$1" ]; then
            printf 'Probe esperava %s. Resultados:\n%s\n' "$1" "$output" >&2
            exit 1
        fi
    }
    expect_probe MYSQL_OK
    ( DB_PASSWORD="" expect_probe MYSQL_ENCONTRADO_SEM_CREDENCIAIS )
    ( DB_PASSWORD="credencial-invalida" expect_probe MYSQL_CREDENCIAL_INVALIDA )

    stage='regressão Worker com schema descartável'
    sed -e 's/amor_em_mechas/amor_em_mechas_test/g' -e "s/<SENHA_FORTE_AQUI>/$secret/g" "$setup" \
        | admin >"$tmp/setup.log" 2>&1
    (
        cd 'Worker Python de rastreamento'
        DB_NAME=amor_em_mechas_test WORKER_MYSQL_TESTS=1 python3 -B -m unittest discover -s tests -v
    )
fi
