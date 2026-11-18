"""Regra de negócio: consulta, compara e atualiza."""
import logging
from dataclasses import dataclass, field

from api_client import TrackingApiClient, TrackingError, TrackingNotFound
from repository import Repository

logger = logging.getLogger(__name__)

STATUS_ENTREGUE = "ENTREGUE"


@dataclass
class CycleSummary:
    total: int = 0
    atualizadas: int = 0
    sem_mudanca: int = 0
    entregues: int = 0
    erros: int = 0
    erros_detalhe: list[str] = field(default_factory=list)


class TrackingService:
    def __init__(self, client: TrackingApiClient, repo: Repository):
        self.client = client
        self.repo = repo

    def run_cycle(self) -> CycleSummary:
        summary = CycleSummary()
        encomendas = self.repo.buscar_nao_entregues()
        summary.total = len(encomendas)
        logger.info("Ciclo iniciado: %d encomenda(s) não entregue(s)", summary.total)

        for enc in encomendas:
            try:
                result = self.client.fetch(enc.codigo_rastreio)

                if result.status == enc.ultimo_status:
                    summary.sem_mudanca += 1
                    logger.debug("%s sem mudança (%s)", enc.codigo_rastreio, result.status)
                    continue

                entregue = result.status == STATUS_ENTREGUE
                self.repo.atualizar_status(enc.id, result.status, result.descricao, entregue)
                summary.atualizadas += 1
                if entregue:
                    summary.entregues += 1
                logger.info("%s: %s -> %s", enc.codigo_rastreio, enc.ultimo_status, result.status)

            except TrackingNotFound as exc:
                self._registrar_erro(summary, enc.codigo_rastreio, exc, warn=True)
            except TrackingError as exc:
                self._registrar_erro(summary, enc.codigo_rastreio, exc)
            except Exception as exc:  # falha ao atualizar ou erro inesperado
                self._registrar_erro(summary, enc.codigo_rastreio, exc, trace=True)

        logger.info(
            "Ciclo finalizado: %d atualizadas, %d sem mudança, %d entregues, %d erros",
            summary.atualizadas, summary.sem_mudanca, summary.entregues, summary.erros,
        )
        return summary

    @staticmethod
    def _registrar_erro(summary, codigo, exc, warn=False, trace=False):
        summary.erros += 1
        summary.erros_detalhe.append(f"{codigo}: {exc}")
        log = logger.warning if warn else logger.error
        log("Erro na encomenda %s: %s", codigo, exc, exc_info=trace)
