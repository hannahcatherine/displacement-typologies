
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
# ==========================================================================
# Load Libraries
# ==========================================================================

#
# Load packages and install them if they're not installed.
# --------------------------------------------------------------------------

pacman::p_load(shiny, RColorBrewer, dplyr, readxl, R.utils, colorspace, bit64, neighborhood, rmapshaper, sf, sp, geojsonsf, scales, data.table,leaflet, tidyverse)
# update.packages(ask = FALSE)
# Cache downloaded tiger files
# options(tigris_use_cache = TRUE)

# ==========================================================================
# Data
# ==========================================================================
city_name = "Vancouver"
#
# Pull in data: change this when there's new data
# --------------------------------------------------------------------------

database <- read.csv(paste("E:\\forked_canada_udp/data/outputs/typologies/", city_name, "_typology_output.csv", sep = ""))

database <- database %>%
  mutate(GeoUID = as.numeric(GeoUID))

scale_this <- function(x){
  (x - mean(x, na.rm=TRUE)) / sd(x, na.rm=TRUE)
}

data_df <- 
  database %>% 
  mutate(
    # create typology for maps
    Typology = 
      factor( # turn to factor for mapping 
        case_when(
          ## Typology ammendments
          typ_cat == "['AdvG', 'BE']" ~ 'Advanced Gentrification',
          typ_cat == "['LISD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
          typ_cat == "['OD']" & gent_96_06 == 1 ~ 'Advanced Gentrification',
          typ_cat == "['LISD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
          typ_cat == "['OD']" & gent_06_16 == 1 ~ 'Early/Ongoing Gentrification',
          typ_cat == "['SAE', 'SGE']" ~ 'Super Gentrification and Exclusion',
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
        # 'Percent vacant homes: ', percent(tr_pvacant, accuracy = .1), '<br>',
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
        'Vulnerable to gentrification: ', case_when(vul_gent_16 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
        'Gentrified from 1996 to 2006: ', case_when(gent_96_06 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
        'Gentrified from 2006 to 2016: ', case_when(gent_06_16 == 1 ~ 'Yes', TRUE ~ 'No')
      )) %>% 
  ungroup() %>% 
  data.frame()

tracts <- st_read("E:\\forked_canada_udp/data/inputs/shp/Vancouver/vancouver.shp")
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
    domain = data_df$Typology, 
    na.color = '#C0C0C0'
  )

# ==========================================================================
# Mapping functions
# ==========================================================================

ui <- fluidPage(
  
  titlePanel(paste(city_name, " Exploratory Data Analysis", sep = "")),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(inputId = "Variable",
                  label = "Choose the data you want to see:",
                  choices = c("Median Rent (2016)" = "real_mrent_2016", 
                              "Average Rent (2016)" = "real_avgrent_2016",
                              "Median Income (2016)" = "real_mhhinc_2016",
                              "Median House Value (2016)" = "real_mhval_2016", 
                              "Average House Value (2016)" = "real_avghval_2016"
                  ))),
    mainPanel(
      leafletOutput("mymap")
      )
)
)

server <- function(input, output, session) {
  output$mymap <- renderLeaflet({
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
        data = df_sf %>% dplyr::filter(Region.Name == 'Vancouver'), 
        group = "City of Vancouver", 
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
        group = "Vancouver CMA", 
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
  })
  
  filtered_data <- reactive({
    dplyr::filter(df_sf, df_sf$input$Variable)
  })
  
  
  
  
  output$plot <- renderPlot({
    ggplot(filtered_data, aes(x = input$Variable)) + 
      geom_density()
  })
  
  
  
  
}

shinyApp(ui, server)
  
