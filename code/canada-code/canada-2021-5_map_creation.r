# ==========================================================================
# Map data for displacement and vulnerability measures
# Author: Tim Thomas - timthomas@berkeley.edu
# Created: 2019.10.13
# 1.0 code: 2020.10.25
# 2.0 code: 2021.08.05
# ==========================================================================

# Clear the session
rm(list = ls())
options(scipen = 10) # avoid scientific notation

# ==========================================================================
# Load Libraries
# ==========================================================================

#
# Load packages and install them if they're not installed.
# --------------------------------------------------------------------------

pacman::p_load(readxl, tidytransit, opendatatoronto, R.utils, colorspace, bit64, rmapshaper, sf, sp, geojsonsf, scales, data.table,leaflet, tidyverse)

# ==========================================================================
# Data
# ==========================================================================
city_name = "Vancouver"
# city_name = commandArgs(trailingOnly = TRUE)
database <- read.csv(paste("E:\\forked_canada_udp/data/outputs/typologies/", city_name, "_typology_output.csv", sep = ""))

database <- database %>%
        mutate(GeoUID = as.numeric(GeoUID))

data_df <- 
  database %>% 
    mutate(
     # create typology for maps
      Typology = 
              factor( # turn to factor for mapping 
                case_when(
                  ## Typology amendments
                  typ_cat == "['AdvG', 'BE']" ~ 'Advanced Gentrification',
                  typ_cat == "['LISD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
                  typ_cat == "['OD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
                  typ_cat == "['LISD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
                  typ_cat == "['OD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
                  typ_cat == "['SAE', 'SGE']" ~ 'Super Gentrification and Exclusion',
                  typ_cat == "['ARE', 'SGE']" ~ 'Super Gentrification and Exclusion',
                  typ_cat == "['SMMI', 'SGE']" ~ 'Super Gentrification and Exclusion',
                  ## Regular adjustments
                  typ_cat == "['AdvG']" ~ 'Advanced Gentrification',
                  typ_cat == "['ARE']" ~ 'At Risk of Becoming Exclusive',
                  typ_cat == "['ARG']" ~ 'At Risk of Gentrification',
                  typ_cat == "['BE']" ~ 'Becoming Exclusive', 
                  typ_cat == "['BE', 'SAE']" ~ "Becoming Exclusive",
                  typ_cat == "['EOG']" ~ 'Early/Ongoing Gentrification',
                  typ_cat == "['OD']" ~ 'Ongoing Displacement',
                  typ_cat == "['SAE']" ~ 'Stable/Advanced Exclusive', 
                  typ_cat == "['LISD']" ~ 'Low-Income/Susceptible to Displacement',
                  typ_cat == "['SMMI']" ~ 'Stable Moderate/Mixed Income',
                  
                  TRUE ~ "Unavailable or Unreliable Data"
                ),
                levels = 
                  c(
                    'Low-Income/Susceptible to Displacement',
                    'Ongoing Displacement',
                    'At Risk of Gentrification',
                    'Early/Ongoing Gentrification',
                    'Advanced Gentrification',
                    'Stable Moderate/Mixed Income',
                    'At Risk of Becoming Exclusive',
                    'Becoming Exclusive',
                    'Stable/Advanced Exclusive',
                    'Super Gentrification and Exclusion',
                    'Unavailable or Unreliable Data'
                  )
            ), 
        real_avghval_16 = case_when(real_avghval_16 > 0 ~ real_avghval_16),
        real_avgrent_16 = case_when(real_avgrent_16 > 0 ~ real_avgrent_16),
        real_mhval_16 = case_when(real_mhval_16 > 0 ~ real_mhval_16),
        real_mrent_16 = case_when(real_mrent_16 > 0 ~ real_mrent_16),
    ) %>% 
    mutate(
        ravg_real_avghval_16 = mean(real_avghval_16, na.rm = TRUE), 
        ravg_real_avgrent_16 = mean(real_avgrent_16, na.rm = TRUE), 
        rm_real_mhval_16 = median(real_mhval_16, na.rm = TRUE), 
        rm_real_mrent_16 = median(real_mrent_16, na.rm = TRUE), 
        rm_per_visible_minority_16 = median(per_visible_minority_16, na.rm = TRUE), 
        rm_per_col_16 = median(per_col_16, na.rm = TRUE)
    ) %>% 
    group_by(GeoUID) %>% 
    mutate(
        per_ch_li = (all_li_count_16-all_li_count_06)/all_li_count_06,
        popup = # What to include in the popup 
          str_c(
              '<b>Tract: ', GeoUID, '<br>',  
              Typology, '</b>',
            # Community input layer
            # Market
              '<br><br>',
              '<b><i><u>Market Dynamics</u></i></b><br>',
              'Tract average home value: ', case_when(!is.na(real_avghval_16) ~ dollar(real_avghval_16), TRUE ~ 'No data'), '<br>',
              'Tract average home value change from 2006 to 2016: ', case_when(is.na(real_avghval_16) ~ 'No data', TRUE ~ percent(pctch_real_avghval_06_16, accuracy = .1)),'<br>',
              'Regional average home value: ', dollar(ravg_real_avghval_16), '<br>',
              '<br>',
              'Tract average rent: ', case_when(!is.na(real_avgrent_16) ~ dollar(real_avgrent_16), TRUE ~ 'No data'), '<br>', 
              'Regional average rent: ', dollar(ravg_real_avgrent_16), '<br>', 
              'Tract median rent change from 2011 to 2016: ', percent(pctch_real_avgrent_11_16, accuracy = .1), '<br>',
              '<br>',
              'Median rent gap (nearby - local): ', dollar(tr_rent_gap), '<br>',
              'Regional median rent gap: ', dollar(rg_rent_gap), '<br>',
              '<br>',
            # demographics
             '<b><i><u>Demographics</u></i></b><br>', 
             'Tract population: ', comma(pop_16), '<br>', 
             'Tract household count: ', comma(hh_16), '<br>', 
             'Percent renter occupied: ', percent(per_rent_16, accuracy = .1), '<br>',
             'Tract median income: ', dollar(real_mhhinc_16), '<br>', 
             'Percent low income hh: ', percent(per_all_li_16, accuracy = .1), '<br>', 
             'Percent change in LI: ', percent(per_ch_li, accuracy = .1), '<br>',
             '<br>',
             'Percent Visible Minority: ', percent(per_visible_minority_16, accuracy = .1), '<br>',
             'Regional median Visible Minority: ', percent(rm_per_visible_minority_16, accuracy = .1), '<br>',
             '<br>',
             'Percent college educated: ', percent(per_col_16, accuracy = .1), '<br>',
             'Regional median educated: ', percent(rm_per_col_16, accuracy = .1), '<br>',
            '<br>',
            # risk factors
             '<b><i><u>Risk Factors</u></i></b><br>', 
             'Mostly low income: ', case_when(low_pdmt_medhhinc_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Mix low income: ', case_when(mix_low_medhhinc_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Median rent change: ', case_when(dp_PChRent == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Median rent gap: ', case_when(dp_RentGap == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Hot Market: ', case_when(hotmarket_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Vulnerable to gentrificationin in 2016: ', case_when(vul_gent_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 1996 to 2006: ', case_when(gent_96_06 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 2006 to 2016: ', case_when(gent_06_16 == 1 ~ 'Yes', TRUE ~ 'No')
          )) %>% 
    ungroup() %>% 
    data.frame()
#
# Color palettes 
# --------------------------------------------------------------------------
displacement_typologies_pal <- 
  colorFactor(
    c(
      
      '#87CEFA', 
      '#6495ED',              
      '#9e9ac8',      
      
      '#756bb1', 
      '#54278f',
      '#FBEDE0',
      
      '#F4C08D',
      '#EE924F', 
      '#C95123',
      '#CA0000',
      "#C0C0C0"), 
    domain = data_df$Typology, 
    na.color = '#C0C0C0'
  )
tracts <- readRDS(paste("E:\\forked_canada_udp/data/inputs/shp/Canada/",city_name,".rds", sep = ""))
tracts$CTUID <- as.numeric(tracts$CTUID, digits = 7)

tracts <- st_transform(tracts, st_crs("+proj=longlat +datum=WGS84"))

# Join the tracts to the dataframe

df_sf <- 
    right_join(tracts %>% mutate(CTUID = as.numeric(CTUID)), data_df, by = c("CTUID" = "GeoUID"))

# Urban area
# https://www12.statcan.gc.ca/census-recensement/2006/ref/dict/geo049-eng.cfm
# According to StatCan: 
# Area with a population of at least 1,000 and no fewer than 400 persons per square kilometre.
# --------------------------------------------------------------------------

df_sf <-  dplyr::filter(df_sf, pop_16 >= 1000 & (pop_16 / area_16) >= 400)

# ==========================================================================
# overlays
# ==========================================================================

### Industrial points

if (city_name == "Vancouver") {
  industrial <- readRDS("E:\\forked_canada_udp/data/overlays/vancouver/industrial.rds")
  industrial <- 
  st_read("E:\\forked_canada_udp/data/overlays/vancouver/MV_ILI_2015.shp") %>% 
    dplyr::filter(substr(Type_of_Us, 1, 10) == "Industrial") %>%
    mutate(
      # create typology for maps
      all_zones = 
        factor( # turn to factor for mapping 
          case_when(
            TRUE ~ "Industrial Area"
          )
        )
    )
   industrial <- st_transform(industrial, st_crs("+proj=longlat +datum=WGS84"))
   saveRDS(industrial, "E:\\forked_canada_udp/data/overlays/vancouver/industrial.rds")
  
### Parks
  
  parks <- readRDS("E:\\forked_canada_udp/data/overlays/vancouver/parks.rds")
  parks <- 
    st_read("E:\\forked_canada_udp/data/overlays/vancouver/RegionalParkBoundary.shp") %>% 
    mutate(
      # create typology for maps
      Parks = 
        factor( # turn to factor for mapping 
          case_when(
            TRUE ~ "Park Boundary"
          )
        )
    )
  parks <- st_transform(parks, st_crs("+proj=longlat +datum=WGS84"))
  saveRDS(parks, "E:\\forked_canada_udp/data/overlays/vancouver/parks.rds")
  
  # Transit lines:
  
  transit_lines <- readRDS("E:\\forked_canada_udp/data/overlays/vancouver/transit_lines.rds")
  transit_stops <- readRDS("E:\\forked_canada_udp/data/overlays/vancouver/transit_stops.rds")
  
  # include all routes except bus routes; which are type 3
   transit_lines <- 
    st_read("E:\\forked_canada_udp/data/overlays/vancouver/TransLink_routes/TransLink_General_Transit_Feed_Specification__GTFS__Data___Routes.shp")
   transit_lines <- transit_lines %>%
    dplyr::filter(route_type != 3)
   transit_lines <- st_transform(transit_lines, st_crs("+proj=longlat +datum=WGS84"))
  
  # only include location_type 1; which are the non bus-stops
   transit_stops <- 
    st_read("E:\\forked_canada_udp/data/overlays/vancouver/TransLink_stops/TransLink_General_Transit_Feed_Specification__GTFS__Data___Stops.shp")
   transit_stops <- transit_stops %>%
    dplyr::filter(location_t == 1)
   transit_stops <- st_transform(transit_stops, st_crs("+proj=longlat +datum=WGS84"))
  
   saveRDS(transit_stops,"E:\\forked_canada_udp/data/overlays/vancouver/transit_stops.rds")
   saveRDS(transit_lines,"E:\\forked_canada_udp/data/overlays/vancouver/transit_lines.rds")
  
  ## Non-market housing ##
  
  non_market_housing <- readRDS("E:\\forked_canada_udp/data/overlays/vancouver/non-market-housing.rds")
   non_market_housing <- 
    st_read("E:\\forked_canada_udp/data/overlays/vancouver/non-market-housing.shp")
   non_market_housing <- st_transform(non_market_housing, st_crs("+proj=longlat +datum=WGS84"))
  
   saveRDS(non_market_housing,"E:\\forked_canada_udp/data/overlays/vancouver/non-market-housing.rds")
   
  # palettes
   transit_pal <- 
     colorFactor(paste("#", unique(transit_lines$route_colo), sep = ""), domain = unique(transit_lines$route_long))
   
   
   parks_pal <- 
     colorFactor('#228B22', domain = parks$Parks)
   
   industry_pal <- 
     colorFactor(c('light gray', 'gray', 'dark gray'), domain = industrial$Type_of_Us)
   
   #housing_pal <- 
   #  colorFactor(
   #    c('#377eb8',
   #      '#4daf4a',
   #      '#984ea3'), 
   #    domain = non_market_housing$project_sta)
  
} else if (city_name == "Toronto") {
  parks <- 
    st_read("E:\\forked_canada_udp/data/overlays/toronto/parks-wgs84/CITY_GREEN_SPACE_WGS84.shp") %>% 
    mutate(
      # create typology for maps
      Parks = 
        factor( # turn to factor for mapping 
          case_when(
            TRUE ~ "Park Boundary"
          )
        )
      
    )
  parks <- parks[!is.na(parks$SCODE_NAME),]
  parks <- st_transform(parks, st_crs("+proj=longlat +datum=WGS84"))
  # Transit lines:
  ttc_subway <- 
    st_read("E:\\forked_canada_udp/data/overlays/toronto/ttc-subway-shapefile-wgs84/TTC_SUBWAY_LINES_WGS84.shp")
  
  go_transit <-
    read_gtfs("E:\\forked_canada_udp/data/overlays/toronto/GO_GTFS.zip", files = c("routes", "shapes"))
  up_express <-
    read_gtfs("E:\\forked_canada_udp/data/overlays/toronto/UP-GTFS.zip", files = c("routes", "shapes"))
  
  go_transit_sf <- gtfs_as_sf(go_transit)
  up_express_sf <- gtfs_as_sf(up_express)
  
  go_routes_sf <- get_route_geometry(go_transit_sf)
  up_routes_sf <- get_route_geometry(up_express_sf)
  
  go_routes_sf <- st_transform(go_routes_sf, st_crs("+proj=longlat +datum=WGS84"))
  up_routes_sf <- st_transform(up_routes_sf, st_crs("+proj=longlat +datum=WGS84"))
  
  ttc_subway['System'] = 'TTC'
  go_routes_sf["System"] = "Go Transit"
  up_routes_sf["System"] = "UP Express"
  ttc_subway = ttc_subway[,c('System', 'geometry')]
  go_routes_sf = go_routes_sf[,c('System', 'geometry')]
  up_routes_sf = up_routes_sf[,c('System', 'geometry')]
  
  all_transit = rbind(ttc_subway, go_routes_sf, up_routes_sf)
  
  non_market_housing <- 
    st_read("E:\\forked_canada_udp/data/overlays/toronto/Geocoding_Result_2.shp")
  non_market_housing <- st_transform(non_market_housing, st_crs("+proj=longlat +datum=WGS84"))
  
  neighbourhoods <- 
    st_read("E:\\forked_canada_udp/data/overlays/toronto/Neighbourhoods/Neighbourhoods.shp")
  neighbourhoods <- st_transform(neighbourhoods, st_crs("+proj=longlat +datum=WGS84"))
  
  former_municipalities <-
    st_read("E:\\forked_canada_udp/data/overlays/toronto/Former Municipality Boundaries Data/Former Municipality Boundaries Data.shp")
  former_municipalities <- st_transform(former_municipalities, st_crs("+proj=longlat +datum=WGS84"))
  parks_plot <- function(map = .) {
    map %>%
      addPolygons(
        data = parks,
        group = "Public Green Areas",
        label = ~NAME,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = "#228B22", 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = '#228B22',
          bringToFront = FALSE
        )
      ) 
  }
  
  transit_plot <- function(map = .) {
    map %>%
      addPolylines(
        data = all_transit,
        group = "Transit Systems",
        fillOpacity = 1, 
        color =  ~transit_pal(System), 
        stroke = TRUE, 
        weight = .75, 
        opacity = 1, 
      ) %>%
      addLegend(
        data = all_transit,
        pal = transit_pal, 
        values = ~System, 
        group = "Transit Systems",
        title = "Transit Systems"
      )
  }
  
  housing_plot <- function(map = .) {
    map %>%
      addCircleMarkers(
        data = non_market_housing,
        radius = 2,
        color =  'orange', 
        fillOpacity = 1, 
        stroke = TRUE, 
        weight = 1,
        group = "Non-market housing",
        
      )
  }
  
  municipalities_plot <- function(map = .) {
    map %>%
      addPolylines(
        data = former_municipalities,
        label = ~FIELD_8,
        color =  ~municipalities_pal(FIELD_8), 
        fillOpacity = .7, 
        stroke = TRUE, 
        weight = 3,
        group = "Former municipalities",
        
      ) %>%
      addLegend(
        data = former_municipalities,
        pal = municipalities_pal, 
        values = ~FIELD_8, 
        group = "Former municipalities",
        title = "Former municipalities"
      )
  }
  
  
  # Options
  options <- function(map = ., 
                      transit = NULL,
                      neighbourhoods = NULL,
                      municipalities = NULL,
                      parks = NULL,
                      housing = NULL
  ) {
    map %>% 
      addLayersControl(
        baseGroups = 
          c(paste("City of", city_name), paste(city_name, "CMA")),
        overlayGroups = 
          c(transit, municipalities, parks, housing
          ),
        options = layersControlOptions(collapsed = FALSE, maxHeight = "auto")) %>%
      hideGroup(
        c(transit, municipalities, parks, housing
        ))
  }
  
  city_map <- 
    map_it() %>% 
    parks_plot() %>%
    municipalities_plot() %>%
    transit_plot() %>%
    housing_plot() %>%
    options(transit = "Transit Systems",parks = "Public Green Areas", municipalities = "Former municipalities", housing = "Non-market housing") %>%
    setView(lng = -79.38, lat = 43.65, zoom = 10)
  
  
  
  
  
}
}


# ==========================================================================
# Maps
# ==========================================================================


if (city_name == "Vancouver") {
  transit_pal <- 
    colorFactor(paste("#", unique(transit_lines$route_colo), sep = ""), domain = unique(transit_lines$route_long))
  
  
  parks_pal <- 
    colorFactor('#228B22', domain = parks$Parks)
  
  industry_pal <- 
    colorFactor(c('light gray', 'gray', 'dark gray'), domain = industrial$Type_of_Us)
  
  #housing_pal <- 
  #  colorFactor(
  #    c('#377eb8',
  #      '#4daf4a',
  #      '#984ea3'), 
  #    domain = non_market_housing$project_sta)
  pks <- function(map = .) {
    map %>%
      addPolygons(
        data = parks,
        group = "Metro Vancouver Regional Parks",
        label = ~Name,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = "#228B22", 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = '#228B22',
          bringToFront = FALSE
        )
      )
  }
  industry <- function(map = .) {
    map %>%
      addPolygons(
        data = industrial,
        group = "Industrial Area",
        label = ~Type_of_Us,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = 'gray', 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = 'grey',
          bringToFront = FALSE
        )
      )
  }
  
  transit <- function(map = .) {
    map %>%
      addPolylines(
        data = transit_lines,
        group = "Transit Routes",
        label = ~route_long,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color =  ~transit_pal(route_long),
        stroke = TRUE, 
        weight = .5, 
        opacity = .6, 
      ) %>%
      addCircleMarkers(
        data = transit_stops,
        radius = 2,
        group = "Transit Routes",
        color = 'black',
        stroke = FALSE,
        fillOpacity = 1
      ) %>%
      addLegend(
        data = transit_lines,
        pal = transit_pal,
        values = ~route_long, 
        group = "Transit Routes",
        title = "Transit Routes"
      )
  }
  
  housing <- function(map = .) {
    map %>%
      addCircleMarkers(
        data = non_market_housing,
        label = ~project_sta,
        radius = 3,
        color =  'orange', 
        fillOpacity = .5, 
        stroke = TRUE, 
        weight = .7,
        group = "Non-market housing",
        
      )
  }
  
  # Options
  options <- function(map = ., 
                      transit = NULL,
                      industry = NULL,
                      parks = NULL,
                      housing = NULL
  ) {
    map %>% 
      addLayersControl(
        baseGroups = 
          c(paste("City of", city_name), paste(city_name, "CMA")),
        overlayGroups = 
          c(transit, industry, parks, housing
          ),
        options = layersControlOptions(collapsed = FALSE, maxHeight = "auto")) %>%
      hideGroup(
        c(transit, industry, parks, housing
        ))
  }
  
  city_map <- 
    map_it() %>% 
    pks() %>%
    industry() %>%
    transit() %>%
    housing() %>%
    options(transit = "Transit Routes", industry = "Industrial Area", parks = "Metro Vancouver Regional Parks", housing = "Non-market housing") %>%
    setView(lng = -123.12, lat = 49.28, zoom = 10)
} else if (city_name == "Toronto") {
  
  parks_pal <- 
    colorFactor('#228B22', domain = parks$NAME)
  
  municipalities_pal <-
    colorFactor(
      c('Set1'), 
      domain = former_municipalities$FIELD_8)
  
  transit_pal <- 
    colorFactor(c('Dark2'), domain = all_transit$System)
  
}



# ==========================================================================
# Mapping functions
# ==========================================================================


map_it <- function(){
  leaflet(data = df_sf) %>% 
    addMapPane(name = "polygons", zIndex = 410) %>% 
    addMapPane(name = "maplabels", zIndex = 420) %>% # higher zIndex rendered on top
    addProviderTiles("CartoDB.PositronNoLabels") %>%
    addProviderTiles("CartoDB.PositronOnlyLabels", 
                     options = leafletOptions(pane = "maplabels"),
                     group = "map labels") %>% # see: http://leaflet-extras.github.io/leaflet-providers/preview/index.html
    addEasyButton(
      easyButton(
        icon="fa-crosshairs", 
        title="My Location",
        onClick=JS("function(btn, map){ map.locate({setView: true}); }"))) %>%
    # Displacement typology
    addPolygons(
      data = df_sf %>% dplyr::filter(Region.Name == city_name), 
      group = paste("City of", city_name), 
      label = ~Typology,
      labelOptions = labelOptions(textsize = "12px"),
      fillOpacity = .5, 
      color = ~displacement_typologies_pal(Typology), 
      stroke = TRUE, 
      weight = .7, 
      opacity = .60, 
      highlightOptions = highlightOptions(
        color = "#ff4a4a",
        weight = 5,
        bringToFront = TRUE
      ),        
      popup = ~popup, 
      popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)
    ) %>%
    addPolygons(
      data = df_sf, 
      group = paste(city_name, "CMA"), 
      label = ~Typology,
      labelOptions = labelOptions(textsize = "12px"),
      fillOpacity = .5, 
      color = ~displacement_typologies_pal(Typology), 
      stroke = TRUE, 
      weight = .7, 
      opacity = .60, 
      highlightOptions = highlightOptions(
        color = "#ff4a4a",
        weight = 5,
        bringToFront = TRUE
      ),        
      popup = ~popup, 
      popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)
    ) %>%
    addLegend(
      data = df_sf,
      pal = displacement_typologies_pal, 
      values = ~Typology, 
      group = "Displacement Typology",  
      title = "Displacement Typology"
    )
}

if (city_name == "Vancouver") {
  pks <- function(map = .) {
    map %>%
      addPolygons(
        data = parks,
        group = "Metro Vancouver Regional Parks",
        label = ~Name,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = "#228B22", 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = '#228B22',
          bringToFront = FALSE
        )
      )
  }
  industry <- function(map = .) {
    map %>%
      addPolygons(
        data = industrial,
        group = "Industrial Area",
        label = ~Type_of_Us,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = 'gray', 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = 'grey',
          bringToFront = FALSE
        )
      )
  }
  
  transit <- function(map = .) {
    map %>%
      addPolylines(
        data = transit_lines,
        group = "Transit Routes",
        label = ~route_long,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color =  ~transit_pal(route_long),
        stroke = TRUE, 
        weight = .5, 
        opacity = .6, 
      ) %>%
      addCircleMarkers(
        data = transit_stops,
        radius = 2,
        group = "Transit Routes",
        color = 'black',
        stroke = FALSE,
        fillOpacity = 1
      ) %>%
      addLegend(
        data = transit_lines,
        pal = transit_pal,
        values = ~route_long, 
        group = "Transit Routes",
        title = "Transit Routes"
      )
  }
  
  housing <- function(map = .) {
    map %>%
      addCircleMarkers(
        data = non_market_housing,
        label = ~project_sta,
        radius = 3,
        color =  'orange', 
        fillOpacity = .5, 
        stroke = TRUE, 
        weight = .7,
        group = "Non-market housing",
        
      )
  }
  
  # Options
  options <- function(map = ., 
                      transit = NULL,
                      industry = NULL,
                      parks = NULL,
                      housing = NULL
  ) {
    map %>% 
      addLayersControl(
        baseGroups = 
          c(paste("City of", city_name), paste(city_name, "CMA")),
        overlayGroups = 
          c(transit, industry, parks, housing
          ),
        options = layersControlOptions(collapsed = FALSE, maxHeight = "auto")) %>%
      hideGroup(
        c(transit, industry, parks, housing
        ))
  }
  
  city_map <- 
    map_it() %>% 
    pks() %>%
    industry() %>%
    transit() %>%
    housing() %>%
    options(transit = "Transit Routes", industry = "Industrial Area", parks = "Metro Vancouver Regional Parks", housing = "Non-market housing") %>%
    setView(lng = -123.12, lat = 49.28, zoom = 10)
} else if (city_name == "Toronto") {
  
  
  parks_plot <- function(map = .) {
    map %>%
      addPolygons(
        data = parks,
        group = "Public Green Areas",
        label = ~NAME,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = "#228B22", 
        stroke = TRUE, 
        weight = .7, 
        opacity = .6, 
        highlightOptions = highlightOptions(
          color = '#228B22',
          bringToFront = FALSE
        )
      ) 
  }
  
  transit_plot <- function(map = .) {
    map %>%
      addPolylines(
        data = all_transit,
        group = "Transit Systems",
        fillOpacity = 1, 
        color =  ~transit_pal(System), 
        stroke = TRUE, 
        weight = .75, 
        opacity = 1, 
      ) %>%
      addLegend(
        data = all_transit,
        pal = transit_pal, 
        values = ~System, 
        group = "Transit Systems",
        title = "Transit Systems"
      )
  }
  
  housing_plot <- function(map = .) {
    map %>%
      addCircleMarkers(
        data = non_market_housing,
        radius = 2,
        color =  'orange', 
        fillOpacity = 1, 
        stroke = TRUE, 
        weight = 1,
        group = "Non-market housing",
        
      )
  }
  
  municipalities_plot <- function(map = .) {
    map %>%
      addPolylines(
        data = former_municipalities,
        label = ~FIELD_8,
        color =  ~municipalities_pal(FIELD_8), 
        fillOpacity = .7, 
        stroke = TRUE, 
        weight = 3,
        group = "Former municipalities",
        
      ) %>%
      addLegend(
        data = former_municipalities,
        pal = municipalities_pal, 
        values = ~FIELD_8, 
        group = "Former municipalities",
        title = "Former municipalities"
      )
  }
  

  # Options
  options <- function(map = ., 
                      transit = NULL,
                      neighbourhoods = NULL,
                      municipalities = NULL,
                      parks = NULL,
                      housing = NULL
  ) {
    map %>% 
      addLayersControl(
        baseGroups = 
          c(paste("City of", city_name), paste(city_name, "CMA")),
        overlayGroups = 
          c(transit, municipalities, parks, housing
          ),
        options = layersControlOptions(collapsed = FALSE, maxHeight = "auto")) %>%
      hideGroup(
        c(transit, municipalities, parks, housing
        ))
  }
  
  city_map <- 
    map_it() %>% 
    parks_plot() %>%
    municipalities_plot() %>%
    transit_plot() %>%
    housing_plot() %>%
    options(transit = "Transit Systems",parks = "Public Green Areas", municipalities = "Former municipalities", housing = "Non-market housing") %>%
    setView(lng = -79.38, lat = 43.65, zoom = 10)
  
  
  
  
  
}

#
# City specific displacement-typologies map
# --------------------------------------------------------------------------


# save map
write_csv(df_sf %>% st_set_geometry(NULL), paste("E:\\forked_canada_udp/data/outputs/typologies/", city_name, "test_final_output.csv", sep = ""))
htmlwidgets::saveWidget(city_map, file=paste("E:\\forked_canada_udp/maps/", city_name, "test_udp.html", sep = ""))

