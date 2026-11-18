"""Regra de negócio: consulta, compara e atualiza."""
import logging
from dataclasses import dataclass, field
from hashlib import sha256

from api_client import TrackingApiClient, TrackingError, TrackingInvalidResponse, TrackingNotFound
from repository import Repository, STATUS_ENTREGUE

logger = logging.getLogger(__name__)

# Vocabulário sintético do stub. A entrega exige correspondência exata.
STATUS_STUB = {
    "AGUARDANDO": "AGUARDANDO",
    "EM_TRANSITO": "EM_TRANSITO",
    "ENTREGUE": "ENTREGUE",
    "ERRO": "ERRO",
}

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
                result = self.client.fetch(enc.codigo_rastreio, envio_id=enc.id)
                status = STATUS_STUB.get(result.status)
                if status is None:
                    identificador = sha256(result.status.encode("utf-8", "surrogatepass")).hexdigest()[:12]
                    raise TrackingInvalidResponse(f"Status sem mapeamento (sha256={identificador})")

                if status == enc.ultimo_status:
                    summary.sem_mudanca += 1
                    logger.debug("envio_id=%s status=%s sem mudança", enc.id, status)
                    continue

                if not self.repo.atualizar_status(enc, status, result.descricao):
                    summary.sem_mudanca += 1
                    logger.debug("envio_id=%s transição ignorada por mudança concorrente", enc.id)
                    continue

                summary.atualizadas += 1
                if status == STATUS_ENTREGUE:
                    summary.entregues += 1
                logger.info("envio_id=%s transição aplicada status=%s", enc.id, status)

            except TrackingNotFound as exc:
                self._registrar_erro(summary, enc.id, str(exc), warn=True)
            except TrackingError as exc:
                self._registrar_erro(summary, enc.id, str(exc))
            except Exception as exc:  # falha ao atualizar ou erro inesperado
                self._registrar_erro(summary, enc.id, type(exc).__name__, trace=True)

        logger.info(
            "Ciclo finalizado: %d atualizadas, %d sem mudança, %d entregues, %d erros",
            summary.atualizadas, summary.sem_mudanca, summary.entregues, summary.erros,
        )
        return summary

    @staticmethod
    def _registrar_erro(summary, envio_id, motivo, warn=False, trace=False):
        summary.erros += 1
        summary.erros_detalhe.append(f"envio_id={envio_id}: {motivo}")
        log = logger.warning if warn else logger.error
        log("envio_id=%s estado anterior preservado: %s", envio_id, motivo, exc_info=trace)
