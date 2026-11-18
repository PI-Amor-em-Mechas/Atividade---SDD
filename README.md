# Painel de Rastreamento de Envios

## Projeto e integrantes

Aplicação para cadastro e acompanhamento automático de encomendas, permitindo visualizar o status atual de cada envio.

### Integrantes

- Artur Alves Munhoz Assis
- Daniela Gomes de Carvalho
- Felipe de Carvalho Ferraz
- Gabriel Gonçalves Pereira
- Giovanna Prado Andrade
- Leonardo Monteiro

## Framework utilizado

O projeto utiliza o SpecKit como framework de Specification-Driven Development (SDD).

O SpecKit foi escolhido por permitir estruturar o desenvolvimento a partir da especificação, passando pelo planejamento, definição das tarefas e implementação.

## Tecnologias

- React
- Vite
- Spring Boot
- MySQL/MariaDB
- Python
- JSON Server
- SpecKit

## Como rodar

### Frontend

```bash
cd framework-worker-entregas
npm install
npm run dev
```

Inicie o Spring em `localhost:8080` e deixe `VITE_API_BASE_URL` vazia para
usar os caminhos relativos `/api/envios`. O Vite encaminha `/api` para o Spring
em desenvolvimento. Defina `API_PROXY_TARGET` se o Spring usar outro endereço.

Para publicar o build na mesma origem, encaminhe `/api` ao Spring no servidor
que hospeda a interface. Se as origens forem separadas, defina
`VITE_API_BASE_URL` com a origem pública da API antes de `npm run build` e
autorize a origem da interface na configuração CORS do servidor.

As datas logísticas são exibidas em `America/Sao_Paulo`. A tabela usa
`dataAtualizacao` e recorre a `atualizadoEm` quando o primeiro campo está
ausente. O histórico é atualizado com a listagem, inclusive quando o diálogo
está aberto.
