"""Persistência no schema MySQL gerenciado pelo Spring."""
import re
from dataclasses import dataclass
from datetime import datetime
from zoneinfo import ZoneInfo

import mysql.connector

from config import Config

STATUS_ENTREGUE = "ENTREGUE"
STATUS_CANONICOS = frozenset({"AGUARDANDO", "EM_TRANSITO", STATUS_ENTREGUE, "ERRO"})
FUSO_RASTREIO = ZoneInfo("America/Sao_Paulo")
LIMITE_EVENTO = 500


@dataclass(frozen=True)
class Encomenda:
    id: int
    codigo_rastreio: str
    ultimo_status: str | None
    entregue: bool
    data_atualizacao: datetime | None
    atualizado_em: datetime


def _formatar_evento(status: str, quando: datetime, descricao: str | None) -> str:
    prefixo = f"{status}|{quando.isoformat(timespec='microseconds')}|"
    texto = " ".join((descricao or "").splitlines()).replace("\x00", "")
    texto = texto.replace("%", "%25").replace("|", "%7C")
    texto = texto[:LIMITE_EVENTO - len(prefixo)]
    # Evita deixar um escape incompleto no ponto de truncamento.
    return prefixo + re.sub(r"%[0-9A-F]?$", "", texto)


class Repository:
    def __init__(self, config: Config):
        if not config.db_user or config.db_password is None:
            raise ValueError("Configure DB_USER e DB_PASSWORD para acessar o MySQL")
        self.conn = mysql.connector.connect(
            host=config.db_host,
            port=config.db_port,
            database=config.db_name,
            user=config.db_user,
            password=config.db_password,
            charset="utf8mb4",
            connection_timeout=10,
            autocommit=True,
        )

    def close(self) -> None:
        self.conn.close()

    def buscar_nao_entregues(self) -> list[Encomenda]:
        with self.conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, codigo_rastreio, ultimo_status, entregue,
                       data_atualizacao, atualizado_em
                FROM envios
                WHERE entregue = FALSE
                  AND (ultimo_status IS NULL OR UPPER(TRIM(ultimo_status)) <> 'ENTREGUE')
                ORDER BY data_atualizacao IS NOT NULL, data_atualizacao ASC, id ASC
                """
            )
            return [Encomenda(*row) for row in cur.fetchall()]

    def atualizar_status(self, original: Encomenda, status: str, descricao: str | None) -> bool:
        """Aplica a transição e anexa o evento, ou retorna False para snapshot obsoleto."""
        if status not in STATUS_CANONICOS:
            raise ValueError(f"Status de rastreamento desconhecido: {status!r}")
        if status == original.ultimo_status:
            return False

        self.conn.start_transaction()
        try:
            with self.conn.cursor(buffered=True) as cur:
                cur.execute(
                    """
                    SELECT id, codigo_rastreio, ultimo_status, entregue,
                           data_atualizacao, atualizado_em
                    FROM envios
                    WHERE id = %s AND entregue = FALSE
                      AND (ultimo_status IS NULL OR UPPER(TRIM(ultimo_status)) <> 'ENTREGUE')
                    FOR UPDATE
                    """,
                    (original.id,),
                )
                atual = cur.fetchone()
                if atual is None or Encomenda(*atual) != original:
                    self.conn.rollback()
                    return False

                quando = datetime.now(FUSO_RASTREIO)
                hora_local = quando.replace(tzinfo=None)
                cur.execute(
                    """
                    UPDATE envios
                    SET ultimo_status = %s, entregue = %s,
                        data_atualizacao = %s, atualizado_em = %s
                    WHERE id = %s
                    """,
                    (status, status == STATUS_ENTREGUE, hora_local, hora_local, original.id),
                )
                if cur.rowcount != 1:
                    self.conn.rollback()
                    return False

                # O lock do envio serializa os anexos feitos pelos Workers para esse ID.
                cur.execute(
                    "SELECT COALESCE(MAX(ordem), -1) + 1 FROM envio_historico WHERE envio_id = %s",
                    (original.id,),
                )
                ordem, = cur.fetchone()
                cur.execute(
                    "INSERT INTO envio_historico (envio_id, ordem, evento) VALUES (%s, %s, %s)",
                    (original.id, ordem, _formatar_evento(status, quando, descricao)),
                )
            self.conn.commit()
        except Exception:
            self.conn.rollback()
            raise
        return True
