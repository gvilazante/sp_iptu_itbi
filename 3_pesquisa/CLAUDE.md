# Frente 3 — Pesquisa

Leia antes o `CLAUDE.md` da raiz (regras de conduta, fatos verificados e ressalvas de método).

## Produto central

Painel quadra × ano, enriquecido com uso do solo (CNEFE) e perfil socioeconômico (Censo 2022 por setor censitário e área de ponderação; PNAD Contínua por estrato geográfico).

Regra de consolidação: a quadra é a unidade mais fina; bases mais agregadas são atribuídas por contenção (centroide da quadra dentro do polígono da unidade maior). Marcar quadras cujo polígono cruza fronteiras.

## Prioridade (pela qualidade da identificação causal)

1. Descritivo: estoque, renovação, verticalização, razão ITBI/valor venal.
2. Plano Diretor de 2014, Eixos de Estruturação: comparação de quadras dos dois lados da fronteira.
3. Metrô: diferenças-em-diferenças com as datas de inauguração.
4. Subdeclaração no ITBI.
5. Por último: crédito, custo de construção, distratos (choques macro, identificação fraca).

## Antes de usar os dados (verificado em 2026-11-15)

- **Valor venal:** o IPTU não traz valor venal total; calcular a partir de área × valor do m² (terreno e construção, com fração ideal e fator de obsolescência). A fórmula exata precisa ser confirmada com a regra da Prefeitura.
- **Preço/m² do ITBI:** usar `preco_m2`. A coluna `preco_m2_declarado` tem um bug (infinito em todas as vendas com proporção transmitida abaixo de 100%) até a correção ser aplicada.
- **ITBI antes de 2006** tem só algumas centenas de linhas por ano: não serve para série.
- **Proporção transmitida abaixo de 100%** fica entre 11% e 15% das guias de 2006 a 2019 e sobe para 42% em 2025: investigar antes de séries de preço e volume.

## Ferramentas

R: `fixest` (econometria), `sf` (espacial). Ler dados do BigQuery via `bigrquery` quando a Frente 2 estiver pronta; até lá, ler Parquet por coluna ou partição (laptop de 8 GB).

O `0004_analise_vendas_por_cep_ou_raio_2026.R` (em `1_pipeline_R/`) já é análise e pode migrar para cá.
