# -------------------------------------------------------------------------
# SCRIPT: Geração Criação do banco de dados de ITBIdata:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAbElEQVR4Xs2RQQrAMAgEfZgf7W9LAguybljJpR3wEse5JOL3ZObDb4x1loDhHbBOFU6i2Ddnw2KNiXcdAXygJlwE8OFVBHDgKrLgSInN4WMe9iXiqIVsTMjH7z/GhNTEibOxQswcYIWYOR/zAjBJfiXh3jZ6AAAAAElFTkSuQmCC
# -------------------------------------------------------------------------
  

# -------------------------------------------------------------------------
# CABEÇALHO ORIGINAL (PRESERVADO INTEGRALMENTE)
# -------------------------------------------------------------------------



if (!exists("library_sp_market_loaded")) source("library_sp_market.R", encoding = "Latin1")

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
dir_shiny_itbi <- paste0(dir_raiz, "/shiny_itbi")



# Carregamento otimizado

if(!exists("iptu_unique_id")) {iptu_unique_id <-readRDS(file.path(dir_core_output, "iptu_unique_id.rds")) %>% as.data.table()}
if(!exists("db_itbi")) {db_itbi <- readRDS(file.path(dir_core_output, "db_itbi.rds")) %>% as.data.table()}
if(!exists("db_cep_unique_addresses")){db_cep_unique_addresses <- readRDS(file.path(dir_core_output, "ibge_cidade_sp_unique_addresses.rds"))}

# restringir aos CEPs que comecam com 01, 04 e 05

################################################################
# trecho abaixo cria dbs compactos para o shiny_itbi
################################################################


dummy <- str_sub(iptu_unique_id$`CEP DO IMOVEL`,1,2) %>% {(.=="01")|(.=="04")}#|(.=="05")}
iptu_unique_id_pocket <- iptu_unique_id %>% filter(dummy) %>% as.data.table()
exclude_columns <- c("AREA OCUPADA","BAIRRO DO IMOVEL","CODLOG DO IMOVEL","COMPLEMENTO DO IMOVEL","DATA DO CADASTRAMENTO",
                      "FASE DO CONTRIBUINTE","FATOR DE OBSOLESCENCIA","FRACAO IDEAL","MES DE INICIO DA VIDA DO CONTRIBUINTE",
                      "NUMERO DA NL","NUMERO DO CONDOMINIO","NUMERO DO CONTRIBUINTE","QUANTIDADE DE ESQUINAS/FRENTES","REFERENCIA DO IMOVEL",
                     "TESTADA PARA CALCULO","TIPO DE PADRAO DA CONSTRUCAO","TIPO DE TERRENO","TIPO DE USO DO IMOVEL",
                     "VALOR DO M2 DE CONSTRUCAO","VALOR DO M2 DO TERRENO")
iptu_unique_id_pocket <- iptu_unique_id_pocket %>% dplyr::select(-all_of(exclude_columns))
iptu_unique_id_pocket[, tipo_uso := as.factor(tipo_uso)]
iptu_unique_id_pocket[, padrao_construcao := as.factor(padrao_construcao)]
iptu_unique_id_pocket[, tipo_construcao := as.factor(tipo_construcao)]



dummy <- str_sub(db_itbi$cep,1,2) %>% {(.=="01")|(.=="04")}#|(.=="05")}
db_itbi_pocket <- db_itbi %>% filter(dummy) %>% as.data.table()
dummy <- db_itbi_pocket$data_de_transacao >= as.Date("2015-01-01")
db_itbi_pocket <- db_itbi_pocket[dummy,] %>% as.data.table()
exclude_columns <- c("bairro","referencia","cartorio_de_registro","matricula_do_imovel","situacao_do_sql","testada_m",
  "fracao_ideal","uso_iptu","descricao_do_padrao_iptu","padrao_iptu","descricao_do_padrao_iptu",
  "lat_quadra","lon_quadra","lat_cep","lon_cep","tipo_de_financiamento")

db_itbi_pocket <- db_itbi_pocket %>% dplyr::select(-all_of(exclude_columns))
db_itbi_pocket[, descricao_do_uso_iptu := as.factor(descricao_do_uso_iptu)]
db_itbi_pocket[, natureza_de_transacao := as.factor(natureza_de_transacao)]

dummy <- str_sub(db_cep_unique_addresses$CEP,1,2) %>% {(.=="01")|(.=="04")}#|(.=="05")}
db_cep_unique_addresses_pocket <- db_cep_unique_addresses[dummy,] %>% as.data.table()

setindex(iptu_unique_id_pocket, NULL) # Remove índices automáticos
setkey(iptu_unique_id_pocket, NULL)   # Remove chaves físicas
# Opcional: Reindexar se a coluna for muito usada para filtros
setindex(iptu_unique_id_pocket, "CEP DO IMOVEL")

setindex(db_itbi_pocket, NULL) # Remove índices automáticos
setkey(db_itbi_pocket, NULL)   # Remove chaves físicas
# Opcional: Reindexar se a coluna for muito usada para filtros
setindex(db_itbi_pocket, "cep")

iptu_unique_id_pocket <- iptu_unique_id_pocket %>% factorize()
db_itbi_pocket <- db_itbi_pocket %>% factorize()
db_cep_unique_addresses_pocket <- db_cep_unique_addresses_pocket %>% factorize()

saveRDS(iptu_unique_id_pocket,file.path(dir_shiny_itbi,"iptu_unique_id.rds"))
saveRDS(db_itbi_pocket,file.path(dir_shiny_itbi,"db_itbi.rds"))
saveRDS(db_cep_unique_addresses_pocket,file.path(dir_shiny_itbi,"ibge_cidade_sp_unique_addresses.rds"))

# restringindo a busca para um raio baseado no CEP (todos os ceps no Raio)para evitar
# problemas de performance, o ideal seria usar um raio de 1km, mas para teste usei 600m
# se o epicentro for um endereco, a busca por raio pode ser feita diretamente, mas se for um cep, o ideal seria pegar o centroide do cep e fazer a busca por raio a partir do centroide, para isso, o banco de ceps precisa ter as coordenadas dos centroides dos ceps

epicenter <- "Rua Leopoldo Couto Magalhaes Jr, 758, Itaim bibi,  Sao Paulo"
epicenter <- "Rua Tajá, 109 - Vila Nova Conceição, São Paulo-SP, 04507-040"
epicenter <- "Rua Turquia 333, São Paulo-SP"

epicenter <- "04507-000"
radius <- 2500
ano_final_itbi <- 2026
ano_inicial_itbi <- ano_final_itbi - 10
remove_garagens <- T

# dummy epicenter está em formato de ctp xxxxx-xxx ou xxxxxxxx
dummy_is_cep <- str_detect(epicenter, "^\\d{5}-?\\d{3}$")

if (dummy_is_cep) {
  db_cep_target <- db_cep_unique_addresses %>% filter(CEP == str_replace(epicenter, "-", "")) 
} else {
  coordenadas <- geocode_bulk(epicenter, method = "osm", delay = .001)
  circle_sf <- st_buffer(coords_to_sf(coordenadas$lat, coordenadas$lon), dist = radius,crs = 4326)%>%
    st_transform(st_crs(db_cep_unique_addresses))
  db_cep_target <- st_filter(db_cep_unique_addresses, circle_sf)
}

lista_cep <- db_cep_target$CEP %>% unique() %>% as.character()
db_iptu_target <- iptu_unique_id %>% filter(iptu_unique_id$`CEP DO IMOVEL` %in% lista_cep)
db_iptu_target <- db_iptu_target %>% filter(last_seen==max(last_seen)) # pega só os iptus validos no ultimo ano
db_itbi_target <- db_itbi[sql_key %in% db_iptu_target$sql_key]  # restringe os itbis para os iptus selecionados
db_itbi_target <- db_itbi_target %>% filter(year(data_de_transacao)<=ano_final_itbi & 
                                              year(data_de_transacao)>=ano_inicial_itbi)  # filtra os itbis para os ultimos anos

db_itbi_target %>% names
###################################################################################
# Renomeando colunas para facilitar a integração
###################################################################################

mapeamento_nomes_iptu <- c(
  "sql_key"                        = "sql_key",
  "geo_id"                         = "geo_id",
  "ANO DA CONSTRUCAO CORRIGIDO"    = "Ano_Construcao",
  "ANO DO EXERCICIO"               = "Ano_IPTU",
  "AREA CONSTRUIDA"                = "Area_Construida",
  "CEP DO IMOVEL"                  = "CEP",
  "NOME DE LOGRADOURO DO IMOVEL"   = "Logradouro",
  "NUMERO DO IMOVEL"               = "Numero",
  "QUANTIDADE DE PAVIMENTOS"       = "Andares",
  "last_seen"                      = "last_seen",
  "lograd_cep"                     = "Lograd_CEP",
  "lon_cep"                        = "Lon_CEP",
  "lat_cep"                        = "Lat_CEP",
  "setor_quadra"                   = "Quadra_SQ",
  "tipo_construcao"                = "Tipo",
  "padrao_construcao"              = "Padrao",
  "tipo_uso"                       = "Uso",
  "data_inicio_contribuicao"       = "d0_iptu",
  "TIPO DE USO DO IMOVEL"            = "TIPO DE USO",
  "PADRAO DE CONSTRUCAO DO IMOVEL" = "PADRAO DE CONSTRUCAO"
)

cols_para_manter <- intersect(names(mapeamento_nomes_iptu), names(db_iptu_target))
db_iptu_target <- db_iptu_target[, ..cols_para_manter]


setnames(db_iptu_target, 
         old = names(mapeamento_nomes_iptu[cols_para_manter]), 
         new = unname(mapeamento_nomes_iptu[cols_para_manter]))

mapeamento_nomes_itbi <- c(
  "sql_key"                                    = "sql_key",
  "nome_do_logradouro"                         = "Logradouro",
  "numero"                                     = "Numero",
  "cep"                                        = "CEP",
  "natureza_de_transacao"                      = "Tipo_Transacao",
  "valor_de_transacao_declarado_pelo_contribuinte" = "Valor_Declarado",
  "data_de_transacao"                          = "Data",
  "valor_venal_de_referencia"                  = "Valor_Venal",
  "base_de_calculo_adotada"                    = "Base_de_Calculo",
  "tipo_de_financiamento"                      = "Tipo_Fianciamento",
  "valor_financiado"                           = "valor_financiado",
  "area_construida_m2"                         = "Area_Construida",
  "preco_m2"                                   = "Preco_por_m2",
  "lon_cep"                                    = "Lon_CEP",
  "lat_cep"                                    = "Lat_CEP",
  "lon_quadra"                                 = "Lon_Quadra",
  "lat_quadra"                                 = "Lat_Quadra",
  "proporcao_transmitida_percent"              = "Perc_Vendido"
  
)

cols_para_manter_itbi <- intersect(names(mapeamento_nomes_itbi), names(db_itbi_target))
db_itbi_target <- db_itbi_target[, ..cols_para_manter_itbi]

setnames(db_itbi_target, 
         old = names(mapeamento_nomes_itbi[cols_para_manter_itbi]), 
         new = unname(mapeamento_nomes_itbi[cols_para_manter_itbi]))

db_iptu_target$endereco <- str_c(db_iptu_target$Logradouro, db_iptu_target$Numero, sep = ", ") %>% str_squish() %>% str_to_title()
db_itbi_target$endereco <- str_c(db_itbi_target$Logradouro, db_itbi_target$Numero, sep = ", ") %>% str_squish() %>% str_to_title()
db_iptu_target$Tipo[is.na(db_iptu_target$Tipo)] <- "NA"
db_itbi_target$Tipo <- db_iptu_target$Tipo[match(db_itbi_target$sql_key, db_iptu_target$sql_key)]
db_itbi_target$geo_id <- db_iptu_target$geo_id[match(db_itbi_target$sql_key, db_iptu_target$sql_key)]
db_itbi_target$Uso <- db_iptu_target$Uso[match(db_itbi_target$sql_key, db_iptu_target$sql_key)]
db_itbi_target$Padrao <- db_iptu_target$Padrao[match(db_itbi_target$sql_key, db_iptu_target$sql_key)]


# contar ocorrencias para cada geo_id no db_itbi_target e Tipo e adicionar a coluna num_vendas_geo_id no db_iptu_target

db_iptu_target <- merge(db_iptu_target, 
                         db_itbi_target[, .(num_vendas_geo_id = .N), by = .(geo_id, Tipo)], 
                         by.x = c("geo_id", "Tipo"), 
                         by.y = c("geo_id", "Tipo"), 
                         all.x = TRUE)

#######################################################################################
# Shiny e reactable feitos no gemini
# https://gemini.google.com/app/ca835881aff27b4a
#######################################################################################


library(shiny)
library(shinyWidgets)
library(reactable)
library(htmltools)
library(data.table)
library(stringr)

# -------------------------------------------------------------------------
# 1. TRATAMENTO PRÉVIO E BLINDAGEM DE DADOS
# -------------------------------------------------------------------------
setDT(db_iptu_target)
setDT(db_itbi_target)
db_itbi_target[, Data := as.Date(Data)]

safe_range <- function(x, default_min = 0, default_max = 100) {
  rng <- range(x, na.rm = TRUE)
  if (any(is.infinite(rng)) || any(is.na(rng))) return(c(default_min, default_max))
  return(rng)
}

range_data  <- safe_range(db_itbi_target$Data, Sys.Date()-365, Sys.Date())
range_valor <- safe_range(db_itbi_target$Valor_Declarado, 0, 1000000)
range_preco <- safe_range(db_itbi_target$Preco_por_m2, 0, 15000)
range_area  <- safe_range(db_itbi_target$Area_Construida, 0, 500)

render_timeline <- function(datas, range_total) {
  start <- as.numeric(range_total[1]); end <- as.numeric(range_total[2])
  tags$svg(height = "20", width = "100",
           tags$line(x1 = "0", y1 = "15", x2 = "100", y2 = "15", style = "stroke:#eee; stroke-width:2"),
           if (length(datas) > 0) {
             points_x <- (as.numeric(datas) - start) / (end - start) * 100
             lapply(points_x, function(x) {
               tagList(
                 tags$line(x1 = x, y1 = "15", x2 = x, y2 = "5", style = "stroke:#059669; stroke-width:2"),
                 tags$circle(cx = x, cy = "5", r = "2", fill = "#059669")
               )
             })
           }
  )
}

# -------------------------------------------------------------------------
# 2. UI
# -------------------------------------------------------------------------
ui <- fluidPage(
  theme = shinythemes::shinytheme("flatly"),
  tags$head(
    tags$link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.2.0/css/all.min.css"),
    tags$style(HTML("
      @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;600&display=swap');
      body { background-color: #ffffff; font-family: 'Inter', sans-serif; color: #333; padding: 30px; }
      .filter-section { border-bottom: 1px solid #eee; padding-bottom: 25px; margin-bottom: 25px; }
      .tile-label { font-size: 11px; font-weight: 600; text-transform: uppercase; color: #666; letter-spacing: 1px; margin-bottom: 12px; }
      .btn-group-bootstrap.checkgroupbutton .btn { 
        background-color: #ffffff !important; color: #888 !important; border: 1px solid #e0e0e0 !important; 
        font-size: 12px !important; margin-right: 8px !important; margin-bottom: 8px !important; padding: 6px 12px !important;
      }
      .btn-group-bootstrap.checkgroupbutton .btn.active { 
        background-color: #1a252f !important; color: #ffffff !important; border: 3px solid #000 !important; font-weight: 600 !important;
        box-shadow: 0 4px 6px rgba(0,0,0,0.2) !important;
      }
      .rt-thead { border-bottom: 2px solid #333; border-top: 1px solid #eee; text-transform: uppercase; font-size: 11px; }
      .rt-td { border-bottom: 1px solid #f0f0f0; padding: 10px 8px !important; font-size: 14px; }
      .slider-container { max-width: 1000px; }
    "))
  ),
  
  h2("Painel de Auditoria | Mercado Imobiliário SP", style = "font-weight: 600;"),
  
  div(class = "filter-section",
      div(class = "tile-label", "USO DO IMÓVEL:"),
      checkboxGroupButtons("filtro_uso", NULL, sort(unique(db_itbi_target$Uso)), individual = TRUE, status = "default", size = "sm", checkIcon = list(yes = icon("check"))),
      div(class = "tile-label", "TIPO DE PADRÃO:", style = "margin-top: 15px;"),
      checkboxGroupButtons("filtro_tipo", NULL, sort(unique(db_itbi_target$Tipo)), individual = TRUE, status = "default", size = "sm", checkIcon = list(yes = icon("check"))),
      
      div(class = "slider-container", style = "margin-top: 20px;",
          fluidRow(
            column(6, sliderInput("venda_slider", "Data da Transação:", min = range_data[1], max = range_data[2], value = range_data, timeFormat = "%Y-%m-%d", width = "100%")),
            column(6, sliderInput("slider_valor", "Valor Declarado:", min = 0, max = range_valor[2], value = range_valor, pre = "R$ ", sep = ".", ticks = F, width = "100%"))
          ),
          fluidRow(
            column(6, sliderInput("slider_preco_m2", "Preço por m²:", min = 0, max = range_preco[2], value = range_preco, pre = "R$ ", sep = ".", ticks = F, width = "100%")),
            column(6, sliderInput("slider_area", "Área Construída:", min = 0, max = range_area[2], value = range_area, post = " m²", sep = ".", ticks = F, width = "100%"))
          )
      )
  ),
  
  div(style = "padding: 0 5px;", reactableOutput("tabela_mestre"))
)

# -------------------------------------------------------------------------
# 3. SERVER
# -------------------------------------------------------------------------
server <- function(input, output, session) {
  
  get_usage_icon <- function(uso) {
    uso_clean <- str_to_lower(uso)
    icon <- switch(uso_clean, "apartamento" = "building", "residência" = "house", "loja" = "store", "garagem ou estacionamento" = "car", "terreno" = "map", "circle")
    return(icon)
  }
  
  itbi_filtrado <- reactive({
    data <- db_itbi_target[
      Data >= input$venda_slider[1] & Data <= input$venda_slider[2] &
        Valor_Declarado >= input$slider_valor[1] & Valor_Declarado <= input$slider_valor[2] &
        Preco_por_m2 >= input$slider_preco_m2[1] & Preco_por_m2 <= input$slider_preco_m2[2] &
        Area_Construida >= input$slider_area[1] & Area_Construida <= input$slider_area[2]
    ]
    if (length(input$filtro_uso) > 0) data <- data[Uso %in% input$filtro_uso]
    if (length(input$filtro_tipo) > 0) data <- data[Tipo %in% input$filtro_tipo]
    data
  })
  
  db_l1_reativo <- reactive({
    v <- itbi_filtrado()
    resumo <- db_iptu_target[, .(
      endereco = {
        tab_end <- table(endereco)
        if (length(tab_end) == 0) NA_character_ else names(tab_end)[which.max(tab_end)]
      },
      Unidades = .N,
      Vendas   = as.integer(v[geo_id == .BY$geo_id & Tipo == .BY$Tipo, .N]),
      Historico = list(v[geo_id == .BY$geo_id & Tipo == .BY$Tipo, sort(Data)]),
      Ultima_Venda = {
        d <- v[geo_id == .BY$geo_id & Tipo == .BY$Tipo, Data]
        if (length(d) == 0) as.Date(NA) else max(d, na.rm = TRUE)
      },
      Area_Media   = mean(Area_Construida, na.rm = TRUE)
    ), by = .(geo_id, Tipo)] 
    resumo
  })
  
  output$tabela_mestre <- renderReactable({
    data_master <- db_l1_reativo()
    req(data_master)
    
    reactable(
      data_master,
      fullWidth = FALSE, compact = TRUE, highlight = TRUE,
      columns = list(
        geo_id   = colDef(name = "ID Geo", width = 125, style = list(fontFamily = "monospace")),
        Tipo     = colDef(name = "Tipo", width = 70, align = "center", style = list(fontWeight = 600, color = "#004a99")),
        endereco = colDef(name = "Endereço (Ref)", width = 300),
        Historico = colDef(name = "Histórico Vendas", width = 130, align = "center",
                           cell = function(val) render_timeline(val, input$venda_slider)),
        Unidades = colDef(name = "Unidades", width = 80, align = "center"),
        Vendas   = colDef(name = "Vendas", width = 80, align = "center", style = list(fontWeight = 600)),
        Ultima_Venda = colDef(name = "Última Venda", width = 120, align = "center", na = "Sem Registro"),
        Area_Media   = colDef(name = "Área Média", width = 110, align = "right", format = colFormat(digits = 1, suffix = " m²"))
      ),
      details = function(index) {
        if (data_master$Vendas[index] == 0) return(div(style = "padding: 15px; color: #999;", "Nenhuma transação registrada para este filtro."))
        
        target_geo  <- data_master$geo_id[index]
        target_tipo <- data_master$Tipo[index]
        v_detalhe   <- itbi_filtrado()[geo_id == target_geo & Tipo == target_tipo]
        
        # --- ORDENAÇÃO DECORRESCENTE POR DATA ---
        setorder(v_detalhe, -Data)
        
        reactable(
          v_detalhe[, .(Data, Icone = Uso, sql_key, Preco_por_m2, Valor_Declarado, valor_financiado, Valor_Venal, Area_Construida, Uso_Texto = Uso)],
          fullWidth = FALSE, compact = TRUE, bordered = TRUE,
          columns = list(
            Data    = colDef(name = "Data", width = 120, align = "center"),
            Icone   = colDef(name = "", width = 45, align = "center", cell = function(v){
              tags$i(class = paste0("fa-solid fa-", get_usage_icon(v)), style = "color: #333; font-size: 12px;")
            }),
            sql_key = colDef(name = "SQL", width = 130, style = list(fontFamily = "monospace", fontSize = "12px")),
            Preco_por_m2 = colDef(name = "$/m²", width = 100, align = "right", format = colFormat(separators = TRUE, digits = 0)),
            Valor_Declarado = colDef(name = "Vlr Decl", width = 110, align = "right", format = colFormat(separators = TRUE, digits = 0)),
            valor_financiado = colDef(name = "Financ", width = 110, align = "right", format = colFormat(separators = TRUE, digits = 0)),
            Valor_Venal = colDef(name = "Vlr Venal", width = 110, align = "right", format = colFormat(separators = TRUE, digits = 0)),
            Area_Construida = colDef(name = "Área", width = 90, align = "right", format = colFormat(digits = 1, suffix = " m²")),
            Uso_Texto = colDef(name = "Uso Detalhado", width = 200, style = list(color = "#666", fontSize = "12px"))
          )
        )
      }
    )
  })
}

shinyApp(ui, server)
