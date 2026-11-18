const ISO = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d{1,9})?)?(Z|[+-]\d{2}:\d{2})?$/u
const formatoSaoPaulo = new Intl.DateTimeFormat('pt-BR', {
  timeZone: 'America/Sao_Paulo', day: '2-digit', month: '2-digit', year: 'numeric',
  hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
})

export function formatarData(valor) {
  const partes = typeof valor === 'string' && ISO.exec(valor)
  if (!partes) return null
  const [, ano, mes, dia, hora, minuto, segundo = '00', offset] = partes
  const diaLimite = new Date(Date.UTC(2000, Number(mes), 0))
  diaLimite.setUTCFullYear(Number(ano), Number(mes), 0)
  if (+mes < 1 || +mes > 12 || +dia < 1 || +dia > diaLimite.getUTCDate()
    || +hora > 23 || +minuto > 59 || +segundo > 59) return null

  // LocalDateTime já representa o relógio de São Paulo. Preserve seus componentes.
  if (!offset) return `${dia}/${mes}/${ano} ${hora}:${minuto}`
  const instante = new Date(valor)
  if (Number.isNaN(instante.valueOf())) return null
  const campos = Object.fromEntries(formatoSaoPaulo.formatToParts(instante).map(({ type, value }) => [type, value]))
  return `${campos.day}/${campos.month}/${campos.year} ${campos.hour}:${campos.minute}`
}

export function normalizarStatus(valor) {
  return typeof valor === 'string' ? valor.trim().toUpperCase().replace(/[\s-]+/gu, '_') : ''
}

export function interpretarEvento(valor) {
  if (typeof valor !== 'string' || !valor.trim()) return null
  const primeiro = valor.indexOf('|')
  if (primeiro < 0) return { status: valor, data: null, descricao: null }
  const segundo = valor.indexOf('|', primeiro + 1)
  if (!valor.slice(0, primeiro).trim() || segundo < 0) return null

  const descricao = valor.slice(segundo + 1)
  if (/\||%(?!25|7C)/iu.test(descricao)) return null
  const data = valor.slice(primeiro + 1, segundo)
  return {
    status: valor.slice(0, primeiro),
    data,
    descricao: descricao.replace(/%25|%7C/giu, (escape) => escape === '%25' ? '%' : '|') || null,
  }
}
