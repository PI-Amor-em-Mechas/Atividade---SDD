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

function StatusBadge({ status }) {
  const chave = String(status ?? '')
    .trim()
    .toUpperCase()
  const config = STATUS_CONFIG[chave] ?? STATUS_DESCONHECIDO

  return (
    <span
      className={`${styles.badge} ${styles[config.variante]}`}
      data-status={chave || 'DESCONHECIDO'}
    >
      <span className={styles.dot} aria-hidden="true" />
      {config.rotulo}
    </span>
  )
}

export default StatusBadge
