import { expect, test } from '@playwright/test'

const base = process.env.FRONTEND_E2E_URL
const controle = process.env.FRONTEND_E2E_CONTROL_URL

test.use({ channel: process.env.FRONTEND_E2E_BROWSER || 'msedge' })
test.skip(!base || !controle, 'Requer Vite, Spring, MySQL e controle local do stub.')

async function ciclo(request, status, chamadas) {
  const resposta = await request.post(controle, { data: { status } })
  expect(resposta.ok()).toBe(true)
  expect(await resposta.json()).toMatchObject({ chamadas })
}

async function evidencia(page, testInfo, nome) {
  const path = testInfo.outputPath(`${nome}.png`)
  await page.screenshot({ path })
  await testInfo.attach(nome, { path, contentType: 'image/png' })
}

test('React, proxy, Spring, MySQL e Worker no navegador', async ({ page, request }, testInfo) => {
  const codigo = 'INTEGRACAO-UI-001'
  await page.goto(base)
  await expect(page.getByText('Nenhuma encomenda encontrada')).toBeVisible()

  const campoCodigo = page.getByRole('textbox', { name: /código de rastreio/i })
  const campoNome = page.getByRole('textbox', { name: /nome do destinatário/i })
  const cadastrar = page.getByRole('button', { name: 'Cadastrar envio' })
  const preencher = async () => {
    await campoCodigo.fill(codigo)
    await campoNome.fill('Pessoa de Teste')
  }

  await cadastrar.click()
  await expect(page.getByText('Informe o código de rastreio.')).toBeVisible()

  const url = new URL('/api/envios', base).href
  const invalidar = (route) => {
    if (route.request().method() === 'POST') {
      return route.continue({ postData: JSON.stringify({ codigoRastreio: codigo, nomeDestinatario: '' }) })
    }
    return route.continue()
  }
  await page.route(url, invalidar)
  await preencher()
  const invalido = page.waitForResponse((resposta) => resposta.url() === url && resposta.status() === 400)
  await cadastrar.click()
  await invalido
  await expect(page.getByText('Dados inválidos')).toBeVisible()
  await expect(page.getByText('nomeDestinatario é obrigatório')).toBeVisible()
  await page.unroute(url, invalidar)

  const criado = page.waitForResponse((resposta) => resposta.url() === url && resposta.status() === 201)
  await cadastrar.click()
  const { id } = await (await criado).json()
  const linha = page.getByRole('row', { name: new RegExp(codigo) })
  const atualizar = page.getByRole('button', { name: 'Atualizar', exact: true })
  await expect(linha.getByText('Aguardando')).toBeVisible()
  await evidencia(page, testInfo, 'cadastro-aguardando')
  await preencher()
  const duplicado = page.waitForResponse((resposta) => resposta.url() === url && resposta.status() === 409)
  await cadastrar.click()
  await duplicado
  await expect(page.getByText('Código de rastreio já cadastrado.')).toBeVisible()

  await ciclo(request, 'EM_TRANSITO', 1)
  await atualizar.click()
  await expect(linha.getByText('Em trânsito')).toBeVisible()

  const acao = linha.getByRole('button', { name: new RegExp(codigo) })
  await cadastrar.focus()
  await page.keyboard.press('Tab')
  await expect(acao).toBeFocused()
  await page.keyboard.press('Enter')
  const dialog = page.getByRole('dialog', { name: new RegExp(codigo) })
  await expect(dialog).toBeVisible()
  await expect(dialog.getByRole('button', { name: 'Fechar' })).toBeFocused()
  await expect(dialog.getByText('Resposta controlada')).toBeVisible()
  await evidencia(page, testInfo, 'historico-em-transito')
  await page.keyboard.press('Escape')
  await expect(dialog).toBeHidden()
  await expect(acao).toBeFocused()

  await ciclo(request, 'EM_TRANSITO', 2)
  const lista = page.waitForResponse((resposta) => resposta.url() === url && resposta.request().method() === 'GET')
  await atualizar.click()
  await lista
  await acao.click()
  await expect(dialog.getByRole('listitem')).toHaveCount(1)
  await dialog.getByRole('button', { name: 'Fechar' }).click()

  await ciclo(request, 'ENTREGUE', 3)
  await atualizar.click()
  await expect(linha.getByText('Entregue')).toBeVisible()
  await acao.click()
  await expect(dialog.getByRole('listitem')).toHaveCount(2)
  await expect(dialog.getByRole('listitem').last().getByText('Entregue')).toBeVisible()
  await evidencia(page, testInfo, 'historico-entregue')
  await page.keyboard.press('Escape')
  await ciclo(request, 'ENTREGUE', 3)
  const detalhe = await request.get(new URL(`/api/envios/${id}`, base).href)
  expect(await detalhe.json()).toMatchObject({ id, entregue: true, ultimoStatus: 'ENTREGUE' })

  // Exercita os fallbacks com a API interceptada só neste cenário.
  await page.route(url, (route) => route.fulfill({ json: [{
    id, codigoRastreio: codigo, nomeDestinatario: 'Pessoa de Teste', ultimoStatus: 'OUTRO',
    entregue: false, dataAtualizacao: 'inválida', historico: [null, 'EM_TRANSITO|inválido|'],
  }] }))
  await atualizar.click()
  await expect(linha.getByText('Desconhecido')).toBeVisible()
  await expect(linha.getByLabel('Data indisponível')).toBeVisible()
  await acao.click()
  await expect(dialog.getByText('Evento em formato indisponível.')).toBeVisible()
  await page.keyboard.press('Escape')
  await page.unroute(url)

  const desligar = await request.post(controle, { data: { offline: true } })
  expect(desligar.ok()).toBe(true)
  await atualizar.click()
  await expect(page.getByText(/não foi possível atualizar a lista/i)).toBeVisible()
  await expect(linha.getByText('Desconhecido')).toBeVisible()
  await evidencia(page, testInfo, 'spring-indisponivel-lista-preservada')
})
