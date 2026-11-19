from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import runpy
import unittest


check_tables = runpy.run_path(str(Path(__file__).parents[1] / "mysql-probe.py"))["check_tables"]


class QueryError(Exception):
    def __init__(self, errno):
        self.errno = errno


class Cursor:
    def __init__(self, failures, privileges):
        self.failures = failures
        self.privileges = privileges

    def execute(self, sql):
        self.sql = sql
        if sql == "SHOW GRANTS":
            return
        prefix = "SELECT * FROM `"
        assert sql.startswith(prefix) and sql.endswith("` LIMIT 0"), sql
        table = sql[len(prefix):].split("`")[0]
        if table in self.failures:
            raise QueryError(self.failures[table])

    def fetchall(self):
        if self.sql != "SHOW GRANTS":
            return []
        return [
            (f"GRANT {privileges} ON `amor_em_mechas`.`{table}` TO account",)
            for table, privileges in self.privileges.items()
        ]


class MySqlProbeTest(unittest.TestCase):
    def test_missing_tables(self):
        for table in ("envios", "envio_historico"):
            with self.subTest(table=table), redirect_stdout(StringIO()) as out:
                self.assertEqual(check_tables(Cursor({table: 1146}, {})), "MYSQL_SCHEMA_INCOMPLETO")
                self.assertEqual(out.getvalue().strip(), f"MYSQL_AUSENTE_{table.upper()}")

    def test_read_denied(self):
        self.assertEqual(check_tables(Cursor({"envios": 1142}, {})), "MYSQL_USUARIO_SEM_PERMISSAO")

    def test_grants(self):
        for privileges in ("SELECT, INSERT, UPDATE", "SELECT, INSERT, UPDATE, DELETE"):
            with self.subTest(privileges=privileges):
                cursor = Cursor({}, {"envios": "SELECT,INSERT,UPDATE,DELETE", "envio_historico": privileges})
                expected = "MYSQL_OK" if privileges.endswith("DELETE") else "MYSQL_USUARIO_SEM_PERMISSAO"
                self.assertEqual(check_tables(cursor), expected)


if __name__ == "__main__":
    unittest.main()
