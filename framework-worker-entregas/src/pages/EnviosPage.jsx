import EnvioTable from '../components/EnvioTable.jsx'
import { useEnvios } from '../hooks/useEnvios.js'
import styles from './EnviosPage.module.css'

function EnviosPage() {
  const {
    envios,
    estado,
    erro,
    erroAtualizacao,
    atualizando,
    atualizar,
  } = useEnvios()

  const atualizacaoIndisponivel = atualizando || estado === 'loading'

  return (
    <main className={styles.page}>
      <header className={styles.header}>
        <div>
          <h1 className={styles.title}>Encomendas</h1>
          <p className={styles.subtitle}>
            Acompanhe as encomendas e seus status.
          </p>
        </div>
        <button
          type="button"
          className={styles.refresh}
          onClick={atualizar}
          disabled={atualizacaoIndisponivel}
        >
          {atualizando ? 'Atualizando…' : 'Atualizar'}
        </button>
      </header>

      {erroAtualizacao && (
        <div className={styles.warning} role="status" aria-live="polite">
          <span>
            Não foi possível atualizar a lista. Os dados exibidos podem estar
            desatualizados.
          </span>
          <button
            type="button"
            className={styles.linkButton}
            onClick={atualizar}
            disabled={atualizando}
          >
            Tentar novamente
          </button>
        </div>
      )}

      {estado === 'loading' && (
        <section className={styles.state} role="status" aria-live="polite">
          <span className={styles.spinner} aria-hidden="true" />
          <p>Carregando encomendas…</p>
        </section>
      )}

      {estado === 'error' && (
        <section className={styles.state} role="alert">
          <h2>Não foi possível carregar as encomendas</h2>
          <p>
            {erro?.message || 'Tente novamente em alguns instantes.'}
          </p>
          <button type="button" className={styles.retry} onClick={atualizar}>
            Tentar novamente
          </button>
        </section>
      )}

      {estado === 'empty' && (
        <section className={styles.state} role="status">
          <h2>Nenhuma encomenda encontrada</h2>
          <p>
            Assim que houver encomendas cadastradas, elas aparecerão aqui.
          </p>
          <button
            type="button"
            className={styles.retry}
            onClick={atualizar}
            disabled={atualizando}
          >
            Atualizar
          </button>
        </section>
      )}

      {estado === 'list' && (
        <>
          <div className={styles.listHeader}>
            <p className={styles.count}>
              {envios.length} {envios.length === 1 ? 'encomenda' : 'encomendas'}
            </p>
            {atualizando && (
              <p className={styles.updating} role="status" aria-live="polite">
                Atualizando dados…
              </p>
            )}
          </div>
          <EnvioTable envios={envios} />
        </>
      )}
    </main>
  )
}

export default EnviosPage
