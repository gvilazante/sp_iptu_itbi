# inspecao_parte2.R — SOMENTE LEITURA, versão econômica em memória (laptop com 8 GB)
# Lê uma coluna por vez em vez do arquivo inteiro.
suppressPackageStartupMessages({ library(arrow); library(data.table) })
raiz <- "G:/My Drive/data/sync_onedrive/RCoding/sp_market_analysis/DB/core_output"
titulo <- function(x) cat("\n\n==================== ", x, " ====================\n", sep = "")

# 3b. IPTU 2025 — coluna a coluna
titulo("3b. IPTU 2025: conteúdo (coluna a coluna)")
f <- file.path(raiz, "parquet_iptu/por_ano/iptu_2025.parquet")
cols <- names(ParquetFileReader$create(f)$GetSchema())
na_pct <- sapply(cols, function(c) {
  x <- read_parquet(f, col_select = c)[[1]]
  r <- round(100 * mean(is.na(x) | as.character(x) == ""), 2); rm(x); gc(verbose = FALSE); r
})
print(sort(na_pct, decreasing = TRUE))
k <- read_parquet(f, col_select = "NUMERO DO CONTRIBUINTE")[[1]]
cat("\nLinhas:", length(k), "| distintos:", uniqueN(k), "\n"); print(table(nchar(k)))
cat("Formato SSSQQQLLLL-D em todos?", all(grepl("^\\d{10}-\\d$", k)), "\n")
rm(k); gc(verbose = FALSE)
d <- read_parquet(f, col_select = "DATA DO CADASTRAMENTO")[[1]]
cat("Exemplos de DATA DO CADASTRAMENTO (texto):\n"); print(head(unique(d[!is.na(d) & d != ""]), 6)); rm(d)
fa <- read_parquet(f, col_select = "FASE DO CONTRIBUINTE")[[1]]
cat("FASE DO CONTRIBUINTE:\n"); print(table(fa, useNA = "ifany")); rm(fa); gc(verbose = FALSE)

# 4. por_regiao
titulo("4. IPTU por_regiao")
dr <- file.path(raiz, "parquet_iptu/por_regiao")
fr <- list.files(dr, recursive = TRUE, full.names = TRUE)
print(data.table(arquivo = sub(dr, "", fr, fixed = TRUE), MB = round(file.size(fr) / 1e6, 1), modificado = file.mtime(fr)))

# 5. ITBI — só as colunas necessárias
titulo("5. ITBI")
ds <- open_dataset(file.path(raiz, "parquet_itbi"))
print(ds$schema)
sel <- c("ano", "n_do_cadastro_sql", "data_de_transacao", "date_release",
         "valor_de_transacao_declarado_pelo_contribuinte", "proporcao_transmitida_percent",
         "preco_m2", "preco_m2_declarado", "preco_m2_valor_venal", "geo_id")
sel <- intersect(sel, names(ds$schema))
it <- as.data.table(ds$NewScan()$Project(sel)$Finish()$ToTable())
cat("\nLinhas totais:", nrow(it), "\n")
print(it[, .N, by = ano][order(ano)], nrows = 100)
cat("\nData de transação nula:", sum(is.na(it$data_de_transacao)), "\n")
cat("Faixa de datas:", format(range(it$data_de_transacao, na.rm = TRUE)), "\n")
cat("Faixa de date_release:", format(range(it$date_release, na.rm = TRUE)), "\n")
cat("Comprimento de n_do_cadastro_sql:\n"); print(table(nchar(it$n_do_cadastro_sql), useNA = "ifany"))
cat("Casou com IPTU (geo_id preenchido):", round(100 * mean(!is.na(it$geo_id) & it$geo_id != ""), 2), "%\n")
for (c in intersect(c("preco_m2", "preco_m2_declarado", "preco_m2_valor_venal"), names(it)))
  cat("Infinitos em", c, ":", sum(is.infinite(it[[c]])), "| NA:", sum(is.na(it[[c]])), "\n")
cat("Proporção transmitida diferente de 100%:", sum(it$proporcao_transmitida_percent != 100, na.rm = TRUE), "\n")
cat("Duplicatas (sql + data + valor):",
    sum(duplicated(it[, .(n_do_cadastro_sql, data_de_transacao, valor_de_transacao_declarado_pelo_contribuinte)])), "\n")
# comparação preco_m2 (linha 316, correto) vs preco_m2_declarado (linha 666, suspeito)
if (all(c("preco_m2", "preco_m2_declarado") %in% names(it))) {
  ok <- is.finite(it$preco_m2) & is.finite(it$preco_m2_declarado)
  cat("preco_m2 vs preco_m2_declarado — linhas com diferença > 1 R$/m2:",
      sum(abs(it$preco_m2[ok] - it$preco_m2_declarado[ok]) > 1), "de", sum(ok), "\n")
  cat("  entre vendas com proporção < 100%: infinitos em preco_m2_declarado =",
      sum(is.infinite(it$preco_m2_declarado) & it$proporcao_transmitida_percent < 100, na.rm = TRUE), "\n")
}
rm(it); gc(verbose = FALSE)

# 6. iptu_unique_id.rds — pode não caber na memória; tenta
titulo("6. iptu_unique_id.rds")
res <- tryCatch({
  u <- readRDS(file.path(raiz, "iptu_unique_id.rds")); setDT(u)
  cat("Linhas:", nrow(u), "| colunas:", ncol(u), "\n")
  cat("Contribuintes distintos:", uniqueN(u[["NUMERO DO CONTRIBUINTE"]]), "\n")
  cat("Colunas:\n"); print(names(u))
  cat("\nfirst_seen:\n"); print(table(u$first_seen))
  cat("\nlast_seen:\n"); print(table(u$last_seen))
  cat("\nCobertura lat_cep:", round(100 * mean(!is.na(u$lat_cep)), 2), "% | lat_quadra:",
      round(100 * mean(!is.na(u$lat_quadra)), 2), "%\n")
  cat("geo_id vazio:", sum(is.na(u$geo_id) | u$geo_id == ""), "\n")
  cat("Exemplos de geo_id:\n"); print(head(unique(u$geo_id), 8))
  "ok"
}, error = function(e) paste("NÃO COUBE NA MEMÓRIA:", conditionMessage(e)))
cat(res, "\n\nFIM DA PARTE 2\n")
