# SOMENTE LEITURA: lê cada partição do ITBI separadamente
suppressPackageStartupMessages(library(arrow))
d <- "G:/My Drive/data/sync_onedrive/RCoding/sp_market_analysis/DB/core_output/parquet_itbi"
cols <- c("data_de_transacao","valor_de_transacao_declarado_pelo_contribuinte","proporcao_transmitida_percent",
          "preco_m2","preco_m2_declarado","geo_id","n_do_cadastro_sql","date_release")
for (f in sort(list.files(d, recursive = TRUE, full.names = TRUE))) {
  r <- tryCatch({
    t <- read_parquet(f, col_select = all_of(cols))
    sprintf("%7d lin | data NA %6d | data %s a %s | release %s a %s | Inf decl %6d | Inf pm2 %4d | casou IPTU %5.1f%% | prop<100 %6d",
      nrow(t), sum(is.na(t$data_de_transacao)),
      suppressWarnings(min(t$data_de_transacao, na.rm = TRUE)), suppressWarnings(max(t$data_de_transacao, na.rm = TRUE)),
      min(t$date_release, na.rm = TRUE), max(t$date_release, na.rm = TRUE),
      sum(is.infinite(t$preco_m2_declarado)), sum(is.infinite(t$preco_m2)),
      100 * mean(!is.na(t$geo_id) & t$geo_id != ""), sum(t$proporcao_transmitida_percent < 100, na.rm = TRUE))
  }, error = function(e) paste("ERRO:", conditionMessage(e)))
  cat(sub(".*parquet_itbi/", "", f), r, "\n")
}
