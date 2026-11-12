import { useCallback, useEffect, useRef, useState } from 'react'
import { listarEnvios } from '../api/enviosApi.js'

export const INTERVALO_ATUALIZACAO_MS = 30000

function normalizarEnvio(envio, indice) {
  if (!envio || typeof envio !== 'object') {
    return null
  }

  const codigoRastreio = String(envio.codigoRastreio ?? '').trim()
  const nomeDestinatario = String(envio.nomeDestinatario ?? '').trim()
  const status = String(envio.status ?? '').trim().toUpperCase()

  return {
    id: `${codigoRastreio || 'sem-codigo'}-${indice}`,
    codigoRastreio,
    nomeDestinatario,
    status,
    dataUltimaAtualizacao: envio.dataUltimaAtualizacao ?? null,
  }
}

function normalizarResposta(resposta) {
  if (!Array.isArray(resposta)) {
    throw new Error('A fonte de dados retornou um formato inesperado.')
  }

  return resposta
    .map((envio, indice) => normalizarEnvio(envio, indice))
    .filter((envio) => envio !== null)
}

export function useEnvios() {
  const [envios, setEnvios] = useState([])
  const [carregando, setCarregando] = useState(true)
  const [erro, setErro] = useState(null)
  const [jaCarregou, setJaCarregou] = useState(false)
  const [atualizando, setAtualizando] = useState(false)

  const idRequisicao = useRef(0)
  const emAndamento = useRef(false)
  const montado = useRef(true)

  const carregar = useCallback(
    async ({ silencioso = false, permitirConcorrencia = false, inicial = false } = {}) => {
      if (emAndamento.current && !permitirConcorrencia) {
        return
      }

      emAndamento.current = true
      idRequisicao.current += 1
      const idAtual = idRequisicao.current

      await Promise.resolve()

      if (!montado.current) {
        return
      }

      if (!silencioso && !inicial) {
        setCarregando(true)
      }
      if (!inicial) {
        setAtualizando(true)
      }

      try {
        const resposta = await listarEnvios()

        if (!montado.current || idAtual !== idRequisicao.current) {
          return
        }

        const lista = normalizarResposta(resposta)
        setEnvios(lista)
        setJaCarregou(true)
        setErro(null)
      } catch (erroCarregamento) {
        if (!montado.current || idAtual !== idRequisicao.current) {
          return
        }

        setErro(
          erroCarregamento instanceof Error
            ? erroCarregamento
            : new Error('Não foi possível carregar as encomendas.'),
        )
      } finally {
        if (montado.current && idAtual === idRequisicao.current) {
          emAndamento.current = false
          setCarregando(false)
          setAtualizando(false)
        }
      }
    },
    [],
  )

  useEffect(() => {
    montado.current = true

    const inicializacao = window.setTimeout(() => {
      carregar({ inicial: true })
    }, 0)

    const intervalo = window.setInterval(() => {
      const visivel =
        typeof document === 'undefined' ||
        document.visibilityState === 'visible'

      if (visivel) {
        carregar({ silencioso: true })
      }
    }, INTERVALO_ATUALIZACAO_MS)

    return () => {
      montado.current = false
      window.clearTimeout(inicializacao)
      window.clearInterval(intervalo)
    }
  }, [carregar])

  const atualizar = useCallback(() => {
    carregar({ silencioso: jaCarregou, permitirConcorrencia: true })
  }, [carregar, jaCarregou])

  let estado = 'list'

  if (!jaCarregou && carregando) {
    estado = 'loading'
  } else if (!jaCarregou && erro) {
    estado = 'error'
  } else if (envios.length === 0) {
    estado = 'empty'
  }

  return {
    envios,
    estado,
    erro,
    erroAtualizacao: jaCarregou ? erro : null,
    atualizando,
    atualizar,
  }
}
