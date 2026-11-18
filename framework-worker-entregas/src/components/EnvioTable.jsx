import { useEffect, useId, useRef, useState } from 'react'
import { formatarData, interpretarEvento } from '../utils/rastreamento.js'
import StatusBadge from './StatusBadge.jsx'
import styles from './EnvioTable.module.css'

function Data({ valor, fallback }) {
  const principal = formatarData(valor)
  const alternativa = valor == null ? formatarData(fallback) : null
  if (principal || alternativa) {
    return <time dateTime={principal ? valor : fallback}>{principal ?? alternativa}</time>
  }
  return <span className={styles.valorVazio} aria-label="Data indisponível">—</span>
}

function Historico({ envio }) {
  if (!envio.historico.length) return <p>Nenhum evento registrado.</p>

  return (
    <ol className={styles.eventos}>
      {envio.historico.map((valor, ordem) => {
        const evento = interpretarEvento(valor)
        return (
          <li key={ordem}>
            {evento ? (
              <>
                <StatusBadge status={evento.status} />
                {evento.data !== null && <Data valor={evento.data} />}
                {evento.descricao && <p>{evento.descricao}</p>}
              </>
            ) : <p>Evento em formato indisponível.</p>}
          </li>
        )
      })}
    </ol>
  )
}

function EnvioTable({ envios }) {
  const titulo = useId()
  const dialog = useRef(null)
  const fechar = useRef(null)
  const acionador = useRef(null)
  const [envioId, setEnvioId] = useState(null)
  const envioSelecionado = envios.find(({ id }) => id === envioId)
  const temSelecao = Boolean(envioSelecionado)

  useEffect(() => {
    if (temSelecao && !dialog.current.open) {
      dialog.current.showModal()
      fechar.current.focus()
    } else if (!temSelecao && dialog.current.open) {
      dialog.current.close()
    }
  }, [temSelecao])

  return (
    <>
      <div className={styles.wrapper}>
        <table className={styles.table}>
          <caption className={styles.caption}>Lista de encomendas</caption>
          <thead>
            <tr>
              <th scope="col">Código de rastreio</th>
              <th scope="col">Destinatário</th>
              <th scope="col">Status</th>
              <th scope="col">Última atualização</th>
              <th scope="col">Histórico</th>
            </tr>
          </thead>
          <tbody>
            {envios.map((envio) => (
              <tr key={envio.id}>
                <th scope="row" className={styles.rastreio}>{envio.codigoRastreio || '—'}</th>
                <td>{envio.nomeDestinatario || '—'}</td>
                <td><StatusBadge status={envio.ultimoStatus} entregue={envio.entregue} envioId={envio.id} /></td>
                <td><Data valor={envio.dataAtualizacao} fallback={envio.atualizadoEm} /></td>
                <td>
                  <button
                    type="button"
                    className={styles.acao}
                    aria-label={`Ver histórico de ${envio.codigoRastreio}`}
                    aria-haspopup="dialog"
                    onClick={(event) => {
                      acionador.current = event.currentTarget
                      setEnvioId(envio.id)
                    }}
                  >
                    Ver histórico
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <dialog
        ref={dialog}
        className={styles.dialog}
        aria-labelledby={titulo}
        onClose={() => {
          setEnvioId(null)
          acionador.current?.focus()
        }}
      >
        {envioSelecionado && (
          <>
            <h2 id={titulo}>Histórico de {envioSelecionado.codigoRastreio}</h2>
            <p>{envioSelecionado.nomeDestinatario}</p>
            <p>Status atual: <StatusBadge status={envioSelecionado.ultimoStatus} entregue={envioSelecionado.entregue} /></p>
            <Historico envio={envioSelecionado} />
            <button type="button" ref={fechar} className={styles.acao} onClick={() => dialog.current.close()}>
              Fechar
            </button>
          </>
        )}
      </dialog>
    </>
  )
}

export default EnvioTable
