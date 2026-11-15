# Registro de decisões e correções

Cada entrada tem um número (`D-NNN`), citado no comentário do código alterado. Formato: contexto, evidência, decisão, efeito nos números, commit.

---

## D-001 — Chaves de API fora do código (2026-11-15)

- **Contexto:** `library_sp_market.R` tinha duas chaves escritas no código (linhas 18–19): Google (geocodificação, Places) e Mapbox.
- **Evidência:** leitura do arquivo original em `sp_market_analysis/library_sp_market.R`.
- **Decisão:** as chaves foram movidas para `1_pipeline_R/.Renviron`, que o `.gitignore` exclui. A `library` passa a ler o arquivo com `readRenviron(".Renviron")` logo depois do `setwd()`. `.Renviron.example` documenta as variáveis (`GOOGLE_API_KEY`, `GOOGLEGEOCODE_API_KEY`, `MAPBOX_API_KEY`).
- **Diferença em relação ao original:** só as linhas 18–19 da `library_sp_market.R` (substituídas por três linhas). Todo o resto é idêntico byte a byte ao arquivo do Drive.
- **Efeito nos números:** nenhum.
- **Chaves atuais mantidas** (decisão do Guilherme em 2026-11-15: não gerar chaves novas).
- **Commit:** o mesmo que introduz os scripts no repositório (as chaves nunca entraram no histórico do Git).

---

## Pendências (problemas encontrados, ainda não corrigidos)

Ordem proposta: primeiro o que muda números, depois robustez, depois limpeza. Cada item vira uma entrada `D-NNN` quando for corrigido.

### Mudam números

| # | Script / linha | Problema | Evidência |
|---|---|---|---|
| P-01 | 0003, l. 666 | `preco_m2_declarado`: o pipe se liga antes da divisão; o arredondamento cai sobre `proporcao/100`, que vira 0 quando a proporção é menor que 100%, e o preço sai infinito | Verificado nos dados: em 2025, 88.125 infinitos para 88.386 guias com proporção < 100%. `preco_m2` (l. 316) não tem infinitos |
| P-02 | 0003, l. 668 | `preco_m2_valor_venal`: mesmo erro de precedência; arredonda a área, não o preço | Leitura do código |
| P-03 | 0003, l. 669 | Usa `db_itbi$valor_venal`, coluna que não existe; a limpeza de infinitos não acontece | Leitura do código (a confirmar em execução) |
| P-04 | 0003, l. 371–392 | `date_release` sai vazio em 100% das linhas (a conversão do nome da aba para data falha) | Verificado em todas as partições do ITBI |
| P-05 | 0002, l. 95 e 126–137 | A conversão de datas é aplicada a `DATA_CADASTRAMENTO` (coluna vazia criada pelo script); a coluna real, `DATA DO CADASTRAMENTO`, fica como texto (`"01/01/25"`) | Verificado no IPTU 2025 |
| P-06 | 0002, l. 84–95 e 120 | 11 colunas com sublinhado são criadas vazias em todos os anos (`VALOR_TOTAL`, `VALOR_TERRENO`, `VALOR_CONSTRUCAO`, `VALOR_M2_TERRENO`, `FRACAO_IDEAL`, `FATOR_OBSOLESCENCIA`, `DATA_CADASTRAMENTO`, `DATA_ULTIMA_ATUALIZACAO`, `ANO_*`), e as conversões numéricas são aplicadas a elas em vez das colunas reais | Verificado: 100% nulas de 1995 a 2025 |

### Robustez

| # | Script / linha | Problema |
|---|---|---|
| P-07 | todos | Caminho dos dados derivado da pasta do script (`this.dir()` + `/DB`); dentro do repositório o caminho não existe. Proposta: variável `SP_DATA_DIR` no `.Renviron` |
| P-08 | 0003, l. 422 | `readRDS(...)` sem atribuição: o script só funciona se o `iptu_unique_id` já estiver na memória |
| P-09 | 0003, l. 599 e 680 | `view()` no meio do script interrompe execução automática |
| P-10 | 0003, l. 97–156 | Download do ITBI roda duas vezes, com nomes de arquivo diferentes; `DB/itbi` tem cada ano em dobro |
| P-11 | 0003, l. 701 | `write_dataset` não apaga partições antigas: sobrou `ano=__HIVE_DEFAULT_PARTITION__` (15 linhas vazias, abril de 2026, schema antigo), que quebra a leitura conjunta da pasta |
| P-12 | 0002, l. 62–67 | Apaga `parquet_iptu/` inteira e não recria `por_regiao/` (trecho comentado); a pasta está vazia |
| P-13 | 0002, l. 170–212 | Empilha todos os anos em memória (`dt_snapshot`); não cabe num laptop de 8 GB |
| P-14 | 0003, l. 507 | `geo_id` fica vazio quando `NUMERO DO CONDOMINIO` é NA (a confirmar quantos casos) |

### Limpeza (0001 e library)

| # | Problema |
|---|---|
| P-15 | 0001, l. 97–101: `x[is.null(x)] <- ""` não faz nada (`is.null` avalia o vetor inteiro); hoje sem dano |
| P-16 | 0001, l. 64: `ibge_agregado_por_cep` é lido e nunca usado; o cabeçalho promete um `cep_databank_sp` que não é gerado |
| P-17 | 0001, l. 124 e 135: `ibge_cidade_sp_unique_addresses` é criado como objeto espacial e logo sobrescrito por uma deduplicação sem geometria |
| P-18 | 0001: comentário diz "máximo", código usa média de lat/lon; moda de `NUM_ENDERECO` por rua não tem significado |
| P-19 | todos: `dir_itbi` usa `/db/itbi` (minúsculas) e o resto `/DB`; `TZ = "Brazil/East"` é nome de fuso obsoleto (`America/Sao_Paulo`) |
| P-20 | library: lista de ~70 pacotes instalados e carregados sempre, inclusive alguns fora do CRAN (`splashr`, `google_places`, `ggplotgui`); muitas funções são de outros projetos (Airbnb, Zap) |

### Questões de método abertas (não são bugs)

- **Q-01:** a fatia de guias de ITBI com proporção transmitida abaixo de 100% fica entre 11% e 15% de 2006 a 2019 e sobe para 18% (2020), 23% (2021), 34% (2022) e 42% (2025). Verificar se uma mesma venda aparece em várias guias antes de séries de preço e volume.
- **Q-02:** o IPTU não tem valor venal total. Definir a fórmula de cálculo a partir das áreas e dos valores do m².
- **Q-03:** o número de imóveis cai de 2020 (3.498.644) para 2021 (3.489.273), único ano de queda na série.
