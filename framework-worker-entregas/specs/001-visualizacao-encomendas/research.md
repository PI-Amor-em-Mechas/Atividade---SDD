# Research: Visualização de Encomendas e Status

## Decisão 1: Camada de dados

**Decisão**: Criar o hook `useEnvios` com `useState`, `useEffect`, `useCallback` e `useRef`.

**Rationale**: A aplicação não possui biblioteca de dados. Para uma única listagem com polling, um hook próprio é suficiente, sem adicionar dependências nem configuração.

**Alternativas consideradas**: React Query/SWR (adicionariam dependência e complexidade desnecessária para o escopo atual).

## Decisão 2: Atualização dos dados

**Decisão**: Carga inicial, polling a cada 30 segundos e botão "Atualizar".

**Rationale**: Atende ao critério de atualizações refletidas na interface sem exigir suporte do backend a eventos. O botão cobre atualizações imediatas.

**Alternativas consideradas**: WebSocket/SSE (backend não expõe), polling de 5s (tráfego desnecessário).

## Decisão 3: Concorrência e ciclo de vida

**Decisão**: Identificador incremental por requisição (`useRef`), ignorando respostas antigas; polling ignora execuções simultâneas; atualização manual tem prioridade.

**Rationale**: Evita que uma resposta lenta sobrescreva dados mais recentes e evita updates após desmontagem. Também lida com o duplo efeito do React StrictMode em desenvolvimento.

**Alternativas consideradas**: Aceitar a última resposta recebida (gera dados inconsistentes).

## Decisão 4: Tratamento de erro

**Decisão**: Reutilizar `EnviosApiError` e exibir:
- erro inicial em painel de tela inteira com "Tentar novamente";
- erro durante atualização como aviso não bloqueante, preservando a lista.

**Rationale**: O cliente HTTP já traduz erros de rede, timeout, 4xx e 5xx para mensagens em português. Preservar dados anteriores evita perda de contexto durante falhas temporárias.

**Alternativas consideradas**: Substituir a lista por erro em qualquer falha (pior experiência).

## Decisão 5: Normalização

**Decisão**: Validar que a resposta é um array; normalizar strings com `trim`; status em maiúsculas; aceitar status desconhecido com apresentação neutra; campos ausentes exibidos como "—".

**Rationale**: Evita quebra da tela diante de dados parciais ou fora do contrato, mantendo a listagem utilizável.

## Decisão 6: Formatação de data

**Decisão**: `Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short' })`; datas inválidas/ausentes exibem "—".

**Rationale**: Formatação nativa, sem dependências, no fuso local do usuário.

## Decisão 7: Estilização

**Decisão**: CSS Modules por componente, reutilizando as variáveis CSS globais de `src/index.css` e suportando tema escuro.

**Rationale**: Escopo local, sem colisões, compatível com Vite e com a identidade visual existente.

**Alternativas consideradas**: Tailwind (não instalado), estilos inline (dificultam responsividade e estados de foco).

## Decisão 8: Acessibilidade

**Decisão**: Status com texto + indicador visual; `role="status"`/`aria-live` no loading; `role="alert"` no erro; tabela semântica; controles operáveis por teclado; `prefers-reduced-motion` respeitado.

**Rationale**: A distinção de status não pode depender apenas de cor, e estados assíncronos precisam ser anunciados.
