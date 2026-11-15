# Frente 1 — Pipeline em R

Leia antes o `CLAUDE.md` da raiz (regras de conduta e fatos verificados).

## Escopo

Auditar e corrigir os scripts que transformam os dados brutos nos Parquets tratados; documentar cada transformação; automatizar a atualização (download, validação do formato, limpeza, nova partição, reconciliação, log).

**Teste de aceitação:** reprocessar um ano já processado e bater linha a linha com o resultado atual (a menos das correções documentadas em `docs/decisoes.md`).

## Ordem de execução e linhagem

| Script | Entrada bruta | Saída |
|---|---|---|
| `library_sp_market.R` | — | Funções; carregada pelos demais. Lê `titulos_ajustes_logradouros.xlsx` (aba `OUTPUT_R`) e o `.Renviron` |
| `0001_extract_ibge_addresses_2025.R` | `DB/ibge/3550308_SAO_PAULO.zip` (CNEFE 2022) | `ibge_cidade_sp_all_addresses.rds`, `..._unique_addresses.rds`, `..._unique_streets.rds` |
| `0002_extract_iptu_2026.R` | `DB/mapas_sp/geosampa_jul_2024/iptu/iptu_AAAA.zip` | `parquet_iptu/por_ano/iptu_AAAA.parquet`; `iptu_unique_id.rds` (first_seen, last_seen, registro mais recente, coordenadas por CEP e por quadra); `lograd_cep.rds` |
| `0003_extract_itbi_improve_iptu_2026.R` | Planilhas "Guias de ITBI pagas" (baixadas do site da Prefeitura para `DB/itbi`) | `db_itbi.rds`, `parquet_itbi/ano=AAAA/`; regrava `iptu_unique_id.rds` com `geo_id`, `tipo_construcao`, `padrao_construcao`, `tipo_uso` |
| `0004_analise_vendas_por_cep_ou_raio_2026.R` | Os `.rds` acima | Recorte para o Shiny (`shiny_itbi/`) e análise por raio. Já é pesquisa, não pipeline |

`geo_id` (criado no 0003): `setor+quadra+"F"+lote` para lote comum; `setor+quadra+"C"+nº do condomínio` para unidades em condomínio.

## Atenção ao rodar

- **Caminhos:** os scripts usam `this.path::this.dir()` + `/DB`. Dentro do repositório, `DB/` não existe; o ajuste do caminho dos dados é a primeira correção prevista (ver `docs/decisoes.md`). Até lá, os scripts só rodam a partir da pasta original no Drive.
- **Chaves de API:** ficam em `1_pipeline_R/.Renviron` (fora do Git). Modelo em `.Renviron.example`.
- **Memória:** o 0002 empilha todos os anos em `dt_snapshot`; provavelmente não roda num laptop de 8 GB.
- **Codificação:** os scripts são Latin-1 com CRLF; o `source()` usa `encoding = "Latin1"`.

## Problemas conhecidos (a corrigir, um por commit)

Lista completa e status em `docs/decisoes.md`, seção "Pendências".

## Pasta `inspecao/`

Scripts somente leitura usados em 2026-11-15 para verificar a estrutura dos dados. Não gravam nada. Resultado resumido em `docs/inspecao_2026-11-15.md`.
