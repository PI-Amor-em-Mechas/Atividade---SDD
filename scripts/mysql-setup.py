"""Apply api-envios/sql/setup-professor.sql with an administrative account.

Inputs come only from environment variables (never from argv, to keep secrets
out of process listings). Output contains only fixed result codes.
"""
import os
import re
import sys
from pathlib import Path

PLACEHOLDER = "<SENHA_FORTE_AQUI>"
SQL_FILE = Path(__file__).resolve().parent.parent / "api-envios" / "sql" / "setup-professor.sql"


def statements(sql):
    lines = [line for line in sql.splitlines() if not line.lstrip().startswith("--")]
    for chunk in "\n".join(lines).split(";"):
        chunk = chunk.strip()
        if chunk:
            yield chunk


def main():
    host = os.environ["DB_HOST"]
    port = int(os.environ["DB_PORT"])
    admin_user = os.getenv("DB_ADMIN_USER") or "root"
    admin_password = os.getenv("DB_ADMIN_PASSWORD") or ""
    app_password = os.getenv("DB_PASSWORD") or ""
    if not re.fullmatch(r"[A-Za-z0-9!_\-]{12,64}", app_password):
        print("SETUP_SENHA_APP_INVALIDA")
        return 1
    try:
        import mysql.connector
    except ImportError:
        print("SETUP_DRIVER_AUSENTE")
        return 1

    sql = SQL_FILE.read_text(encoding="utf-8").replace(PLACEHOLDER, app_password)
    try:
        with mysql.connector.connect(
            host=host, port=port, user=admin_user, password=admin_password,
            connection_timeout=8, use_pure=True, autocommit=True,
        ) as connection:
            print("SETUP_ADMIN_OK", flush=True)
            with connection.cursor() as cursor:
                for statement in statements(sql):
                    cursor.execute(statement)
                    if cursor.with_rows:
                        cursor.fetchall()
                # CREATE USER IF NOT EXISTS preserves an old password; sync it with the saved .env.
                cursor.execute(
                    "ALTER USER 'rastreamento_app'@'localhost' IDENTIFIED BY %s", (app_password,)
                )
            print("SETUP_OK")
            return 0
    except mysql.connector.Error as exc:
        code = {
            1045: "SETUP_ADMIN_NEGADO",
            1044: "SETUP_ADMIN_SEM_PERMISSAO",
            1142: "SETUP_ADMIN_SEM_PERMISSAO",
            1227: "SETUP_ADMIN_SEM_PERMISSAO",
            1410: "SETUP_ADMIN_SEM_PERMISSAO",
            1819: "SETUP_POLITICA_SENHA",
            2003: "SETUP_HOST_INACESSIVEL",
        }.get(exc.errno, "SETUP_FALHOU")
        print(code)
        print(f"SETUP_ERRNO={exc.errno}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
