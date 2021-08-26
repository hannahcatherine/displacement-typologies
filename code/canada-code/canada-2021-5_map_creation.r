# ==========================================================================
# Map data for displacement and vulnerability measures
# Author: Tim Thomas - timthomas@berkeley.edu
# Created: 2019.10.13
# 1.0 code: 2020.10.25
# Note: The US Census API has been unreliable in some occasions. We therefore
#   suggest downloading every API run that you do when it is successful. 
#   The "Begin..." sections highlight these API downloads followed by a load
#   option. Uncomment and edit these API runs as needed and then comment them 
#   again when testing your maps. 
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

# load packages
if (!require("pacman")) install.packages("pacman")
if (!require("tidyverse")) install.packages("tidyverse")
# pacman::p_install_gh("timathomas/neighborhood", "jalvesaq/colorout")
pacman::p_load(readxl, R.utils, colorspace, bit64, neighborhood, rmapshaper, sf, sp, geojsonsf, scales, data.table, tigris, tidycensus, leaflet, tidyverse)
# update.packages(ask = FALSE)
# Cache downloaded tiger files
# options(tigris_use_cache = TRUE)

# ==========================================================================
# Data
# ==========================================================================

#
# Pull in data: change this when there's new data
# --------------------------------------------------------------------------

data <- read.csv("E:\\forked_canada_udp/data/outputs/typologies/vancouver_typology_output.csv")

data <- data %>%
        mutate(GeoUID = as.numeric(GeoUID))
#
# Create Neighborhood Racial Typologies for mapping - do not have canadian equivalent
# --------------------------------------------------------------------------
# State fips code list: https://www.mcc.co.mercer.pa.us/dps/state_fips_code_listing.htm
#
# Demographics: Student population and vacancy
# --------------------------------------------------------------------------

###
# Begin demographic download
###
# dem_vars <- 
#   c('st_units' = 'B25001_001',
#     'st_vacant' = 'B25002_003', 
#     'st_ownocc' = 'B25003_002', 
#     'st_rentocc' = 'B25003_003',
#     'st_totenroll' = 'B14007_001',
#     'st_colenroll' = 'B14007_017',
#     'st_proenroll' = 'B14007_018',
#     'st_pov_under' = 'B14006_009', 
#     'st_pov_grad' = 'B14006_010')
# tr_dem_acs <-
#   get_acs(
#     geography = "tract",
#     state = states,
#     output = 'wide',
#     variables = dem_vars,
#     cache_table = TRUE,
#     year = 2018
#   )
# fwrite(tr_dem_acs, '~/git/displacement-typologies/data/outputs/downloads/tr_dem_acs.csv.gz')
### 
# End
###

# tr_dem_acs <- read_csv('~/git/displacement-typologies/data/outputs/downloads/tr_dem_acs.csv.gz')

# tr_dem <- 
#  tr_dem_acs %>% 
#  group_by(GEOID) %>% 
#  mutate(
#    tr_pstudents = sum(st_colenrollE, st_proenrollE, na.rm = TRUE)/st_totenrollE, 
#    tr_prenters = st_rentoccE/st_unitsE,
#    tr_pvacant = st_vacantE/st_unitsE,
#    GEOID = as.numeric(GEOID)
#    )

# Load UCLA indicators for LA maps
# ucla_df <- read_excel("~/git/displacement-typologies/data/inputs/UCLAIndicators/UCLA_CNK_COVID19_Vulnerability_Indicators_8_20_2020.xls")
#
# Prep dataframe for mapping
# --------------------------------------------------------------------------

scale_this <- function(x){
  (x - mean(x, na.rm=TRUE)) / sd(x, na.rm=TRUE)
}

df <- 
    data %>% 
    mutate(
     # create typology for maps
        Typology = 
            factor( # turn to factor for mapping 
                case_when(
            ## Typology ammendments
                    typ_cat == "['AdvG', 'BE']" ~ 'Advanced Gentrification',
                    typ_cat == "['LISD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
                    typ_cat == "['LISD']" & gent_96_06_urban == 1 ~ 'Advanced Gentrification',
                    typ_cat == "['OD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
                    typ_cat == "['OD']" & gent_96_06_urban == 1 ~ 'Advanced Gentrification',
                    typ_cat == "['LISD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['LISD']" & gent_06_16_urban == 1 ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['OD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['OD']" & gent_06_16_urban == 1 ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['SAE', 'VHI']" ~ 'Super Gentrification and Exclusion',
            ## Regular adjustments
                    typ_cat == "['AdvG']" ~ 'Advanced Gentrification',
                    typ_cat == "['ARE']" ~ 'At Risk of Becoming Exclusive',
                    typ_cat == "['ARG']" ~ 'At Risk of Gentrification',
                    typ_cat == "['BE']" ~ 'Becoming Exclusive', 
                    typ_cat == "['EOG']" ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['OD']" ~ 'Ongoing Displacement',
                    typ_cat == "['SAE']" ~ 'Stable/Advanced Exclusive', 
                    typ_cat == "['LISD']" ~ 'Low-Income/Susceptible to Displacement',
                    typ_cat == "['SMMI']" ~ 'Stable Moderate/Mixed Income',
                    typ_cat == "['SGE']" ~ 'Super Gentrification and Exclusion',
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
        real_avgrent_16 = case_when(real_avgrent_16 > 0 ~ real_avgrent_16)
    ) %>% 
    mutate(
        ravg_real_avghval_16 = mean(real_avghval_16, na.rm = TRUE), 
        ravg_real_avgrent_16 = mean(real_avgrent_16, na.rm = TRUE), 
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
              'Tract home value change from 2006 to 2016: ', case_when(is.na(real_avghval_16) ~ 'No data', TRUE ~ percent(pctch_real_avghval_06_16, accuracy = .1)),'<br>',
              'Regional average home value: ', dollar(ravg_real_avghval_16), '<br>',
              '<br>',
              'Tract average rent: ', case_when(!is.na(real_avgrent_16) ~ dollar(real_avgrent_16), TRUE ~ 'No data'), '<br>', 
              'Regional average rent: ', case_when(is.na(real_avgrent_16) ~ 'No data', TRUE ~ dollar(ravg_real_avgrent_16)), '<br>', 
              'Tract rent change from 2006 to 2016: ', percent(pctch_real_avgrent_06_16, accuracy = .1), '<br>',
              '<br>',
              'Rent gap (nearby - local): ', dollar(tr_rent_gap), '<br>',
              'Regional average rent gap: ', dollar(rm_rent_gap), '<br>',
              '<br>',
            # demographics
             '<b><i><u>Demographics</u></i></b><br>', 
             'Tract population: ', comma(pop_16), '<br>', 
             'Tract household count: ', comma(hh_16), '<br>', 
             'Percent renter occupied: ', percent(per_rent_16, accuracy = .1), '<br>',
             # 'Percent vacant homes: ', percent(tr_pvacant, accuracy = .1), '<br>',
             'Tract median income: ', dollar(real_mhhinc_16), '<br>', 
             'Percent low income hh: ', percent(per_all_li_16, accuracy = .1), '<br>', 
             # 'Percent change in LI: ', percent(per_ch_li, accuracy = .1), '<br>',
             '<br>',
             'Percent Visible Minority: ', percent(per_visible_minority_16, accuracy = .1), '<br>',
             'Regional median Visible Minority: ', percent(rm_per_visible_minority_16, accuracy = .1), '<br>',
             '<br>',
             # 'Percent students: ', percent(tr_pstudents, accuracy = .1), '<br>',
             'Percent college educated: ', percent(per_col_16, accuracy = .1), '<br>',
             'Regional median educated: ', percent(rm_per_col_16, accuracy = .1), '<br>',
            '<br>',
            # risk factors
             '<b><i><u>Risk Factors</u></i></b><br>', 
             'Mostly low income: ', case_when(low_pdmt_medhhinc_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Mix low income: ', case_when(mix_low_medhhinc_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Rent change: ', case_when(dp_PChRent == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Rent gap: ', case_when(dp_RentGap == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Hot Market: ', case_when(hotmarket_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Vulnerable to gentrification: ', case_when(vul_gent_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 1996 to 2006: ', case_when(gent_96_06 == 1 | gent_96_06_urban == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 2006 to 2016: ', case_when(gent_06_16 == 1 | gent_06_16_urban == 1 ~ 'Yes', TRUE ~ 'No')
          )) %>% 
    ungroup() %>% 
    data.frame()

###
# Begin Download tracts in each of the shapes in sf (simple feature) class
###


# tracts <- 
#     reduce(
#         map(states, function(x) # purr loop
#             get_acs(
#                 geography = "tract", 
#                 variables = "B01003_001", 
#                 state = x, 
#                 geometry = TRUE, 
#                 year = 2018)
#         ), 
#         rbind # bind each of the dataframes together
#     ) %>% 
#     select(GEOID) %>% 
#     mutate(GEOID = as.numeric(GEOID)) %>% 
#     st_transform(st_crs(4326)) 

#     saveRDS(tracts, '~/git/displacement-typologies/data/outputs/downloads/state_tracts.RDS')
###
# End
###

tracts <- st_read("Vancouver/vancouver.shp")
tracts$CTUID <- as.numeric(tracts$CTUID, digits = 7)



tracts <- st_transform(tracts, st_crs("+proj=longlat +datum=WGS84"))



# Join the tracts to the dataframe

df_sf <- 
    right_join(tracts %>% mutate(CTUID = as.numeric(CTUID)), df, by = c("CTUID" = "GeoUID")) 

# ==========================================================================
# Select tracts within counties that intersect with urban areas - only for tigris, aka US data
# ==========================================================================

### read in urban areas

###
# Begin Download
###
# urban_areas <- 
#   urban_areas() %>% 
#   st_transform(st_crs(df_sf))
# saveRDS(urban_areas, "~/git/displacement-typologies/data/outputs/downloads/urban_areas.rds")
### 
# End Download
###

# urban_areas <-
  # readRDS("~/git/displacement-typologies/data/outputs/downloads/urban_areas.rds") 

#
# Download water
# --------------------------------------------------------------------------

###
# Begin Download Counties
###
# counties <- 
#   counties(states) %>% 
#   st_transform(st_crs(df_sf)) %>% 
#   .[df_sf, ]  %>% 
#   arrange(STATEFP, COUNTYFP) 
#
# st_geometry(counties) <- NULL
#
# state_water <- counties %>% pull(STATEFP)
# county_water <- counties %>% pull(COUNTYFP)
#
# water <- 
# map2_dfr(state_water, county_water, 
#   function(states = state_water, counties = county_water){
#     area_water(
#       state = states,
#       county = counties, 
#       class = 'sf') %>% 
#     filter(AWATER > 500000)
#     }) %>% 
# st_transform(st_crs(df_sf))
#
# saveRDS(water, "~/git/displacement-typologies/data/outputs/downloads/water.rds")
###
# End
###

# water <- readRDS("~/git/displacement-typologies/data/outputs/downloads/water.rds")

#
# Remove water & non-urban areas & simplify spatial features
# --------------------------------------------------------------------------

# st_erase <- function(x, y) {
# st_difference(x, st_union(y))
# }

###
# Note: This takes a very long time to run. 
###
# df_sf_urban <- 
#  df_sf %>% 
#  st_crop(urban_areas) %>%
#  st_erase(water) %>% 
#  ms_simplify(keep = 0.5)

# ==========================================================================
# overlays
# ==========================================================================

### Redlining

    ###add your city here


### Industrial points


industrial <- 
  st_read("E:\\forked_canada_udp/data/overlays/industrial/vancouver/MVILI2015/MV_ILI_2015.shp") %>% 
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
### HUD
#plot(industrial)


### Parks

parks <- 
  st_read("E:\\forked_canada_udp/data/overlays/RegionalParkBoundary/RegionalParkBoundary.shp") %>% 
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


transit <- 
  st_read("E:\\forked_canada_udp/data/overlays/FrequentTransitDevelopmentAreas/FTDA_RCS.shp")

# replace the one lone Bus* entry
transit[7,5] <- "Bus"
transit <- transit %>% drop_na("Type")
transit <- st_transform(transit, st_crs("+proj=longlat +datum=WGS84"))
transit <- st_zm(transit, drop = T, what = "ZM")


## Non-market housing
non_market_housing <- 
  st_read("E:\\forked_canada_udp/data/overlays/non-market-housing/non-market-housing.shp")
non_market_housing <- st_transform(non_market_housing, st_crs("+proj=longlat +datum=WGS84"))


### Hospitals

### Universities

### Road map
###
# Begin download road maps
###
# road_map <- 
#     reduce(
#         map(states, function(state){
#             primary_secondary_roads(state, class = 'sf')
#         }),
#         rbind
#     ) %>% 
#     filter(RTTYP %in% c('I','U')) %>% 
#     ms_simplify(keep = 0.1) %>% 
#     st_transform(st_crs(df_sf_urban)) %>%
#     st_join(., df_sf_urban %>% select(city), join = st_intersects) %>% 
#     mutate(rt = case_when(RTTYP == 'I' ~ 'Interstate', RTTYP == 'U' ~ 'US Highway')) %>% 
#     filter(!is.na(city))
# saveRDS(road_map, '~/git/displacement-typologies/data/outputs/downloads/roads.rds')
###
# End
###

# road_map <- readRDS('~/git/displacement-typologies/data/outputs/downloads/roads.rds')

### Atlanta Beltline
### Opportunity Zones
# ==========================================================================
# Maps
# ==========================================================================

#
# Color palettes 
# --------------------------------------------------------------------------
displacement_typologies_pal <- 
    colorFactor(
        c(
            # '#e3dcf5',
            '#87CEFA',#cbc9e2', # "#f2f0f7", 
            '#6495ED',#5b88b5', #"#6699cc", #light blue              
            '#9e9ac8', #D9D7E8', #"#cbc9e2", #D9D7E8     
            # "#9e9ac8",
            '#756bb1', #B7B6D3', #"#756bb1", #B7B6D3
            '#54278f', #8D82B6', #"#54278f", #8D82B6
            '#FBEDE0', #"#ffffd4", #FBEDE0
            # '#ffff85',
            '#F4C08D', #"#fed98e", #EE924F
            '#EE924F', #"#fe9929", #EE924F
            '#C95123', #"#cc4c02", #C75023
            '#CA0000',
            "#C0C0C0"), 
        domain = df$Typology, 
        na.color = '#C0C0C0'
    )


parks_pal <- 
     colorFactor('#228B22', domain = parks$Parks)

industry_pal <- 
  colorFactor(c('light gray', 'gray', 'dark gray'), domain = industrial$Type_of_Us)

transit_pal <- 
  colorFactor(
    c("PiYG"), 
    domain = transit$Type)


housing_pal <- 
  colorFactor(
    c('#377eb8',
      '#4daf4a',
      '#984ea3'), 
    domain = non_market_housing$project_sta)
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
        data = df_sf, 
        group = "Displacement Typology", 
        label = ~Typology,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .65, 
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
      pal = displacement_typologies_pal, 
      values = ~Typology, 
      group = "Displacement Typology",  
      title = "Displacement Typology"
    )
}

pks <- function(map = .) {
  map %>%
    addPolygons(
      data = parks,
      group = "Metro Vancouver Regional Parks",
      label = ~Name,
      labelOptions = labelOptions(textsize = "12px"),
      fillOpacity = .25, 
      color = "#228B22", 
      stroke = TRUE, 
      weight = 1, 
      opacity = .75, 
      highlightOptions = highlightOptions(
        color = '#228B22',
        bringToFront = FALSE
      )
    ) %>%
    addLegend(
      data = parks,
      pal = parks_pal, 
      values = ~Parks, 
      group = "Metro Vancouver Regional Parks",  
      title = "Metro Vancouver Regional Parks"
    )
}

industry <- function(map = .) {
  map %>%
    addPolygons(
      data = industrial,
      group = "Industrial Area",
      label = ~Type_of_Us,
      labelOptions = labelOptions(textsize = "12px"),
      fillOpacity = .15, 
      color = ~industry_pal(Type_of_Us), 
      stroke = TRUE, 
      weight = 1, 
      opacity = .5, 
      highlightOptions = highlightOptions(
        color = 'grey',
        bringToFront = FALSE
      )
    ) %>%
    addLegend(
      data = industrial,
      pal = industry_pal, 
      values = ~Type_of_Us,
      group = "Industrial Area",
      title = "Industrial Area"
    )
}

FTDA <- function(map = .) {
  map %>%
    addPolygons(
      data = transit,
      group = "Frequent Transit Development Area",
      label = ~NAME,
      labelOptions = labelOptions(textsize = "12px"),
      fillOpacity = .15, 
      color =  ~transit_pal(Type), 
      stroke = TRUE, 
      weight = 1, 
      opacity = .5, 
      highlightOptions = highlightOptions(
        color = 'blue',
        bringToFront = FALSE
      )
    ) %>%
    addLegend(
      data = transit,
      pal = transit_pal, 
      values = ~Type, 
      group = "Frequent Transit Development Area",
      title = "Frequent Transit Development Area"
    )
}

housing <- function(map = .) {
  map %>%
    addCircleMarkers(
      data = non_market_housing,
      label = ~project_sta,
      radius = 5, 
      color =  ~housing_pal(project_sta), 
      fillOpacity = .8, 
      stroke = TRUE, 
      weight = .6,
      group = "Non-market housing",

    ) %>%
    addLegend(
      data = non_market_housing,
      pal = housing_pal, 
      values = ~project_sta, 
      group = "Non-market housing",
      title = "Non-market housing"
    )
  
  
}

# Options
options <- function(
  map = .,
  pks = NULL,
  industry = NULL,
  transit = NULL,
  housing = NULL) {
  map %>% 
    addLayersControl(
      overlayGroups = 
        c("Displacement Typology", pks, industry, transit, housing),
      options = layersControlOptions(collapsed = FALSE, maxHeight = "auto")) %>%
    hideGroup(c(pks, industry, transit, housing))
}

#
# City specific displacement-typologies map
# --------------------------------------------------------------------------

# vancouver
vancouver <- 
  map_it() %>% 
  pks() %>%
  industry() %>%
  FTDA() %>%
  housing() %>%
  options(pks = "Metro Vancouver Regional Parks", industry = "Industrial Area", transit = "Frequent Transit Development Area", housing = "Non-market housing") %>%
  setView(lng = -123.1, lat = 49.2, zoom = 10)
# save map
htmlwidgets::saveWidget(vancouver, file="vancouver_udp_median_transit.html")

# Create file exports
# --------------------------------------------------------------------------
#vancouver_sf <- df_sf %>% dplyr::select(CTUID, Typology)
#st_write(vancouver_sf, "vancouver_map.gpkg", append=FALSE)
#write_csv(vancouver_sf %>% st_set_geometry(NULL), "vancouver_final_output.csv")

