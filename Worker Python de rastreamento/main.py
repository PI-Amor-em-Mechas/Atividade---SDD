"""Ponto de entrada do Worker de rastreamento."""
import logging
import signal
import sys
import threading

from api_client import TrackingApiClient
from config import Config
from repository import Repository
from tracking_service import TrackingService

logger = logging.getLogger("worker")
stop_event = threading.Event()


def _handle_signal(signum, _frame):
    logger.info("Sinal %s recebido, encerrando após o ciclo atual", signum)
    stop_event.set()


def main() -> int:
    cfg = Config()
    logging.basicConfig(
        level=cfg.log_level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    logger.info("Worker iniciado")
    client = TrackingApiClient(cfg.tracking_api_url, cfg.api_timeout_seconds)

    while not stop_event.is_set():
        repo = None
        try:
            repo = Repository(cfg.database_url)
            TrackingService(client, repo).run_cycle()
        except Exception:
            logger.exception("Falha no ciclo (banco indisponível?)")
            if cfg.poll_interval_seconds == 0:
                return 1
        finally:
            if repo:
                repo.close()

        if cfg.poll_interval_seconds == 0:
            break
        stop_event.wait(cfg.poll_interval_seconds)

    logger.info("Worker finalizado")
    return 0


if __name__ == "__main__":
    sys.exit(main())
