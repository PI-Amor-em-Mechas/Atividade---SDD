import { useEffect } from 'react'
import { normalizarStatus } from '../utils/rastreamento.js'
import styles from './StatusBadge.module.css'

const STATUS_CONFIG = {
  AGUARDANDO: { rotulo: 'Aguardando', variante: 'aguardando' },
  EM_TRANSITO: { rotulo: 'Em trânsito', variante: 'em-transito' },
  ENTREGUE: { rotulo: 'Entregue', variante: 'entregue' },
  ERRO: { rotulo: 'Erro', variante: 'erro' },
}

const STATUS_DESCONHECIDO = {
  rotulo: 'Desconhecido',
  variante: 'desconhecido',
}

function StatusBadge({ status, entregue, envioId }) {
  const chave = normalizarStatus(status)
  const divergente = entregue === true && chave !== 'ENTREGUE'
  const conhecido = Object.hasOwn(STATUS_CONFIG, chave)
  const config = divergente || !conhecido ? STATUS_DESCONHECIDO : STATUS_CONFIG[chave]

  useEffect(() => {
    if (import.meta.env.DEV && divergente && envioId != null) {
      console.warn('Flag de entrega divergente do status do envio', envioId)
    }
  }, [divergente, envioId])

  return (
    <span
      className={`${styles.badge} ${styles[config.variante]}`}
      data-status={config === STATUS_DESCONHECIDO ? 'DESCONHECIDO' : chave}
    >
      <span className={styles.dot} aria-hidden="true" />
      {divergente ? 'Status inconsistente' : config.rotulo}
    </span>
  )
}

export default StatusBadge
