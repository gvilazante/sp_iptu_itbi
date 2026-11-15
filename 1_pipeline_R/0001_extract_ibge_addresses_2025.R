# script organiza dados dos CEP e dados de todos os endereços de são paulo
# inputs:
#
#ibge_cidade_sp_all_addresses <- read_csv2(paste0(dir_ibge,"/3550308_SAO_PAULO.zip"))
# arruivos com informaçoes basicas dos endereços do estado de sp, inclusive coordenadas,
# descrição do estabelecimento, endereco completissio,  
#
#ibge_agregado_por_cep <- read_csv2(paste0(dir_ibge,"/Agregados_por_CEP_CNEFE_Censo_2022.zip"))
#banco de dados com o numereo de lugares de cada tipo no CeP (residencias, escolas, hospitais, etc)
#
#banco de dados dos CEPS (corrreios), all_ceps_sp, com informacoes resumidas por cep: bairro, cidade, estado, numero de endereços, numero de residencias, numero de casas, numero de apartamentos, numero de estabelecimentos de ensino, numero de estabelecimentos de saude, numero de estabelecimentos religiosos, numero de estabelecimentos de outras finalidades, numero de edificacoes em construcao ou reforma
#
#output:
# aquivo cep_databank_sp com todas as informaçoes, exceto as de mapa


if(!("this.path" %in% installed.packages())) {install.packages("this.path")}
base_directory = this.path::this.dir() # set path to the current directory of the file
if(base_directory!=getwd()) {setwd(base_directory)}
Sys.setenv(TZ="Brazil/East")
if(exists('library_sp_market_loaded')) {if(!library_sp_market_loaded) {
  source("library_sp_market.R",encoding="Latin1")}} else {
    source("library_sp_market.R",encoding="Latin1")}

dir_raiz<-getwd()
dir_sub<-"/DB"
dir_db <- paste0(dir_raiz,dir_sub)
dir_mapas <- paste0(dir_db,"/mapas_sp/geosampa_jul_2024")
dir_lotes <- paste0(dir_mapas,"/lotes")
dir_itbi <- paste0(dir_raiz,"/db/itbi")
dir_iptu <- paste0(dir_mapas,"/iptu")
dir_cep <- paste0(dir_db,"/cep")
dir_ibge <- paste0(dir_db,"/ibge")
dir_core_output <-  paste0(dir_db,"/core_output")



################################################################################
# Arquivos IBGE - CNEFE - CADASTRO NAC DE ENDERECOS PARA FINS ESTATISTICOS
# https://www.ibge.gov.br/estatisticas/sociais/populacao/38734-cadastro-nacional-de-enderecos-para-fins-estatisticos.html?edicao=38891&t=downloads

# Agregado por CEP
# CEP	Código de Endereçamento Postal
# TOT_END	Total de endereços
# TOT_DP	Total de domicílios particulares
# TOT_TIPO_101	Total de casas
# TOT_TIPO_102	Total de casas de vila ou em condomínio
# TOT_TIPO_103	Total de apartamentos
# TOT_TIPO_104	Total de outros tipos de edificação
# TOT_DOM_COND	Total de domicílios em arranjos condominiais
# TOT_DC	Total de domicílios coletivos
# TOT_EAGRO	Total de estabelecimentos agropecuários
# TOT_EENSINO	Total de estabelecimentos de ensino
# TOT_ESAUDE	Total de estabelecimentos de saúde
# TOT_ERELIG	Total de estabelecimentos religiosos
# TOT_EOF	Total de estabelecimentos de outras finalidades
# TOT_ECR	Total de edificações em construção ou reforma

# leitura do arquivo baixado para o estado de sp, o computador nao agenta
# uf_sp <- read_csv2(paste0(dir_ibge,"/35_sp.csv"))


ibge_cidade_sp_all_addresses <- read_csv2(paste0(dir_ibge,"/3550308_SAO_PAULO.zip"))
ibge_agregado_por_cep <- read_csv2(paste0(dir_ibge,"/Agregados_por_CEP_CNEFE_Censo_2022.zip"))


################################################################################
# Cria o db de endereços unicos na cidade de sp com base no cnefe (rua, titulo, nome e numero)




# Cria logradfull com a concaencao dos componentes do logradrouro para depois criar o enderço únicio a partir do CEP
ibge_cidade_sp_all_addresses$lograd_full <- 
  str_c(ifelse(is.na(ibge_cidade_sp_all_addresses$NOM_TIPO_SEGLOGR),"",ibge_cidade_sp_all_addresses$NOM_TIPO_SEGLOGR),
        " ",
        ifelse(is.na(ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR),"",ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR),
        " ",
        ibge_cidade_sp_all_addresses$NOM_SEGLOGR) %>% str_squish()


# Ajeita latitude e longitude, de -23526868 para -23.526868, passando para numérico (nao basta dividir pois o numero de algarismos pode variar)

  ibge_cidade_sp_all_addresses <-
  ibge_cidade_sp_all_addresses %>%
  mutate(
    LATITUDE = as.numeric(
      sub("^(-?\\d{2})(\\d+)$", "\\1.\\2", LATITUDE)
    ),
    LONGITUDE = as.numeric(
      sub("^(-?\\d{2})(\\d+)$", "\\1.\\2", LONGITUDE)
    )
  )


  # limpa os NAs e NULLs para nao atrapalhar a contagem de logradouros unicos
  ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR[is.null(ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR)] <- ""
  ibge_cidade_sp_all_addresses$NOM_SEGLOGR[is.null(ibge_cidade_sp_all_addresses$NOM_SEGLOGR)] <- ""
  ibge_cidade_sp_all_addresses$NUM_ENDERECO[is.null(ibge_cidade_sp_all_addresses$NUM_ENDERECO)] <- ""
  ibge_cidade_sp_all_addresses$LATITUDE[is.null(ibge_cidade_sp_all_addresses$LATITUDE)] <- NA
  ibge_cidade_sp_all_addresses$LONGITUDE[is.null(ibge_cidade_sp_all_addresses$LONGITUDE)] <- NA
  
  ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR[is.na(ibge_cidade_sp_all_addresses$NOM_TITULO_SEGLOGR)] <- ""
  ibge_cidade_sp_all_addresses$NOM_SEGLOGR[is.na(ibge_cidade_sp_all_addresses$NOM_SEGLOGR)] <- ""
  ibge_cidade_sp_all_addresses$NUM_ENDERECO[is.na(ibge_cidade_sp_all_addresses$NUM_ENDERECO)] <- ""
  ibge_cidade_sp_all_addresses$LATITUDE[is.na(ibge_cidade_sp_all_addresses$LATITUDE)] <- NA
  ibge_cidade_sp_all_addresses$LONGITUDE[is.na(ibge_cidade_sp_all_addresses$LONGITUDE)] <- NA
  
  
# cria db de enderecos unicos ("CEP",lograd_full,"NOM_TIPO_SEGLOGR","NOM_TITULO_SEGLOGR","NOM_SEGLOGR","NUM_ENDERECO") 
# através do group_by, conta o numero de endereços difenretes em cada logradouro unico
# pegar tambem latituide e longitude (max se houver varios)
# nao esqueca de retirar o os NAs e NULLs dos vetores para calcular os max


# cria o db de ruas unicas, bom para corrigir o nome das ruas a partir do CEP
ibge_cidade_sp_unique_streets <- ibge_cidade_sp_all_addresses %>% group_by(CEP,lograd_full) %>% 
  summarise(NOM_TIPO_SEGLOGR = names(which.max(table(NOM_TIPO_SEGLOGR))),
            NOM_TITULO_SEGLOGR = names(which.max(table(NOM_TITULO_SEGLOGR))),
            NOM_SEGLOGR = names(which.max(table(NOM_SEGLOGR))),
            NUM_ENDERECO = names(which.max(table(NUM_ENDERECO))),
            LATITUDE = mean(LATITUDE,na.rm=T),
            LONGITUDE = mean(LONGITUDE,na.rm=T)) %>% ungroup()
ibge_cidade_sp_unique_addresses <- st_as_sf(ibge_cidade_sp_unique_streets, coords = c("LONGITUDE", "LATITUDE"), crs = 4326)



# cria db de logradouros unicos ("CEP",lograd_full,"NOM_TIPO_SEGLOGR","NOM_TITULO_SEGLOGR","NOM_SEGLOGR","NUM_ENDERECO") 
# através do group_by, conta o numero de endereços difenretes em cada logradouro unico
# pegar tambem latituide e longitude (max se houver varios)
# nao esqueca de retirar o os NAs e NULLs dos vetores para calcular os max


dummy <- !duplicated(ibge_cidade_sp_all_addresses[,c("CEP","lograd_full","NUM_ENDERECO")])
ibge_cidade_sp_unique_addresses <-  ibge_cidade_sp_all_addresses[dummy,]


# Salva
saveRDS(ibge_cidade_sp_all_addresses,paste0(dir_core_output,'/ibge_cidade_sp_all_addresses.rds'), compress = "xz")
saveRDS(ibge_cidade_sp_unique_addresses,paste0(dir_core_output,'/ibge_cidade_sp_unique_addresses.rds'), compress = "xz")
saveRDS(ibge_cidade_sp_unique_streets,paste0(dir_core_output,'/ibge_cidade_sp_unique_streets.rds'), compress = "xz")

