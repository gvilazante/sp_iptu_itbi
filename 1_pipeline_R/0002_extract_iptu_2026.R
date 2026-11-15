# -------------------------------------------------------------------------
# SCRIPT: Geração Parquet IPTU São Paulo
# -------------------------------------------------------------------------

# script cria um parquet file com os IPTU de São Paulo para todos os anos disponíveis na pasta IPTU
# inputs:
# aquivos IPTU na pasta dir_iptu no formato iptu_aaaa.zip que contem um unico arquivo csv com os dados daquele
#
# output:
# 1. parquet com os dados completos do iptu desde 1996 na pasta dir_parquet, dividido por ano
# 2. parquet com os dados agregados por regiao (prefixo CEP)
# 3. um arquivo rds com os dados da primeira (first_seen) e da ultima aparição (last_seen)
#    de cada matricula de iptu com os dados da matricula mais recente vista

# -------------------------------------------------------------------------
# CABEÇALHO ORIGINAL (PRESERVADO INTEGRALMENTE)
# -------------------------------------------------------------------------

if (!("this.path" %in% installed.packages())) {
  install.packages("this.path")
}
base_directory <- this.path::this.dir() # set path to the current directory of the file
if (base_directory != getwd()) {
  setwd(base_directory)
}
Sys.setenv(TZ = "Brazil/East")

if (exists("library_sp_market_loaded")) {
  if (!library_sp_market_loaded) {
    source("library_sp_market.R", encoding = "Latin1")
  }
} else {
  source("library_sp_market.R", encoding = "Latin1")
}

dir_raiz <- getwd()
dir_sub <- "/DB"
dir_db <- paste0(dir_raiz, dir_sub)
dir_mapas <- paste0(dir_db, "/mapas_sp/geosampa_jul_2024")
dir_lotes <- paste0(dir_mapas, "/lotes")
dir_itbi <- paste0(dir_raiz, "/db/itbi")
dir_iptu <- paste0(dir_mapas, "/iptu")
dir_cep <- paste0(dir_db, "/cep")
dir_ibge <- paste0(dir_db, "/ibge")
dir_core_output <- paste0(dir_db, "/core_output")
dir_parquet <- paste0(dir_core_output, "/parquet_iptu")

library(data.table)
library(arrow)
library(stringr)
library(magrittr)
library(sf)
library(mapview)

# -------------------------------------------------------------------------
# OVERWRITE CONTROLADO
# -------------------------------------------------------------------------

dir_parquet_ano <- paste0(dir_parquet, "/por_ano")
dir_parquet_regiao <- paste0(dir_parquet, "/por_regiao")

if (dir.exists(dir_parquet)) {
  unlink(dir_parquet, recursive = TRUE)
}

dir.create(dir_parquet_ano, recursive = TRUE)
dir.create(dir_parquet_regiao, recursive = TRUE)

# -------------------------------------------------------------------------
# LISTA DE ZIPs
# -------------------------------------------------------------------------

arquivos_zip <- list.files(
  dir_iptu,
  pattern = "^iptu_[0-9]{4}\\.zip$",
  full.names = TRUE,
  ignore.case = TRUE
) %>% sort()

# -------------------------------------------------------------------------
# COLUNAS CONTROLADAS
# -------------------------------------------------------------------------

float_cols <- c(
  "VALOR_M2_TERRENO", "VALOR_TERRENO", "VALOR_CONSTRUCAO",
  "VALOR_TOTAL", "FATOR_OBSOLESCENCIA", "FRACAO_IDEAL",
  "QUANTIDADE DE ESQUINAS/FRENTES", "TESTADA PARA CALCULO"
)

int_cols <- c(
  "ANO_CONSTRUCAO", "ANO_ULTIMA_REFORMA",
  "ANO_AQUISICAO", "QUANTIDADE DE PAVIMENTOS"
)

date_cols <- c("DATA_CADASTRAMENTO", "DATA_ULTIMA_ATUALIZACAO")

# -------------------------------------------------------------------------
# ETAPA 1 - PARQUET POR ANO (SANEAMENTO E NORMALIZAÇÃO)
# -------------------------------------------------------------------------

for (i in 1:length(arquivos_zip)) {
  zip_path <- arquivos_zip[i]
  ano_arquivo <- str_extract(basename(zip_path), "[0-9]{4}")
  message("Processando ano: ", ano_arquivo)

  temp_dir <- tempfile()
  dir.create(temp_dir)
  unzip(zip_path, exdir = temp_dir)
  csv_file <- list.files(temp_dir, pattern = "\\.csv$", full.names = TRUE)[1]

  dt <- tryCatch(
    fread(csv_file, sep = ";", encoding = "UTF-8"),
    error = function(e) fread(csv_file, sep = ";", encoding = "Latin-1")
  )

  dt[, ano := as.integer(ano_arquivo)]

  # Garantir colunas e conversão numérica
  controlled_cols <- c(float_cols, int_cols, date_cols)
  for (col in controlled_cols) if (!col %in% names(dt)) dt[, (col) := NA]

  for (col in float_cols) dt[, (col) := as.numeric(gsub(",", ".", as.character(get(col))))]
  for (col in int_cols) suppressWarnings(dt[, (col) := as.integer(get(col))])

  # --- TRATAMENTO DE DATAS (CORREÇÃO DO ERRO DE PARSING) ---
  for (col in date_cols) {
    dt[, (col) := as.character(get(col))]

    # Normaliza DD/MM/YY para DD/MM/YYYY seguindo critério imobiliário (95-99 | 00-26)
    dt[grepl("^\\d{2}/\\d{2}/\\d{2}$", get(col)), (col) := {
      prefixo <- substr(get(col), 1, 6)
      ano_2dig <- as.integer(substr(get(col), 7, 8))
      seculo <- ifelse(ano_2dig >= 95, "19", "20")
      paste0(prefixo, seculo, sprintf("%02d", ano_2dig))
    }]
    dt[, (col) := as.Date(get(col), format = "%d/%m/%Y")]
  }

  setcolorder(dt, sort(names(dt)))
  write_parquet(dt, file.path(dir_parquet_ano, paste0("iptu_", ano_arquivo, ".parquet")))

  unlink(temp_dir, recursive = TRUE)
  rm(dt)
  gc()
}
#
# regioes <- list(
#   centro = c("01"),
#   zona_norte = c("02"),
#   zona_leste = c("03", "08"),
#   zona_sul = c("04"),
#   zona_oeste = c("05")
# )

# -------------------------------------------------------------------------
# ETAPA 2 - IPTU UNIQUE ID (PROCESSAMENTO ITERATIVO DE BAIXA MEMÓRIA)
# -------------------------------------------------------------------------
# esse arquivo tem o first_seen e a informação mais recente de cada matricula

if (!exists("parquets_ano")) {
  parquets_ano <- list.files(dir_parquet_ano, full.names = TRUE, pattern = "\\.parquet$")
}

# Inicializamos os objetos de controle
iptu_unique_id <- NULL # Para datas de ciclo de vida
dt_snapshot <- NULL # Para os dados cadastrais mais recentes

message("Iniciando processamento iterativo por ano...")

for (f in parquets_ano) {
  ano_corrente <- as.integer(str_extract(basename(f), "[0-9]{4}"))
  message("Lendo arquivo: ", basename(f))

  # Lemos apenas o ano atual
  dt_temp <- read_parquet(f) %>% as.data.table()

  # --- PARTE A: Atualização do Ciclo de Vida (first/last seen) ---
  dt_summary_temp <- dt_temp[, .(
    first_seen = min(ano, na.rm = TRUE),
    last_seen  = max(ano, na.rm = TRUE)
  ), by = `NUMERO DO CONTRIBUINTE`]

  if (is.null(iptu_unique_id)) {
    iptu_unique_id <- dt_summary_temp
  } else {
    # Redução iterativa: compara o estado anterior com o novo arquivo
    iptu_unique_id <- rbind(iptu_unique_id, dt_summary_temp)
    iptu_unique_id <- iptu_unique_id[, .(
      first_seen = min(first_seen),
      last_seen  = max(last_seen)
    ), by = `NUMERO DO CONTRIBUINTE`]
  }

  # --- PARTE B: Atualização do Snapshot (Keep most recent) ---
  if (is.null(dt_snapshot)) {
    dt_snapshot <- dt_temp
  } else {
    # Identificamos quem no dt_temp é MAIS RECENTE que o que já temos no snapshot
    # Nota: Em bases anuais, o arquivo atual costuma ser o mais recente,
    # mas o join por ano garante integridade se os arquivos não estiverem em ordem.

    # Criamos um identificador de 'última versão'
    dt_snapshot <- rbind(dt_snapshot, dt_temp, fill = TRUE)
    # Mantemos apenas a linha com o maior ano para cada SQL
    setorder(dt_snapshot, `NUMERO DO CONTRIBUINTE`, -ano)
    dt_snapshot <- unique(dt_snapshot, by = "NUMERO DO CONTRIBUINTE")
  }

  # Limpeza agressiva de memória por iteração
  rm(dt_temp, dt_summary_temp)
  gc()
}

# Agora o iptu_unique_id contém as datas corretas e o dt_snapshot os dados cadastrais
# Fazemos o merge final apenas para garantir os campos de first_seen
setkey(dt_snapshot, `NUMERO DO CONTRIBUINTE`)
setkey(iptu_unique_id, `NUMERO DO CONTRIBUINTE`)

iptu_unique_id <- dt_snapshot[iptu_unique_id[, .(`NUMERO DO CONTRIBUINTE`, first_seen)],
  on = "NUMERO DO CONTRIBUINTE"
]

iptu_unique_id$`NUMERO DO IMOVEL` <- as.integer(iptu_unique_id$`NUMERO DO IMOVEL`)
iptu_unique_id$`CEP DO IMOVEL` <- str_remove(iptu_unique_id$`CEP DO IMOVEL`, "-")
iptu_unique_id$last_seen <- iptu_unique_id$ano # O ano do snapshot é o ano mais recente visto para cada matrícula

saveRDS(iptu_unique_id, file = file.path(dir_core_output, "iptu_unique_id.rds"), compress = "xz")
# etapa 2 concluida

# -------------------------------------------------------------------------
# ETAPA 3 - BUSCAR AS COORDENADAS DOS IPTUS A PARTIR DO DB DOS CEPS UNICOS
# -------------------------------------------------------------------------



message("Processando base de endereços IBGE...")

# CARREGA BANCO DE DADOS DE TODOS OS ENDEREÇOS
ibge_addresses <- readRDS(file.path(dir_core_output, "ibge_cidade_sp_unique_addresses.rds"))
setDT(ibge_addresses)
ibge_addresses$lograd_full <- str_squish(ibge_addresses$lograd_full) %>% str_to_upper()

# CARREGA BANCO DE DADOS DE TODOS OS LOGRADOUROS
lograd_cep <- unique(ibge_addresses[, .(CEP, lograd_full)])
lograd_cep[, n_logradouros := .N, by = CEP]

# LIMPA LOGRADOUROS COM NOME RUIDO (SEM DENOMINACAO, PARTICULAR ETC)
# 1. Definição dos termos de ruído
termo_sd <- "(?i)sem denomina[çc][aã]o"
termo_part <- "(?i)particular"
regex_ruido <- "(?i)sem denomina[çc][aã]o|particular"
library(stringi)
dummy <- not(stri_detect_regex(stri_trans_tolower(lograd_cep$lograd_full), regex_ruido))
lograd_cep <- lograd_cep[dummy,]


# cria lograd_cep com o numero de ruas distintas que aparecem no mesmo CEP, e o numero de enderecos distintos que aparecem no mesmo CEP e logradouro
# show number of unique addresses from ibge_addresses for each unique CEP / logra_full in lograd_dep dataframe

lograd_cep <- lograd_cep %>%
  select(-matches("^n_addresses")) %>%
  left_join(
    ibge_addresses %>%
      filter(!is.na(NUM_ENDERECO)) %>%
      distinct(CEP, lograd_full, NUM_ENDERECO) %>%
      group_by(CEP, lograd_full) %>%
      summarise(n_addresses = n(), .groups = "drop"),
    by = c("CEP", "lograd_full")
  )

lograd_cep$n_addresses[is.na(lograd_cep$n_addresses)] <- 0L

saveRDS(lograd_cep, file.path(dir_core_output, "lograd_cep.rds"), compress = "xz")


#########################################################
# continuação Gemini para atribuir coordenadas aos iptus a partir do db do CEP
########################################################

library(data.table)

# --- 1. CONFIGURAÇÃO DE AMBIENTE E MAPEAMENTO ---
# Forçar data.table por referência para eficiência de memória (4M+ linhas)
setDT(ibge_addresses)
setDT(lograd_cep)
setDT(iptu_unique_id)

# Nomes originais (o acento em 'IMÓVEL' estava causando erro de 'object not found')
col_cep_orig <- "CEP DO IMOVEL"
col_num_orig <- "NUMERO DO IMOVEL"

# Renomeação temporária para nomes seguros (snake_case)
setnames(iptu_unique_id,
  old = c(col_cep_orig, col_num_orig),
  new = c("cep_iptu", "num_iptu")
)

# --- 2. NORMALIZAÇÃO DA REFERÊNCIA (IBGE/CNEFE) ---

# Converter NUM_ENDERECO para integer in-place (normaliza "001" para 1)
ibge_addresses[, NUM_ENDERECO := as.integer(NUM_ENDERECO)]

# Selecionar apenas CEPs de logradouro único (n_logradouros == 1 já existe no lograd_cep)
ceps_unicos <- lograd_cep[n_logradouros == 1, .(CEP)]

# Filtrar base de referência: apenas CEPs unívocos e numeração válida
dummy <- ((ibge_addresses$CEP %in% ceps_unicos$CEP) & !is.na(ibge_addresses$NUM_ENDERECO)) %>% which()
ibge_ref_clean <- ibge_addresses[
  dummy,
  .(CEP, NUM_ENDERECO, LATITUDE, LONGITUDE, lograd_full)
]

# Garantir apenas um par de coordenadas por (CEP, Número) via .SD[1]
ibge_ref_clean <- ibge_ref_clean[, .SD[1], by = .(CEP, NUM_ENDERECO)]

# povoa o iptu com o logradouro do CEP
iptu_unique_id$NOME_DE_LOGRADOURO_DO_IMOVEL <- str_squish(iptu_unique_id$`NOME DE LOGRADOURO DO IMOVEL`) %>% str_to_upper()
iptu_unique_id$lograd_cep <- NA_character_
match_dummy <- match(iptu_unique_id$cep_iptu, ibge_ref_clean$CEP)
iptu_unique_id$lograd_cep <- ibge_ref_clean$lograd_full[match_dummy]

db_iptu <- iptu_unique_id[, .(lograd_cep, num_iptu)]
db_cep <- ibge_addresses[, .(lograd_full, NUM_ENDERECO)]
names(db_iptu) <- names(db_cep)
match_dummy <- multi_match_dt(db_iptu, db_cep)
# 1-sum(is.na(match_dummy))/nrow(db_iptu)

iptu_unique_id$lat_cep <- iptu_unique_id$lon_cep <- NA_character_
iptu_unique_id$lat_cep <- ibge_addresses$LATITUDE[match_dummy]
iptu_unique_id$lon_cep <- ibge_addresses$LONGITUDE[match_dummy]

# Restaura os nomes originais com acentos e espaços
setnames(iptu_unique_id,
  old = c("cep_iptu", "num_iptu"),
  new = c(col_cep_orig, col_num_orig)
)

# salva o iptu_unique_id atualizado com as coordenadas



# Cálculo final de cobertura
populados <- iptu_unique_id[!is.na(iptu_unique_id$lat), .N]
total_iptu <- nrow(iptu_unique_id)
pct <- round(100 * populados / total_iptu, 2)
print(paste0("Cobertura de coordenadas via CEP: ", pct, "% (", populados, " de ", total_iptu, " IPTUs)"))

##################################################################
# nova rodada de coordenadas, dessa vez baseadas no centroide da quadra
##################################################################



# carrega arquivo todas as quadras paste0(dir_mapas,/todas_as_quadras_jul_2024.rds)
if (!(exists("db_quadras"))) {
  db_quadras <- readRDS(paste0(dir_mapas, "/todas_as_quadras_jul_2024.rds"))
}
if (!(exists("iptu_unique_id"))) {
  iptu_unique_id <- readRDS(paste0(dir_core_output, "/iptu_unique_id.rds"))
}
db_quadras$setor_quadra <- paste0(db_quadras$qd_setor, db_quadras$qd_fiscal)
iptu_unique_id$setor_quadra <- str_sub(iptu_unique_id$"NUMERO DO CONTRIBUINTE", 1, 6)
db_quadras <- db_quadras %>% st_transform(4326)

# criar as colunas lat_quadra e lon_quadra
temp_coordinates <- db_quadras %>%
  st_fix() %>%
  st_centroid() %>%
  sf_to_coordinates()
db_quadras$lon_quadra <- temp_coordinates$lon
db_quadras$lat_quadra <- temp_coordinates$lat

match_dummy <- match(iptu_unique_id$setor_quadra, db_quadras$setor_quadra)
iptu_unique_id$lon_quadra <- db_quadras$lon_quadra[match_dummy]
iptu_unique_id$lat_quadra <- db_quadras$lat_quadra[match_dummy]

# salvar
saveRDS(iptu_unique_id, file = file.path(dir_core_output, "iptu_unique_id.rds"), compress = "xz")
