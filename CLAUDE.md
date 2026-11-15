# Ocupação Urbana SP — contexto do projeto

Pesquisa quantitativa sobre a dinâmica imobiliária de São Paulo (1995–2026) com base no IPTU (cadastro anual), no ITBI (transações) e em bases geográficas, urbanísticas e socioeconômicas.

## Regras de conduta (valem para todas as frentes)

1. **Nada é executado sem aprovação explícita do Guilherme**, nem leitura de pastas, a não ser que ele tenha pedido aquela ação. Ele descreve o contexto; Claude propõe; executa só depois do "pode".
2. **Não chutar.** Antes de afirmar algo sobre colunas, chaves ou formatos, abrir os dados ou o código e citar o que foi visto. O que não foi verificado é marcado como "a confirmar".
3. **Toda mudança é documentada**: entrada em `docs/decisoes.md` (o que estava errado, evidência, o que mudou, efeito nos números) e comentário curto no código com data e número da decisão (`D-NNN`).
4. **Uma correção por commit.** O primeiro commit dos scripts é o original; cada correção vem depois, revisável linha a linha.
5. **Nunca sobrescrever as saídas oficiais em `DB/core_output` sem aprovação.** Scripts corrigidos gravam primeiro numa pasta de teste; a comparação com a saída atual é apresentada antes da troca.
6. **Linguagem:** R na limpeza e na econometria (Guilherme revisa linha a linha, código comentado); Python na infraestrutura (Claude implementa, Guilherme valida o resultado).

## Onde está cada coisa

| O quê | Onde |
|---|---|
| Este repositório (código e documentação) | `G:\My Drive\data\sync_onedrive\Downloads\__Skills_AI\IPTU_ITBI` |
| Dados brutos e tratados (fora do Git) | `G:\My Drive\data\sync_onedrive\RCoding\sp_market_analysis\DB` |
| Scripts originais (referência até o pipeline novo ser validado) | `G:\My Drive\data\sync_onedrive\RCoding\sp_market_analysis` |
| R 4.6.2 | `C:\Program Files\R\R-4.6.2\bin\Rscript.exe` (RStudio em `C:\Program Files\RStudio`) |

```
CLAUDE.md                 # este arquivo
docs/decisoes.md          # registro de decisões e correções (D-001, D-002, ...)
docs/inspecao_2026-11-15.md  # o que a inspeção dos dados mostrou
docs/agenda_pesquisa.md   # (pendente) agenda vinda do ChatGPT
1_pipeline_R/             # Frente 1: pipeline de limpeza em R
2_bigquery/               # Frente 2: carga e consultas no BigQuery
3_pesquisa/               # Frente 3: econometria em R
```

## Restrições do ambiente

- **Laptop Windows 11 com 7,6 GB de RAM** (cerca de 1 GB livre no uso normal). Ler o `iptu_unique_id.rds` inteiro ou empilhar os 31 anos do IPTU em memória não cabe. Ler Parquet coluna a coluna ou por partição; levar agregações pesadas para o BigQuery.
- O Smart App Control do Windows foi desligado em 2026-11-15 porque bloqueava as DLLs dos pacotes do CRAN.
- Os scripts R estão em **Latin-1 com CRLF**. Editar preservando a codificação (não converter para UTF-8 sem combinar).
- O repositório mora dentro do Google Drive para desktop (decisão do Guilherme, ciente do risco de o Drive travar ou duplicar arquivos da pasta `.git`).

## Fatos verificados nos dados (detalhes em `docs/inspecao_2026-11-15.md`)

- **Chave do IPTU:** `NUMERO DO CONTRIBUINTE` no formato `SSSQQQLLLL-D` (setor 3, quadra 3, lote 4, dígito verificador), 12 caracteres com hífen, único dentro de cada ano. `NUMERO DO CONDOMINIO` no formato `NN-D` (`00-0` = fora de condomínio).
- **IPTU:** 31 arquivos anuais (1995–2025), de 2,36 a 3,81 milhões de linhas, com as mesmas 42 colunas. Coluna `ano` (inteiro) presente em todos.
- **Não existe valor venal total no IPTU** (as colunas `VALOR_TOTAL`, `VALOR_TERRENO` e `VALOR_CONSTRUCAO` são 100% vazias, criadas pelo script). Há só valor do m² do terreno e da construção.
- **ITBI:** partições `ano=AAAA` de 1994 a 2026; cobertura real a partir de 2006 (antes, só algumas centenas de linhas por ano). 2026 vai até 07/08.

## Ressalvas de método (valem para todas as frentes)

1. O valor venal do IPTU mede a política tributária (Planta Genérica de Valores, revisões em degraus em 2001, 2009, 2013/14 e 2017/18), não o mercado. O sinal de mercado está no corte transversal e na razão ITBI/valor venal.
2. O IPTU de um lançamento novo não é preço de mercado; serve para datar a entrada do estoque.
3. O ITBI tem quebra de regime em 2022 (STJ, Tema 1113: base é o valor declarado, não o valor de referência).
4. A planta precifica a face de quadra; a quadra serve para agregar.
5. A quadra não é imutável (remembramentos, desapropriações, renumerações): é preciso uma tabela de correspondência no tempo.
6. Geocodificar por CEP é inferior ao join espacial pela chave de lote contra o mapa de lotes.
7. Valores monetários sempre em termos reais (IPCA).
8. Região por CEP é recorte operacional; para análise, usar subprefeitura e distrito por join espacial (GeoSampa).
9. O CNEFE é um retrato de 2022.
10. Atributos herdados de unidades grandes (estrato da PNAD) são contexto: cluster dos erros-padrão no nível da unidade.
11. **Proporção transmitida no ITBI:** a fatia de guias com proporção abaixo de 100% fica entre 11% e 15% de 2006 a 2019 e sobe para 42% em 2025. Antes de qualquer série de preço, verificar se uma venda aparece em várias guias.
