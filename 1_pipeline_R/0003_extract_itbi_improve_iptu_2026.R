# -------------------------------------------------------------------------
# SCRIPT: Geração Criação do banco de dados de ITBI
#       : ao final tambem faz correcoes e ajustes em db de ITBI e IPTU
# -------------------------------------------------------------------------


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



# -------------------------------------------------------------------------
# ATUALIZAÇÃO DE ARQUIVOS ITBI (PRE-STEP)
# -------------------------------------------------------------------------
# Atualiza base local de arquivos ITBI (baixa apenas novos)

library(rvest)
library(stringr)
library(dplyr)
library(magrittr)

url_ref <- "https://www.prefeitura.sp.gov.br/cidade/secretarias/fazenda/acesso_a_informacao/index.php?p=31501"


# lê página e extrai links
links <- read_html(url_ref) %>%
  html_elements("a") %>%
  html_attr("href") %>%
  na.omit()

# filtra apenas arquivos Excel relevantes
links_xls <- links %>%
  str_subset("\\.xls|\\.xlsx") %>%
  str_subset(regex("guia", ignore_case = TRUE))

# garante URL absoluta
links_xls <- ifelse(
  str_detect(links_xls, "^http"),
  links_xls,
  paste0("https://www.prefeitura.sp.gov.br", links_xls)
)

df_links <- tibble(
  url = links_xls,
  file_name = basename(links_xls) %>% tolower()
)

# compara com arquivos já existentes
files_local <- list.files(dir_itbi) %>% tolower()

# extrai ano do nome do arquivo (assume padrão "20xx" no filename)
df_links <- df_links %>%
  mutate(
    ano = str_extract(file_name, "20[0-9]{2}") %>% as.numeric()
  )

# define o ano mais recente disponível no site
latest_year <- max(df_links$ano, na.rm = TRUE)

# regra:
# - baixa arquivos ainda não existentes
# - sempre rebaixa arquivos do ano mais recente (podem ter meses novos)
df_to_download <- df_links %>%
  filter(
    !(file_name %in% files_local) | ano == latest_year
  )

# download incremental
for (i in seq_len(nrow(df_to_download))) {
  url_raw <- df_to_download$url[i]
  url <- URLencode(url_raw) # corrige espaços e caracteres especiais
  
  dest <- file.path(dir_itbi, df_to_download$file_name[i])
  
  tryCatch(
    {
      download.file(url, destfile = dest, mode = "wb")
      print(paste("OK:", df_to_download$file_name[i]))
    },
    error = function(e) {
      print(paste("ERRO:", url_raw))
    }
  )
  
  Sys.sleep(1)
}


library(curl)

for (i in seq_len(nrow(df_to_download))) {
  url_raw <- df_to_download$url[i]
  
  # separa URL em base e nome do arquivo (problema está no filename)
  base <- dirname(url_raw)
  file_name_raw <- basename(url_raw)
  
  # corrige encoding inconsistente do HTML:
  # 1) decodifica (%28 ? ()
  # 2) re-encoda corretamente (espaços, parênteses etc.)
  file_name_encoded <- curl::curl_escape(URLdecode(file_name_raw))
  
  # reconstrói URL válida (sem mexer no domínio)
  url <- paste0(base, "/", file_name_encoded)
  
  # salva com nome "limpo" (legível no disco)
  dest <- file.path(dir_itbi, URLdecode(file_name_raw))
  
  tryCatch(
    {
      # download robusto (curl + user-agent de browser)
      curl_download(
        url,
        destfile = dest,
        handle = new_handle(useragent = "Mozilla/5.0")
      )
      
      print(paste("OK:", basename(dest)))
    },
    error = function(e) {
      print(paste("ERRO:", url_raw))
      print(e)
    }
  )
  
  Sys.sleep(1) # evita throttle do servidor
}


# -------------------------------------------------------------------------
# LEITURA DOS ARQUIVOS ITBI - CRIAÇÃO DO BANCO DE DADOS
# -------------------------------------------------------------------------

library(readxl)
library(magrittr)



# ============================================================
# ETAPA 1 + 2 ? LEITURA, PADRONIZAÇÃO E CONSOLIDAÇÃO
#
# - lê apenas abas com ano no nome
# - força leitura como texto (evita conversões posteriores)
# - aplica regra estrutural:
#     col 1 contém "cadastro"
#     col 28 contém "acc"
# - mantém apenas as 28 colunas esperadas
# - padroniza nomes com expected_cols
# - acumula em lista e faz bind único (eficiente)
# ============================================================

library(readxl)
library(dplyr)
library(stringr)
library(magrittr)

# funcao para extrair todas as abas de um xlsx
read_excel_allsheets <- function(filename) {
  sheets <- excel_sheets(filename)
  lapply(sheets, function(s) read_excel(filename, sheet = s))
}

# lista com o conteudo das sheets de todos os arquivos excel da pasta
FileList <- list.files(
  path = dir_itbi,
  pattern = "guia",
  full.names = TRUE,
  ignore.case = TRUE
)


expected_cols <- c(
  "n_do_cadastro_sql",
  "nome_do_logradouro",
  "numero",
  "complemento",
  "bairro",
  "referencia",
  "cep",
  "natureza_de_transacao",
  "valor_de_transacao_declarado_pelo_contribuinte",
  "data_de_transacao",
  "valor_venal_de_referencia",
  "proporcao_transmitida_percent",
  "valor_venal_de_referencia_proporcional",
  "base_de_calculo_adotada",
  "tipo_de_financiamento",
  "valor_financiado",
  "cartorio_de_registro",
  "matricula_do_imovel",
  "situacao_do_sql",
  "area_do_terreno_m2",
  "testada_m",
  "fracao_ideal",
  "area_construida_m2",
  "uso_iptu",
  "descricao_do_uso_iptu",
  "padrao_iptu",
  "descricao_do_padrao_iptu",
  "acc"
)

list_dfs <- list()
counter <- 1

for (i in seq_along(FileList)) {
  print(paste("arquivo", i, "de", length(FileList)))
  
  sheets <- readxl::excel_sheets(FileList[i])
  
  # mantém apenas abas com ano no nome
  sheets <- sheets[stringr::str_detect(sheets, "[0-9]{4}")]
  
  for (s in sheets) {
    df <- readxl::read_excel(FileList[i], sheet = s, col_types = "text")
    
    col_names <- tolower(names(df))
    
    # validação estrutural mínima
    cond1 <- stringr::str_detect(col_names[1], "cadastro")
    cond2 <- length(col_names) >= 28 && stringr::str_detect(col_names[28], "acc")
    
    if (!(cond1 && cond2)) {
      cat("\nERRO ? Arquivo:", basename(FileList[i]), "| Aba:", s, "\n")
      stop("Estrutura inesperada")
    }
    
    # mantém apenas colunas esperadas (remove lixo à direita)
    df <- df[, seq_along(expected_cols)]
    
    # aplica nomes padronizados
    names(df) <- expected_cols
    
    # adiciona referência temporal (nome da aba)
    df$date_release <- s
    
    # acumula
    list_dfs[[counter]] <- df
    counter <- counter + 1
  }
}

# consolidação final (rápida)
db_itbi <- dplyr::bind_rows(list_dfs)


# ============================================================
# ETAPA 3 ? REMOÇÃO DE DUPLICATAS ESTRUTURAIS
# ============================================================

db_itbi <- db_itbi %>%
  dplyr::distinct(
    n_do_cadastro_sql,
    data_de_transacao,
    valor_de_transacao_declarado_pelo_contribuinte,
    .keep_all = TRUE
  )


# ============================================================
# ETAPA 4 ? CONVERSÃO DE TIPOS
# ============================================================

numeric_cols <- c(
  "valor_de_transacao_declarado_pelo_contribuinte",
  "valor_venal_de_referencia",
  "proporcao_transmitida_percent",
  "valor_venal_de_referencia_proporcional",
  "base_de_calculo_adotada",
  "valor_financiado",
  "area_do_terreno_m2",
  "testada_m",
  "fracao_ideal",
  "area_construida_m2"
)

for (col in numeric_cols) {
  db_itbi[[col]] <- as.numeric(db_itbi[[col]])
}

db_itbi$data_de_transacao <- as.Date(
  as.numeric(db_itbi$data_de_transacao),
  origin = "1899-12-30"
)


db_itbi$preco_m2 <- db_itbi$valor_de_transacao_declarado_pelo_contribuinte / db_itbi$area_construida_m2/(db_itbi$proporcao_transmitida_percent/100)
db_itbi$preco_m2[is.infinite(db_itbi$preco_m2)] <- NA





# ============================================================
# ETAPA 5 ? CORREÇÕES DE DADOS
# ============================================================

# CEP
db_itbi <- db_itbi %>%
  dplyr::mutate(
    cep = stringr::str_trim(cep) %>%
      stringr::str_pad(side = "left", pad = "0", width = 8)
  )

# SQL
db_itbi <- db_itbi %>%
  dplyr::mutate(
    n_do_cadastro_sql = stringr::str_trim(n_do_cadastro_sql) %>%
      stringr::str_pad(side = "left", pad = "0", width = 11)
  )

# logradouro
db_itbi <- db_itbi %>%
  dplyr::mutate(
    nome_do_logradouro = stringr::str_replace_all(
      nome_do_logradouro,
      "R S FRANCISCO",
      "R SAO FRANCISCO"
    )
  )

# área privativa estimada
db_itbi <- db_itbi %>%
  dplyr::mutate(
    area_privativa_estim = area_construida_m2 - (fracao_ideal * area_do_terreno_m2)
  )

db_itbi <- db_itbi %>%
  dplyr::mutate(
    area_privativa_estim = dplyr::case_when(
      area_privativa_estim <= 0 | abs(fracao_ideal) > 1 | area_construida_m2 < area_privativa_estim ~ NA_real_,
      TRUE ~ area_privativa_estim
    )
  )

db_itbi <- db_itbi %>%
  dplyr::mutate(
    area_privativa_estim = round(area_privativa_estim, 1)
  )

# date_release
replace_vector <- c(
  jan = "01", fev = "02", mar = "03", abr = "04",
  mai = "05", jun = "06", jul = "07", ago = "08",
  set = "09", out = "10", nov = "11", dez = "12",
  "-" = "/"
)

db_itbi <- db_itbi %>%
  dplyr::mutate(
    date_release = stringr::str_replace_all(date_release, replace_vector)
  )

db_itbi <- db_itbi %>%
  dplyr::mutate(
    date_release = stringr::str_split(date_release, "/") %>%
      purrr::map_chr(~ paste(rev(.), collapse = "/"))
  )

db_itbi <- db_itbi %>%
  dplyr::mutate(
    date_release = as.Date(date_release, format = "%Y/%m/%d")
  )



# garante coluna ano
db_itbi$ano <- format(db_itbi$data_de_transacao, "%Y")


# -------------------------------------------------------------------------
# EXPORTA LAT LON DA QUADRA (IMPRECISO) E DO CEP (PRECISO MAS INCOMPLETO)
# PARA O DB_ITBI
# -------------------------------------------------------------------------

# Carregamento de dependências para manipulação de strings e big data
library(stringr)
library(data.table) # Utilizado para garantir performance em bases de 4M+ linhas

# Função de normalização para o padrão PMSP: Setor(3)-Quadra(3)-Lote(4)-DV(1)
# Garante a integridade da chave eliminando ruído de máscara e truncamento de zeros
normalize_sql <- function(x) {
  x %>%
    # Remove qualquer caractere não-numérico (ex: hífens e pontos presentes no IPTU)
    str_replace_all("[^0-9]", "") %>%
    # Padding para 11 dígitos: crucial para setores iniciais (ex: de '67...' para '067...')
    # Sem isso, o join falha para toda a região central de São Paulo
    str_pad(width = 11, side = "left", pad = "0")
}

# Conversão por referência (in-place) para mitigar overhead de RAM
# O comando setDT evita a duplicação do objeto na memória, essencial para o volume do IPTU
readRDS(file.path(dir_core_output, "iptu_unique_id.rds"))
setDT(iptu_unique_id)
setDT(db_itbi)

# Geração da sql_key via operador de atribuição por referência (:=)
# Normaliza o 'NUMERO DO CONTRIBUINTE' (estoque) para o padrão de 11 dígitos puros
iptu_unique_id[, sql_key := normalize_sql(`NUMERO DO CONTRIBUINTE`)]

# Normaliza o 'n_do_cadastro_sql' (fluxo de transações) para o mesmo padrão
# Alinha o ITBI com a chave única do IPTU para permitir o merge subsequente
db_itbi[, sql_key := normalize_sql(n_do_cadastro_sql)]

# cria um vetor com os indices do db_itbi que tem correspondencia no iptu_unique_id
match_itbi_iptu <- match(db_itbi$sql_key, iptu_unique_id$sql_key)

# importar lat_quadra lon_quadra lat_cep, lon_cep do arquivo iptu_unique_id

db_itbi[, lat_quadra := iptu_unique_id$lat_quadra[match_itbi_iptu]]
db_itbi[, lon_quadra := iptu_unique_id$lon_quadra[match_itbi_iptu]]
db_itbi[, lat_cep := iptu_unique_id$lat_cep[match_itbi_iptu]]
db_itbi[, lon_cep := iptu_unique_id$lon_cep[match_itbi_iptu]]

# -------------------------------------------------------------------------
# NORMALIZAÇÃO DE CHAVES PRIMÁRIAS (SQL) PARA JOIN DETERMINÍSTICO - ITBI e IPTU
# -------------------------------------------------------------------------

# Carregamento de dependências para manipulação de strings e big data
library(stringr)
library(data.table) # Utilizado para garantir performance em bases de 4M+ linhas

# Função de normalização para o padrão PMSP: Setor(3)-Quadra(3)-Lote(4)-DV(1)
# Garante a integridade da chave eliminando ruído de máscara e truncamento de zeros
normalize_sql <- function(x) {
  x %>%
    # Remove qualquer caractere não-numérico (ex: hífens e pontos presentes no IPTU)
    str_replace_all("[^0-9]", "") %>%
    # Padding para 11 dígitos: crucial para setores iniciais (ex: de '67...' para '067...')
    # Sem isso, o join falha para toda a região central de São Paulo
    str_pad(width = 11, side = "left", pad = "0")
}

# Conversão por referência (in-place) para mitigar overhead de RAM
# O comando setDT evita a duplicação do objeto na memória, essencial para o volume do IPTU
setDT(iptu_unique_id)
setDT(db_itbi)

# Geração da sql_key via operador de atribuição por referência (:=)
# Normaliza o 'NUMERO DO CONTRIBUINTE' (estoque) para o padrão de 11 dígitos puros
iptu_unique_id$"NUMERO DO CONTRIBUINTE" <- normalize_sql(iptu_unique_id$"NUMERO DO CONTRIBUINTE")


# Normaliza o 'n_do_cadastro_sql' (fluxo de transações) para o mesmo padrão
# Alinha o ITBI com a chave única do IPTU para permitir o merge subsequente
db_itbi$"n_do_cadastro_sql" <- normalize_sql(db_itbi$"n_do_cadastro_sql")


# cria a coluna geo_id para unificar os numeros de lotes e condominios de forma univoca (levando em conta o numero do condominio)
# de forma que geo_id com letra F se referem a lotes, e com a letra C referem-se a condominio


# corrige quando aparece o simbolo ??? que vem da coversao mal feita de
# string em latin1 para utf8
corrige_latin1_to_utf8_character <- function(vector_char) {
  unique_string <- vector_char %>%
    unique() %>%
    sort()
  unique_string_base <- unique_string
  dummy <- stri_detect_regex(unique_string, "\uFFFD")
  unique_string[dummy] <- unique_string[dummy] %>% iconv(from = "latin1", to = "UTF-8")
  ref <- match(vector_char, unique_string_base)
  output <- unique_string[ref]
  
  return(output)
}

iptu_unique_id$`TIPO DE PADRAO DA CONSTRUCAO` <-
  corrige_latin1_to_utf8_character(iptu_unique_id$`TIPO DE PADRAO DA CONSTRUCAO`) %>%
  tolower()

iptu_unique_id$`TIPO DE USO DO IMOVEL` <-
  corrige_latin1_to_utf8_character(iptu_unique_id$`TIPO DE USO DO IMOVEL`) %>%
  tolower()


iptu_unique_id$geo_id <- ""
dummy_condo <- (str_before_first(iptu_unique_id$`NUMERO DO CONDOMINIO`, "-") != "00")

iptu_unique_id$geo_id[which(!dummy_condo)] <- (stringi::stri_c(
  iptu_unique_id$`NUMERO DO CONTRIBUINTE`[which(!dummy_condo)] %>% stri_sub(1, 6), "F",
  (iptu_unique_id$`NUMERO DO CONTRIBUINTE`[which(!dummy_condo)] %>% stri_sub(7, 10))
))

iptu_unique_id$geo_id[which(dummy_condo)] <- (stringi::stri_c(
  (iptu_unique_id$`NUMERO DO CONTRIBUINTE`[which(dummy_condo)] %>% stri_sub(1, 6)), "C",
  str_before_first(iptu_unique_id$`NUMERO DO CONDOMINIO`[which(dummy_condo)], "-") %>% as.integer() %>% sprintf("%04d", .)
))


db_itbi$geo_id <- iptu_unique_id$geo_id[match_itbi_iptu]


################################################################
# cria as colunas de tipo de construcao, padrao de construcao e tipo de uso
################################################################

# cria divisao de tipo de construcao: cv ch rh rv i p eg
# cv - comercial vertical
# ch - comercial horizontal
# rh - residencial horizontal
# rv - residencial vertical
# i - industrial
# p - publico
# eg - edifício de garagens

tipo <- iptu_unique_id$`TIPO DE PADRAO DA CONSTRUCAO` %>%
  str_before_first(" - padrão") %>%
  str_replace("residência", "residencial") %>%
  str_replace("comercial ", "c") %>%
  str_replace("residencial ", "r") %>%
  str_replace("vertical", "v") %>%
  str_replace("horizontal", "h")

tipo[str_detect(tipo, "terreno")] <- "t"
tipo[str_detect(tipo, "indústria")] <- "i"
tipo[str_detect(tipo, "barracão")] <- "i"
tipo[str_detect(tipo, "templo")] <- "p"
tipo[str_detect(tipo, "edifício de garagens")] <- "eg"
tipo[is.na(tipo)]<-""

dummy <- (is.na(tipo) | tipo == "")&(str_detect(iptu_unique_id$`TIPO DE USO DO IMOVEL` , "terreno"))
tipo[dummy]="t"

iptu_unique_id$tipo_construcao <- tipo

padrao <- iptu_unique_id$`TIPO DE PADRAO DA CONSTRUCAO` %>% str_after_first("padrão ")
iptu_unique_id$padrao_construcao <- padrao



tipo <- iptu_unique_id$`TIPO DE USO DO IMOVEL`
tipo[str_detect(tipo, "uso misto")] <- "uso misto"
tipo[str_detect(tipo, "loja")] <- "loja"
tipo[str_detect(tipo, "apartamento")] <- "apartamento"
tipo[str_detect(tipo, "residência")] <- "residência"
tipo[str_detect(tipo, "flat")] <- "flat"
tipo[str_detect(tipo, "escritório")] <- "escritório ou consultório"
tipo[str_detect(tipo, "garagem")] <- "garagem ou estacionamento"
tipo[str_detect(tipo, "estacionamento")] <- "garagem ou estacionamento"
tipo[str_detect(tipo, "depósito")] <- "depósito"
tipo[str_detect(tipo, "asilo")] <- "asilo, creche ou convento"
tipo[str_detect(tipo, "cinema")] <- "entretenimento"
tipo[str_detect(tipo, "clube esportivo")] <- "clube"
tipo[str_detect(tipo, "cortiço")] <- "hab coletiva subnormal"
tipo[str_detect(tipo, "hospital")] <- "hospital"
tipo[str_detect(tipo, "hotel")] <- "hotel"
tipo[str_detect(tipo, "indústria")] <- "indústria"
tipo[str_detect(tipo, "utilização múltipla")] <- "uso misto"
tipo[str_detect(tipo, "posto de serviço")] <- "posto de gasolina"
tipo[str_detect(tipo, "prédio com uso exclusivamente residencial")] <- "predio residencial"
tipo[str_detect(tipo, "prédio com uso exclusivamente comercial")] <- "predio comercial"
tipo[str_detect(tipo, "radioemissora")] <- "infra de comunicação"

iptu_unique_id$tipo_uso <- tipo


# ============================================================
# Cria novas colunas iptu e itbi
# ============================================================

# deletar todas as colunas que todos os valores sejam NA ou vazios
# Filtra as colunas onde EXISTE pelo menos um valor que não seja NA e não seja vazio
# Fórmula robusta para múltiplos tipos (Date, Numeric, Character)
iptu_unique_id <- iptu_unique_id[, .SD, .SDcols = \(x) {
  res <- if(is.character(x)) !is.na(x) & x != "" else !is.na(x)
  any(res, na.rm = TRUE)
}]

iptu_unique_id[sample(1:nrow(iptu_unique_id), 5000),] %>% view()


# criar data de início da vida do contribuinte a partir do mes e ano de início da vida do contribuinte, colocando o dia como 01 e tratando os casos em que o mes ou o ano est???o faltando (colocando NA)
meses <- iptu_unique_id$`MES DE INICIO DA VIDA DO CONTRIBUINTE`
anos <- iptu_unique_id$`ANO DE INICIO DA VIDA DO CONTRIBUINTE`
iptu_unique_id$data_inicio_contribuicao <- as.Date(paste0("01/", meses, "/", anos), format = "%d/%m/%Y")
iptu_unique_id$data_inicio_contribuicao[is.na(meses) | is.na(anos)] <- NA




# UNIFICAR AS COLUNAS iptu_unique_id$`QUANTIDADE DE ESQUINAS/FRENTES` E iptu_unique_id$`QUANTIDADE DE ESQUINAS FRENTES`
tryCatch({
  iptu_unique_id$`QUANTIDADE DE ESQUINAS/FRENTES`[is.na(iptu_unique_id$`QUANTIDADE DE ESQUINAS/FRENTES`)] <-
    iptu_unique_id$`QUANTIDADE DE ESQUINAS FRENTES`[is.na(iptu_unique_id$`QUANTIDADE DE ESQUINAS/FRENTES`)]
  iptu_unique_id$`QUANTIDADE DE ESQUINAS FRENTES` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})

# UNIFICAR AS COLUNAS iptu_unique_id$`DATA DO CADASTRAMENTO` E iptu_ Dunique_id$`DATA_CADASTRAMENTO`
tryCatch({
  iptu_unique_id$`DATA DO CADASTRAMENTO`[is.na(iptu_unique_id$`DATA DO CADASTRAMENTO`)] <-
    iptu_unique_id$`DATA_CADASTRAMENTO`[is.na(iptu_unique_id$`DATA DO CADASTRAMENTO`)]
  iptu_unique_id$`DATA_CADASTRAMENTO` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})

# UNIFICAR AS COLUNAS iptu_unique_id$`FATOR DE OBSOLESCENCIA` E iptu_unique_id$`FATOR_OBSOLESCENCIA`
tryCatch({iptu_unique_id$`FATOR DE OBSOLESCENCIA`[is.na(iptu_unique_id$`FATOR DE OBSOLESCENCIA`)] <-
  iptu_unique_id$`FATOR_OBSOLESCENCIA`[is.na(iptu_unique_id$`FATOR DE OBSOLESCENCIA`)]
iptu_unique_id$`FATOR_OBSOLESCENCIA` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})

# UNIFICAR AS COLUNAS iptu_unique_id$`FRACAO IDEAL` E iptu_unique_id$`FRACAO_IDEAL`
tryCatch({iptu_unique_id$`FRACAO IDEAL`[is.na(iptu_unique_id$`FRACAO IDEAL`)] <-
  iptu_unique_id$`FRACAO_IDEAL`[is.na(iptu_unique_id$`FRACAO IDEAL`)]
iptu_unique_id$`FRACAO_IDEAL` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})

# UNIFICAR AS COLUNAS iptu_unique_id$`FRACAO IDEAL` E iptu_unique_id$`FRACAO_IDEAL`
tryCatch({iptu_unique_id$`VALOR DO M2 DO TERRENO`[is.na(iptu_unique_id$`VALOR DO M2 DO TERRENO`)] <-
  iptu_unique_id$`VALOR_M2_TERRENO`[is.na(iptu_unique_id$`VALOR DO M2 DO TERRENO`)]
iptu_unique_id$`VALOR_M2_TERRENO` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})


# NOME DE LOGRADOURO DO IMOVEL e NOME_DE_LOGRADOURO_DO_IMOVEL
tryCatch({iptu_unique_id$`NOME DE LOGRADOURO DO IMOVEL`[is.na(iptu_unique_id$`NOME DE LOGRADOURO DO IMOVEL`)] <-
  iptu_unique_id$`NOME_DE_LOGRADOURO_DO_IMOVEL`[is.na(iptu_unique_id$`NOME DE LOGRADOURO DO IMOVEL`)]
iptu_unique_id$`NOME_DE_LOGRADOURO_DO_IMOVEL` <- NULL
},error = function(e) {
  message("ERRO AO UNIFICAR COLUNAS, PROVAVELMENTE COLUNA NAO EXISTE")
})



# cria preco por m2 declarado e preco por m2 de prefeitura para itbi

db_itbi$preco_m2_declarado <- db_itbi$valor_de_transacao_declarado_pelo_contribuinte / db_itbi$area_construida_m2 /(db_itbi$proporcao_transmitida_percent/100)%>% round(0) %>% as.integer()

db_itbi$preco_m2_valor_venal <- db_itbi$valor_venal_de_referencia/ db_itbi$area_construida_m2 %>% round(0) %>% as.integer()
db_itbi$preco_m2_valor_venal[is.infinite(db_itbi$valor_venal)|is.na(db_itbi$preco_m2_valor_venal)] <- NA

# retira os registro em o o valor declarado seja NA ou zero
db_itbi <- db_itbi %>%
  dplyr::filter(
    !is.na(valor_de_transacao_declarado_pelo_contribuinte)
  ) %>% 
  dplyr::filter(
    valor_de_transacao_declarado_pelo_contribuinte != 0)


db_itbi[sample(1:nrow(db_itbi), 1000),] %>% view()


# ============================================================
# SALVAR BASE CONSOLIDADA EM RDS
# ============================================================


saveRDS(db_itbi, file.path(dir_core_output, "db_itbi.rds"),compress="xz")
saveRDS(iptu_unique_id, file.path(dir_core_output, "iptu_unique_id.rds"),compress="xz")


# ============================================================
# EXPORTAÇÃO PARQUET (PARTICIONADO POR ANO)
# ============================================================

library(arrow)

dir_parquet_itbi <- file.path(dir_core_output, "parquet_itbi")
dir.create(dir_parquet_itbi, showWarnings = FALSE, recursive = TRUE)

arrow::write_dataset(
  db_itbi,
  path = dir_parquet_itbi,
  partitioning = "ano",
  format = "parquet"
)


list.files(dir_parquet_itbi, recursive = TRUE)


all.equal(
  nrow(db_itbi),
  open_dataset(dir_parquet_itbi) %>% dplyr::count() %>% dplyr::collect() %>% .$n
)
