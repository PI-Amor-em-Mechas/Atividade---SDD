const API_BASE_URL = (import.meta.env.VITE_API_BASE_URL || '').trim().replace(/\/+$/u, '')
const DEFAULT_TIMEOUT_MS = 10000

export class EnviosApiError extends Error {
  constructor(message, { kind, status, campos } = {}) {
    super(message)
    this.name = 'EnviosApiError'
    this.kind = kind
    this.status = status
    this.campos = campos
  }
}

function erroContrato() {
  return new EnviosApiError('A API retornou dados de encomenda em um formato inesperado.', { kind: 'contract' })
}

export function normalizarEnvio(envio) {
  if (!envio || !Number.isSafeInteger(envio.id) || envio.id <= 0
    || typeof envio.codigoRastreio !== 'string' || typeof envio.nomeDestinatario !== 'string'
    || typeof envio.entregue !== 'boolean'
    || (envio.historico != null && !Array.isArray(envio.historico))
    || [envio.ultimoStatus, envio.dataAtualizacao, envio.criadoEm, envio.atualizadoEm]
      .some((valor) => valor != null && typeof valor !== 'string')) {
    throw erroContrato()
  }
  return {
    id: envio.id,
    codigoRastreio: envio.codigoRastreio,
    nomeDestinatario: envio.nomeDestinatario,
    ultimoStatus: envio.ultimoStatus?.trim() ? envio.ultimoStatus : null,
    entregue: envio.entregue,
    criadoEm: envio.criadoEm ?? null,
    atualizadoEm: envio.atualizadoEm ?? null,
    dataAtualizacao: envio.dataAtualizacao ?? null,
    historico: envio.historico ?? [],
  }
}

async function request(statusEsperado, { signal, ...options } = {}) {
  const timeout = AbortSignal.timeout(DEFAULT_TIMEOUT_MS)
  try {
    const response = await fetch(`${API_BASE_URL}/api/envios`, {
      ...options,
      signal: signal ? AbortSignal.any([signal, timeout]) : timeout,
      headers: { Accept: 'application/json', ...options.headers },
    })
    const tipo = response.headers.get('content-type')?.split(';', 1)[0].trim().toLowerCase()
    let dados
    if (tipo === 'application/json' || tipo?.endsWith('+json')) {
      try {
        dados = await response.json()
      } catch (error) {
        if (!(error instanceof SyntaxError)) throw error
      }
    }
    if (!response.ok) {
      const { status } = response
      const servidor = status >= 500
      const mensagem = typeof dados?.mensagem === 'string' && dados.mensagem.trim()
      throw new EnviosApiError(
        servidor ? 'O servidor não conseguiu processar a solicitação.'
          : mensagem || (status === 404 ? 'Recurso não encontrado.' : 'A solicitação não pôde ser processada.'),
        { kind: servidor ? 'server' : 'client', status, campos: status === 400 ? dados?.campos : undefined },
      )
    }
    if (response.status !== statusEsperado || dados == null) throw erroContrato()
    return dados
  } catch (error) {
    if (signal?.aborted || error instanceof EnviosApiError) throw error
    if (timeout.aborted) {
      throw new EnviosApiError('A API demorou muito para responder. Tente novamente.', { kind: 'timeout' })
    }
    throw new EnviosApiError('Não foi possível conectar à API. Verifique se o servidor está disponível.', { kind: 'network' })
  }
}

export async function listarEnvios({ signal } = {}) {
  const resposta = await request(200, { signal })
  if (!Array.isArray(resposta)) throw erroContrato()
  const envios = resposta.map(normalizarEnvio)
  if (new Set(envios.map(({ id }) => id)).size !== envios.length) throw erroContrato()
  return envios
}

export async function cadastrarEnvio({ codigoRastreio, nomeDestinatario }) {
  const resposta = await request(201, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ codigoRastreio, nomeDestinatario }),
  })
  return normalizarEnvio(resposta)
}
