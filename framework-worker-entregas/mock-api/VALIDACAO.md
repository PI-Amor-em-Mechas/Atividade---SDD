# Mock de leitura da interface

Em `mock-api/`, execute `npm install` e `npm start`. Em outro terminal,
inicie o Vite com `API_PROXY_TARGET=http://localhost:3001` e
`VITE_API_BASE_URL` vazia.

`GET /api/envios` retorna um array com os nomes e tipos do Spring. As
fixtures usam `AGUARDANDO`, `EM_TRANSITO` e `ENTREGUE`, datas com e sem
offset e eventos simples e estruturados.

O JSON Server serve apenas para exercícios isolados de leitura da UI. Para
cadastro, validação, duplicidade ou processamento do Worker, use a API Spring
com MySQL e o stub HTTP do módulo Python. O JSON Server grava POSTs sem os
defaults e as restrições do Spring.
