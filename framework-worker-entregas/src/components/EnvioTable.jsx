import StatusBadge from './StatusBadge.jsx'
import styles from './EnvioTable.module.css'

const formatadorData = new Intl.DateTimeFormat('pt-BR', {
  dateStyle: 'short',
  timeStyle: 'short',
})

function DataUltimaAtualizacao({ valor }) {
  const data = valor ? new Date(valor) : null
  const dataValida = data instanceof Date && !Number.isNaN(data.getTime())

  if (!dataValida) {
    return (
      <span
        className={styles.valorVazio}
        aria-label="Data de atualização não informada"
      >
        —
      </span>
    )
  }

  return <time dateTime={data.toISOString()}>{formatadorData.format(data)}</time>
}

function ValorOuTraco({ valor }) {
  if (!valor) {
    return <span className={styles.valorVazio}>—</span>
  }

  return valor
}

function EnvioTable({ envios }) {
  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <caption className={styles.caption}>Lista de encomendas</caption>
        <thead>
          <tr>
            <th scope="col">Código de rastreio</th>
            <th scope="col">Destinatário</th>
            <th scope="col">Status</th>
            <th scope="col">Última atualização</th>
          </tr>
        </thead>
        <tbody>
          {envios.map((envio) => (
            <tr key={envio.id}>
              <th scope="row" className={styles.rastreio}>
                <ValorOuTraco valor={envio.codigoRastreio} />
              </th>
              <td>
                <ValorOuTraco valor={envio.nomeDestinatario} />
              </td>
              <td>
                <StatusBadge status={envio.status} />
              </td>
              <td>
                <DataUltimaAtualizacao valor={envio.dataUltimaAtualizacao} />
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}

export default EnvioTable
