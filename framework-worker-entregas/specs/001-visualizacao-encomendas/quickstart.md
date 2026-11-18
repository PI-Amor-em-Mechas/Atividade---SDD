# Quickstart

1. Inicie MySQL e Spring em `localhost:8080` conforme o README do módulo Java.
2. Em `framework-worker-entregas`, execute `npm install` e `npm run dev`.
   Deixe `VITE_API_BASE_URL` vazia para usar o proxy. Opcionalmente, altere
   `API_PROXY_TARGET` para outro endereço interno.
3. Cadastre um envio e confirme `AGUARDANDO`. Repita o código para conferir
   a mensagem de duplicidade. A API valida os limites de 50 e 150 caracteres.
4. Inicie o stub do provider e execute ciclos do Worker segundo o README do
   módulo Python. Use “Atualizar” ou o polling para observar as transições.
5. Use Tab até “Ver histórico”, Enter para abrir e Escape para fechar. Confira
   o retorno de foco e os eventos em ordem.

Validação de frontend: `npm run lint`, `npm run build` e `npm test`.

O teste de navegador roda com `npm run test:e2e`. Use um banco descartável
e vazio. Passe a URL do Vite em `FRONTEND_E2E_URL` e a URL do controlador
local de teste em `FRONTEND_E2E_CONTROL_URL`. O controlador recebe
`POST {"status":"EM_TRANSITO"}` ou `POST {"status":"ENTREGUE"}`, executa um
ciclo do Worker contra o stub e devolve a contagem acumulada em
`{"chamadas":1}`. O pedido `POST {"offline":true}` encerra a instância
Spring de teste para verificar a recuperação da interface. O navegador padrão
é Edge, com opção de canal em `FRONTEND_E2E_BROWSER`.

## Verificações manuais da interface

- Atrase a resposta inicial no DevTools e confirme “Carregando encomendas…”. Com `[]`, confirme “Nenhuma encomenda encontrada”.
- Desligue a API antes da primeira carga e confira a mensagem com “Tentar novamente”. Religue a API e confirme a recuperação.
- Atualize um envio e confira “Atualizar” e o polling de 30 segundos com a página visível. Desligue a API após carregar e confira que o aviso aparece junto à lista anterior.
- Confira os quatro badges. Use dados de teste com status desconhecido, data inválida e evento ilegível para verificar os fallbacks.
- Em 360 px, navegue por teclado e verifique foco visível, mensagens anunciadas e rolagem horizontal contida na tabela.

## Publicação

Para servir o build, encaminhe `/api` na mesma origem. Se as origens
forem separadas, configure `VITE_API_BASE_URL` no build e autorize
explicitamente a origem da interface no servidor da API.
