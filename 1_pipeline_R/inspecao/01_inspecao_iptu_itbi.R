# =============================================================================
# inspecao_parquets.R — SOMENTE LEITURA
# Objetivo: verificar a estrutura real dos dados tratados (IPTU, ITBI e
# iptu_unique_id) antes de qualquer decisão. Não grava nada no Drive.
# Saída: apenas texto no console.
# =============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(data.table)
})

raiz <- "G:/My Drive/data/sync_onedrive/RCoding/sp_market_analysis/DB/core_output"
dir_ano <- file.path(raiz, "parquet_iptu/por_ano")
dir_reg <- file.path(raiz, "parquet_iptu/por_regiao")
dir_itbi <- file.path(raiz, "parquet_itbi")

titulo <- function(x) cat("\n\n==================== ", x, " ====================\n", sep = "")

# -----------------------------------------------------------------------------
# 1. IPTU por_ano — schema de cada ano (lê só o rodapé do arquivo, é barato)
# -----------------------------------------------------------------------------
titulo("1. IPTU: colunas por ano")
arqs <- sort(list.files(dir_ano, pattern = "\\.parquet$", full.names = TRUE))
schemas <- lapply(arqs, function(f) {
  pf <- ParquetFileReader$create(f)
  s <- pf$GetSchema()
  data.table(ano = sub("\\D*(\\d{4}).*", "\\1", basename(f)),
             coluna = names(s),
             tipo = sapply(s$fields, function(x) x$type$ToString()),
             n_linhas = pf$num_rows)
})
sch <- rbindlist(schemas)
cat("Linhas por ano:\n"); print(unique(sch[, .(ano, n_linhas)]), nrows = 100)
cat("\nTotal de colunas distintas:", uniqueN(sch$coluna), "\n")
pres <- dcast(sch, coluna ~ ano, value.var = "tipo", fun.aggregate = function(x) x[1], fill = "-")
cat("\nPresença e tipo de cada coluna por ano ('-' = ausente):\n")
print(pres, nrows = 500, width = 250)
cat("\nColunas com tipo diferente entre anos:\n")
print(sch[, .(tipos = paste(unique(tipo), collapse = " | ")), by = coluna][grepl("\\|", tipos)])

# -----------------------------------------------------------------------------
# 2. IPTU — colunas "gêmeas" (com espaço vs. com sublinhado): quantos não nulos
# -----------------------------------------------------------------------------
titulo("2. IPTU: preenchimento das colunas gêmeas por ano")
gemeas <- c("FATOR DE OBSOLESCENCIA", "FATOR_OBSOLESCENCIA",
            "FRACAO IDEAL", "FRACAO_IDEAL",
            "DATA DO CADASTRAMENTO", "DATA_CADASTRAMENTO",
            "VALOR DO M2 DO TERRENO", "VALOR_M2_TERRENO",
            "QUANTIDADE DE ESQUINAS/FRENTES", "QUANTIDADE DE ESQUINAS FRENTES",
            "VALOR_TERRENO", "VALOR_CONSTRUCAO", "VALOR_TOTAL",
            "DATA_ULTIMA_ATUALIZACAO", "ANO_CONSTRUCAO", "ANO_ULTIMA_REFORMA", "ANO_AQUISICAO")
res_gem <- rbindlist(lapply(arqs, function(f) {
  cols <- intersect(gemeas, names(ParquetFileReader$create(f)$GetSchema()))
  dt <- as.data.table(read_parquet(f, col_select = cols))
  data.table(ano = sub("\\D*(\\d{4}).*", "\\1", basename(f)),
             coluna = cols,
             nao_nulos = sapply(cols, function(c) sum(!is.na(dt[[c]]) & as.character(dt[[c]]) != "")))
}))
print(dcast(res_gem, coluna ~ ano, value.var = "nao_nulos", fill = NA), width = 250)

# -----------------------------------------------------------------------------
# 3. IPTU 2025 (e 1995) — conteúdo: chave, nulos, exemplos
# -----------------------------------------------------------------------------
for (a in c("1995", "2025")) {
  titulo(paste0("3. IPTU ", a, ": conteúdo"))
  dt <- as.data.table(read_parquet(file.path(dir_ano, paste0("iptu_", a, ".parquet"))))
  k <- as.character(dt[["NUMERO DO CONTRIBUINTE"]])
  cat("Linhas:", nrow(dt), "| contribuintes distintos:", uniqueN(k), "\n")
  cat("Comprimento do NUMERO DO CONTRIBUINTE:\n"); print(table(nchar(k), useNA = "ifany"))
  cat("Caracteres não numéricos presentes:", paste(unique(unlist(strsplit(gsub("[0-9]", "", k), ""))), collapse = " "), "\n")
  cat("Exemplos de chave:\n"); print(head(k, 8))
  if ("NUMERO DO CONDOMINIO" %in% names(dt)) {
    cat("Exemplos de NUMERO DO CONDOMINIO:\n"); print(head(unique(dt[["NUMERO DO CONDOMINIO"]]), 8))
  }
  cat("Valores de 'ano':\n"); print(table(dt$ano, useNA = "ifany"))
  cat("\nPercentual de nulos/vazios por coluna:\n")
  na_pct <- sapply(dt, function(x) round(100 * mean(is.na(x) | as.character(x) == ""), 2))
  print(sort(na_pct, decreasing = TRUE))
  cat("\nUma linha de exemplo (transposta):\n")
  print(t(dt[sample(.N, 1)]))
  rm(dt); gc(verbose = FALSE)
}

# -----------------------------------------------------------------------------
# 4. IPTU por_regiao — o que existe lá
# -----------------------------------------------------------------------------
titulo("4. IPTU por_regiao")
fr <- list.files(dir_reg, recursive = TRUE, full.names = TRUE)
print(data.table(arquivo = sub(dir_reg, "", fr), MB = round(file.size(fr) / 1e6, 1),
                 modificado = file.mtime(fr)))

# -----------------------------------------------------------------------------
# 5. ITBI — schema, linhas por partição, datas e chave
# -----------------------------------------------------------------------------
titulo("5. ITBI")
ds <- open_dataset(dir_itbi)
print(ds$schema)
itbi <- as.data.table(ds)
cat("\nLinhas totais:", nrow(itbi), "\n")
cat("Linhas por ano (partição):\n"); print(itbi[, .N, by = ano][order(ano)], nrows = 100)
cat("\nData de transação nula:", sum(is.na(itbi$data_de_transacao)), "\n")
cat("Faixa de datas:", format(range(itbi$data_de_transacao, na.rm = TRUE)), "\n")
cat("Faixa de date_release:", format(range(itbi$date_release, na.rm = TRUE)), "\n")
cat("Comprimento de n_do_cadastro_sql:\n"); print(table(nchar(itbi$n_do_cadastro_sql), useNA = "ifany"))
cat("ITBI com geo_id preenchido (casou com IPTU): ",
    round(100 * mean(!is.na(itbi$geo_id) & itbi$geo_id != ""), 2), "%\n")
cat("Infinitos em preco_m2_declarado:", sum(is.infinite(itbi$preco_m2_declarado)), "\n")
cat("Infinitos em preco_m2:", sum(is.infinite(itbi$preco_m2)), "\n")
cat("Duplicatas exatas (sql + data + valor):",
    sum(duplicated(itbi[, .(n_do_cadastro_sql, data_de_transacao, valor_de_transacao_declarado_pelo_contribuinte)])), "\n")
cat("Proporção transmitida diferente de 100%:", sum(itbi$proporcao_transmitida_percent != 100, na.rm = TRUE), "\n")
cat("\nPercentual de nulos por coluna:\n")
print(sort(sapply(itbi, function(x) round(100 * mean(is.na(x)), 2)), decreasing = TRUE))
rm(itbi); gc(verbose = FALSE)

# -----------------------------------------------------------------------------
# 6. iptu_unique_id.rds — a tabela "um registro por contribuinte"
# -----------------------------------------------------------------------------
titulo("6. iptu_unique_id.rds")
u <- as.data.table(readRDS(file.path(raiz, "iptu_unique_id.rds")))
cat("Linhas:", nrow(u), "| colunas:", ncol(u), "\n")
cat("Contribuintes distintos:", uniqueN(u[["NUMERO DO CONTRIBUINTE"]]), "\n")
cat("Colunas:\n"); print(names(u))
cat("\nfirst_seen:\n"); print(table(u$first_seen))
cat("\nlast_seen:\n"); print(table(u$last_seen))
cat("\nCobertura de coordenadas: lat_cep",
    round(100 * mean(!is.na(u$lat_cep)), 2), "% | lat_quadra",
    round(100 * mean(!is.na(u$lat_quadra)), 2), "%\n")
cat("geo_id vazio:", sum(is.na(u$geo_id) | u$geo_id == ""), "\n")
cat("Exemplos de geo_id:\n"); print(head(unique(u$geo_id), 8))

cat("\n\nFIM DA INSPEÇÃO\n")
