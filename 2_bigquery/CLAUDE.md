# Frente 2 — BigQuery

Leia antes o `CLAUDE.md` da raiz (regras de conduta e fatos verificados).

## Escopo

Carregar os Parquets tratados no BigQuery (carga nativa) e manter a carga incremental. Python/`bq`; Claude decide a implementação, Guilherme valida o resultado.

## Arquitetura decidida

- Projeto GCP com faturamento vinculado (fora do sandbox, onde tabelas expiram em 60 dias).
- Orçamento com alerta de R$ 10 (só avisa) e cota "Query usage per day" de 30 GiB (bloqueio real).
- Conjunto de dados `sp_imob`, local US (multirregional), armazenamento físico:
  ```sql
  ALTER SCHEMA sp_imob SET OPTIONS (storage_billing_model = 'PHYSICAL', max_time_travel_hours = 48);
  ```
- Tudo roda no laptop Windows; atualização disparada manualmente.
- Google Cloud SDK instalado em `C:\Program Files (x86)\Google\Cloud SDK` (está no PATH; configuração e autenticação a verificar).

## Fatos que afetam a carga (verificados em 2026-11-15)

- **IPTU:** carregar só `parquet_iptu/por_ano/` (31 arquivos, 1995–2025). A pasta `por_regiao/` está vazia.
- Tabela `iptu` particionada por inteiro (`--range_partitioning=ano,1995,2030,1`) e agrupada (clustering) por setor e quadra (derivados dos 6 primeiros dígitos de `NUMERO DO CONTRIBUINTE`).
- **Colunas vazias:** 11 colunas com sublinhado são 100% nulas em todos os anos (`VALOR_TOTAL`, `VALOR_TERRENO`, `VALOR_CONSTRUCAO`, `VALOR_M2_TERRENO`, `FRACAO_IDEAL`, `FATOR_OBSOLESCENCIA`, `DATA_CADASTRAMENTO`, `DATA_ULTIMA_ATUALIZACAO`, `ANO_AQUISICAO`, `ANO_CONSTRUCAO`, `ANO_ULTIMA_REFORMA`). Decidir com o Guilherme se entram na tabela.
- **Tipos que variam:** `DATA DO CADASTRAMENTO` (bool vazio 1995–2015, texto 2016+) e `FASE DO CONTRIBUINTE` (bool vazio 1995–2015, inteiro 2016+). Fixar o schema explicitamente na carga.
- **Nomes de coluna com espaço e barra** (`QUANTIDADE DE ESQUINAS/FRENTES`): o BigQuery não aceita; renomear para snake_case com um mapa versionado.
- **ITBI:** a coluna `ano` só existe no nome da pasta (`ano=AAAA`); acrescentar na carga, um arquivo por vez. Ignorar `ano=__HIVE_DEFAULT_PARTITION__` (resto de uma rodada antiga, 15 linhas vazias).
- `iptu_unique_id` (um registro por contribuinte, com first_seen/last_seen) deve ser recriado no BigQuery a partir da tabela `iptu`, não carregado do `.rds`.

## Passos

1. Configurar o projeto no console (faturamento, orçamento, cota, conjunto de dados).
2. Carregar um ano de IPTU como teste; medir tamanho real e custo por consulta.
3. Script de carga completa (IPTU e ITBI).
4. Script de carga incremental (só o arquivo novo).
5. Página web só depois do painel validado.
