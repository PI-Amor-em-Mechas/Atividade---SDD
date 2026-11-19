"""Read-only MySQL/MariaDB probe. Output contains only fixed result codes."""
import os
import re
import socket
import sys


def read_exact(sock, count):
    data = bytearray()
    while len(data) < count:
        chunk = sock.recv(count - len(data))
        if not chunk:
            raise EOFError
        data.extend(chunk)
    return bytes(data)


def check_protocol(host, port):
    try:
        with socket.create_connection((host, port), timeout=4) as sock:
            header = read_exact(sock, 4)
            length = int.from_bytes(header[:3], "little")
            if header[3] != 0 or not 20 <= length <= 4096:
                return "MYSQL_PROTOCOLO_INVALIDO"
            packet = read_exact(sock, length)
            end = packet.find(b"\0", 1)
            # Protocol 10, server version, thread ID, salt, filler and capability flags.
            if packet[0] != 10 or end < 2 or length < end + 16 or packet[end + 13] != 0:
                return "MYSQL_PROTOCOLO_INVALIDO"
            return "MYSQL_PROTOCOLO_OK"
    except (socket.timeout, TimeoutError):
        return "MYSQL_TIMEOUT"
    except EOFError:
        return "MYSQL_PROTOCOLO_INVALIDO"
    except OSError:
        return "MYSQL_HOST_INACESSIVEL"


TABLES = ("envios", "envio_historico")
REQUIRED = {"SELECT", "INSERT", "UPDATE", "DELETE"}
TABLE_GRANT = re.compile(
    r"^GRANT (.+?) ON `?amor_em_mechas`?\.`?(envios|envio_historico)`? TO ",
    re.IGNORECASE,
)


def check_tables(cursor):
    missing = []
    denied = False
    for table in TABLES:
        try:
            cursor.execute(f"SELECT * FROM `{table}` LIMIT 0")
            cursor.fetchall()
        except Exception as exc:
            if getattr(exc, "errno", None) == 1146:
                missing.append(table)
            elif getattr(exc, "errno", None) in (1142, 1143):
                denied = True
            else:
                raise
    for table in missing:
        print(f"MYSQL_AUSENTE_{table.upper()}")
    if denied:
        return "MYSQL_USUARIO_SEM_PERMISSAO"
    if missing:
        return "MYSQL_SCHEMA_INCOMPLETO"

    # Require explicit table grants from the setup script. Never execute test writes.
    cursor.execute("SHOW GRANTS")
    granted = {table: set() for table in TABLES}
    for (statement,) in cursor.fetchall():
        match = TABLE_GRANT.match(statement)
        if match:
            privileges, table = match.groups()
            granted[table.lower()].update(item.strip().upper() for item in privileges.split(","))
    if any(not REQUIRED <= privileges for privileges in granted.values()):
        return "MYSQL_USUARIO_SEM_PERMISSAO"
    return "MYSQL_OK"


def probe(host, port):
    protocol = check_protocol(host, port)
    print(protocol if protocol == "MYSQL_PROTOCOLO_OK" else "MYSQL_NAO_ENCONTRADO", flush=True)
    if protocol != "MYSQL_PROTOCOLO_OK":
        return
    user = os.getenv("DB_USER")
    password = os.getenv("DB_PASSWORD")
    if not user or not password:
        print("MYSQL_ENCONTRADO_SEM_CREDENCIAIS")
        return
    if user.casefold() == "root" or os.getenv("DB_NAME") != "amor_em_mechas":
        print("MYSQL_CONFIGURACAO_INVALIDA")
        return
    try:
        import mysql.connector
    except ImportError:
        print("MYSQL_DRIVER_AUSENTE")
        return

    step = "auth"
    try:
        with mysql.connector.connect(
            host=host, port=port, user=user, password=password, connection_timeout=5,
            read_timeout=5, write_timeout=5, use_pure=True,
        ) as connection:
            print("MYSQL_AUTENTICACAO_OK")
            step = "database"
            connection.database = os.environ["DB_NAME"]
            print("MYSQL_DATABASE_OK")
            step = "query"
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                if cursor.fetchone() != (1,):
                    print("MYSQL_SELECT_FALHOU")
                    return
                print("MYSQL_SELECT_OK")
                result = check_tables(cursor)
                if result == "MYSQL_OK":
                    cursor.execute("SELECT VERSION()")
                    (version,) = cursor.fetchone()
                    print("MYSQL_MOTOR_MARIADB" if "mariadb" in version.lower() else "MYSQL_MOTOR_MYSQL")
                print(result)
    except mysql.connector.Error as exc:
        reason = {1044: "MYSQL_USUARIO_SEM_PERMISSAO", 1045: "MYSQL_CREDENCIAL_INVALIDA",
                  1049: "MYSQL_DATABASE_AUSENTE", 2003: "MYSQL_HOST_INACESSIVEL",
                  3024: "MYSQL_TIMEOUT"}.get(exc.errno)
        if isinstance(exc, TimeoutError) or "Timeout" in type(exc).__name__:
            reason = "MYSQL_TIMEOUT"
        print(reason or {"auth": "MYSQL_CONEXAO_FALHOU", "database": "MYSQL_USUARIO_SEM_PERMISSAO",
                         "query": "MYSQL_SELECT_FALHOU"}[step])
        return
    except (TypeError, AttributeError):
        print("MYSQL_DRIVER_INCOMPATIVEL")
        return


if __name__ == "__main__":
    probe(os.environ["DB_HOST"], int(os.environ["DB_PORT"]))
