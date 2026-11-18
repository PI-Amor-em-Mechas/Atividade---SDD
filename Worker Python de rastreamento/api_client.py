"""Cliente HTTP da API de rastreamento."""
import logging
import unicodedata
from dataclasses import dataclass

import requests

logger = logging.getLogger(__name__)


class TrackingError(Exception):
    """Base para erros de consulta ao rastreamento."""


class TrackingTimeout(TrackingError):
    pass


class TrackingUnavailable(TrackingError):
    pass


class TrackingNotFound(TrackingError):
    pass


class TrackingInvalidResponse(TrackingError):
    pass


@dataclass(frozen=True)
class TrackingResult:
    status: str
    descricao: str | None = None


def normalize_status(raw: str) -> str:
    """'Saiu para entrega' -> 'SAIU_PARA_ENTREGA'."""
    text = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode()
    return "_".join(text.upper().replace("-", " ").split())


class TrackingApiClient:
    def __init__(self, base_url: str, timeout: float):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.session = requests.Session()

    def fetch(self, codigo: str) -> TrackingResult:
        url = f"{self.base_url}/{codigo}"
        try:
            resp = self.session.get(url, timeout=self.timeout)
        except requests.Timeout as exc:
            raise TrackingTimeout(f"Timeout consultando {codigo}") from exc
        except requests.ConnectionError as exc:
            raise TrackingUnavailable(f"API indisponível ao consultar {codigo}") from exc
        except requests.RequestException as exc:
            raise TrackingUnavailable(f"Falha de rede consultando {codigo}: {exc}") from exc

        if resp.status_code == 404:
            raise TrackingNotFound(f"Código inexistente: {codigo}")
        if resp.status_code >= 500 or resp.status_code in (429, 408):
            raise TrackingUnavailable(f"API retornou HTTP {resp.status_code} para {codigo}")
        if resp.status_code >= 400:
            raise TrackingInvalidResponse(f"HTTP {resp.status_code} inesperado para {codigo}")

        try:
            data = resp.json()
        except ValueError as exc:
            raise TrackingInvalidResponse(f"JSON inválido para {codigo}") from exc

        status = data.get("status") if isinstance(data, dict) else None
        if not isinstance(status, str) or not status.strip():
            raise TrackingInvalidResponse(f"Campo 'status' ausente/inválido para {codigo}")

        descricao = data.get("descricao")
        return TrackingResult(
            status=normalize_status(status),
            descricao=descricao if isinstance(descricao, str) else None,
        )
