"""Ponto de entrada do Worker de rastreamento."""
import logging
import signal
import sys
import threading
from contextlib import closing

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
    try:
        cfg = Config()
        client = TrackingApiClient(cfg)
    except ValueError:
        logger.error("Configuração inválida. Confira TRACKING_PROVIDER, TRACKING_API_BASE_URL e opções no README.")
        return 2
    logging.basicConfig(
        level=cfg.log_level,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    # Os logs de transporte em DEBUG incluem o path com o código de rastreio.
    logging.getLogger("urllib3.connectionpool").setLevel(logging.WARNING)
    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)

    logger.info("Worker iniciado")
    with closing(client):
        return _executar(cfg, client)


def _executar(cfg: Config, client: TrackingApiClient) -> int:
    while not stop_event.is_set():
        repo = None
        try:
            repo = Repository(cfg)
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
