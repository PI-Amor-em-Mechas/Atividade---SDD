# Feature Specification: Visualização de Encomendas e Status

**Feature Branch**: `001-visualizacao-encomendas`

**Created**: 2026-11-12

**Status**: Draft

**Input**: User description: "Planeje a implementação de uma tela responsável pela visualização das encomendas e seus respectivos status. Cada encomenda deverá apresentar código de rastreio, nome do destinatário, status e data da última atualização. A interface deverá distinguir AGUARDANDO, EM_TRANSITO, ENTREGUE e ERRO. Implementar loading, lista carregada, lista vazia e erro de carregamento. Critérios de aceite: encomendas carregadas pela API, loading apresentado corretamente, estado vazio tratado, status apresentado visualmente, dados exibidos corretamente, erro de carregamento tratado e atualizações dos dados refletidas na interface."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Consultar encomendas e seus status (Priority: P1)

Um operador acessa a tela principal da aplicação para consultar todas as encomendas cadastradas e identificar rapidamente a situação de cada uma.

**Why this priority**: É o núcleo da feature. Sem a listagem correta das encomendas e seus status, a tela não entrega valor algum.

**Independent Test**: Com a fonte de dados disponível e contendo registros nos quatro status, acessar a tela principal e verificar que cada encomenda apresenta código de rastreio, nome do destinatário, status e data da última atualização.

**Acceptance Scenarios**:

1. **Given** que existem encomendas cadastradas, **When** o usuário acessa a tela principal, **Then** a lista exibe todas as encomendas com código de rastreio, nome do destinatário, status e data da última atualização.
2. **Given** uma encomenda com status AGUARDANDO, EM_TRANSITO, ENTREGUE ou ERRO, **When** ela é exibida na lista, **Then** o status é identificável por texto e por um indicador visual próprio, distinguindo-o dos demais status.
3. **Given** encomendas com datas de atualização diferentes, **When** a lista é exibida, **Then** cada data é apresentada de forma legível, no formato local em português do Brasil.
4. **Given** uma encomenda com dados parciais, **When** ela é exibida, **Then** o campo ausente é apresentado com um marcador explícito (por exemplo, "—"), sem quebrar a tela.

---

### User Story 2 - Acompanhar atualizações de status (Priority: P2)

Um operador mantém a tela aberta e precisa ver mudanças de status sem recarregar a página manualmente, além de poder solicitar uma atualização imediata quando desejar.

**Why this priority**: Status de encomendas mudam com frequência; dados desatualizados levam a decisões operacionais erradas.

**Independent Test**: Com a tela carregada, alterar o status de uma encomenda na fonte de dados e verificar que a interface reflete a mudança automaticamente em até 30 segundos ou imediatamente após acionar o controle de atualização.

**Acceptance Scenarios**:

1. **Given** a tela carregada com encomendas, **When** os dados são alterados na fonte, **Then** a lista reflete a alteração em até 30 segundos, sem ação do usuário.
2. **Given** a tela carregada com encomendas, **When** o usuário aciona o controle de atualização, **Then** os dados são consultados novamente e a lista reflete as alterações.
3. **Given** uma atualização em andamento, **When** os dados ainda não retornaram, **Then** a lista atual permanece visível e utilizável, com indicação discreta de atualização.

---

### User Story 3 - Entender estados de carregamento, vazio e erro (Priority: P3)

Um operador precisa saber o que está acontecendo quando a tela está carregando, quando não há encomendas e quando os dados não puderam ser obtidos, incluindo uma forma de tentar novamente.

**Why this priority**: Evita telas em branco, dúvidas sobre ausência de dados e frustração em falhas temporárias.

**Independent Test**: Simular cada condição (resposta lenta, lista vazia, falha de conexão e falha após carga bem-sucedida) e verificar que a interface apresenta o estado correspondente com mensagem clara.

**Acceptance Scenarios**:

1. **Given** que a tela acabou de ser aberta, **When** os dados ainda estão sendo obtidos, **Then** um indicador de carregamento é apresentado.
2. **Given** que a consulta foi concluída sem encomendas, **When** a tela é exibida, **Then** uma mensagem informa que nenhuma encomenda foi encontrada.
3. **Given** que a consulta inicial falhou, **When** a tela é exibida, **Then** uma mensagem de erro amigável é apresentada com uma ação para tentar novamente.
4. **Given** que a consulta inicial falhou, **When** o usuário aciona "tentar novamente" após a fonte se recuperar, **Then** a lista é carregada normalmente.
5. **Given** que a lista já estava carregada, **When** uma atualização automática ou manual falha, **Then** os dados anteriores permanecem visíveis e um aviso não bloqueante informa a falha de atualização.

---

### Edge Cases

- A fonte de dados demora mais que o esperado: o usuário deve ver o estado de carregamento e, em caso de tempo esgotado, uma mensagem de erro com opção de nova tentativa.
- A fonte retorna uma lista vazia: a tela deve exibir o estado vazio, sem tabela e sem erro.
- A fonte fica indisponível após uma carga bem-sucedida: a lista anterior deve ser preservada e o usuário deve ser avisado de que os dados podem estar desatualizados.
- O status retornado não pertence aos quatro valores conhecidos: a encomenda deve ser exibida com um status neutro identificado como desconhecido, sem quebrar a tela.
- A data de última atualização é inválida ou ausente: exibir um marcador explícito em vez de uma data incorreta.
- O código de rastreio ou o nome do destinatário está ausente: exibir um marcador explícito e manter a linha visível.
- Duas atualizações retornam fora de ordem: a interface deve manter o resultado mais recente solicitado.
- A lista contém muitos registros: a visualização deve continuar utilizável por meio de rolagem, sem quebrar o layout.
- A tela é fechada ou o usuário navega para fora: atualizações automáticas devem cessar.
- O usuário utiliza apenas teclado ou leitor de tela: os estados e os status devem ser compreensíveis sem depender exclusivamente de cor.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST obter as encomendas da fonte oficial de dados da aplicação, sem usar dados fixos na interface.
- **FR-002**: A tela MUST apresentar, para cada encomenda, código de rastreio, nome do destinatário, status e data da última atualização.
- **FR-003**: A tela MUST restringir a apresentação de status aos valores AGUARDANDO, EM_TRANSITO, ENTREGUE e ERRO.
- **FR-004**: Cada status MUST ser distinguível dos demais por texto e por um indicador visual próprio, não apenas por cor.
- **FR-005**: A tela MUST apresentar um estado de carregamento durante a consulta inicial dos dados.
- **FR-006**: A tela MUST apresentar um estado vazio, com mensagem clara, quando a consulta for concluída sem encomendas.
- **FR-007**: A tela MUST apresentar um estado de erro, com mensagem amigável e ação de nova tentativa, quando a consulta inicial falhar.
- **FR-008**: O usuário MUST poder solicitar uma atualização manual dos dados a qualquer momento após a carga inicial.
- **FR-009**: A tela MUST atualizar os dados automaticamente em intervalos de até 30 segundos enquanto estiver aberta.
- **FR-010**: Durante uma atualização manual ou automática, a lista já carregada MUST permanecer visível e utilizável.
- **FR-011**: Quando uma atualização falhar e já existirem dados carregados, o sistema MUST preservar os dados anteriores e exibir um aviso não bloqueante sobre a falha.
- **FR-012**: O sistema MUST apresentar datas no formato local em português do Brasil; datas ausentes ou inválidas MUST ser substituídas por um marcador explícito.
- **FR-013**: Valores de status desconhecidos MUST ser apresentados como desconhecidos, sem interromper a renderização da lista.
- **FR-014**: Campos obrigatórios ausentes MUST ser apresentados com um marcador explícito, mantendo a linha correspondente visível.
- **FR-015**: A tela MUST ignorar respostas de atualizações antigas que cheguem depois de uma atualização mais recente.
- **FR-016**: A tela MUST cessar as atualizações automáticas quando não estiver mais em uso.
- **FR-017**: Os estados de carregamento e erro MUST ser anunciados a tecnologias assistivas, e todos os controles MUST ser operáveis por teclado.
- **FR-018**: A tela MUST ser utilizável em telas de desktop e móveis, mantendo a listagem legível e sem rolagem horizontal da página inteira.
- **FR-019**: A tela MUST ser somente leitura, não permitindo alterar encomendas ou status nesta entrega.

### Key Entities

- **Encomenda**: Item rastreado pelo sistema. Atributos principais: código de rastreio (identificador único), nome do destinatário, status atual e data/hora da última atualização.
- **Status da Encomenda**: Situação atual da encomenda, limitada a AGUARDANDO, EM_TRANSITO, ENTREGUE e ERRO.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% das encomendas retornadas pela fonte são exibidas com os quatro campos obrigatórios (código de rastreio, destinatário, status e data da última atualização).
- **SC-002**: Alterações realizadas na fonte de dados são refletidas na interface em até 30 segundos, ou imediatamente após uma atualização manual.
- **SC-003**: Em 100% dos acessos com consulta superior a 1 segundo, o usuário visualiza um indicador de carregamento antes da conclusão.
- **SC-004**: Em 100% dos cenários de lista vazia, falha de carga e falha de atualização, a interface apresenta uma mensagem explícita, nunca uma tela em branco ou sem feedback.
- **SC-005**: Em teste de usabilidade com pelo menos 5 participantes, pelo menos 90% identificam corretamente o status de uma encomenda em até 5 segundos, sem depender apenas de cor.
- **SC-006**: Após a recuperação da fonte de dados, 100% das tentativas de "tentar novamente" resultam na lista carregada.
- **SC-007**: A tela permanece funcional e sem falhas visíveis quando recebe status desconhecido, data inválida ou campo obrigatório ausente.
- **SC-008**: A tela é utilizável em larguras de 360 px a 1280 px, sem rolagem horizontal da página inteira.
- **SC-009**: O usuário consegue localizar uma encomenda pelo código de rastreio e ler seu status sem instruções adicionais.

## Out of Scope

- Cadastro, edição ou exclusão de encomendas.
- Tela de detalhes ou histórico completo de movimentações.
- Busca, filtros, ordenação personalizada, paginação ou exportação.
- Notificações externas (e-mail, push, SMS).
- Controle de acesso e autenticação, que são tratados pela aplicação existente.
- Funcionamento offline.

## Assumptions

- A fonte oficial de dados retorna uma coleção de encomendas com os quatro campos definidos e status nos valores canônicos AGUARDANDO, EM_TRANSITO, ENTREGUE e ERRO.
- As datas são fornecidas em formato padronizado com informação de fuso horário e são apresentadas no fuso local do usuário.
- A tela é a página principal da aplicação nesta entrega, sem necessidade de navegação adicional.
- A atualização automática ocorre a cada 30 segundos enquanto a tela estiver aberta; o intervalo pode ser ajustado sem alterar o comportamento esperado.
- A ordem de exibição segue a ordem fornecida pela fonte de dados.
- Os códigos de rastreio são únicos por encomenda.
- A autenticação e a autorização de acesso à aplicação já são tratadas fora do escopo desta feature.
- A fonte de dados pode ficar temporariamente indisponível; a tela deve tratar essa condição de forma amigável.
- A identidade visual e os recursos de estilização existentes na aplicação devem ser reutilizados.
- A entrega é somente para navegadores web modernos de desktop e dispositivos móveis.
