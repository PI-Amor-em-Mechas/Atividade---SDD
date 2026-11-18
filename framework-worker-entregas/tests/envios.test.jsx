// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor, within } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import App from '../src/App.jsx'
import { listarEnvios, normalizarEnvio } from '../src/api/enviosApi.js'
import StatusBadge from '../src/components/StatusBadge.jsx'
import EnvioTable from '../src/components/EnvioTable.jsx'
import { INTERVALO_ATUALIZACAO_MS } from '../src/hooks/useEnvios.js'
import { formatarData, interpretarEvento } from '../src/utils/rastreamento.js'

const envio = {
  id: 423, codigoRastreio: 'AB123BR', nomeDestinatario: 'Maria Silva',
  ultimoStatus: 'AGUARDANDO', entregue: false, dataAtualizacao: '2026-11-18T23:59:59',
  criadoEm: '2026-11-18T14:00:00', atualizadoEm: '2026-11-18T14:00:00',
  historico: ['AGUARDANDO'],
}

function json(dados, status = 200) {
  return new Response(JSON.stringify(dados), { status, headers: { 'Content-Type': 'application/json' } })
}

function preencherFormulario() {
  fireEvent.change(screen.getByRole('textbox', { name: /código de rastreio/i }), { target: { value: ' AB123BR ' } })
  fireEvent.change(screen.getByRole('textbox', { name: /nome do destinatário/i }), { target: { value: 'Maria Silva' } })
  fireEvent.click(screen.getByRole('button', { name: 'Cadastrar envio' }))
}

afterEach(() => {
  cleanup()
  vi.useRealTimers()
  vi.restoreAllMocks()
  vi.unstubAllGlobals()
})

describe('contrato Spring', () => {
  it('preserva campos válidos e normaliza histórico nulo', () => {
    expect(normalizarEnvio({ ...envio, historico: null })).toEqual({ ...envio, historico: [] })
  })

  it('rejeita ausência de ID, respostas HTML e envelopes inesperados', async () => {
    expect(() => normalizarEnvio({ ...envio, id: undefined })).toThrow(/formato inesperado/)
    vi.stubGlobal('fetch', vi.fn()
      .mockResolvedValueOnce(new Response('<html>', { headers: { 'Content-Type': 'text/html' } }))
      .mockResolvedValueOnce(json({ envios: [envio] })))
    await expect(listarEnvios()).rejects.toMatchObject({ kind: 'contract' })
    await expect(listarEnvios()).rejects.toMatchObject({ kind: 'contract' })
  })

  it('mantém a identidade do nó quando muda a ordem dos registros', () => {
    const outro = { ...envio, id: 9, codigoRastreio: 'OUTRO' }
    const { rerender } = render(<EnvioTable envios={[envio, outro]} />)
    const linha = screen.getByRole('row', { name: /AB123BR/ })
    rerender(<EnvioTable envios={[outro, { ...envio, codigoRastreio: 'NOVO' }]} />)
    expect(screen.getByRole('row', { name: /NOVO/ })).toBe(linha)
  })
})

describe('apresentação', () => {
  it.each([
    ['AGUARDANDO', 'Aguardando'], [' em-transito ', 'Em trânsito'],
    ['ENTREGUE', 'Entregue'], ['ERRO', 'Erro'], ['pré-ENTREGUE', 'Desconhecido'], [null, 'Desconhecido'],
  ])('exibe %s como %s', (status, rotulo) => {
    render(<StatusBadge status={status} />)
    expect(screen.getByText(rotulo)).toBeTruthy()
  })

  it('exibe divergência entre flag e status', () => {
    render(<StatusBadge status="EM_TRANSITO" entregue />)
    expect(screen.getByText('Status inconsistente')).toBeTruthy()
  })

  it.each([
    ['2026-11-18T23:59:59.123456', '18/11/2026 23:59'],
    ['2026-11-18T23:59:59-03:00', '18/11/2026 23:59'],
    ['2026-11-19T02:59:00Z', '18/11/2026 23:59'],
    ['2026-02-30T14:00:00', null], ['erro', null], [null, null],
  ])('formata data %s', (valor, esperado) => {
    expect(formatarData(valor)).toBe(esperado)
  })

  it('interpreta evento simples, evento estruturado e restaura escapes uma vez', () => {
    expect(interpretarEvento('AGUARDANDO')).toEqual({ status: 'AGUARDANDO', data: null, descricao: null })
    expect(interpretarEvento('EM_TRANSITO|2026-11-18T14:30:00-03:00|50%25 %7C %257C')).toEqual({
      status: 'EM_TRANSITO', data: '2026-11-18T14:30:00-03:00', descricao: '50% | %7C',
    })
    expect(interpretarEvento('ENTREGUE|inválido|')).toEqual({ status: 'ENTREGUE', data: 'inválido', descricao: null })
    expect(interpretarEvento('ENTREGUE|incompleto')).toBeNull()
    expect(interpretarEvento('EM_TRANSITO|2026-11-18T14:30:00-03:00|%ZZ')).toBeNull()
    expect(interpretarEvento(null)).toBeNull()
    expect(interpretarEvento(12)).toBeNull()
  })

  it('renderiza eventos em ordem com um fallback para itens inválidos', () => {
    const historico = ['AGUARDANDO', 'EM_TRANSITO|2026-11-18T14:30:00-03:00|50%25 %7C caixa', null]
    const { container } = render(<EnvioTable envios={[{ ...envio, historico }]} />)
    const elemento = container.querySelector('dialog')
    elemento.showModal = () => { elemento.open = true }
    fireEvent.click(screen.getByRole('button', { name: /ver histórico/i }))
    const dialog = screen.getByRole('dialog')
    expect(within(dialog).getByText('18/11/2026 14:30')).toBeTruthy()
    expect(within(dialog).getByText('50% | caixa')).toBeTruthy()
    expect(within(dialog).getByText('Evento em formato indisponível.')).toBeTruthy()
    expect(within(dialog).getAllByRole('listitem')).toHaveLength(3)
  })
})

describe('fluxos da página', () => {
  it('lista pelo GET, cadastra com o payload mínimo e recarrega após 201', async () => {
    const fetch = vi.fn().mockResolvedValueOnce(json([]))
      .mockResolvedValueOnce(json(envio, 201)).mockResolvedValueOnce(json([envio]))
    vi.stubGlobal('fetch', fetch)
    render(<App />)
    await screen.findByText('Nenhuma encomenda encontrada')
    preencherFormulario()
    const linha = await screen.findByRole('row', { name: /AB123BR/ })
    expect(within(linha).getByText('Aguardando')).toBeTruthy()
    expect(within(linha).getByText('18/11/2026 23:59')).toBeTruthy()
    expect(fetch.mock.calls.map(([url]) => url)).toEqual(Array(3).fill('/api/envios'))
    expect(fetch.mock.calls[1][1]).toMatchObject({ method: 'POST', body: JSON.stringify({
      codigoRastreio: 'AB123BR', nomeDestinatario: 'Maria Silva',
    }) })
  })

  it.each([
    [409, { mensagem: 'Duplicidade' }, 'Código de rastreio já cadastrado.'],
    [400, { mensagem: 'Dados inválidos', campos: { codigoRastreio: 'Informe um código válido.' } }, 'Dados inválidos'],
  ])('exibe erro HTTP %s sem limpar os valores', async (status, corpo, mensagem) => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValueOnce(json([])).mockResolvedValueOnce(json(corpo, status)))
    render(<App />)
    await screen.findByText('Nenhuma encomenda encontrada')
    preencherFormulario()
    expect(await screen.findByText(mensagem)).toBeTruthy()
    const input = screen.getByRole('textbox', { name: /código de rastreio/i })
    expect(input.value).toBe(' AB123BR ')
    if (status === 400) {
      expect(screen.getByText('Informe um código válido.')).toBeTruthy()
      expect(input.getAttribute('aria-invalid')).toBe('true')
    }
  })

  it('acompanha trânsito e entrega, pausa oculto e preserva a lista na falha', async () => {
    vi.useFakeTimers()
    const visibilidade = vi.spyOn(document, 'visibilityState', 'get').mockReturnValue('visible')
    const fetch = vi.fn().mockResolvedValueOnce(json([envio]))
      .mockResolvedValueOnce(json([{ ...envio, ultimoStatus: 'EM_TRANSITO' }]))
      .mockResolvedValueOnce(json([{ ...envio, ultimoStatus: 'ENTREGUE', entregue: true }]))
      .mockRejectedValueOnce(new TypeError('rede'))
    vi.stubGlobal('fetch', fetch)
    render(<App />)
    const avancar = (ms) => act(() => vi.advanceTimersByTimeAsync(ms))
    await avancar(1)
    expect(screen.getByText('Aguardando')).toBeTruthy()
    visibilidade.mockReturnValue('hidden')
    await avancar(INTERVALO_ATUALIZACAO_MS)
    expect(fetch).toHaveBeenCalledTimes(1)
    visibilidade.mockReturnValue('visible')
    await avancar(INTERVALO_ATUALIZACAO_MS)
    expect(screen.getByText('Em trânsito')).toBeTruthy()
    await avancar(INTERVALO_ATUALIZACAO_MS)
    expect(screen.getByText('Entregue')).toBeTruthy()
    await avancar(INTERVALO_ATUALIZACAO_MS)
    expect(screen.getByText('Entregue')).toBeTruthy()
    expect(screen.getByText(/não foi possível atualizar a lista/i)).toBeTruthy()
  })

  it('mostra falha inicial e permite tentar novamente', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValueOnce(new TypeError('rede')).mockResolvedValueOnce(json([])))
    render(<App />)
    await waitFor(() => expect(screen.getByRole('alert').textContent).toMatch(/não foi possível conectar/i))
    fireEvent.click(screen.getByRole('button', { name: 'Tentar novamente' }))
    expect(await screen.findByText('Nenhuma encomenda encontrada')).toBeTruthy()
  })
})
