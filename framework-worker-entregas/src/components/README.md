Componentes reutilizáveis da interface.

## EnvioForm

Formulário de cadastro com código de rastreio e nome do destinatário obrigatórios.
Rejeita campos vazios ou compostos apenas por espaços e remove espaços nas
extremidades antes de chamar `cadastrarEnvio` (`POST /api/envios`).

- Bloqueia novas submissões enquanto o cadastro está em andamento.
- Exibe sucesso, duplicidade (HTTP 409) ou erro inesperado.
- Preserva os campos em caso de erro e limpa os campos após sucesso.
- Chama `onCadastrado()` somente após sucesso; a página usa esse evento para
  atualizar a listagem pelo mecanismo já existente.

A unicidade do código deve ser garantida pelo backend, não pela lista local.
Veja o [contrato da API](../../specs/001-visualizacao-encomendas/contracts/envios-api.md).
