"""Configuração do Worker, lida de variáveis de ambiente."""
import math
import os
from dataclasses import dataclass, field
from urllib.parse import urlsplit


@dataclass(frozen=True)
class Config:
    db_host: str = field(default_factory=lambda: os.getenv("DB_HOST", "localhost"))
    db_port: int = field(default_factory=lambda: int(os.getenv("DB_PORT", "3306")))
    db_name: str = field(default_factory=lambda: os.getenv("DB_NAME", "amor_em_mechas"))
    db_user: str = field(default_factory=lambda: os.getenv("DB_USER", "rastreamento_app"))
    db_password: str | None = field(default_factory=lambda: os.getenv("DB_PASSWORD"), repr=False)
    tracking_provider: str = field(default_factory=lambda: os.getenv("TRACKING_PROVIDER", ""))
    tracking_api_base_url: str = field(default_factory=lambda: os.getenv("TRACKING_API_BASE_URL", ""))
    tracking_api_token: str = field(default_factory=lambda: os.getenv("TRACKING_API_TOKEN", ""), repr=False)
    tracking_timeout_seconds: float = field(default_factory=lambda: float(os.getenv("TRACKING_TIMEOUT_SECONDS", "10")))
    tracking_max_retries: int = field(default_factory=lambda: int(os.getenv("TRACKING_MAX_RETRIES", "0")))
    tracking_retry_backoff_seconds: float = field(default_factory=lambda: float(os.getenv("TRACKING_RETRY_BACKOFF_SECONDS", "1")))
    poll_interval_seconds: int = field(default_factory=lambda: int(os.getenv("POLL_INTERVAL_SECONDS", "0")))
    log_level: str = field(default_factory=lambda: os.getenv("LOG_LEVEL", "INFO"))

    def validar_provider(self) -> None:
        if self.tracking_provider != "stub":
            raise ValueError("Configure TRACKING_PROVIDER=stub para testes locais. Provider real aguarda contrato.")
        try:
            url = urlsplit(self.tracking_api_base_url)
            porta = url.port
        except ValueError:
            raise ValueError("TRACKING_API_BASE_URL inválida") from None
        if (
            url.scheme not in {"http", "https"}
            or url.hostname not in {"localhost", "127.0.0.1", "::1"}
            or not porta or porta == 8080
            or url.username is not None or url.password is not None
            or "?" in self.tracking_api_base_url or "#" in self.tracking_api_base_url
            or any(c.isspace() or ord(c) < 32 for c in self.tracking_api_base_url)
            or url.path.rstrip("/") != "/rastreamento"
        ):
            raise ValueError("TRACKING_API_BASE_URL deve apontar para o stub em loopback, rota /rastreamento, porta explícita diferente de 8080")
        if self.tracking_api_token and (
            not self.tracking_api_token.isascii()
            or any(not 33 <= ord(c) <= 126 for c in self.tracking_api_token)
        ):
            raise ValueError("TRACKING_API_TOKEN inválido")
        if not math.isfinite(self.tracking_timeout_seconds) or self.tracking_timeout_seconds <= 0:
            raise ValueError("Timeout de rastreamento deve ser positivo e finito")
        if not 0 <= self.tracking_max_retries <= 5:
            raise ValueError("TRACKING_MAX_RETRIES deve estar entre 0 e 5")
        if not 0 < self.tracking_retry_backoff_seconds <= 30:
            raise ValueError("TRACKING_RETRY_BACKOFF_SECONDS deve ser positivo e até 30")
