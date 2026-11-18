import { useId, useRef, useState } from 'react'
import { cadastrarEnvio, EnviosApiError } from '../api/enviosApi.js'
import styles from './EnvioForm.module.css'

function EnvioForm({ onCadastrado }) {
  const id = useId()
  const emAndamento = useRef(false)
  const [codigoRastreio, setCodigoRastreio] = useState('')
  const [nomeDestinatario, setNomeDestinatario] = useState('')
  const [erros, setErros] = useState({})
  const [enviando, setEnviando] = useState(false)
  const [feedback, setFeedback] = useState(null)

  async function handleSubmit(event) {
    event.preventDefault()

    if (emAndamento.current) {
      return
    }

    const envio = {
      codigoRastreio: codigoRastreio.trim(),
      nomeDestinatario: nomeDestinatario.trim(),
    }
    const novosErros = {}

    if (!envio.codigoRastreio) {
      novosErros.codigoRastreio = 'Informe o código de rastreio.'
    } else if (envio.codigoRastreio.length > 50) {
      novosErros.codigoRastreio = 'Use até 50 caracteres no código de rastreio.'
    }
    if (!envio.nomeDestinatario) {
      novosErros.nomeDestinatario = 'Informe o nome do destinatário.'
    } else if (envio.nomeDestinatario.length > 150) {
      novosErros.nomeDestinatario = 'Use até 150 caracteres no nome do destinatário.'
    }

    setErros(novosErros)
    setFeedback(null)

    if (Object.keys(novosErros).length > 0) {
      const campo = Object.keys(novosErros)[0]
      event.currentTarget.elements.namedItem(campo).focus()
      return
    }

    emAndamento.current = true
    setEnviando(true)

    try {
      await cadastrarEnvio(envio)
    } catch (error) {
      if (error instanceof EnviosApiError && error.status === 400) {
        const campos = {}
        for (const campo of ['codigoRastreio', 'nomeDestinatario']) {
          if (typeof error.campos?.[campo] === 'string') campos[campo] = error.campos[campo]
        }
        setErros(campos)
      }
      setFeedback({
        tipo: 'erro',
        mensagem:
          error instanceof EnviosApiError && error.status === 409
            ? 'Código de rastreio já cadastrado.'
            : error instanceof EnviosApiError ? error.message : 'Não foi possível cadastrar o envio.',
      })
      return
    } finally {
      emAndamento.current = false
      setEnviando(false)
    }

    setCodigoRastreio('')
    setNomeDestinatario('')
    setFeedback({ tipo: 'sucesso', mensagem: 'Envio cadastrado com sucesso.' })
    onCadastrado?.()
  }

  return (
    <section className={styles.section} aria-labelledby={`${id}-titulo`}>
      <h2 id={`${id}-titulo`}>Nova encomenda</h2>
      <form className={styles.form} onSubmit={handleSubmit} noValidate aria-busy={enviando}>
        <div className={styles.field}>
          <label htmlFor={`${id}-codigo`}>Código de rastreio (obrigatório)</label>
          <input
            id={`${id}-codigo`}
            name="codigoRastreio"
            value={codigoRastreio}
            onChange={(event) => {
              setCodigoRastreio(event.target.value)
              setErros((atuais) => ({ ...atuais, codigoRastreio: undefined }))
            }}
            required
            disabled={enviando}
            aria-invalid={Boolean(erros.codigoRastreio)}
            aria-describedby={erros.codigoRastreio ? `${id}-erro-codigo` : undefined}
          />
          {erros.codigoRastreio && (
            <p id={`${id}-erro-codigo`} className={styles.error} role="alert">
              {erros.codigoRastreio}
            </p>
          )}
        </div>
        <div className={styles.field}>
          <label htmlFor={`${id}-destinatario`}>Nome do destinatário (obrigatório)</label>
          <input
            id={`${id}-destinatario`}
            name="nomeDestinatario"
            autoComplete="name"
            value={nomeDestinatario}
            onChange={(event) => {
              setNomeDestinatario(event.target.value)
              setErros((atuais) => ({ ...atuais, nomeDestinatario: undefined }))
            }}
            required
            disabled={enviando}
            aria-invalid={Boolean(erros.nomeDestinatario)}
            aria-describedby={erros.nomeDestinatario ? `${id}-erro-destinatario` : undefined}
          />
          {erros.nomeDestinatario && (
            <p id={`${id}-erro-destinatario`} className={styles.error} role="alert">
              {erros.nomeDestinatario}
            </p>
          )}
        </div>
        <button type="submit" className={styles.submit} disabled={enviando}>
          {enviando ? 'Cadastrando…' : 'Cadastrar envio'}
        </button>
      </form>
      {feedback && (
        <p
          className={feedback.tipo === 'erro' ? styles.error : styles.success}
          role={feedback.tipo === 'erro' ? 'alert' : 'status'}
        >
          {feedback.mensagem}
        </p>
      )}
    </section>
  )
}

export default EnvioForm
