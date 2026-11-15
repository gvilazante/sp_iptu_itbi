# =============================================================================
# Setup: Working directory, paths, environment variables, and libraries
# =============================================================================


Sys.setenv(TZ = "Brazil/East")
if (!("this.path" %in% installed.packages())) install.packages("this.path")
base_directory <- this.path::this.dir() # set path to the current directory of the file
if (base_directory != getwd()) setwd(base_directory)
setwd(base_directory)
dir_raiz <- base_directory
dir_sub <- "/DB"
dir_base <- paste0(dir_raiz, dir_sub, "/")
library_sp_market_loaded <<- T
Sys.setenv(TZ = "Brazil/East")
Sys.setenv("OGR_GEOMETRY_ACCEPT_UNCLOSED_RING" = "NO") # Instruct GDAL to reject non-closed rings

# [2026-11-15] Chaves de API movidas para 1_pipeline_R/.Renviron, fora do Git (ver docs/decisoes.md, D-001)
if (file.exists(".Renviron")) readRenviron(".Renviron")
google_register_key <- Sys.getenv("GOOGLE_API_KEY") # conta Guilherme vilazante
Sys.setenv(GOOGLEGEOCODE_API_KEY = google_register_key)

####### Installation of Libraries (load or install if needed)
{
  load.lib <- sort(c(
    "tidyverse", "dplyr", "devtools", "pracma", "tidyquant", "magrittr", "purrr", "lubridate", "ltm",
    "TTR", "tictoc", "forecast", "forcats", "BBmisc", "prettyunits", "rlist", "rstudioapi", "splashr", "wdman",
    "janitor", "Tmisc", "stringr", "readr", "readxl", "utils", "XML", "taskscheduleR", "textclean",
    "stringi", "clock", "writexl", "imager", "jpeg", "here", "magick", "SimDesign", "filesstrings",
    "dbscan", "stringdist", "RecordLinkage", "kit", "fs", "arrow", "duckplyr",
    "GGally", "igraph", "ggplot2", "ggthemes", "ggmap", "mapview", "foreign", "ggplotgui",
    "ggThemeAssist", "ggplotAssist", "ggedit", "ggside", "googleway", "sp", "sf", "geosphere",
    "leaflet", "leafpop", "leafem", "lwgeom", "plotly", "google_places", "tidygeocoder","reactable",
    "shiny","shinythemes","shinydashboard","shinyWidgets","shinyjs","shinycssloaders","shinytest2","DT","plotly"
  ))

  if (exists("pocket_libraries") && pocket_libraries == T) {
    load.lib <- sort(c(
      "conflicted", "duckplyr", "arrow", "fs",
      "tidyverse", "dplyr", "devtools", "tidyquant", "magrittr", "purrr", "lubridate",
      "TTR", "tictoc", "forecast", "forcats", "BBmisc", "prettyunits", "rlist", "rstudioapi", "splashr", "wdman",
      "janitor", "Tmisc", "stringr", "readr", "readxl", "utils", "XML", "taskscheduleR", "textclean",
      "stringi", "clock", "writexl", "imager", "jpeg", "here", "magick", "SimDesign", "filesstrings",
      "dbscan", "stringdist", "RecordLinkage", "kit",
      "ggplot2", "ggthemes", "ggmap", "mapview",
      "ggThemeAssist", "ggplotAssist", "ggedit", "ggside", "googleway", "sp", "sf", "geosphere",
      "leaflet", "leafpop", "leafem", "lwgeom", "plotly", "google_places", "tidygeocoder"
    ))
  }

  install.lib <- load.lib[!load.lib %in% installed.packages()]
  for (lib in install.lib) install.packages(lib, dependencies = TRUE, quiet = T)
  sapply(load.lib, require, character = TRUE)
}

# =============================================================================
# Functions
# =============================================================================

# --- harmonize_columns ---
# Description:
#   Harmonizes the classes of specified columns between two data frames.
# Inputs:
#   - dbA, dbB: Data frames to harmonize.
#   - names_A, names_B: Vectors of column names (from dbA and dbB, respectively) to be harmonized.
# Output:
#   - A list with elements "dbA" and "dbB" containing the harmonized data frames.
harmonize_columns <- function(dbA, dbB, names_A, names_B) {
  for (i in seq_along(names_A)) {
    colA <- dbA[[names_A[i]]]
    colB <- dbB[[names_B[i]]]
    if (is.character(colA) || is.character(colB)) {
      dbA[[names_A[i]]] <- as.character(colA)
      dbB[[names_B[i]]] <- as.character(colB)
    } else if (is.numeric(colA) || is.numeric(colB)) {
      dbA[[names_A[i]]] <- as.numeric(colA)
      dbB[[names_B[i]]] <- as.numeric(colB)
    } else if (is.double(colA) || is.double(colB)) {
      dbA[[names_A[i]]] <- as.double(colA)
      dbB[[names_B[i]]] <- as.double(colB)
    } else if (is.integer(colA) || is.integer(colB)) {
      dbA[[names_A[i]]] <- as.integer(colA)
      dbB[[names_B[i]]] <- as.integer(colB)
    }
  }
  return(list(dbA = dbA, dbB = dbB))
}

# --- multi_match ---
# Description:
#   Performs matching on multiple columns between two data frames.
# Inputs:
#   - dbA, dbB: Data frames.
#   - namesA, namesB: (Optional) Vectors of column names for matching (defaults to all names if NA).
# Output:
#   - A vector of row indices from dbB that correspond to matching rows in dbA.
multi_match <- function(dbA, dbB, namesA = NA, namesB = NA) {
  dbA <- as_tibble(dbA)
  dbB <- as_tibble(dbB)
  if (any(is.na(namesA))) {
    namesA <- names(dbA)
  }
  if (any(is.na(namesB))) {
    namesB <- namesA
    names(dbB) <- namesA
  }
  dbB$counter <- 1:NROW(dbB)
  if (any(sapply(dbA[, namesA], class) != sapply(dbB[, namesB], class))) {
    print("colunas incompatíveis, processo de hamonização")
    dbA_dbB_harmonized <- harmonize_columns(dbA, dbB, namesA, namesB)
    dbA <- dbA_dbB_harmonized$dbA
    dbB <- dbA_dbB_harmonized$dbB
    print("processo de hamonização completo, não se preocupe")
  }

  dbB <- dbB %>% distinct(across(all_of(namesB)), .keep_all = T)
  multi_matches <- left_join(dbA, dbB, by = setNames(namesB, namesA))
  output <- multi_matches$counter %>%
    unlist() %>%
    unname()
  return(output)
}



# =============================================================================================
# FUNÇÃO: multi_match_dt
# DESCRIÇÃO: Extensão multidimensional da função match() utilizando a engine data.table.
#            Realiza o lookup de índices entre dois datasets (dbA em dbB) com base em múltiplas
#            chaves, retornando a posição da primeira ocorrência encontrada. Inclui etapa de
#            harmonização de tipos de dados para garantir compatibilidade das chaves.
#
# PARÂMETROS:
#   - dbA:    Dataset de origem (target) onde se busca obter os índices.
#   - dbB:    Dataset de referência (lookup table).
#   - namesA: Vetor de caracteres com os nomes das colunas de busca em dbA.
#   - namesB: Vetor de caracteres com os nomes das colunas correspondentes em dbB.
#
# PERFORMANCE:
#   - Utiliza Joins de Atribuição (Non-copying) e Radix Sort para busca O(n log n).
#   - Harmonização condicional: só processa se houver mismatch de classe entre as chaves.
#   - Comportamento idêntico ao match() (mult = "first", nomatch = NA).
# =============================================================================================

library(data.table)

multi_match_dt <- function(dbA, dbB, namesA = NULL, namesB = NULL) {
  # 1. Normalização de nomes de colunas
  if (is.null(namesA)) namesA <- names(dbA)
  if (is.null(namesB)) namesB <- namesA

  # 2. Verificação e Harmonização de Classes
  # Comparamos as classes das colunas de busca entre dbA e dbB
  classesA <- sapply(dbA[, namesA, with = FALSE], class)
  classesB <- sapply(dbB[, namesB, with = FALSE], class)

  if (!all(classesA == classesB)) {
    message("Colunas incompatíveis detectadas. Iniciando processo de harmonização...")
    harmonized <- harmonize_columns(dbA, dbB, namesA, namesB)
    dbA <- harmonized$dbA
    dbB <- harmonized$dbB
    message("Processo de harmonização completo.")
  }

  # 3. Preparação para Data.Table (Shallow copy)
  dtA <- as.data.table(dbA)
  dtB <- as.data.table(dbB)

  # 4. Criação da Lookup Table minimalista
  # O índice original .I é preservado para o retorno
  dtB_work <- dtB[, .(idx = .I), by = c(namesB)]

  # 5. Join de Atribuição (Lookup)
  # mult = "first": simula match() pegando apenas a primeira ocorrência
  # x.idx: extrai o vetor de índices resultante
  output <- dtB_work[dtA, on = setNames(namesB, namesA), mult = "first", x.idx]

  return(output)
}


# --- kmz_to_sf ---
# Description:
#   Unzips a KMZ file and reads its content as an sf object.
# Inputs:
#   - kmz_path: Path to the KMZ file.
# Output:
#   - An sf object reprojected to CRS 5533.
kmz_to_sf <- function(kmz_path) {
  dir_base <- getwd()
  dir_temp <- paste0(dir_base, "/temp_kmz")
  output <- unzip(kmz_path, exdir = dir_temp, overwrite = T) %>%
    st_read() %>%
    st_transform(crs = 5533)
  unlink(dir_temp, recursive = TRUE)
  return(output)
}

# --- shp_zipped_to_sf ---
# Description:
#   Unzips a zipped shapefile and returns it as an sf object.
# Inputs:
#   - shp_path: Path to the zipped shapefile.
# Output:
#   - An sf object reprojected to CRS 31983.
shp_zipped_to_sf <- function(shp_path) {
  dir_base <- str_before_last(shp_path, "/")
  dir_temp <- paste0(dir_base, "/temp_shp")
  output <- unzip(shp_path, exdir = dir_temp, overwrite = T)
  output <- output[1] %>%
    str_before_last_dot() %>%
    paste0(., ".shp") %>%
    read_sf() %>%
    st_transform(crs = 31983)
  unlink(dir_temp, recursive = TRUE)
  return(output)
}

# --- closest_point_in_polygon ---
# Description:
#   Finds the closest point on an sf polygon to a given sf point.
# Inputs:
#   - sf_point: An sf point.
#   - sf_polygon: An sf polygon.
# Output:
#   - A list with:
#       lat, lon: Coordinates of the closest point,
#       distance: Distance between the points,
#       closest_point_sf: The sf point of the closest location.
closest_point_in_polygon <- function(sf_point, sf_polygon) {
  if (st_crs(sf_point) != st_crs(sf_polygon)) {
    stop("Objects must have the same CRS.")
  }
  nearest_points <- st_nearest_points(sf_point, sf_polygon)
  points_A <- st_cast(nearest_points, "POINT")[seq(1, length(nearest_points) * 2, by = 2)]
  points_B <- st_cast(nearest_points, "POINT")[seq(2, length(nearest_points) * 2, by = 2)]
  distance_a_b <- st_distance(points_A, points_B, by_element = TRUE) %>% as.numeric()
  closest_point_coords <- coordenada_do_sf(points_B)
  lat <- closest_point_coords$lat
  lon <- closest_point_coords$lon
  list(lat = lat, lon = lon, distance = distance_a_b, closest_point_sf = points_B)
}

# --- closest_point_btw_sfs ---
# Description:
#   Computes the closest points between two sf objects.
# Inputs:
#   - sf_A, sf_B: Two sf objects.
# Output:
#   - A list with:
#       sfA, sf_B: The (possibly reprojected) input objects,
#       nearest_A, nearest_B: Nearest points on each,
#       distance: The distance between these points.
closest_point_btw_sfs <- function(sf_A, sf_B) {
  if (st_crs(sf_A) != st_crs(sf_B)) {
    print("Objects must have the same CRS, fixing it")
    sf_A <- st_transform(sf_A, crs = 31983)
    sf_B <- st_transform(sf_B, crs = 31983)
  }
  nearest_points <- st_nearest_points(sf_A, sf_B)
  point_A <- st_cast(nearest_points, "POINT")[seq(1, length(nearest_points) * 2, by = 2)]
  point_B <- st_cast(nearest_points, "POINT")[seq(2, length(nearest_points) * 2, by = 2)]
  distance_a_b <- st_distance(point_A, point_B, by_element = TRUE) %>% as.numeric()
  list(sfA = sf_A, sf_B = sf_B, nearest_A = point_A, nearest_B = point_B, distance = distance_a_b)
}

# --- generate_points ---
# Description:
#   Generates evenly spaced points along an sf line.
# Inputs:
#   - sf_line: An sf object representing a line.
#   - n_points: Number of points to generate.
# Output:
#   - An sf object containing the generated points.
generate_points <- function(sf_line, n_points) {
  st_line_sample(sf_line, n = n_points, type = "regular") %>%
    st_cast("POINT") %>%
    st_sf()
}

# --- fix_logradouro ---
# Description:
#   Normalizes and standardizes street names.
# Inputs:
#   - string: A character string with the street name.
#   - remove_de: Logical flag; if TRUE, removes articles like " DE ".
# Output:
#   - A normalized street name string.
from_to <- read_xlsx("titulos_ajustes_logradouros.xlsx", sheet = "OUTPUT_R")
from_to$to <- str_squish(from_to$to) %>% str_c(" ", ., " ")
from_to$from <- str_squish(from_to$from) %>% str_c(" ", ., " ")
from_to <- from_to[!is.na(from_to$to) & !is.na(from_to$from), ]
fix_logradouro <- function(string, remove_de = F) {
  string <- string %>%
    toupper() %>%
    str_c(" ", ., " ") %>%
    str_replace_all("\\.", " ") %>%
    str_replace_all("'", " ") %>%
    str_replace_all("-", " ") %>%
    stri_replace_all_fixed(from_to$from, from_to$to, vectorize_all = F)
  if (remove_de) {
    string <- string %>% stri_replace_all_fixed(c(" DE ", " DAS ", " DA ", " DOS ", " DO "),
      c(" ", " ", " ", " ", " "),
      vectorize_all = F
    )
  }
  str_squish(string)
}

# --- bairros_airbnb ---
# Description:
#   Retrieves and groups neighborhood URLs from an Excel file.
# Inputs:
#   - search_name: Group name or code from the Excel file.
#   - bin_size: Number of neighborhoods per group.
# Output:
#   - A concatenated string for use in Airbnb queries.
bairros_airbnb <- function(search_name = "sp_city", bin_size = 1) {
  tryCatch({
    bairros_zap <- tibble(read_xlsx(paste0(dir_base, "neighborhood.xlsx")) %>% filter(!is.na(place_code)))
  })
  if (search_name %in% names(bairros_zap)) {
    chain <- bairros_zap$place_url[dplyr::select(bairros_zap, all_of(search_name)) == 1 & !is.na(dplyr::select(bairros_zap, search_name))]
    chain <- agrupamento(chain, bin_size, separador = ";,")
    return(chain)
  } else {
    if (search_name %in% bairros_zap$place_code) {
      chain <- bairros_zap$place_url[bairros_zap$place_code == search_name]
      chain <- agrupamento(chain, bin_size, separador = ";,")
      return(chain)
    } else {
      if (all(sapply(search_name, is_valid_url))) {
        url_onde_output <- param_get(search_name, "onde") %>%
          dplyr::select(c("onde")) %>%
          as.list() %>%
          sapply(., function(x) {
            if (str_detect(str_sub(x, 1, 1), ",")) {
              substring(x, 2, nchar(x))
            } else {
              x
            }
          })
        chain <- agrupamento(url_onde_output, bin_size, separador = ";,")
      } else {
        return(NA)
      }
    }
  }
}

# --- read_html_selenium ---
# Description:
#   Retrieves an HTML page via RSelenium if available; otherwise uses httr.
# Inputs:
#   - url_target: The URL to fetch.
#   - source_out: Logical flag; if TRUE, returns the source as text.
# Output:
#   - The parsed HTML or its source text.
read_html_selenium <- function(url_target = html_ref, source_out = F) {
  page <- NA
  if (!exists("selenium_dummy") == T) selenium_dummy <- F
  url_source <- ifelse(source_out, paste0("view-source:", url_target), url_target)
  tryCatch({
    if (selenium_dummy == T) {
      remote_driver$navigate(url_source)
      page <- read_html(remote_driver$getPageSource()[[1]])
      if (source_out) {
        page <- as.character(page)
      }
      url_do_zap <<- remote_driver$getCurrentUrl()[[1]] %>%
        ifelse(source_out, str_replace(., "view-source:", ""), .)
    } else {
      page <- httr::GET(url_target) %>% httr::content("parsed")
      if (source_out) {
        page <- html_text2(page)
      }
    }
  })
  return(page)
}



# Função para geocodificação em lote com delay entre solicitações
geocode_bulk <- function(enderecos, method = "osm", delay = .1, api = NULL) {
  # Input:
  # - enderecos: Um vetor de strings contendo os endereços a serem geocodificados.
  # - method: O método de geocodificação a ser usado. Pode ser:
  #   - "osm": Nominatim do OpenStreetMap (gratuito, 1 solicitação/segundo).
  #   - "census": US Census Bureau (gratuito, apenas para endereços nos EUA).
  #   - "google": Google Maps API (precisa de chave de API, 40.000 solicitações/mês).
  #   - "here": HERE API (precisa de chave de API, 250.000 solicitações/mês).
  #   - "mapbox": Mapbox API (precisa de chave de API, 100.000 solicitações/mês).
  #   - "tomtom": TomTom API (precisa de chave de API, 2.500 solicitações/dia).
  #   - "arcgis": ArcGIS Online (precisa de chave de API, 1.000 solicitações/mês).
  #   - "opencage": OpenCage Data API (precisa de chave de API, 2.500 solicitações/dia).
  #   - "geocodio": Geocodio API (precisa de chave de API, 2.500 solicitações/dia).
  # - delay: Tempo de atraso (em segundos) entre cada solicitação para respeitar o limite de taxa do serviço.

  # Inicializa um dataframe vazio para armazenar os resultados
  check_and_load_packages(c("tidygeocoder", "dplyr"))
  results <- data.frame(endereco = character(), lat = numeric(), lon = numeric(), stringsAsFactors = FALSE)

  # Loop através de cada endereço no vetor fornecido
  for (endereco in enderecos) {
    # Geocodifica o endereço atual usando o método especificado
    endereco <- tibble(address = endereco)
    result <- tidygeocoder::geocode(endereco, method = method, address = "address", )

    # Adiciona os resultados de lat/lon ao dataframe de resultados
    results <- rbind(results, data.frame(endereco = endereco, lat = result$lat, lon = result$long))

    # Adiciona um atraso entre as solicitações para evitar o bloqueio de IP
    Sys.sleep(delay)
  }

  # Output:
  # - results: Um dataframe com três colunas:
  #   - endereco: O endereço original.
  #   - lat: A latitude geocodificada para o endereço.
  #   - lon: A longitude geocodificada para o endereço.

  return(results)
}



#### Função Coordenada do SF - coordenada_do_sf(x_sf)
# in: vetor lat e vetor longitude
# out: lista de sfs ##############%
############################################## %
coords_to_sf <- function(lat_in, lon_in) {
  lat_in <- as.numeric(lat_in)
  lon_in <- as.numeric(lon_in)

  output <- lapply(1:length(lon_in), function(x) {
    st_point(c(lon_in[x], lat_in[x]))
  }) %>%
    st_sfc(crs = 4326) %>%
    st_transform(5533) %>%
    st_as_sf() %>%
    st_make_valid()
  return(output[[1]])
}




####### Função Coordenada do Endereço - coord_endereco(enrereco) ######%
# in: lista com string de endereços, kind of output: "latlon", "latlona", "more", or "all"
# out: sf com coordenadas e texto do endereço
######################################################################## %
coord_endereco <- function(endereco, output = "latlon", method = "osm") {
  # latlon (default) só lat e long, latlona lat, lon e endereço, more e all

  temp <- geocode_bulk(endereco, delay = .1, method = method)

  lat_in <- temp$lat
  lon_in <- temp$lon
  coords <- st_point(c(lon_in, lat_in))
  coords <- st_sfc(coords, crs = 4326)
  coords <- st_transform(coords, 5533)
  coords <- st_as_sf(coords)

  # mapview(coords)

  # leaflet(coords) %>%
  #   addTiles() %>%
  #   addMarkers(lng = lon_in, lat = lat_in, popup = endereco)

  # register_google(key=google_api_key)

  # coordenada no formato SF / Geocode
  #
  # google_info<-geocode(endereco,output = output)
  # if(output=="all"){
  #   lat_in <- google_info$results[[1]]$geometry$location$lat
  #   lon_in <- google_info$results[[1]]$geometry$location$lng
  # } else {
  #   lat_in<-as.numeric(google_info[["lat"]])
  #   lon_in<-as.numeric(google_info[["lon"]])
  # }
  # coords<-st_point(c(lon_in,lat_in))
  # coords<-st_sfc(coords,crs=4326)
  # coords<-st_transform(coords,5533)
  # coords<-st_as_sf(coords)
  return(list(point_sf = coords, lat = lat_in, lon = lon_in, full_info = NA))
}



#### Função Coordenada do SF - coordenada_do_sf(x_sf)
# in: vetor lat e vetor longitude
# out: lista de sfs ##############%
############################################## %
sf_to_coordinates <- function(sf_object) {
  if (inherits(sf_object, "sf") & inherits(sf_object, "data.frame")) {
    if (sf::st_geometry_type(sf_object)[1] == "POINT") {
      coords <- sf::st_coordinates(st_transform(sf_object, crs = 4326))
      lat <- coords[, 2]
      lon <- coords[, 1]
      # return(coords)
      output <- tibble(lat = lat, lon = lon)
      return(output)
    } else {
      stop("The sf object is not of POINT geometry type.")
    }
  } else {
    stop("The input is not a sf object.")
  }
}


#' Calcular Bounding Box para filtragem prévia de coordenadas
#' 
#' @param lat Latitude central em graus decimais (WGS84).
#' @param lon Longitude central em graus decimais (WGS84).
#' @param radius_m Raio de busca em metros.
#' @return Lista com os limites min/max de latitude e longitude.
coord_bounding_box <- function(lat, lon, radius_m) {
  
  # 1. Delta Latitude:
  # A distância entre paralelos é constante (~111.1 km por grau).
  # Divisão do raio pela constante em metros para obter o deslocamento em graus.
  delta_lat <- radius_m / 111100
  
  # 2. Delta Longitude (Correção de Convergência):
  # A distância entre meridianos encurta conforme nos aproximamos dos polos.
  # A distância de 1 grau de longitude é proporcional ao cosseno da latitude:
  # d = 111100 * cos(lat). Convertemos lat para radianos (pi/180).
  delta_lon <- radius_m / (111100 * cos(lat * pi / 180))
  
  # Retorna os limites para uso direto no data.table::between()
  return(list(
    lat_min = lat - delta_lat,
    lat_max = lat + delta_lat,
    lon_min = lon - delta_lon,
    lon_max = lon + delta_lon
  ))
}





# --- coordinates_to_dbsf (for Zap) ---
coordinates_to_dbsf <- function(data, lat_col = "lat", lon_col = "lon", crs = 4326) {
  data %>%
    rowwise() %>%
    mutate(
      geometry = if (is.na(.data[[lat_col]]) | is.na(.data[[lon_col]])) {
        st_sfc(st_point(), crs = crs)
      } else {
        st_sfc(st_point(c(.data[[lon_col]], .data[[lat_col]])), crs = crs)
      }
    ) %>%
    ungroup() %>%
    st_as_sf()
}

# --- coordenada_do_sf ---
coordenada_do_sf <- function(x_sf) {
  centroide <- if (st_is(x_sf, "POINT")) {
    st_transform(x_sf, crs = 4326)
  } else {
    st_transform(st_centroid(x_sf), crs = 4326)
  }
  coord_list <- unlist(st_coordinates(centroide))
  coordenadas <- coord_list[c(2, 1)]
  names(coordenadas) <- c("lat", "lon")
  return(list("lat" = coordenadas[1], "lon" = coordenadas[2], "latlon" = coordenadas, "objeto" = x_sf))
}

# --- coord_to_pois_google (for Zap) ---
coord_to_pois_google <- function(lat = NA, lon = NA, category = "all", radius = 400, output = "simplified") {
  google_api_query_res <- google_places(place_type = category, location = c(lat, lon), radius = radius, key = google_register_key)
  temp <- google_api_query_res %>%
    pluck("results") %>%
    flattenlist()
  temp_simplified <- list()
  temp_simplified$lat <- temp$geometry$location$lat
  temp_simplified$lon <- temp$geometry$location$lng
  temp_simplified$place_id <- temp$place_id
  temp_simplified$address <- temp$formatted_address
  temp_simplified$name <- temp$name
  temp_simplified$business <- map(1:length(temp$name), function(x) {
    name <- paste0("types", x)
    pluck(temp, name) %>%
      .[. != "point_of_interest"] %>%
      .[. != "establishment"] %>%
      pluck(1)
  }) %>% unlist()
  temp_simplified$num_rating <- temp$user_ratings_total
  temp_simplified$rating <- temp$rating
  if (output == "simplified") {
    return(list(lat = temp_simplified$lat, lon = temp_simplified$lon, name = temp_simplified$name))
  } else {
    return(list(lat = temp_simplified$lat, lon = temp_simplified$lon, name = temp_simplified$name, db = temp))
  }
}

# --- web_mapview_html ---
# Description:
#   Creates a web page from a map (mapview or leaflet) and opens it in a browser.
# Inputs:
#   - mapa_mapview: A map object.
#   - url_name: Output HTML file name (default is "saida.html" in the working directory).
# Output:
#   - Opens the HTML page in a browser.
web_mapview_html <- function(mapa_mapview, url_name = "") {
  if (url_name == "") {
    url_name <- paste0(getwd(), "/saida.html")
  }
  mapshot(mapa_mapview, url = url_name)
  return(browseURL(url_name))
}

# --- plotar_google_maps_lotes ---
# Description:
#   Creates a Google Maps page displaying spatial lot data.
# Inputs:
#   - sf_core: An sf object with the lot data.
# Output:
#   - A map object rendered via google_map.
plotar_google_maps_lotes <- function(sf_core) {
  flags <- FALSE
  key_vila <- google_register_key
  output <- google_map(key = key_vila, split_view = "pano") %>%
    add_polygons(
      data = sf_core, polyline = "geometry",
      fill_colour = "#3C8D93", fill_opacity = 0.5,
      stroke_colour = "#003B32", stroke_opacity = 0.9, stroke_weight = 0.8,
      mouse_over = "label", info_window = "id_sf"
    ) %>%
    add_polygons(
      data = sf_noncore,
      fill_colour = "#9FAFBF", fill_opacity = 0.1,
      stroke_colour = "#3C8D93", stroke_opacity = 0.4, stroke_weight = 0.5,
      mouse_over = "label", info_window = "id_sf"
    )
  if (flags == T) {
    message("Flags Plot Google 4")
  }
  return(output)
}

# --- geo_filter_airbnb ---
# Description:
#   Filters the Airbnb work database by geography and parameters.
# Inputs:
#   - address: A reference address.
#   - radius: A numeric vector (min, max) for search radius.
#   - neighbs, city_neighb: Optional neighborhood or city filters.
#   - guests, baths, beds, bedrooms: Occupancy filter vectors.
#   - price_range: Price range (min, max).
#   - air, wifi, pool, gym, pets, park, kitchen, superhost: Amenity flags (as "sn", "s", or "n").
#   - min_reviews: Minimum number of reviews.
#   - last_seen_months: Time filter in months.
# Output:
#   - A filtered data frame from the Airbnb work database.
geo_filter_airbnb <- function(address = "edificio copan, sao Paulo",
                              radius = c(0, 300),
                              neighbs = NULL,
                              city_neighb = NULL,
                              guests = 0:20,
                              baths = 0:20,
                              beds = 0:20,
                              bedrooms = c(0, 20),
                              price_range = c(10, 5000),
                              air = "sn",
                              wifi = "sn",
                              pool = "sn",
                              gym = "sn",
                              pets = "sn",
                              park = "sn",
                              kitchen = "sn",
                              superhost = "sn",
                              min_reviews = 0,
                              last_seen_months = 200) {
  superhost <- case_when(superhost == "s" ~ T, superhost == "n" ~ F, superhost == "sn" ~ c(T, F))
  air <- case_when(air == "s" ~ T, air == "n" ~ F, air == "sn" ~ c(T, F))
  wifi <- case_when(wifi == "s" ~ T, wifi == "n" ~ F, wifi == "sn" ~ c(T, F))
  pool <- case_when(pool == "s" ~ T, pool == "n" ~ F, pool == "sn" ~ c(T, F))
  gym <- case_when(gym == "s" ~ T, gym == "n" ~ F, gym == "sn" ~ c(T, F))
  pets <- case_when(pets == "s" ~ T, pets == "n" ~ F, pets == "sn" ~ c(T, F))
  park <- case_when(park == "s" ~ T, park == "n" ~ F, park == "sn" ~ c(T, F))
  kitchen <- case_when(kitchen == "s" ~ T, kitchen == "n" ~ F, kitchen == "sn" ~ c(T, F))
  dir_raiz <- (dirname(rstudioapi::getActiveDocumentContext()$path))
  if (!exists("library_airbnb_loaded")) source(paste0("library_airbnb.R"))
  dir_sub <- "/DB"
  dir_base <- paste0(dir_raiz, dir_sub, "/")
  dir_zap <- str_replace(tolower(dir_base), "airbnb", "zap_imoveis_update")
  if (!exists("db_work_airbnb")) {
    db_work_airbnb <<- read_rds(paste0(dir_base, "db_work_new.rds"))
  }
  dummy <- rep(T, NROW(db_work_airbnb)) &
    db_work_airbnb$guests %in% guests &
    db_work_airbnb$baths %in% baths &
    db_work_airbnb$beds %in% beds &
    db_work_airbnb$bedroom %in% bedrooms &
    db_work_airbnb$superhost %in% superhost &
    between(db_work_airbnb$gross_rate, price_range[1], price_range[2]) &
    db_work_airbnb$dummy_air %in% air &
    db_work_airbnb$dummy_wifi %in% wifi &
    db_work_airbnb$dummy_kitchen %in% kitchen &
    db_work_airbnb$dummy_parking %in% park &
    db_work_airbnb$dummy_pool %in% pool &
    db_work_airbnb$review_num >= min_reviews &
    (as.Date(db_work_airbnb$last_seen) >= (today() %m-% months(last_seen_months)))
  dummy[is.na(dummy)] <- F
  db_foco <- db_work_airbnb[dummy, ]
  if (is.null(neighbs)) {
    output_radius <- neighbors_address(
      lat_vector = db_foco$lat,
      lon_vector = db_foco$lon,
      address = address,
      radius = radius
    )
    db_foco_raio <- db_foco[output_radius$choosen_lines, ]
  } else {
    choosen_lines <- st_intersects(coords_to_sf(db_foco$lat, db_foco$lon),
      pluck(neighb_polygon(city_ref = city_neighb, neighb_ref = neighbs), "polygon"),
      sparse = F
    ) %>% which()
    db_foco_raio <- db_foco[choosen_lines, ]
  }
}

# --- geo_filter_zap ---
# Description:
#   Filters the Zap work database by geographic and other parameters.
# Inputs:
#   - address: Reference address.
#   - radius: Search radius (min, max).
#   - neighbs, city_neighb: Neighborhood or city filters.
#   - reach, area_range, price_range, furniture, pool, gym, air, last_seen_months: Other filters.
#   - directory: Optional directory override.
# Output:
#   - A filtered data frame from the Zap work database.
geo_filter_zap <- function(address = "edificio copan, sao Paulo",
                           radius = c(0, 300),
                           neighbs = NULL,
                           city_neighb = NULL,
                           reach = "circle",
                           area_range = c(20, 200),
                           price_range = c(30, 350),
                           furniture = "sn",
                           pool = "sn",
                           gym = "sn",
                           air = "sn",
                           last_seen_months = 200,
                           directory = NA) {
  furniture <- case_when(furniture == "s" ~ T, furniture == "n" ~ F, furniture == "sn" ~ c(T, F))
  air <- case_when(air == "s" ~ T, air == "n" ~ F, air == "sn" ~ c(T, F))
  pool <- case_when(pool == "s" ~ T, pool == "n" ~ F, pool == "sn" ~ c(T, F))
  gym <- case_when(gym == "s" ~ T, gym == "n" ~ F, gym == "sn" ~ c(T, F))
  if (is.na(directory)) {
    dir_raiz <- (dirname(rstudioapi::getActiveDocumentContext()$path))
  } else {
    dir_raiz <- directory
  }
  if (!exists("library_airbnb_loaded")) source(paste0("library_airbnb.R"))
  dir_sub <- "/DB"
  dir_base <- paste0(dir_raiz, dir_sub, "/")
  dir_zap <- str_replace(tolower(dir_base), "airbnb", "zap_imoveis_update")
  if (!exists("db_work_zap")) {
    db_work_zap <<- read_rds(paste0(dir_zap, "db_work.rds"))
  }
  cidades_estudo <- unique(sort(db_work_zap$city))
  bairros_estudo <- unique(sort(db_work_zap$neighborhood))
  bairro_foco <- bairros_estudo
  cidade_foco <- cidades_estudo
  db_work_zap$amenities[sapply(db_work_zap$amenities, length) == 0] <- c("empty")
  amenities <- unique(sort(c(db_work_zap$amenities %>% unlist(), "empty")))
  dummy <- rep(T, nrow(db_work_zap)) &
    (db_work_zap$neighborhood %in% bairro_foco) &
    (db_work_zap$city %in% cidade_foco) &
    (db_work_zap$amenities.FURNISHED %in% furniture) &
    (db_work_zap$amenities.POOL %in% pool) &
    (db_work_zap$amenities.GYM %in% gym) &
    !(db_work_zap$unitTypes %in% c("HOME")) &
    (db_work_zap$isRent == T) &
    (db_work_zap$pricepersqm %>% between(price_range[1], price_range[2])) &
    (db_work_zap$usableAreas %>% between(area_range[1], area_range[2])) &
    (db_work_zap$last_seen >= today() %m-% months(last_seen_months)) &
    !(is.na(db_work_zap$pricepersqm)) &
    !(is.na(db_work_zap$neighborhood)) &
    sapply(db_work_zap$usageTypes, function(x) {
      "RESIDENTIAL" %in% x
    }) &
    sapply(db_work_zap$amenities, function(x) {
      any(x %in% amenities)
    })
  dummy[is.na(dummy)] <- F
  db_foco <- db_work_zap[dummy, ]
  if (is.null(neighbs)) {
    output_radius <- neighbors_address(
      lat_vector = db_foco$point.lat,
      lon_vector = db_foco$point.lon,
      address = address,
      radius = radius
    )
    db_foco_raio <- db_foco[output_radius$choosen_lines, ]
  } else {
    choosen_lines <- st_intersects(coords_to_sf(db_foco$point.lat, db_foco$point.lon),
      pluck(neighb_polygon(city_ref = city_neighb, neighb_ref = neighbs), "polygon"),
      sparse = F
    ) %>% which()
    db_foco_raio <- db_foco[choosen_lines, ]
  }
  return(db_foco_raio)
}

# --- neighb_polygon ---
# Description:
#   Creates a neighborhood polygon from the Zap work database.
# Inputs:
#   - city_ref: Vector of city names.
#   - neighb_ref: Vector of neighborhood names.
#   - db_work_zap: (Optional) Preloaded Zap database.
#   - dev_factor: Standard deviation factor for outlier removal.
#   - max_radius: Maximum distance to consider.
# Output:
#   - A list with:
#       polygon: An sf polygon for the neighborhood,
#       points: The sf points used.
neighb_polygon <- function(city_ref = c("São Paulo"), neighb_ref = c("Santana"),
                           db_work_zap = NULL, dev_factor = 3, max_radius = 5000) {
  if (NROW(db_work_zap) == 0) {
    dir_raiz <- getwd()
    dir_sub <- "/DB"
    dir_base <- paste0(dir_raiz, dir_sub, "/")
    dir_zap <- str_replace(tolower(dir_base), "airbnb", "zap_imoveis_update")
    db_work_zap <- read_rds(paste0(dir_zap, "db_work.rds"))
  }
  dummy <- (db_work_zap$city %in% city_ref) & (db_work_zap$neighborhood %in% neighb_ref) & !(is.na(db_work_zap$point.lat))
  db_foco <- db_work_zap[dummy, ]
  db_foco$sf <- coords_to_sf(db_foco$point.lat, db_foco$point.lon)
  kill_outliers <- function(x = db_foco, stdev = 3) {
    centroid <- coords_to_sf(mean(db_foco$point.lat), mean(db_foco$point.lon))
    dist_to_centroid <- st_distance(db_foco$sf, centroid) %>% as.numeric()
    trimmed_dist <- dist_to_centroid[dist_to_centroid <= max_radius]
    normalized_dist <- (dist_to_centroid - mean(trimmed_dist)) / std(trimmed_dist)
    dummy_outlier <- (normalized_dist <= stdev)
    output <- x[dummy_outlier, ]
    return(output)
  }
  db_foco <- kill_outliers(x = db_foco, stdev = dev_factor)
  dummy <- chull(db_foco$point.lat, db_foco$point.lon)
  points_polygon <- db_foco$sf[c(dummy, dummy[1])]
  polygon_neighb <- points_polygon %>%
    st_combine() %>%
    st_cast("POLYGON") %>%
    st_buffer(10)
  output <- list(polygon = polygon_neighb, points = db_foco$sf)
  return(output)
}

# --- percentil_chart ---
# Description:
#   Creates a quantile chart using ggplot for one or two data series.
# Inputs:
#   - values_quantile_1: A numeric vector for the first series.
#   - values_quantile_2: (Optional) A numeric vector for the second series.
#   - title_ref: Chart title.
#   - subtitle_ref: Chart subtitle.
#   - y_lable: Y-axis label.
#   - x_lable: X-axis label.
#   - stops: Numeric vector of quantile stops (between 0 and 1).
# Output:
#   - A ggplot object.
percentil_chart <- function(values_quantile_1 = vhouse_db_zap$pricepersqm,
                            values_quantile_2 = NA,
                            title_ref = "Distribuição Aluguéis - R$/mês",
                            subtitle_ref = NA,
                            y_lable = "R$/month",
                            x_lable = "Ranking:    0% smallest, 100% largest",
                            stops = c(.5, .7, .8, .9)) {
  if (is.na(subtitle_ref)) {
    subtitle_ref <- paste0(NROW(values_quantile_1), " unidades")
  }
  y_chart <- values_quantile_1
  x_chart <- ecdf(values_quantile_1)(values_quantile_1)
  min_y <- quantile(values_quantile_1, 0) * .95
  max_y <- quantile(values_quantile_1, .99) * 1.05
  stops_quantiles <- map_dbl(stops, ~ round(quantile(values_quantile_1, .x), 1))
  stops_label_a <- as.character(round(stops_quantiles + 10^-10, 1))
  stops_label_b <- paste0(round(100 * stops, 1), "%")
  data_1 <- tibble(x = x_chart, y = y_chart)
  data_1_labels <- tibble(
    stops = stops, stops_quantiles = stops_quantiles,
    stops_label_a = stops_label_a, stops_label_b = stops_label_b
  )
  if (any(!is.na(values_quantile_2))) {
    subtitle_ref <- paste0(NROW(values_quantile_1), " + ", NROW(values_quantile_2), " unidades")
    y2_chart <- values_quantile_2
    x2_chart <- ecdf(values_quantile_2)(values_quantile_2)
    min_y <- min(min_y, quantile(values_quantile_2, 0) * .95)
    max_y <- max(max_y, quantile(values_quantile_2, .99) * 1.05)
    stops_2 <- stops
    stops_quantiles_2 <- map_dbl(stops, ~ round(quantile(values_quantile_2, .x), 1))
    stops_label_a_2 <- as.character(round(stops_quantiles_2 + 10^-10, 1))
    stops_label_b_2 <- paste0(round(100 * stops, 1), "%")
    data_2 <- tibble(x = x2_chart, y = y2_chart)
    data_2_labels <- tibble(
      stops_2 = stops_2, stops_quantiles_2 = stops_quantiles_2,
      stops_label_a_2 = stops_label_a_2, stops_label_b_2 = stops_label_b_2
    )
  } else {
    data_2 <- NULL
    data_2_labels <- NULL
  }
  map_ggplot <-
    ggplot(NULL, aes(x, y)) +
    geom_line(data = data_1, size = 1.4, color = "#209e89") +
    geom_point(data = data_1, alpha = .1, stroke = T, colour = "grey") +
    scale_x_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0, 1, .1)) +
    scale_y_continuous(breaks = seq(0, max_y, 50), minor_breaks = seq(0, max_y, 10), limits = c(min_y, max_y)) +
    geom_vline(xintercept = stops, alpha = 0.3) +
    geom_point(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles)) +
    geom_text(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles, label = stops_label_a), vjust = -2.5) +
    geom_text(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles, label = stops_label_b), vjust = -1) +
    labs(title = title_ref, subtitle = subtitle_ref, y = y_lable, x = x_lable) +
    theme(aspect.ratio = 10 / 14)
  if (any(!is.na(values_quantile_2))) {
    map_ggplot <- map_ggplot +
      geom_line(aes(x = data_2$x, y = data_2$y), size = 1.4, color = "coral") +
      geom_point(aes(x = data_2$x, y = data_2$y), alpha = .1, stroke = T, colour = "black") +
      geom_vline(xintercept = stops_2, alpha = 0.3) +
      geom_point(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2)) +
      geom_text(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2, label = data_2_labels$stops_label_a_2), vjust = 1.3) +
      geom_text(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2, label = data_2_labels$stops_label_b_2), vjust = 2.8)
  }
  return(map_ggplot)
}

# --- percentil_chart_plotly ---
# Description:
#   Creates an interactive (plotly) quantile chart for one or two data series.
# Inputs and outputs are the same as percentil_chart, but returns a plotly object.
percentil_chart_plotly <- function(values_quantile_1 = vhouse_db_zap$pricepersqm,
                                   values_quantile_2 = NA,
                                   title_ref = "Distribuição Aluguéis - R$/mês",
                                   subtitle_ref = NA,
                                   y_lable = "R$/month",
                                   x_lable = "Ranking:    0% smallest, 100% largest",
                                   stops = c(.5, .7, .8, .9)) {
  if (is.na(subtitle_ref)) {
    subtitle_ref <- paste0(NROW(values_quantile_1), " unidades")
  }
  y_chart <- values_quantile_1
  x_chart <- ecdf(values_quantile_1)(values_quantile_1)
  min_y <- quantile(values_quantile_1, 0) * .95
  max_y <- quantile(values_quantile_1, .99) * 1.05
  stops_quantiles <- map_dbl(stops, ~ round(quantile(values_quantile_1, .x), 1))
  stops_label_a <- as.character(round(stops_quantiles + 10^-10, 1))
  stops_label_b <- paste0(round(100 * stops, 1), "%")
  data_1 <- tibble(x = x_chart, y = y_chart)
  data_1_labels <- tibble(
    stops = stops, stops_quantiles = stops_quantiles,
    stops_label_a = stops_label_a, stops_label_b = stops_label_b
  )
  if (any(!is.na(values_quantile_2))) {
    subtitle_ref <- paste0(NROW(values_quantile_1), " + ", NROW(values_quantile_2), " unidades")
    y2_chart <- values_quantile_2
    x2_chart <- ecdf(values_quantile_2)(values_quantile_2)
    min_y <- min(min_y, quantile(values_quantile_2, 0) * .95)
    max_y <- max(max_y, quantile(values_quantile_2, .99) * 1.05)
    stops_2 <- stops
    stops_quantiles_2 <- map_dbl(stops, ~ round(quantile(values_quantile_2, .x), 1))
    stops_label_a_2 <- as.character(round(stops_quantiles_2 + 10^-10, 1))
    stops_label_b_2 <- paste0(round(100 * stops, 1), "%")
    data_2 <- tibble(x = x2_chart, y = y2_chart)
    data_2_labels <- tibble(
      stops_2 = stops_2, stops_quantiles_2 = stops_quantiles_2,
      stops_label_a_2 = stops_label_a_2, stops_label_b_2 = stops_label_b_2
    )
  } else {
    data_2 <- NULL
    data_2_labels <- NULL
  }
  map_ggplot <-
    ggplot(data = NULL, aes(x, y)) +
    geom_line(data = data_1, size = 1.4, color = "#209e89") +
    geom_point(data = data_1, alpha = .1, stroke = T, colour = "grey") +
    scale_x_continuous(labels = scales::percent_format(accuracy = 1), breaks = seq(0, 1, .1)) +
    scale_y_continuous(breaks = seq(0, max_y, 50), minor_breaks = seq(0, max_y, 10), limits = c(min_y, max_y)) +
    geom_vline(xintercept = stops, alpha = 0.3) +
    geom_point(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles)) +
    geom_text(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles, label = stops_label_a), vjust = -2.5) +
    geom_text(data = data_1_labels, mapping = aes(x = stops, y = stops_quantiles, label = stops_label_b), vjust = -1) +
    labs(title = title_ref, subtitle = subtitle_ref, y = y_lable, x = x_lable) +
    theme(aspect.ratio = 10 / 19)
  if (any(!is.na(values_quantile_2))) {
    map_ggplot <- map_ggplot +
      geom_line(aes(x = data_2$x, y = data_2$y), size = 1.4, color = "coral") +
      geom_point(aes(x = data_2$x, y = data_2$y), alpha = .1, stroke = T, colour = "black") +
      geom_vline(xintercept = stops_2, alpha = 0.3) +
      geom_point(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2)) +
      geom_text(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2, label = data_2_labels$stops_label_a_2), vjust = 1.3) +
      geom_text(aes(x = data_2_labels$stops_2, y = data_2_labels$stops_quantiles_2, label = data_2_labels$stops_label_b_2), vjust = 2.8)
  }
  return(ggplotly(map_ggplot))
}

# --- expand_airbnb_pages ---
# Description:
#   Given a list of Airbnb search URLs, expands each URL with pagination parameters.
# Inputs:
#   - url_airbnb_in: A vector of base Airbnb search URLs.
# Output:
#   - A vector of URLs expanded with additional pagination parameters.
expand_airbnb_pages <- function(url_airbnb_in) {
  url_list_filhotes <- outer(
    url_airbnb_in,
    sapply(seq(0, 280, 20), function(x) {
      paste0("&items_offset=", x, "&section_offset=4")
    }),
    paste0
  ) %>% as.vector()
  return(url_list_filhotes)
}

# --- sf_circle_around_epicenter ---
# Description:
#   Creates an sf circle (buffer) around a given epicenter (specified as a coordinate or address).
# Inputs:
#   - lat, lon: Numeric coordinates (optional if epicenter_string is provided).
#   - epicenter_string: A string that will be geocoded.
#   - radius: Radius in meters.
# Output:
#   - An sf polygon representing the circle.
sf_circle_around_epicenter <- function(lat = NA, lon = NA, epicenter_string = NA, radius = 1000) {
  if (!is.na(epicenter_string)) {
    temp <- geocode_bulk(epicenter_string, method = "google", delay = .001)
    lat <- temp$lat
    lon <- temp$lon
  }
  circle_output <- st_buffer(st_sfc(st_point(c(lon, lat)), crs = 4326), dist = radius) %>% st_fix()
  return(circle_output)
}

# --- clean_geometry ---
# Description:
#   Removes extra geometry columns from an sf object or a data frame.
# Inputs:
#   - data_in: An sf object or data frame.
# Output:
#   - The cleaned object.
clean_geometry <- function(data_in) {
  if (inherits(data_in, "sf")) {
    if ("geometry.y" %in% colnames(data_in)) {
      data_in <- data_in[, !colnames(data_in) %in% "geometry.y"]
    }
    if ("geometry.x" %in% colnames(data_in)) {
      colnames(data_in)[colnames(data_in) == "geometry.x"] <- "geometry"
    }
  } else if (inherits(data_in, "data.frame")) {
    cols_to_remove <- c("geometry", "geometry.x", "geometry.y")
    data_in <- data_in[, !colnames(data_in) %in% cols_to_remove]
  } else {
    stop("Input must be a data.frame or sf object.")
  }
  return(data_in)
}


## corrige distorcões mais comuns em um sf
st_fix <- function(x, crs = 4326) {
  # Define CRS options (4326 para GPS global, 31983 para latitudes brasileiras específicas)

  # Helper function para corrigir apenas geometrias inválidas
  fix_geometry <- function(geom, is_valid) {
    if (st_is_empty(geom) || is.na(st_dimension(geom)) || is_valid) {
      return(geom) # Pula geometrias vazias, inválidas ou já válidas
    }
    geom_valid <- st_make_valid(geom)
    if (!st_is_empty(geom_valid)) {
      return(st_simplify(geom_valid, dTolerance = 0.01))
    }
    return(geom) # Retorna original se simplificação falhar
  }

  # Verifica e ajusta o CRS de entrada
  input_crs <- st_crs(x)
  if (is.na(input_crs$epsg)) {
    message("CRS de entrada não definido. Definindo como ", crs, ".")
    x <- st_set_crs(x, crs)
  } else if (input_crs$epsg != crs) {
    message("CRS de entrada (", input_crs$epsg, ") diferente do desejado (", crs, "). Transformando.")
    x <- st_transform(x, crs)
  }

  # Verifica validade de todas as geometrias de uma vez
  geoms <- st_geometry(x)
  valid_check <- st_is_valid(geoms)

  # Processamento principal
  tryCatch(
    {
      # Aplica correção apenas onde necessário
      fixed_geoms <- st_sfc(
        mapply(fix_geometry, geoms, valid_check, SIMPLIFY = FALSE),
        crs = crs
      )

      # Atualiza o objeto sf com as geometrias corrigidas
      output <- st_set_geometry(x, fixed_geoms) %>%
        st_sf()
    },
    error = function(e) {
      message("Erro detectado: ", e$message, ". Aplicando correção básica.")
      # Fallback: Mesmo processo no caso de erro
      fixed_geoms <- st_sfc(
        mapply(fix_geometry, geoms, valid_check, SIMPLIFY = FALSE),
        crs = crs
      )
      output <- st_set_geometry(x, fixed_geoms) %>%
        st_sf()
    }
  )

  return(output)
}


#### Funçõeses de Suporte ----


# Função: clean_name
# Descrição:
#   Esta função recebe um vetor de strings (por exemplo, nomes) e realiza a limpeza e normalização dos textos.
#   Ela converte todas as letras para minúsculas, remove acentos, elimina caracteres que não sejam letras (a-z)
#   ou espaços, e ajusta os espaços, removendo duplicatas e espaços no início/fim da string.
#
# Inputs:
#   x: Vetor de caracteres ou string única contendo os textos a serem limpos.
#
# Outputs:
#   Retorna um vetor de caracteres com os textos processados, onde:
#     - Todas as letras estão em minúsculas.
#     - Os acentos foram removidos.
#     - Apenas letras (a-z) e espaços são mantidos.
#     - espaços extras (duplicados ou no início/fim) são removidos, deixando apenas um espaço entre as palavras.
#
clean_name <- function(x) {
  # Converter o texto para minúsculas para garantir padronização.
  x <- tolower(x)

  # Remover acentos, convertendo caracteres acentuados para suas formas sem acento.
  x <- stringi::stri_trans_general(x, "Latin-ASCII")

  # Remover caracteres que não sejam letras (a-z) ou espaços.
  # A expressão regular "[^a-z\\s]" seleciona tudo que não for letra ou espaço.
  # O uso de 'perl = TRUE' garante o suporte completo à expressão regular.
  x <- gsub("[^a-z\\s]", "", x, perl = TRUE)

  # Remover espaços duplicados e eliminar espaços no início e no fim da string.
  # A função str_squish() do pacote stringr substitui sequências de espaços por um único espaço.
  x <- stringr::str_squish(x)

  # Retornar o vetor de strings limpo.
  return(x)
}


# --- quantile_vector ---
# Description:
#   Computes quantiles for a numeric vector and returns them in a tibble.
# Inputs:
#   - vector: A numeric vector.
#   - number_points: Number of quantile stops to calculate.
# Output:
#   - A tibble with columns "value" and "quantiles".
quantile_vector <- function(vector, number_points = 200) {
  stops <- min(number_points, length(vector) - 1)
  temp <- vector[!is.na(vector)] %>%
    quantile(probs = (0:stops) / stops) %>%
    tibble(value = ., quantiles = names(.))
  temp$quantiles <- temp$quantiles %>%
    str_remove("%") %>%
    as.numeric() / 100
  return(temp)
}

# --- check_and_load_packages ---
# Description:
#   Checks whether each package is installed and loads it (installing if necessary).
# Input:
#   - packages: A character vector of package names.
# Output:
#   - Loads the packages (invisibly).
check_and_load_packages <- function(packages) {
  for (package in packages) {
    if (!require(package, character.only = TRUE)) {
      install.packages(package, dependencies = TRUE)
      library(package, character.only = TRUE)
    }
  }
}

# --- corrige_latin1_to_utf8_character ---
# Description:
#   Corrects encoding issues by converting from latin1 to UTF-8.
# Input:
#   - vector_char: A character vector.
# Output:
#   - The corrected character vector.
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

# --- n_most_frequent ---
# Description:
#   Returns the n most frequent elements in a vector.
# Inputs:
#   - vector: A vector.
#   - num_elem: The number of most frequent elements to return.
# Output:
#   - A named vector (table) of the n most frequent elements.
n_most_frequent <- function(vector, num_elem) {
  sort(table(vector), decreasing = TRUE)[1:num_elem]
}

# --- unnest_deep_list ---
# Description:
#   Flattens a deeply nested list into a one-level list.
# Input:
#   - db: A nested list.
# Output:
#   - A flattened list.
unnest_deep_list <- function(db) {
  renquote <- function(l) if (is.list(l)) lapply(l, renquote) else enquote(l)
  output <- lapply(unlist(renquote(db)), eval)
  return(output)
}

# --- trim_extremes ---
# Description:
#   Clips the extreme values in a vector based on a specified percentile.
# Inputs:
#   - vect: A numeric vector.
#   - extreme_pct: The fraction for lower and upper extremes.
# Output:
#   - A vector with extreme values clipped.
trim_extremes <- function(vect, extreme_pct = 0.04) {
  sapply(vect, function(x) {
    min(max(x, quantile(vect, extreme_pct)), quantile(vect, 1 - extreme_pct))
  })
}

# --- trim_extremes_std ---
# Description:
#   Clips values that fall beyond a given number of standard deviations.
# Inputs:
#   - vect: A numeric vector.
#   - std_range: The number of standard deviations.
# Output:
#   - A vector with extreme values clipped.
trim_extremes_std <- function(vect, std_range = 2) {
  min_sample <- mean(vect) - std_range * std(vect)
  max_sample <- mean(vect) + std_range * std(vect)
  sapply(vect, function(x) {
    min(max(x, min_sample), max_sample)
  })
}

# --- any_match ---
# Description:
#   Returns the positions in a list of strings that match any of a set of patterns.
# Inputs:
#   - list_strings: A vector of strings.
#   - list_patterns: A vector of regex patterns.
# Output:
#   - A vector of matching positions.
any_match <- function(list_strings, list_patterns) {
  sapply(list_patterns, grep, list_strings) %>%
    unlist() %>%
    unname() %>%
    as.vector()
}

# --- agrupamento ---
# Description:
#   Concatenates a list of strings into groups (bins) with a given separator.
# Inputs:
#   - chain: A vector of strings.
#   - bin_size: The group size.
#   - separador: The separator string (default is a comma).
# Output:
#   - A vector of concatenated strings.
agrupamento <- function(chain, bin_size, separador = ",") {
  chain_tible <- tibble(chain)
  length_chain <- nrow(chain_tible)
  start_point <- seq(1, length_chain, by = min(bin_size, length_chain))
  output <- c()
  for (k1 in seq_along(start_point)) {
    grupo <- capture.output(cat(chain[start_point[k1]:min(length_chain, start_point[k1] + bin_size - 1)], sep = separador))
    output <- if (k1 == 1) {
      grupo
    } else {
      c(output, grupo)
    }
  }
  return(output)
}

# --- string_between ---
# Description:
#   Extracts substrings between two specified delimiters.
# Inputs:
#   - text_base: The full text.
#   - start_str, end_str: The starting and ending delimiter strings.
#   - case: Logical flag for case sensitivity.
#   - include_ends: Logical flag; if TRUE, includes delimiters in the output.
# Output:
#   - A vector of extracted substrings.
string_between <- function(text_base, start_str, end_str, case = T, include_ends = T) {
  if (!case) {
    start_str <- str_to_lower(start_str)
    end_str <- str_to_lower(end_str)
    text_base <- str_to_lower(text_base)
  }
  matches <- str_match_all(text_base, paste0(start_str, "(.*?)", end_str))
  if (include_ends) {
    output <- matches[[1]][, 1]
  } else {
    output <- matches[[1]][, 2]
  }
  return(output)
}

# --- list_url_gif_and_grid ---
# Description:
#   Downloads a list of image URLs and produces a GIF and a grid image.
# Inputs:
#   - list_images_url: A vector of image URLs.
#   - num_photos: Number of photos to download.
#   - num_col: Number of columns for the grid.
#   - fps_gif: Frames per second for the GIF.
#   - num_photos_gif: Number of photos for the GIF.
# Output:
#   - A list with "grid_image" and "gif_image".
list_url_gif_and_grid <- function(list_images_url, num_photos = NA, num_col = NA,
                                  fps_gif = NA, num_photos_gif = NA) {
  library("magick")
  num_photos <- min(num_photos, length(list_images_url), na.rm = T)
  grid_output <- NA
  gif_output <- NA
  tryCatch(
    {
      tryCatch({
        img_download <- image_read(list_images_url[1:min(num_photos, length(list_images_url), na.rm = T)])
      })
      fps_gif <- min(fps_gif, 1, na.rm = T)
      num_photos_gif <- min(length(img_download), num_photos_gif, na.rm = T)
      gif_output <- image_animate(img_download[1:min(num_photos_gif, length(img_download))],
        fps = fps_gif, dispose = "previous"
      )
      num_photos <- min(num_photos, length(list_images_url), na.rm = T)
      num_col <- if (is.na(num_col)) {
        ceiling(sqrt(num_photos))
      } else {
        num_col
      }
      num_row <- ceiling(num_photos / num_col)
      starts <- seq(1, num_photos, num_col)
      ends <- sapply(starts + num_col - 1, function(x) {
        min(x, num_photos)
      })
      for (j4 in seq_along(starts)) {
        line_append <- image_append(img_download[starts[j4]:ends[j4]])
        if (j4 == 1) {
          grid_output <- line_append
        } else {
          grid_output <- image_append(c(grid_output, line_append), stack = T)
        }
      }
    },
    error = function(cond) {
      grid_output <- NA
      gif_output <- NA
    }
  )
  output <- list(grid_image = grid_output, gif_image = gif_output)
  return(output)
}

# --- redistribute_between ---
# Description:
#   Applies a linear transformation to scale a range into a new interval.
# Inputs:
#   - range: A numeric vector.
#   - min_point, max_point: The target minimum and maximum.
# Output:
#   - The transformed numeric vector.
redistribute_between <- function(range, min_point, max_point) {
  range <- as.vector(range)
  delta_target <- max_point - min_point
  delta_range <- max(range) - min(range)
  beta <- delta_target / delta_range
  alfa <- min_point - beta * min(range)
  new_range <- alfa + beta * range
  new_range
}

# --- detect_pattern_any_comlumy_function ---
# Description:
#   Checks each row of a data frame for a pattern across all columns.
# Inputs:
#   - dataframe: A data frame.
#   - pattern: A pattern to search for.
# Output:
#   - A logical vector indicating if the pattern is found in any column of each row.
detect_pattern_any_comlumy_function <- function(dataframe, pattern) {
  Reduce(`|`, Map(function(x) grepl("Matt", x), dataframe))
}

# --- flattenlist ---
# Description:
#   Recursively flattens a nested list into a one-level list.
# Input:
#   - x: A (possibly nested) list.
# Output:
#   - A flattened list.
flattenlist <- function(x) {
  morelists <- sapply(x, function(xprime) class(xprime)[1] == "list")
  out <- c(x[!morelists], unlist(x[morelists], recursive = FALSE))
  if (sum(morelists)) {
    Recall(out)
  } else {
    return(out)
  }
}

# ---------------- Internal programming functions ----------------

library(magrittr)
library(dplyr)

# -----------------------------------------------------------------------------
# factorize
# -----------------------------------------------------------------------------
# Converte automaticamente colunas character em factor quando a cardinalidade
# justifica (categoria de verdade, não identificador disfarçado).
# Critério (AND):
#   1. n_distinct(x) <= max_levels  -> limite absoluto de níveis
#   2. n_distinct(x) / length(x) <= max_ratio -> exige repetição mínima
# Args:
#   df         : data.frame ou tibble
#   max_levels : nº máximo de níveis distintos para fatorizar (default 100)
#   max_ratio  : razão máxima distintos/total para fatorizar (default 0.5)
# Returns:
#   data.frame com as colunas qualificadas convertidas para factor.
# -----------------------------------------------------------------------------
factorize <- function(df, max_levels = 100, max_ratio = 0.1) {
  df %>% mutate(across(
    # seleciona colunas character cuja cardinalidade satisfaz ambos os critérios
    where(is.character) & where(~ {
      nd <- n_distinct(.x, na.rm = TRUE)
      nd <= max_levels && nd / length(.x) <= max_ratio
    }),
    as.factor
  ))
}


# --- make_dirs ---
# Description:
#   Constructs a path and creates directories if they do not exist.
# Inputs:
#   - ... : Path components.
# Output:
#   - A normalized file path.
make_dirs <- function(...) {
  path <- file.path(...)
  if (grepl("\\.", basename(path)) == TRUE) {
    pathToBuild <- file.path(dirname(path), "/")
  } else if (substr(path, nchar(path), nchar(path)) == "/") {
    pathToBuild <- path
  } else {
    pathToBuild <- file.path(path, "/")
  }
  if (!dir.exists(pathToBuild)) {
    dir.create(pathToBuild, recursive = TRUE)
  }
  return(normalizePath(path, winslash = "/"))
}

# --- collapse_vec ---
# Description:
#   Collapses a vector of values into a single string with wrapping and a separator.
# Inputs:
#   - ... : Vectors to collapse.
#   - wrap: Characters to wrap each element.
#   - collapse: Separator string.
#   - unique: Logical; if TRUE, remove duplicate values.
# Output:
#   - A single string.
collapse_vec <- function(..., wrap = "'", collapse = ", ", unique = TRUE) {
  vec <- as.character(c(...))
  if (unique == TRUE) {
    vec <- unique(vec)
  }
  paste(character(0), vec, character(0), collapse = collapse, sep = wrap)
}

# --- fuzzy_needle ---
# Description:
#   Converts a space-separated string into a fuzzy regex pattern.
# Input:
#   - vec: A string.
# Output:
#   - A fuzzy regex string.
fuzzy_needle <- function(vec) {
  words <- unique(unlist(strsplit(vec, "\\s+")))
  groups <- sapply(words, function(x) paste0("(?=.*", x, ")"), USE.NAMES = FALSE)
  paste0(groups, collapse = "")
}

# --- is_valid_url ---
# Description:
#   Checks if a given string is a valid URL.
# Input:
#   - string: A URL string.
# Output:
#   - TRUE if valid, FALSE otherwise.
is_valid_url <- function(string) {
  any(grepl("(https?|ftp)://[^\\s/$.?#].[^\\s]*", string))
}

# --- shhh ---
# Description:
#   Suppresses console output for an expression.
# Input:
#   - expr: An expression.
# Output:
#   - The result of evaluating the expression (silently).
shhh <- function(expr) {
  call <- quote(expr)
  invisible(utils::capture.output(
    out <- suppressWarnings(suppressMessages(suppressPackageStartupMessages(eval(call))))
  ))
  return(invisible(out))
}

# --- %notin% ---
# Description:
#   Convenience operator: returns TRUE if x is not in y.
"%notin%" <- function(x, y) {
  !(match(x, y, nomatch = 0) > 0)
}

# --- get_matching_rows ---
# Description:
#   Returns row indices from df_right that match rows in df_left based on specified columns.
# Inputs:
#   - df_left: Left data frame.
#   - df_right: Right data frame.
#   - name_id_left: Column names in df_left for matching.
#   - name_id_right: Column names in df_right for matching.
# Output:
#   - A vector of matching row indices.
get_matching_rows <- function(df_left, df_right, name_id_left, name_id_right) {
  if (length(name_id_left) != length(name_id_right)) {
    stop("Length of name_id_left and name_id_right must be the same")
  }
  by_mapping <- setNames(name_id_right, name_id_left)
  df_right <- df_right %>% mutate(row_index = row_number())
  joined_df <- left_join(df_left, df_right, by = by_mapping)
  matches <- joined_df$row_index
  return(matches)
}

# --- left_join_first_match_custom ---
# Description:
#   Performs a left join on multiple columns and retains only the first match for each row.
# Inputs:
#   - df_left: Left data frame.
#   - df_right: Right data frame.
#   - name_id_left: Column names from df_left.
#   - name_id_right: Column names from df_right.
# Output:
#   - A data frame of joined results with only the first match per group.
left_join_first_match_custom <- function(df_left, df_right, name_id_left, name_id_right) {
  if (length(name_id_left) != length(name_id_right)) {
    stop("Length of name_id_left and name_id_right must be the same")
  }
  by_mapping <- setNames(name_id_right, name_id_left)
  joined_df <- left_join(df_left, df_right, by = by_mapping)
  result_df <- joined_df %>%
    group_by(across(all_of(name_id_left))) %>%
    slice(1) %>%
    ungroup()
  return(result_df)
}

# --- get_matrix_elements ---
# Description:
#   Extracts specified elements from a matrix given a vector of row indices.
# Inputs:
#   - m: A matrix.
#   - V: A vector of row indices (one per column).
# Output:
#   - A vector of extracted elements.
get_matrix_elements <- function(m, V) {
  if (length(V) != ncol(m)) {
    stop("The length of vector V must match the number of columns in the matrix.")
  }
  if (any(V > nrow(m)) || any(V < 1)) {
    stop("All elements of V must be valid row indices (between 1 and the number of rows).")
  }
  result <- m[cbind(V, 1:ncol(m))]
  return(result)
}
