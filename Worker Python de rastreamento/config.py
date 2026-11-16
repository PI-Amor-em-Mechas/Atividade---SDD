"""Configuração do Worker, lida de variáveis de ambiente."""
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Config:
    database_url: str = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/encomendas")
    tracking_api_url: str = os.getenv("TRACKING_API_URL", "http://localhost:8080/rastreamento")
    api_timeout_seconds: float = float(os.getenv("API_TIMEOUT_SECONDS", "10"))
    # 0 = executa um ciclo e encerra (útil para cron); >0 = loop contínuo.
    poll_interval_seconds: int = int(os.getenv("POLL_INTERVAL_SECONDS", "0"))
    log_level: str = os.getenv("LOG_LEVEL", "INFO")
