import os
import unittest
from datetime import datetime
from unittest.mock import Mock, patch
from uuid import uuid4

from mysql.connector import DataError

from api_client import TrackingResult, TrackingTimeout
from config import Config
from repository import Repository
from tracking_service import TrackingService


@unittest.skipUnless(os.getenv("WORKER_MYSQL_TESTS") == "1", "requer MySQL de teste")
class RepositoryMySQLTest(unittest.TestCase):
    def setUp(self):
        self.config = Config()
        self.assertTrue(self.config.db_name.endswith("_test"), "use um schema descartável")
        self.repo = Repository(self.config)
        self.addCleanup(self.repo.close)
        self.ids = []
        self.addCleanup(self.excluir_fixtures)
        self.assertEqual(self.query("SELECT COUNT(*) FROM envios"), [(0,)])

    def query(self, sql, parametros=()):
        with self.repo.conn.cursor() as cursor:
            cursor.execute(sql, parametros)
            resultado = cursor.fetchall() if cursor.with_rows else cursor.lastrowid
        self.repo.conn.commit()
        return resultado

    def excluir_fixtures(self):
        for envio_id in self.ids:
            self.query("DELETE FROM envio_historico WHERE envio_id = %s", (envio_id,))
            self.query("DELETE FROM envios WHERE id = %s", (envio_id,))

    def criar(self, status="AGUARDANDO", entregue=False, data=datetime(2020, 1, 1)):
        envio_id = self.query(
            """INSERT INTO envios (codigo_rastreio, nome_destinatario, ultimo_status,
                                   entregue, data_atualizacao, criado_em, atualizado_em)
               VALUES (%s, 'Teste Worker', %s, %s, %s, '2020-01-01', '2020-01-01')""",
            (uuid4().hex, status, entregue, data),
        )
        self.ids.append(envio_id)
        return envio_id

    def estado(self, envio_id):
        return self.query(
            """SELECT ultimo_status, entregue, data_atualizacao, atualizado_em, criado_em
               FROM envios WHERE id = %s""",
            (envio_id,),
        )[0]

    def historico(self, envio_id):
        return self.query(
            "SELECT ordem, evento FROM envio_historico WHERE envio_id = %s ORDER BY ordem",
            (envio_id,),
        )

    def test_seleciona_pendentes_em_ordem_e_com_nulos_primeiro(self):
        recente = self.criar(data=datetime(2020, 1, 2))
        antigo = self.criar()
        empate = self.criar()
        sem_status_e_data = self.criar(status=None, data=None)
        self.assertEqual(
            [envio.id for envio in self.repo.buscar_nao_entregues()],
            [sem_status_e_data, antigo, empate, recente],
        )

    def test_exclui_entregues_por_flag_ou_status(self):
        self.criar("ENTREGUE", True)
        self.criar("Entregue", False)
        self.criar("AGUARDANDO", True)
        self.assertEqual(self.repo.buscar_nao_entregues(), [])

    def test_transicao_atualiza_datas_e_anexa_um_evento(self):
        envio_id = self.criar()
        self.query(
            "INSERT INTO envio_historico (envio_id, ordem, evento) VALUES (%s, 0, 'AGUARDANDO')",
            (envio_id,),
        )
        antes = self.estado(envio_id)
        envio, = self.repo.buscar_nao_entregues()
        self.assertTrue(self.repo.atualizar_status(envio, "EM_TRANSITO", "Linha\r\nA|" + "x" * 500))
        status, entregue, data, atualizado, criado = self.estado(envio_id)
        self.assertEqual((status, entregue, criado), ("EM_TRANSITO", False, antes[4]))
        self.assertGreater(data, antes[2])
        self.assertEqual(data, atualizado)
        inicial, (ordem, evento) = self.historico(envio_id)
        self.assertEqual(inicial, (0, "AGUARDANDO"))
        self.assertEqual(ordem, 1)
        self.assertEqual(len(evento), 500)
        status_evento, instante, descricao = evento.split("|")
        self.assertEqual(status_evento, status)
        hora_evento = datetime.fromisoformat(instante)
        self.assertIsNotNone(hora_evento.utcoffset())
        self.assertEqual(hora_evento.replace(tzinfo=None), data)
        self.assertTrue(descricao.startswith("Linha A%7C"))

    def test_status_igual_nao_duplica_historico(self):
        envio_id = self.criar("EM_TRANSITO")
        antes = self.estado(envio_id)
        client = Mock()
        client.fetch.return_value = TrackingResult("EM_TRANSITO")
        resumo = TrackingService(client, self.repo).run_cycle()
        self.assertEqual(resumo.sem_mudanca, 1)
        self.assertEqual(self.estado(envio_id), antes)
        self.assertEqual(self.historico(envio_id), [])

    def test_entrega_terminal_nao_e_consultada_no_ciclo_seguinte(self):
        envio_id = self.criar("EM_TRANSITO")
        client = Mock()
        client.fetch.return_value = TrackingResult("ENTREGUE")
        service = TrackingService(client, self.repo)
        self.assertEqual(service.run_cycle().entregues, 1)
        self.assertEqual(self.estado(envio_id)[:2], ("ENTREGUE", True))
        self.assertEqual(service.run_cycle().total, 0)
        client.fetch.assert_called_once()
        self.assertEqual(len(self.historico(envio_id)), 1)

    def test_erro_mysql_no_insert_reverte_update(self):
        envio_id = self.criar()
        antes = self.estado(envio_id)
        self.query("SET SESSION sql_mode = 'STRICT_ALL_TABLES'")
        envio, = self.repo.buscar_nao_entregues()
        with patch("repository._formatar_evento", return_value="x" * 501):
            with self.assertRaises(DataError):
                self.repo.atualizar_status(envio, "EM_TRANSITO", None)
        self.assertEqual(self.estado(envio_id), antes)
        self.assertEqual(self.historico(envio_id), [])

    def test_snapshot_concorrente_nao_sobrescreve_nem_duplica(self):
        envio_id = self.criar()
        outra_conexao = Repository(self.config)
        self.addCleanup(outra_conexao.close)
        antigo, = self.repo.buscar_nao_entregues()
        concorrente, = outra_conexao.buscar_nao_entregues()
        self.assertTrue(outra_conexao.atualizar_status(concorrente, "EM_TRANSITO", None))
        self.assertFalse(self.repo.atualizar_status(antigo, "EM_TRANSITO", None))
        self.assertFalse(self.repo.atualizar_status(antigo, "ERRO", None))
        self.assertEqual(self.estado(envio_id)[:2], ("EM_TRANSITO", False))
        self.assertEqual(len(self.historico(envio_id)), 1)

    def test_falhas_isoladas_preservam_estado_e_permite_proximo_envio(self):
        timeout = self.criar()
        desconhecido = self.criar()
        saudavel = self.criar()
        client = Mock()
        client.fetch.side_effect = [
            TrackingTimeout("timeout controlado"),
            TrackingResult("STATUS_NOVO"),
            TrackingResult("EM_TRANSITO"),
        ]
        resumo = TrackingService(client, self.repo).run_cycle()
        self.assertEqual((resumo.erros, resumo.atualizadas), (2, 1))
        for falho in (timeout, desconhecido):
            self.assertEqual(self.estado(falho)[:2], ("AGUARDANDO", False))
            self.assertEqual(self.historico(falho), [])
        self.assertEqual(self.estado(saudavel)[:2], ("EM_TRANSITO", False))
        self.assertEqual(len(self.historico(saudavel)), 1)
