"""Cliente HTTP do contrato local de rastreamento."""
import logging
import random
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from email.utils import parsedate_to_datetime
from urllib.parse import quote

import requests
from urllib3.exceptions import ReadTimeoutError

from config import Config

logger = logging.getLogger(__name__)
HTTP_REPETIVEL = {408, 429, 500, 502, 503, 504}
ESPERA_MAXIMA = 30


class TrackingError(Exception):
    """Falha esperada de consulta."""


class TrackingTimeout(TrackingError):
    pass


class TrackingUnavailable(TrackingError):
    pass


class TrackingNotFound(TrackingError):
    pass


class TrackingInvalidResponse(TrackingError):
    pass


class TrackingRejected(TrackingError):
    pass


@dataclass(frozen=True)
class TrackingResult:
    status: str
    descricao: str | None = None


def retry_after(valor: str | None) -> float | None:
    if not valor:
        return None
    valor = valor.strip()
    if valor.isascii() and valor.isdecimal():
        return float(valor)
    try:
        instante = parsedate_to_datetime(valor)
        if instante.tzinfo is None:
            instante = instante.replace(tzinfo=timezone.utc)
        return max(0, (instante - datetime.now(timezone.utc)).total_seconds())
    except (ValueError, TypeError, OverflowError):
        return None


class TrackingApiClient:
    def __init__(self, config: Config):
        config.validar_provider()
        self.config = config
        self.base_url = config.tracking_api_base_url.rstrip("/")
        self.session = requests.Session()
        self.session.trust_env = False
        self.session.headers["Accept"] = "application/json"
        if config.tracking_api_token:
            self.session.headers["Authorization"] = f"Bearer {config.tracking_api_token}"
        self.proxima_consulta = 0.0

    def close(self) -> None:
        self.session.close()

    def fetch(self, codigo: str, *, envio_id: int | None = None) -> TrackingResult:
        if not codigo.strip() or codigo.strip() in {".", ".."}:
            raise TrackingRejected("Código de rastreio inválido")
        if time.monotonic() < self.proxima_consulta:
            raise TrackingUnavailable("Consulta adiada por Retry-After do provider")

        url = f"{self.base_url}/{quote(codigo, safe='')}"
        for tentativa in range(1, self.config.tracking_max_retries + 2):
            inicio = time.monotonic()
            http_status = None
            espera = None
            repetir = False
            try:
                with self.session.get(
                    url, timeout=self.config.tracking_timeout_seconds, allow_redirects=False
                ) as resposta:
                    http_status = resposta.status_code
                    if http_status == 200:
                        return self._parse(resposta)
                    repetir = http_status in HTTP_REPETIVEL
                    if repetir:
                        espera = retry_after(resposta.headers.get("Retry-After"))
                    if http_status == 404:
                        raise TrackingNotFound("HTTP 404: código inexistente")
                    if repetir or http_status >= 500:
                        raise TrackingUnavailable(f"HTTP {http_status}: provider indisponível")
                    raise TrackingRejected(f"HTTP {http_status}: resposta rejeitada")
            except requests.exceptions.SSLError:
                erro = TrackingRejected("Falha de validação TLS")
            except requests.ConnectTimeout:
                erro = TrackingTimeout("Timeout de conexão")
                repetir = True
            except (requests.ReadTimeout, requests.Timeout):
                erro = TrackingTimeout("Timeout de leitura")
                repetir = True
            except requests.ConnectionError as exc:
                if exc.args and isinstance(exc.args[0], ReadTimeoutError):
                    erro = TrackingTimeout("Timeout de leitura")
                else:
                    erro = TrackingUnavailable("Falha de conexão com o provider")
                repetir = True
            except requests.RequestException:
                erro = TrackingInvalidResponse("Falha no protocolo HTTP")
            except TrackingError as exc:
                erro = exc
            finally:
                logger.debug(
                    "provider=%s envio_id=%s tentativa=%d http=%s duracao_ms=%.0f",
                    self.config.tracking_provider, envio_id, tentativa, http_status,
                    (time.monotonic() - inicio) * 1000,
                )

            logger.debug("envio_id=%s tentativa=%d resultado=%s", envio_id, tentativa, type(erro).__name__)
            base = self.config.tracking_retry_backoff_seconds * 2 ** (tentativa - 1)
            atraso = espera if espera is not None else min(ESPERA_MAXIMA, base + random.uniform(0, 0.25))
            if espera is not None or http_status == 429:
                self.proxima_consulta = time.monotonic() + atraso
            if not repetir or tentativa > self.config.tracking_max_retries or atraso > ESPERA_MAXIMA:
                raise erro from None
            time.sleep(atraso)

        raise AssertionError("Tentativas HTTP esgotadas")

    @staticmethod
    def _parse(resposta: requests.Response) -> TrackingResult:
        tipo = resposta.headers.get("Content-Type", "").partition(";")[0].strip().lower()
        if tipo != "application/json" and not (tipo.startswith("application/") and tipo.endswith("+json")):
            raise TrackingInvalidResponse("Content-Type inesperado")
        try:
            data = resposta.json()
        except ValueError:
            raise TrackingInvalidResponse("JSON inválido") from None
        status = data.get("status") if isinstance(data, dict) else None
        if not isinstance(status, str) or not status.strip():
            raise TrackingInvalidResponse("Campo status ausente ou inválido")
        descricao = data.get("descricao")
        if descricao is not None and not isinstance(descricao, str):
            raise TrackingInvalidResponse("Campo descricao inválido")
        return TrackingResult(status, descricao)
