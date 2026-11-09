const configuredApiBaseUrl = (import.meta.env.VITE_API_BASE_URL || '').trim()
const API_BASE_URL = configuredApiBaseUrl.endsWith('/')
  ? configuredApiBaseUrl.replace(/\/$/u, '')
  : configuredApiBaseUrl
const DEFAULT_TIMEOUT_MS = 10000

export class EnviosApiError extends Error {
  constructor(message, { kind, status, details, cause } = {}) {
    super(message, { cause })
    this.name = 'EnviosApiError'
    this.kind = kind
    this.status = status
    this.details = details
  }
}

async function request(path, options = {}) {
  const controller = new AbortController()
  const timeoutId = setTimeout(() => controller.abort(), DEFAULT_TIMEOUT_MS)

  try {
    const response = await fetch(`${API_BASE_URL}${path}`, {
      ...options,
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        ...options.headers,
      },
    })

    const contentType = response.headers.get('content-type') || ''
    const details = contentType.includes('application/json')
      ? await response.json().catch(() => null)
      : await response.text()

    if (!response.ok) {
      const kind = response.status >= 500 ? 'server' : 'client'
      const message =
        details?.message ||
        (kind === 'server'
          ? 'O servidor não conseguiu processar a solicitação.'
          : 'A solicitação não pôde ser processada.')

      throw new EnviosApiError(message, {
        kind,
        status: response.status,
        details,
      })
    }

    return details
  } catch (error) {
    if (error instanceof EnviosApiError) {
      throw error
    }

    if (error.name === 'AbortError') {
      throw new EnviosApiError(
        'A API demorou muito para responder. Tente novamente.',
        { kind: 'timeout', cause: error },
      )
    }

    throw new EnviosApiError(
      'Não foi possível conectar à API. Verifique se o servidor está disponível.',
      { kind: 'network', cause: error },
    )
  } finally {
    clearTimeout(timeoutId)
  }
}

export function listarEnvios() {
  return request('/api/envios')
}

export function cadastrarEnvio(envio) {
  return request('/api/envios', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(envio),
  })
}