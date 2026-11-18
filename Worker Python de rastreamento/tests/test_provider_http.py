import unittest
from threading import Thread
from types import SimpleNamespace
from unittest.mock import Mock, patch

import requests

from api_client import (
    TrackingApiClient, TrackingInvalidResponse, TrackingNotFound, TrackingRejected,
    TrackingTimeout, TrackingUnavailable, retry_after,
)
from config import Config
from provider_stub import criar_stub
from tracking_service import TrackingService


class ProviderHTTPTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stub = criar_stub()
        cls.thread = Thread(target=cls.stub.serve_forever, daemon=True)
        cls.thread.start()
        cls.addClassCleanup(cls.stub.server_close)
        cls.addClassCleanup(cls.thread.join)
        cls.addClassCleanup(cls.stub.shutdown)

    def setUp(self):
        self.stub.chamadas.clear()
        self.stub.estados.clear()
        self.url = f"http://127.0.0.1:{self.stub.server_port}/rastreamento///"

    def client(self, retries=0, token="", timeout=1):
        client = TrackingApiClient(Config(
            tracking_provider="stub", tracking_api_base_url=self.url, tracking_api_token=token,
            tracking_max_retries=retries, tracking_timeout_seconds=timeout,
        ))
        self.addCleanup(client.close)
        return client

    def ciclo(self, client, *codigos, anterior="AGUARDANDO"):
        repo = Mock()
        envios = [
            SimpleNamespace(id=i, codigo_rastreio=codigo, ultimo_status=anterior)
            for i, codigo in enumerate(codigos, 1)
        ]
        repo.buscar_nao_entregues.return_value = envios
        resumo = TrackingService(client, repo).run_cycle()
        return resumo, repo, envios

    def test_url_e_bearer_sem_segredo_nos_logs(self):
        codigo = "A/B ?#ç"
        token = "segredo-sintetico-do-teste"
        self.stub.estados[codigo] = "EM_TRANSITO"
        with self.assertLogs("api_client", "DEBUG") as logs:
            result = self.client(token=token).fetch(codigo, envio_id=42)
        self.assertEqual(result.status, "EM_TRANSITO")
        self.assertEqual(self.stub.chamadas, [("/rastreamento/A%2FB%20%3F%23%C3%A7", f"Bearer {token}")])
        self.assertNotIn(token, str(logs.output))
        self.assertNotIn(codigo, str(logs.output))

    def test_config_rejeita_default_spring_url_invalida_e_provider_desconhecido(self):
        for provider, url in [("", self.url), ("inventado", self.url), ("stub", ""),
                              ("stub", "http://localhost:8080/rastreamento"),
                              ("stub", "http://localhost:erro/rastreamento"),
                              ("stub", "https://example.com/rastreamento")]:
            with self.subTest(provider=provider, url=url), self.assertRaises(ValueError):
                TrackingApiClient(Config(tracking_provider=provider, tracking_api_base_url=url))

    def test_mapa_explicito_e_entrega_exata(self):
        resumo, repo, envios = self.ciclo(self.client(), "EM_TRANSITO", "ENTREGUE", "Entregue")
        self.assertEqual((resumo.atualizadas, resumo.entregues, resumo.erros), (2, 1, 1))
        self.assertEqual(repo.atualizar_status.call_count, 2)
        repo.atualizar_status.assert_any_call(envios[0], "EM_TRANSITO", "Objeto em transferência")
        repo.atualizar_status.assert_any_call(envios[1], "ENTREGUE", None)

    def test_status_desconhecido_preserva_estado_e_omite_valor_bruto(self):
        with self.assertLogs("tracking_service", "ERROR") as logs:
            resumo, repo, _ = self.ciclo(self.client(), "VALOR_PRIVADO")
        self.assertEqual(resumo.erros, 1)
        self.assertNotIn("VALOR_PRIVADO", str(logs.output))
        self.assertIn("sha256", resumo.erros_detalhe[0])
        repo.atualizar_status.assert_not_called()

    def test_timeout_tem_retry_limitado_e_preserva_estado(self):
        with patch("api_client.time.sleep"):
            resumo, repo, _ = self.ciclo(self.client(retries=1, timeout=0.05), "TIMEOUT")
        self.assertEqual(len(self.stub.chamadas), 2)
        self.assertEqual(resumo.erros, 1)
        repo.atualizar_status.assert_not_called()

    def test_timeout_ao_ler_corpo_e_classificado(self):
        with self.assertRaisesRegex(TrackingTimeout, "Timeout de leitura"):
            self.client(timeout=0.08).fetch("TIMEOUT_CORPO")

    def test_404_nao_repete_e_preserva_estado(self):
        resumo, repo, _ = self.ciclo(self.client(retries=2), "404")
        self.assertEqual(len(self.stub.chamadas), 1)
        self.assertEqual(resumo.erros, 1)
        repo.atualizar_status.assert_not_called()
        with self.assertRaises(TrackingNotFound):
            self.client().fetch("404")

    def test_429_respeita_retry_after_e_adia_outros_codigos(self):
        with patch("api_client.time.sleep") as sleep:
            resumo, repo, _ = self.ciclo(self.client(retries=1), "429", "EM_TRANSITO")
        sleep.assert_called_once_with(2)
        self.assertEqual(len(self.stub.chamadas), 2)
        self.assertEqual(resumo.erros, 2)
        repo.atualizar_status.assert_not_called()
        self.assertEqual(retry_after("Wed, 01 Jan 2020 00:00:00 GMT"), 0)
        self.assertIsNone(retry_after("inválido"))

    def test_408_e_5xx_repetem_com_limite_e_proximo_envio_prossegue(self):
        with patch("api_client.time.sleep") as sleep:
            resumo, repo, envios = self.ciclo(self.client(retries=1), "408", "500", "EM_TRANSITO")
        self.assertEqual(sleep.call_count, 2)
        self.assertEqual(len(self.stub.chamadas), 5)
        self.assertEqual((resumo.erros, resumo.atualizadas), (2, 1))
        repo.atualizar_status.assert_called_once_with(envios[2], "EM_TRANSITO", "Objeto em transferência")

    def test_payload_invalido_sem_retry_e_sem_escrita(self):
        client = self.client(retries=2)
        for codigo in ("JSON_INVALIDO", "SEM_STATUS", "TIPO_INVALIDO"):
            with self.subTest(codigo=codigo), self.assertRaises(TrackingInvalidResponse):
                client.fetch(codigo)
        resumo, repo, _ = self.ciclo(client, "JSON_INVALIDO", "SEM_STATUS", "TIPO_INVALIDO")
        self.assertEqual(resumo.erros, 3)
        self.assertEqual(len(self.stub.chamadas), 6)
        repo.atualizar_status.assert_not_called()

    def test_redirect_e_4xx_rejeitados_sem_repeticao(self):
        client = self.client(retries=2)
        for codigo in ("REDIRECT", "400", "401", "403", "409"):
            with self.subTest(codigo=codigo), self.assertRaises(TrackingRejected):
                client.fetch(codigo)
        self.assertEqual(len(self.stub.chamadas), 5)

    def test_tls_conexao_e_timeout_de_conexao_classificados(self):
        for erro, classe, tentativas in [
            (requests.exceptions.SSLError, TrackingRejected, 1),
            (requests.ConnectionError, TrackingUnavailable, 2),
            (requests.ConnectTimeout, TrackingTimeout, 2),
        ]:
            with self.subTest(erro=erro):
                client = self.client(retries=1)
                with patch.object(client.session, "get", side_effect=erro("detalhe privado")) as get:
                    with patch("api_client.time.sleep"), self.assertRaises(classe) as falha:
                        client.fetch("CODIGO")
                self.assertEqual(get.call_count, tentativas)
                self.assertNotIn("detalhe privado", str(falha.exception))

    def test_status_igual_sem_escrita(self):
        resumo, repo, _ = self.ciclo(self.client(), "EM_TRANSITO", anterior="EM_TRANSITO")
        self.assertEqual(resumo.sem_mudanca, 1)
        repo.atualizar_status.assert_not_called()
