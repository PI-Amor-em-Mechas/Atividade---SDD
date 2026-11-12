# Quickstart: Visualização de Encomendas e Status

## Pré-requisitos

- Node.js compatível com Vite 8
- Dependências instaladas (`npm install`)
- Backend de encomendas disponível
- Arquivo `.env` na raiz com:

```dotenv
VITE_API_BASE_URL=http://localhost:8080
```

## Executar

```bash
npm install
npm run dev
```

Acesse a URL exibida pelo Vite. A tela de encomendas é a página principal da aplicação.

## Verificações automatizadas

```bash
npm run lint
npm run build
```

## Cenários de validação

### 1. Loading inicial

- Atrasar a resposta do backend ou usar throttling no DevTools.
- **Esperado**: indicador "Carregando encomendas…" até a resposta.

### 2. Lista carregada

- Backend deve retornar registros nos quatro status.
- **Esperado**: tabela com código de rastreio, destinatário, status e data; badges distintos para AGUARDANDO, EM_TRANSITO, ENTREGUE e ERRO; datas em pt-BR.

### 3. Lista vazia

- Backend retorna `[]`.
- **Esperado**: mensagem "Nenhuma encomenda encontrada", sem tabela e sem erro.

### 4. Erro inicial

- Desligar o backend, retornar 500 ou simular timeout.
- **Esperado**: painel de erro com mensagem amigável e botão "Tentar novamente".

### 5. Recuperação

- Religar o backend e acionar "Tentar novamente".
- **Esperado**: estado de loading e, em seguida, a lista.

### 6. Atualização manual

- Alterar o status de uma encomenda no backend e clicar em "Atualizar".
- **Esperado**: lista permanece visível durante a atualização e reflete a mudança ao concluir.

### 7. Atualização automática

- Alterar um registro no backend e aguardar até 30 segundos.
- **Esperado**: interface reflete a alteração sem interação.

### 8. Falha durante atualização

- Carregar a lista, depois desligar o backend e aguardar o polling.
- **Esperado**: lista anterior permanece visível + aviso "Não foi possível atualizar a lista…".

### 9. Dados defensivos

- Retornar status desconhecido, data inválida e campo ausente.
- **Esperado**: badge "Desconhecido", data "—" e campo "—", sem quebra da tela.

### 10. Acessibilidade e responsividade

- Navegar por teclado e testar com largura de 360 px.
- **Esperado**: botões acessíveis por teclado, loading/erro anunciados, status legível sem depender de cor, tabela com rolagem interna e sem rolagem horizontal da página.
