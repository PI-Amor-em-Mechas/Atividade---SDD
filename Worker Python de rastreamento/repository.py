"""Acesso ao banco (PostgreSQL).

Esquema assumido:
  encomendas(id, codigo_rastreio, ultimo_status, data_atualizacao, entregue BOOLEAN)
  historico_status(id, encomenda_id, status, descricao, data_registro)
"""
from dataclasses import dataclass

import psycopg2


@dataclass(frozen=True)
class Encomenda:
    id: int
    codigo_rastreio: str
    ultimo_status: str | None


class Repository:
    def __init__(self, database_url: str):
        self.conn = psycopg2.connect(database_url)

    def close(self) -> None:
        self.conn.close()

    def buscar_nao_entregues(self) -> list[Encomenda]:
        with self.conn, self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, codigo_rastreio, ultimo_status
                FROM encomendas
                WHERE entregue = FALSE
                  AND (ultimo_status IS NULL OR ultimo_status <> 'ENTREGUE')
                ORDER BY data_atualizacao NULLS FIRST, id
                """
            )
            return [Encomenda(*row) for row in cur.fetchall()]

    def atualizar_status(self, encomenda_id: int, status: str, descricao: str | None, entregue: bool) -> None:
        """Atualiza a encomenda e grava o histórico na mesma transação."""
        try:
            with self.conn, self.conn.cursor() as cur:
                cur.execute(
                    """
                    UPDATE encomendas
                    SET ultimo_status = %s, data_atualizacao = NOW(), entregue = %s
                    WHERE id = %s
                    """,
                    (status, entregue, encomenda_id),
                )
                cur.execute(
                    """
                    INSERT INTO historico_status (encomenda_id, status, descricao, data_registro)
                    VALUES (%s, %s, %s, NOW())
                    """,
                    (encomenda_id, status, descricao),
                )
        except Exception:
            self.conn.rollback()
            raise
