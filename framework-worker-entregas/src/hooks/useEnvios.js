import { useCallback, useEffect, useRef, useState } from 'react'
import { listarEnvios } from '../api/enviosApi.js'

export const INTERVALO_ATUALIZACAO_MS = 30000

export function useEnvios() {
  const [envios, setEnvios] = useState([])
  const [erro, setErro] = useState(null)
  const [jaCarregou, setJaCarregou] = useState(false)
  const [atualizando, setAtualizando] = useState(true)
  const requisicao = useRef(null)

  const carregar = useCallback(async (substituir = false) => {
    if (requisicao.current && !substituir) return
    requisicao.current?.abort()
    const controller = new AbortController()
    requisicao.current = controller
    setAtualizando(true)
    try {
      const lista = await listarEnvios({ signal: controller.signal })
      if (controller.signal.aborted) return
      setEnvios(lista)
      setJaCarregou(true)
      setErro(null)
    } catch (falha) {
      if (!controller.signal.aborted) setErro(falha)
    } finally {
      if (!controller.signal.aborted) {
        requisicao.current = null
        setAtualizando(false)
      }
    }
  }, [])

  useEffect(() => {
    const inicial = window.setTimeout(carregar, 0)
    const intervalo = window.setInterval(() => {
      if (document.visibilityState === 'visible') carregar()
    }, INTERVALO_ATUALIZACAO_MS)
    return () => {
      window.clearTimeout(inicial)
      window.clearInterval(intervalo)
      requisicao.current?.abort()
      requisicao.current = null
    }
  }, [carregar])

  const atualizar = useCallback(() => carregar(true), [carregar])
  const estado = !jaCarregou
    ? (atualizando ? 'loading' : 'error')
    : (envios.length ? 'list' : 'empty')

  return { envios, estado, erro, erroAtualizacao: jaCarregou ? erro : null, atualizando, atualizar }
}
