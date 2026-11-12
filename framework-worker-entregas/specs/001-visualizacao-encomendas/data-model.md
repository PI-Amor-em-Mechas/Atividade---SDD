# Data Model: Visualização de Encomendas e Status

## Entidade: Encomenda

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `codigoRastreio` | string | sim | Identificador exibido na primeira coluna; usado na identidade da linha; vazio → "—" |
| `nomeDestinatario` | string | sim | Exibido na segunda coluna; vazio → "—" |
| `status` | enum | sim | `AGUARDANDO`, `EM_TRANSITO`, `ENTREGUE`, `ERRO`; desconhecido → badge neutro "Desconhecido" |
| `dataUltimaAtualizacao` | string ISO 8601 | sim | Convertida para data/hora local em pt-BR; inválida/ausente → "—" |

### Forma normalizada usada pela interface

```text
{
  id: string,
  codigoRastreio: string,
  nomeDestinatario: string,
  status: string,
  dataUltimaAtualizacao: string | null
}
```

### Regras de normalização

1. A resposta da fonte MUST ser um array; caso contrário, tratar como erro de contrato.
2. Itens que não sejam objetos são descartados.
3. Strings recebem `trim`.
4. O status é convertido para maiúsculas.
5. O `id` é derivado do código de rastreio, com fallback por índice para garantir chave única.
6. Nenhuma encomenda é mutada; a tela é somente leitura.

## Enum: Status

| Valor | Rótulo | Variante visual |
|---|---|---|
| `AGUARDANDO` | Aguardando | âmbar/neutro |
| `EM_TRANSITO` | Em trânsito | azul |
| `ENTREGUE` | Entregue | verde |
| `ERRO` | Erro | vermelho |
| desconhecido | Desconhecido | neutro/cinza |

## Máquina de estados da interface

| Estado | Condição | Comportamento |
|---|---|---|
| `loading` | primeira carga em andamento | Indicador de carregamento com anúncio acessível |
| `error` | primeira carga falhou e nada foi carregado | Mensagem + botão "Tentar novamente" |
| `empty` | carga concluída sem registros | Mensagem de lista vazia + ação de atualizar |
| `list` | há registros carregados | Tabela de encomendas |
| `refreshing` | já carregou e nova busca está em andamento | Lista permanece visível; botão desabilitado e indicador discreto |
| `stale-error` | atualização falhou após carga bem-sucedida | Lista preservada + aviso não bloqueante |

## Transições

```text
loading → list      (sucesso com registros)
loading → empty     (sucesso sem registros)
loading → error     (falha inicial)
error   → loading   (nova tentativa)
empty   → list      (atualização traz registros)
list    → list      (atualização bem-sucedida)
list    → stale-error (falha em atualização)
stale-error → list  (atualização seguinte bem-sucedida)
```
