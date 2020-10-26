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
p_install_gh("timathomas/neighborhood", "jalvesaq/colorout")
p_load(colorout, neighborhood, readxl, R.utils, bit64, neighborhood, fst, rmapshaper, sf, geojsonsf, scales, data.table, tigris, tidycensus, leaflet, tidyverse)

update.packages(ask = FALSE)
# Cache downloaded tiger files
options(tigris_use_cache = TRUE)

# ==========================================================================
# Data
# ==========================================================================

#
# Pull in data: change this when there's new data
# --------------------------------------------------------------------------

data <- 
    bind_rows( # pull in data
        read_csv('~/git/displacement-typologies/data/outputs/typologies/Atlanta_typology_output.csv') %>% 
            mutate(city = 'Atlanta'),
        read_csv('~/git/displacement-typologies/data/outputs/typologies/Chicago_typology_output.csv') %>% 
            mutate(city = 'Chicago'),
        read_csv('~/git/displacement-typologies/data/outputs/typologies/Cleveland_typology_output.csv') %>% 
            mutate(city = 'Cleveland'),    
        read_csv('~/git/displacement-typologies/data/outputs/typologies/Denver_typology_output.csv') %>%
            mutate(city = 'Denver'),            
        read_csv('~/git/displacement-typologies/data/outputs/typologies/LosAngeles_typology_output.csv') %>% 
            mutate(city = 'LosAngeles'), 
        read_csv('~/git/displacement-typologies/data/outputs/typologies/SanFrancisco_typology_output.csv') %>% 
            mutate(city = 'SanFrancisco'),
        read_csv('~/git/displacement-typologies/data/outputs/typologies/Seattle_typology_output.csv') %>% 
            mutate(city = 'Seattle')
    ) %>% 
    left_join(., 
        read_csv('~/git/displacement-typologies/data/overlays/oppzones.csv') %>% 
        select(
          GEOID = geoid, 
          opp_zone = tract_type
          ) %>%
        mutate(GEOID = as.numeric(GEOID)) 
    )

#
# Create Neighborhood Racial Typologies for mapping
# --------------------------------------------------------------------------


states <- c('17', '13', '08', '28', '47', '06', '53', '39', '25', '33')

###
# Begin Neighborhood Typology creation
###
# df_nt <- ntdf(state = states) %>% mutate(GEOID = as.numeric(GEOID))
# ntcheck(df_nt)
# glimpse(df_nt)
# df_nt %>% group_by(nt_conc) %>% count() %>% arrange(desc(n))
# fwrite(df_nt, '~/git/displacement-typologies/data/outputs/downloads/df_nt.csv.gz')
###
# End
###

# Read in data from above API and reassign factor levels
df_nt <- read_csv('~/git/displacement-typologies/data/outputs/downloads/dt_nt.csv.gz') %>%
  mutate(nt_conc =
    factor(nt_conc,
      levels = c(
        "Mostly Asian",
        "Mostly Black",
        "Mostly Latinx",
        "Mostly Other",
        "Mostly White",
        "Asian-Black",
        "Asian-Latinx",
        "Asian-Other",
        "Asian-White",
        "Black-Latinx",
        "Black-Other",
        "Black-White",
        "Latinx-Other",
        "Latinx-White",
        "Other-White",
        "3 Group Mixed",
        "4 Group Mixed",
        "Diverse",
        "Unpopulated Tract"
        )
    )
  )

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
tr_dem_acs <- read_csv('~/git/displacement-typologies/data/outputs/downloads/tr_dem_acs.csv.gz')

tr_dem <- 
  tr_dem_acs %>% 
  group_by(GEOID) %>% 
  mutate(
    tr_pstudents = sum(st_colenrollE, st_proenrollE, na.rm = TRUE)/st_totenrollE, 
    tr_prenters = st_rentoccE/st_unitsE,
    tr_pvacant = st_vacantE/st_unitsE,
    GEOID = as.numeric(GEOID)
    )

# Load UCLA indicators for LA maps
ucla_df <- read_excel("~/git/displacement-typologies/data/inputs/UCLAIndicators/UCLA_CNK_COVID19_Vulnerability_Indicators_8_20_2020.xls")
#
# Prep dataframe for mapping
# --------------------------------------------------------------------------

scale_this <- function(x){
  (x - mean(x, na.rm=TRUE)) / sd(x, na.rm=TRUE)
}

### Left off change to percentage rank rather than diverging. 
df <- 
    data %>% 
    left_join(df_nt) %>% 
    left_join(tr_dem) %>% 
    left_join(ucla_df, by = c("GEOID" = "tract")) %>% 
    group_by(city) %>% 
    # mutate(
    #     sc_pct_atrisk_workers = scale_this(pct_atrisk_workers),
    #     sc_pct_wo_UI = scale_this(pct_wo_UI),
    #     sc_SIPBI_dec = scale_this(SIPBI_dec),
    #     sc_RVI_dec = scale_this(RVI_dec),
    #     sc_Nr_Aug = scale_this(Nr_Aug)) %>% 
    # ungroup() %>% 
    mutate(
        cat_pct_atrisk_workers = 
            factor(
                case_when(
                    pct_atrisk_workers <= 10 ~ "0 to 10%",
                    pct_atrisk_workers > 10 & pct_atrisk_workers <= 20 ~ "10% to 20%",
                    pct_atrisk_workers > 20 & pct_atrisk_workers <= 30 ~ "20% to 30%",
                    pct_atrisk_workers > 30 & pct_atrisk_workers <= 40 ~ "30% to 40%",
                    pct_atrisk_workers > 40 ~ "40% +"), 
                levels = (
                    c("0 to 10%",
                    "10% to 20%",
                    "20% to 30%",
                    "30% to 40%",
                    "40% +")
                    )),
        cat_pct_wo_UI = 
            factor(
                case_when(
                    pct_wo_UI <= 10 ~ "0 to 10%",
                    pct_wo_UI > 10 & pct_wo_UI <= 20 ~ "10% to 20%",
                    pct_wo_UI > 20 & pct_wo_UI <= 30 ~ "20% to 30%",
                    pct_wo_UI > 30 & pct_wo_UI <= 40 ~ "30% to 40%",
                    pct_wo_UI > 40 ~ "40% +"), 
                levels = (
                    c("0 to 10%",
                    "10% to 20%",
                    "20% to 30%",
                    "30% to 40%",
                    "40% +")
                    )),
        cat_SIPBI_dec = 
            factor(
                case_when(
                    SIPBI_dec <= 2 ~ "< 2",
                    SIPBI_dec > 2 & SIPBI_dec <= 4 ~ "3 to 4",
                    SIPBI_dec > 4 & SIPBI_dec <= 6 ~ "5 to 6",
                    SIPBI_dec > 6 & SIPBI_dec <= 8 ~ "7 to 8",
                    SIPBI_dec > 8 ~ "9 to 10"), 
                levels = (
                    c("< 2",
                    "3 to 4",
                    "5 to 6",
                    "7 to 8",
                    "9 to 10")
                    )),
        cat_RVI_dec = 
            factor(
                case_when(
                    RVI_dec <= 2 ~ "< 2",
                    RVI_dec > 2 & RVI_dec <= 4 ~ "3 to 4",
                    RVI_dec > 4 & RVI_dec <= 6 ~ "5 to 6",
                    RVI_dec > 6 & RVI_dec <= 8 ~ "7 to 8",
                    RVI_dec > 8 ~ "9 to 10"), 
                levels = (
                    c("< 2",
                    "3 to 4",
                    "5 to 6",
                    "7 to 8",
                    "9 to 10")
                    )),
        cat_Nr_Aug = 
            factor(
                case_when(
                    Nr_Aug <= 10 ~ "0 to 10%",
                    Nr_Aug > 10 & Nr_Aug <= 20 ~ "10% to 20%",
                    Nr_Aug > 20 & Nr_Aug <= 30 ~ "20% to 30%",
                    Nr_Aug > 30 & Nr_Aug <= 40 ~ "30% to 40%",
                    Nr_Aug > 40 ~ "40% +"), 
                levels = (
                    c("0 to 10%",
                    "10% to 20%",
                    "20% to 30%",
                    "30% to 40%",
                    "40% +")
                    )),
     # create typology for maps
        Typology = 
            factor( # turn to factor for mapping 
                case_when(
                    typ_cat == "['AdvG', 'BE']" ~ 'Advanced Gentrification',
                    typ_cat == "['AdvG']" ~ 'Advanced Gentrification',
                    typ_cat == "['ARE']" ~ 'At Risk of Becoming Exclusive',
                    typ_cat == "['ARG']" ~ 'At Risk of Gentrification',
                    typ_cat == "['BE']" ~ 'Becoming Exclusive', 
                    typ_cat == "['EOG']" ~ 'Early/Ongoing Gentrification',
                    typ_cat == "['OD']" ~ 'Ongoing Displacement',
                    typ_cat == "['SAE']" ~ 'Stable/Advanced Exclusive', 
                    typ_cat == "['SLI']" ~ 'Low-Income/Susceptible to Displacement',
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
                        "Unavailable or Unreliable Data"
                    )
            ), 
        real_mhval_18 = case_when(real_mhval_18 > 0 ~ real_mhval_18),
        real_mrent_18 = case_when(real_mrent_18 > 0 ~ real_mrent_18)
    ) %>% 
    group_by(city) %>% 
    mutate(
        rm_real_mhval_18 = median(real_mhval_18, na.rm = TRUE), 
        rm_real_mrent_18 = median(real_mrent_18, na.rm = TRUE), 
        rm_per_nonwhite_18 = median(per_nonwhite_18, na.rm = TRUE), 
        rm_per_col_18 = median(per_col_18, na.rm = TRUE)
    ) %>% 
    group_by(GEOID) %>% 
    mutate(
        per_ch_li = (all_li_count_18-all_li_count_00)/all_li_count_00,
        popup = # What to include in the popup 
          str_c(
              '<b>Tract: ', GEOID, '<br>', 
              Typology, '</b>',
            # Market
              '<br><br>',
              '<b><i><u>Market Dynamics</u></i></b><br>',
              'Tract median home value: ', case_when(!is.na(real_mhval_18) ~ dollar(real_mhval_18), TRUE ~ 'No data'), '<br>',
              'Tract home value change from 2000 to 2018: ', case_when(is.na(real_mhval_18) ~ 'No data', TRUE ~ percent(pctch_real_mhval_00_18, accuracy = .1)),'<br>',
              'Regional median home value: ', dollar(rm_real_mhval_18), '<br>',
              '<br>',
              'Tract median rent: ', case_when(!is.na(real_mrent_18) ~ dollar(real_mrent_18), TRUE ~ 'No data'), '<br>', 
              'Regional median rent: ', case_when(is.na(real_mrent_18) ~ 'No data', TRUE ~ dollar(rm_real_mrent_18)), '<br>', 
              'Tract rent change from 2012 to 2018: ', percent(pctch_real_mrent_12_18, accuracy = .1), '<br>',
              '<br>',
              'Rent gap (nearby - local): ', dollar(tr_rent_gap), '<br>',
              'Regional median rent gap: ', dollar(rm_rent_gap), '<br>',
              '<br>',
            # demographics
             '<b><i><u>Demographics</u></i></b><br>', 
             'Tract population: ', comma(pop_18), '<br>', 
             'Tract household count: ', comma(hh_18), '<br>', 
             'Percent renter occupied: ', percent(tr_prenters, accuracy = .1), '<br>',
             'Percent vacant homes: ', percent(tr_pvacant, accuracy = .1), '<br>',
             'Tract median income: ', dollar(real_hinc_18), '<br>', 
             'Percent low income hh: ', percent(per_all_li_18, accuracy = .1), '<br>', 
             'Percent change in LI: ', percent(per_ch_li, accuracy = .1), '<br>',
             '<br>',
             'Percent POC: ', percent(per_nonwhite_18, accuracy = .1), '<br>',
             'Regional median POC: ', percent(rm_per_nonwhite_18, accuracy = .1), '<br>',
             'Tract racial typology: ', NeighType, '<br>', 
             'White: ', percent(pWhite, accuracy = .1), '<br>', 
             'Black: ', percent(pBlack, accuracy = .1), '<br>', 
             'Asian: ', percent(pAsian, accuracy = .1), '<br>', 
             'Latinx: ', percent(pLatinx, accuracy = .1), '<br>', 
             'Other: ', percent(pOther, accuracy = .1), '<br>',
             '<br>',
             'Percent students: ', percent(tr_pstudents, accuracy = .1), '<br>',
             'Percent college educated: ', percent(per_col_18, accuracy = .1), '<br>',
             'Regional median educated: ', percent(rm_per_col_18, accuracy = .1), '<br>',
            '<br>',
            # risk factors
             '<b><i><u>Risk Factors</u></i></b><br>', 
             'Mostly low income: ', case_when(low_pdmt_medhhinc_18 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Mix low income: ', case_when(mix_low_medhhinc_18 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Rent change: ', case_when(dp_PChRent == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Rent gap: ', case_when(dp_RentGap == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Hot Market: ', case_when(hotmarket_18 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
             'Vulnerable to gentrification: ', case_when(vul_gent_18 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 1990 to 2000: ', case_when(gent_90_00 == 1 | gent_90_00_urban == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
             'Gentrified from 2000 to 2018: ', case_when(gent_00_18 == 1 | gent_00_18_urban == 1 ~ 'Yes', TRUE ~ 'No')
          )) %>% 
    # mutate(
    #     popup_ucla = 
    #         str_c(
    #             '<b>Tract: ', GEOID, '<br>', 
    #             'Workers at Risk of Job Displacement', '<br>', 
    #             'Due to COVID-19 Business Closures: </b>', '<br>', 
    #             case_when(!is.na(pct_atrisk_workers) ~ percent(pct_atrisk_workers*.01, , accuracy = .1), 
    #                 TRUE ~ "No Data"), '<br>', '<br>', 
    #             '<b>Workers not Covered by Unemployment', '<br>', 
    #             'Insurance Program: </b>', '<br>', 
    #             case_when(!is.na(pct_wo_UI) ~ percent(pct_wo_UI*.01, , accuracy = .1), 
    #                 TRUE ~ "No Data"), '<br>', '<br>', 
    #             '<b>Shelter-in-Place Burden Index: </b>', '<br>', 
    #             case_when(!is.na(SIPBI_dec) ~ SIPBI_dec, 
    #                 TRUE ~ "No Data"), '<br>', '<br>', 
    #             '<b>Renter Vulnerability Index: </b>', '<br>', 
    #             case_when(!is.na(RVI_dec) ~ RVI_dec, 
    #                 TRUE ~ "No Data"), '<br>', '<br>', 
    #             '<b>2020 Census Non-Response Rate: </b>', '<br>',
    #             case_when(!is.na(Nr_Aug) ~ percent(Nr_Aug*.01, , accuracy = .1), 
    #                 TRUE ~ "No Data"))
    #         ) %>% 
    ungroup() %>% 
    data.frame()

# State codes for downloading tract polygons; add your state here
states <- c("06", "17", "13", "08", "28", "47", "53")

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
tracts <- readRDS('~/git/displacement-typologies/data/outputs/downloads/state_tracts.RDS')

# Join the tracts to the dataframe

df_sf <- 
    right_join(tracts, df) %>%
    ms_simplify(keep = 0.5)

# ==========================================================================
# Select tracts within counties that intersect with urban areas
# ==========================================================================

### read in urban areas
# urban_areas <-
#   readRDS("~/git/displacement-typologies/data/inputs/shp/urban_areas/tl_2019_us_uac10.rds")

# ### Select urban areas that intersect with df_sf
# urban_areas <-
#   urban_areas[df_sf, ]

# ### download counties
#   ###
#   # Begin Download
#   ###
#   # counties <-
#   #   counties(state = states) %>%
#   #   st_transform(st_crs(df_sf))
#   #
#   # st_write(counties, "~/git/displacement-typologies/data/outputs/downloads/select_counties.gpkg", append = FALSE)
#   ###
#   # End download
#   ###
# counties <- st_read("~/git/displacement-typologies/data/outputs/downloads/select_counties.gpkg")

# ### Select counties overlapping urban areas
# county <-
#   counties[urban_areas,]

# # Join the tracts to the dataframe

# df_sf <-
#   df_sf[county,]

#
# Explore problem areas
# --------------------------------------------------------------------------


# ct <- 
#     fread('~/git/displacement-typologies/data/inputs/sparcc_community_tracts.csv') %>% 
#     rename(city = City) %>% 
#     mutate(GEOID = as.numeric(GEOID), 
#       cs = "Community Suggested Change") %>% 
#     left_join(df_sf, .) %>% 
#     st_set_geometry(value = "geometry") %>% 
#     group_by(GEOID) %>% 
#     mutate(
#         popup_cs = # What to include in the popup 
#           str_c(
#               '<b>Tract: ', GEOID, '<br>
#               UDP Typology: ', Typology, '</b>',
#             # Market
#               '<br><br>',
#               '<b>Community Suggested Change<br>
#               Site Notes</b>: <br>', CommunityComments,
#               '<br><br>',
#               '<b><i><u>Market Dynamics</u></i></b><br>',
#               'Tract median home value: ', case_when(!is.na(real_mhval_17) ~ dollar(real_mhval_17), TRUE ~ 'No data'), '<br>',
#               'Tract home value change from 2000 to 2017: ', case_when(is.na(real_mhval_17) ~ 'No data', TRUE ~ percent(pctch_real_mhval_00_17)),'<br>',
#               'Regional median home value: ', dollar(rm_real_mhval_17), '<br>',
#               '<br>',
#               'Tract median rent: ', case_when(!is.na(real_mrent_17) ~ dollar(real_mrent_17), TRUE ~ 'No data'), '<br>', 
#               'Regional median rent: ', case_when(is.na(real_mrent_17) ~ 'No data', TRUE ~ dollar(rm_real_mrent_17)), '<br>', 
#               'Tract rent change from 2012 to 2017: ', percent(pctch_real_mrent_12_17), '<br>',
#               '<br>',
#               'Rent gap (nearby - local): ', dollar(tr_rent_gap), '<br>',
#               'Regional median rent gap: ', dollar(rm_rent_gap), '<br>',
#               '<br>',
#             # demographics
#             '<b><i><u>Demographics</u></i></b><br>', 
#             'Tract population: ', comma(pop_17), '<br>', 
#             'Tract household count: ', comma(hh_17), '<br>', 
#             'Percent renter occupied: ', percent(tr_prenters, accuracy = .1), '<br>',
#             'Percent vacant homes: ', percent(tr_pvacant, accuracy = .1), '<br>',
#             'Tract median income: ', dollar(real_hinc_17), '<br>', 
#             'Percent low income hh: ', percent(per_all_li_17, accuracy = .1), '<br>', 
#             'Percent change in LI: ', percent(per_ch_li, accuracy = .1), '<br>',
#             '<br>',
#             'Percent POC: ', percent(per_nonwhite_17, accuracy = .1), '<br>',
#             'Regional median POC: ', percent(rm_per_nonwhite_17, accuracy = .1), '<br>',
#             'Tract racial typology: ', NeighType, '<br>', 
#             'White: ', percent(pWhite, accuracy = .1), '<br>', 
#             'Black: ', percent(pBlack, accuracy = .1), '<br>', 
#             'Asian: ', percent(pAsian, accuracy = .1), '<br>', 
#             'Latinx: ', percent(pLatinx, accuracy = .1), '<br>', 
#             'Other: ', percent(pOther, accuracy = .1), '<br>',
#             '<br>',
#             'Percent students: ', percent(tr_pstudents, accuracy = .1), '<br>',
#             'Percent college educated: ', percent(per_col_17, accuracy = .1), '<br>',
#             'Regional median educated: ', percent(rm_per_col_17, accuracy = .1), '<br>',
#             '<br>',
#             # risk factors
#             '<b><i><u>Risk Factors</u></i></b><br>', 
#             'Mostly low income: ', case_when(low_pdmt_medhhinc_17 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
#             'Mix low income: ', case_when(mix_low_medhhinc_17 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
#             'Rent change: ', case_when(dp_PChRent == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
#             'Rent gap: ', case_when(dp_RentGap == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
#             'Hot Market: ', case_when(hotmarket_17 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>',
#             'Vulnerable to gentrification: ', case_when(vul_gent_17 == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
#             'Gentrified from 1990 to 2000: ', case_when(gent_90_00 == 1 | gent_90_00_urban == 1 ~ 'Yes', TRUE ~ 'No'), '<br>', 
#             'Gentrified from 2000 to 2017: ', case_when(gent_00_17 == 1 | gent_00_17_urban == 1 ~ 'Yes', TRUE ~ 'No')
#           )
#     )    
    

# ==========================================================================
# overlays
# ==========================================================================

### Redlining

    ###add your city here
red <- 
    rbind(
        geojson_sf('~/git/displacement-typologies/data/overlays/CODenver1938_1.geojson') %>% 
        mutate(city = 'Denver'),
        geojson_sf('~/git/displacement-typologies/data/overlays/GAAtlanta1938_1.geojson') %>% 
        mutate(city = 'Atlanta'),
        geojson_sf('~/git/displacement-typologies/data/overlays/ILChicago1940_1.geojson') %>% 
        mutate(city = 'Chicago'),
        geojson_sf('~/git/displacement-typologies/data/overlays/TNMemphis19XX_1.geojson') %>% 
        mutate(city = 'Memphis'),
        geojson_sf('~/git/displacement-typologies/data/overlays/CALosAngeles1939.geojson') %>% 
        mutate(city = 'LosAngeles'),
        geojson_sf('~/git/displacement-typologies/data/overlays/WASeattle1936.geojson') %>% 
        mutate(city = 'Seattle'),
        geojson_sf('~/git/displacement-typologies/data/overlays/WATacoma1937.geojson') %>% 
        mutate(city = 'Seattle')
    ) %>% 
    mutate(
        Grade = 
            factor(
                case_when(
                    holc_grade == 'A' ~ 'A "Best"',
                    holc_grade == 'B' ~ 'B "Still Desirable"',
                    holc_grade == 'C' ~ 'C "Definitely Declining"',
                    holc_grade == 'D' ~ 'D "Hazardous"'
                ), 
                levels = c(
                    'A "Best"',
                    'B "Still Desirable"',
                    'C "Definitely Declining"',
                    'D "Hazardous"')
            ), 
        popup = # What to include in the popup 
          str_c(
              'Redline Grade: ', Grade
          )
    ) 

### Industrial points

industrial <- st_read('~/git/displacement-typologies/data/overlays/industrial.shp') %>% 
    mutate(site = 
        case_when(
            site_type == 0 ~ "Superfund", 
            site_type == 1 ~ "TRI", 
        )) %>% 
    filter(state != "CO") %>% 
    st_as_sf() 

### HUD

hud <- st_read('~/git/displacement-typologies/data/overlays/HUDhousing.shp') %>% 
    st_as_sf() 

### Rail data
rail <- 
    st_join(
        fread('~/git/displacement-typologies/data/inputs/tod_database_download.csv') %>% 
            st_as_sf(
                coords = c('Longitude', 'Latitude'), 
                crs = 4269
            ) %>% 
            st_transform(4326), 
        df_sf %>% select(city), 
        join = st_intersects
    ) %>% 
    filter(!is.na(city))

### Hospitals
hospitals <- 
    st_join(
        fread('~/git/displacement-typologies/data/inputs/Hospitals.csv') %>% 
            st_as_sf(
                coords = c('X', 'Y'), 
                crs = 4269
            ) %>% 
            st_transform(4326), 
        df_sf %>% select(city), 
        join = st_intersects
    ) %>% 
    mutate(
        popup = str_c(NAME, "<br>", NAICS_DESC), 
        legend = "Hospitals"
    ) %>% 
    filter(!is.na(city), grepl("GENERAL", NAICS_DESC))
    # Describe NAME, TYPE, and NAICS_DESC in popup

### Universities
university <- 
    st_join(
        fread('~/git/displacement-typologies/data/inputs/university_HD2016.csv') %>% 
            st_as_sf(
                coords = c('LONGITUD', 'LATITUDE'), 
                crs = 4269
            ) %>% 
            st_transform(4326), 
        df_sf %>% select(city), 
        join = st_intersects
    ) %>% 
    filter(ICLEVEL == 1, SECTOR < 3) %>% # filters to significant universities and colleges
    mutate(
        legend = case_when(
            SECTOR == 1 ~ 'Major University', 
            SECTOR == 2 ~ 'Medium University or College')
    ) %>% 
    filter(!is.na(city))

### Road map; add your state here
states <- 
    c('GA', 'CO', 'TN', 'MS', 'AR', 'IL', 'WA', 'OH', 'CA')

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
#     st_transform(st_crs(df_sf)) %>%
#     st_join(., df_sf %>% select(city), join = st_intersects) %>% 
#     mutate(rt = case_when(RTTYP == 'I' ~ 'Interstate', RTTYP == 'U' ~ 'US Highway')) %>% 
#     filter(!is.na(city))
# st_write(road_map, '~/git/displacement-typologies/data/outputs/downloads/roads.gpkg', append = FALSE)
###
# End
###
road_map <- st_read('~/git/displacement-typologies/data/outputs/downloads/roads.gpkg')

### Atlanta Beltline
beltline <- 
  st_read("~/git/displacement-typologies/data/overlays/beltline.shp") %>% 
  mutate(name = "Beltline", 
    name2 = "Possible Gentrifier")

### Opportunity Zones
opp_zone <- 
  st_read("~/git/displacement-typologies/data/overlays/OpportunityZones/OpportunityZones.gpkg") %>%
  st_transform(st_crs(df_sf)) %>% 
  st_join(., df_sf %>% select(city), join = st_intersects) %>% 
  filter(!is.na(city))

# ==========================================================================
# Maps
# ==========================================================================

#
# Color palettes 
# --------------------------------------------------------------------------

redline_pal <- 
    colorFactor(
        c("#4ac938", "#2b83ba", "#ff8c1c", "#ff1c1c"), 
        domain = red$Grade, 
        na.color = "transparent"
    )

nt_pal <-
    colorFactor(c(
        '#33a02c', # 'Mostly Asian', green
        '#1f78b4', # 'Mostly Black', blue
        '#e31a1c', # 'Mostly Latinx', red
        '#9b66b0', # 'Mostly Other', purple
        '#C95123', # 'Mostly White',
        '#1fc2ba', # 'Asian-Black',
        '#d6ae5c', # 'Asian-Latinx',
        '#91c7b9', # 'Asian-Other',
        '#b2df8a', # 'Asian-White',
        '#de4e4b', # 'Black-Latinx',
        '#71a1f5', # 'Black-Other',
        '#a6cee3', # 'Black-White',
        '#f0739b', # 'Latinx-Other',
        '#fb9a99', # 'Latinx-White',
        '#c28a86', # 'Other-White',
        '#fdbf6f', # '3 Group Mixed',
        '#cab2d6', # '4 Group Mixed',
        '#1d5fd1', # 'Diverse',
        '#FFFFFF'),  # 'Unpopulated Tract'
      domain = df$nt_conc,
      na.color = '#C0C0C0'
        )

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
            # "#A9A9A9", # intended for greater student pop
            "#C0C0C0"), 
        domain = df$Typology, 
        na.color = '#C0C0C0'
    )

industrial_pal <- 
    colorFactor(c("#a65628", "#999999"), domain = c("Superfund", "TRI"))

rail_pal <- 
    colorFactor(
        c(
            '#377eb8',
            '#4daf4a',
            '#984ea3'
        ), 
        domain = c("Proposed Transit", "Planned Transit", "Existing Transit"))

road_pal <- 
    colorFactor(
        c(
            '#333333',
            '#666666'
        ), 
        domain = c("Interstate", "US Highway"))

ucla_pal1 <- 
    colorFactor(
        c("#ffffb2",
        "#fecc5c",
        "#fd8d3c",
        "#f03b20",
        "#bd0026"
            ), 
        domain = c("0 to 10%",
                    "10% to 20%",
                    "20% to 30%",
                    "30% to 40%",
                    "40% +"),  
        na.color = '#C0C0C0')

ucla_pal2 <- 
    colorFactor(
        c("#ffffb2",
        "#fecc5c",
        "#fd8d3c",
        "#f03b20",
        "#bd0026"
            ), 
        domain = c("< 2",
                    "3 to 4",
                    "5 to 6",
                    "7 to 8",
                    "9 to 10"),  
        na.color = '#C0C0C0')

# make map

map_it <- function(city_name, st){
  leaflet(data = df_sf %>% filter(city == city_name)) %>% 
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
        data = df_sf %>% filter(city == city_name), 
        group = "Displacement Typology", 
        label = ~Typology,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5, 
        color = ~displacement_typologies_pal(Typology), 
        stroke = TRUE, 
        weight = .7, 
        opacity = .60, 
        popup = ~popup, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)
    ) %>%   
    addLegend(
        pal = displacement_typologies_pal, 
        values = ~Typology, 
        group = "Displacement Typology", 
        title = "Displacement Typology"
    ) %>% 
# Redlined areas
    addPolygons(
        data = red %>% filter(city == city_name), 
        group = "Redlined Areas", 
        label = ~Grade,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .3, 
        color = ~redline_pal(Grade), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .8, 
        highlightOptions = highlightOptions(
                            color = "#ff4a4a", 
                            weight = 5,
                            bringToFront = TRUE
                            ), 
        popup = ~popup
    ) %>%   
    addLegend(
        data = red, 
        pal = redline_pal, 
        values = ~Grade, 
        group = "Redlined Areas",
        title = "Redline Zones"
    ) %>%  
# Neighborhood Segregation
    addPolygons(
        data = df_sf %>% filter(city == city_name),
        group = "Neighborhood Segregation",
        label = ~nt_conc,
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .5,
        color = ~nt_pal(nt_conc),
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
    addLegend(,
        # position = 'bottomright',s
        pal = nt_pal,
        values = ~nt_conc,
        group = "Neighborhood Segregation",
        title = "Neighborhood<br>Segregation"
    ) %>%

# Roads
    addPolylines(
        data = road_map %>% filter(city == city_name), 
        group = "Highways", 
        # label = ~rt,
        # labelOptions = labelOptions(textsize = "12px"),
        # fillOpacity = .3, 
        color = ~road_pal(rt), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .1    
    ) %>%
    # addLegend(
    #     data = road_map, 
    #     pal = road_pal, 
    #     values = ~rt, 
    #     group = "Highways",
    #     title = "Highways"
    # ) %>%     
# Public Housing
    addCircleMarkers(
        data = hud %>% filter(state == st), #add your state here
        radius = 5, 
        lng = ~longitude, 
        lat = ~latitude, 
        color = ~"#ff7f00",
        # clusterOptions = markerClusterOptions(), 
        group = 'Public Housing', 
        # popup = ~site,
        fillOpacity = .5, 
        stroke = FALSE
    ) %>%     
# Rail
    addCircleMarkers(
        data = rail %>% filter(city == city_name), 
        label = ~Buffer, 
        radius = 5, 
        color = ~rail_pal(Buffer),
        group = 'Transit Stations', 
        popup = ~Buffer,
        fillOpacity = .8, 
        stroke = TRUE, 
        weight = .6
    ) %>%     
    addLegend(
        data = rail, 
        pal = rail_pal, 
        values = ~Buffer, 
        group = "Transit Stations", 
        title = "Transit Stations"
    ) %>%  
# University
    addCircleMarkers(
        data = university %>% filter(city == city_name), 
        label = ~INSTNM, 
        radius = 5, 
        color = ~'#39992b',
        group = 'Universities & Colleges', 
        popup = ~INSTNM,
        fillOpacity = .8, 
        stroke = TRUE, 
        weight = .6
    ) %>%     
# Hospitals
    addCircleMarkers(
        data = hospitals %>% filter(city == city_name), 
        label = ~NAME, 
        radius = 5, 
        color = ~"#e41a1c",
        group = 'Hospitals', 
        popup = ~popup,
        fillOpacity = .8, 
        stroke = TRUE, 
        weight = .6
    )}

 # Industrial
 ind <- function(st, map = .){
  map %>% 
    # leaflet(industrial %>% filter(state %in% st))
     addCircleMarkers(
         data = industrial %>% filter(state %in% st), 
         label = ~site, 
         radius = 5, 
         # lng = ~longitude, 
         # lat = ~latitude, 
         color = ~industrial_pal(site),
         # clusterOptions = markerClusterOptions(), 
         group = 'Industrial Sites', 
         popup = ~site,
         fillOpacity = .8, 
         stroke = TRUE, 
         weight = .6
     ) %>%     
     addLegend(
         data = industrial, 
         pal = industrial_pal, 
         values = ~site, 
         group = "Industrial Sites", 
         title = "Industrial Sites"
     )}  

# Beltline
 belt <- function(map = .){
  map %>% 
    addPolylines(
            data = beltline, 
            group = "Beltline", 
            color = "#2ca25f",
            stroke = TRUE, 
            weight = 5, 
            # opacity = .1    
        )}  

# Community Input
  # ci <- function(map = ., city_name){
  #   map %>% 
  #   addPolygons(
  #       data = df_sf %>% filter(city == city_name, !is.na(cs)), 
  #       group = "Community Input", 
  #       label = ~cs,
  #       labelOptions = labelOptions(textsize = "12px"),
  #       fillOpacity = .1, 
  #       color = "#ff4a4a", 
  #       stroke = TRUE, 
  #       weight = 1, 
  #       opacity = .9, 
  #       highlightOptions = highlightOptions(
  #                         color = "#ff4a4a", 
  #                         weight = 5,
  #                             bringToFront = TRUE
  #                             ), 
  #       popup = ~popup_cs, 
  #       popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)
  #   )
  #   } 
     # addLegend(
         # pal = "#ff4a4a", 
         # values = ~cs, 
         # group = "Community Input"
     # ) %>% 

# Opportunity Zones
oz <- function(map = ., city_name){
  map %>% 
    addPolygons(
        data = opp_zone %>% filter(city == city_name, !is.na(opp_zone)), 
        group = "Opportunity Zones", 
        label = "Opportunity Zone",
        labelOptions = labelOptions(textsize = "12px"),
        fillOpacity = .1, 
        color = "#c51b8a", 
        stroke = TRUE, 
        weight = 1, 
        opacity = .9, 
        highlightOptions = highlightOptions(
                          color = "#c51b8a", 
                          weight = 5,
                              bringToFront = FALSE
                              ), 
        # popup = ~opp_zone, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)
    ) 
  }
    # addLegend(
    #     pal = "#c51b8a", 
    #     values = ~opp_zone, 
    #     group = "Opportunity Zones"
    # ) %>% 

# UCLA indicators

ucla <- function(map = ., city_name){        
    map %>% 
    addPolygons(
        data = df_sf %>% filter(city == city_name), 
        group = "Job Displacement Risk", 
        label = ~str_c("Job Displacement Risk: ", percent(pct_atrisk_workers*.01, accuracy = .1)), 
        labelOptions = labelOptions(textsize = "12px"), 
        fillOpacity = .5, 
        color = ~ucla_pal1(cat_pct_atrisk_workers), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .5, 
        highlightOptions = highlightOptions(
            color = "#c51b8a", 
            weight = 5, 
            bringToFront = FALSE), 
        # popup = ~popup_ucla, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)) %>% 
    addLegend(
        data = df_sf %>% filter(city == city_name), 
        pal = ucla_pal1, 
        values = ~cat_pct_atrisk_workers, 
        group = "Job Displacement Risk", 
        title = "Job Displacement Risk") %>% 
    addPolygons(
        data = df_sf %>% filter(city == city_name), 
        group = "Without Unemployment Insurance", 
        label = ~str_c("Without Unemployment Insurance: ", percent(pct_wo_UI*.01, accuracy = .1)), 
        labelOptions = labelOptions(textsize = "12px"), 
        fillOpacity = .5, 
        color = ~ucla_pal1(cat_pct_wo_UI), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .5, 
        highlightOptions = highlightOptions(
            color = "#c51b8a", 
            weight = 5, 
            bringToFront = FALSE), 
        # popup = ~popup_ucla, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)) %>% 
    addLegend(
        data = df_sf %>% filter(city == city_name), 
        pal = ucla_pal1, 
        values = ~cat_pct_wo_UI, 
        group = "Without Unemployment Insurance", 
        title = "Without Unemployment Insurance") %>% 
    addPolygons(
        data = df_sf %>% filter(city == city_name), 
        group = "Shelter-in-Place Burden", 
        label = ~str_c("Shelter-in-Place Burden: ", SIPBI_dec), 
        labelOptions = labelOptions(textsize = "12px"), 
        fillOpacity = .5, 
        color = ~ucla_pal2(cat_SIPBI_dec), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .5, 
        highlightOptions = highlightOptions(
            color = "#c51b8a", 
            weight = 5, 
            bringToFront = FALSE), 
        # popup = ~popup_ucla, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)) %>% 
    addLegend(
        data = df_sf %>% filter(city == city_name), 
        pal = ucla_pal2, 
        values = ~cat_SIPBI_dec, 
        group = "Shelter-in-Place Burden", 
        title = "Shelter-in-Place Burden") %>% 
    addPolygons(
        data = df_sf %>% filter(city == city_name), 
        group = "Renter Vulnerability Index", 
        label = ~str_c("Renter Vulnerability Index: ", RVI_dec), 
        labelOptions = labelOptions(textsize = "12px"), 
        fillOpacity = .5, 
        color = ~ucla_pal2(cat_RVI_dec), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .5, 
        highlightOptions = highlightOptions(
            color = "#c51b8a", 
            weight = 5, 
            bringToFront = FALSE), 
        # popup = ~popup_ucla, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)) %>% 
    addLegend(
        data = df_sf %>% filter(city == city_name), 
        pal = ucla_pal2, 
        values = ~cat_RVI_dec, 
        group = "Renter Vulnerability Index", 
        title = "Renter Vulnerability Index") %>% 
    addPolygons(
        data = df_sf %>% filter(city == city_name), 
        group = "Census Non-Response Rate", 
        label = ~str_c("Census Non-Response Rate: ", percent(Nr_Aug*.01, accuracy = .1)), 
        labelOptions = labelOptions(textsize = "12px"), 
        fillOpacity = .5, 
        color = ~ucla_pal1(cat_Nr_Aug), 
        stroke = TRUE, 
        weight = 1, 
        opacity = .5, 
        highlightOptions = highlightOptions(
            color = "#c51b8a", 
            weight = 5, 
            bringToFront = FALSE), 
        # popup = ~popup_ucla, 
        popupOptions = popupOptions(maxHeight = 215, closeOnClick = TRUE)) %>% 
    addLegend(
        data = df_sf %>% filter(city == city_name), 
        pal = ucla_pal1, 
        values = ~cat_Nr_Aug, 
        group = "Census Non-Response Rate", 
        title = "Census Non-Response Rate") #%>% 
    # addLayersControl(
    #     position = 'topright',
    #     overlayGroups = c(
    #         "Job Displacement Risk",
    #         "Without Unemployment Insurance",
    #         "Shelter-in-Place Burden",
    #         "Renter Vulnerability Index", 
    #         "Census Non-Response Rate"),
    #     options = layersControlOptions(collapsed = FALSE)) %>% 
    #     hideGroup(
    #         c("Job Displacement Risk",
    #         "Without Unemployment Insurance",
    #         "Shelter-in-Place Burden",
    #         "Renter Vulnerability Index", 
    #         "Census Non-Response Rate"))    
    }

# Options
options <- function(
    map = ., 
    belt = NULL, 
    ci = NULL, 
    oz = NULL, 
    ph = NULL, 
    ucla1 = NULL, 
    ucla2 = NULL, 
    ucla3 = NULL, 
    ucla4 = NULL, 
    ucla5 = NULL, 
    is = NULL){
  map %>% 
    addLayersControl(
         overlayGroups = 
             c("Displacement Typology", 
                "Redlined Areas", 
                "Neighborhood Segregation",
                 ci, #
                oz,#
                 "Hospitals", 
                 "Universities & Colleges", 
                 ph, #?
                 "Transit Stations", 
                 is, #
                 belt, 
                 ucla1,
                 ucla2,
                 ucla3, 
                 ucla4, 
                 ucla5, 
                 "Highways"),
         options = layersControlOptions(collapsed = FALSE, scroll = FALSE)) %>% 
     hideGroup(
         c(ci, 
          oz,
          "Redlined Areas", 
          "Neighborhood Segregation",
             "Hospitals", 
             "Universities & Colleges", 
             ph, 
             "Transit Stations", 
             belt,
             is, 
             ucla1,
             ucla2,
             ucla3, 
             ucla4, 
             ucla5))
 }

#
# City specific displacement-typologies map
# --------------------------------------------------------------------------

# Atlanta, GA
atlanta <- 
    map_it("Atlanta", 'GA') %>% 
    ind(st = "GA") %>% 
    # ci(city_name = "Atlanta") %>% 
    oz(city_name = "Atlanta") %>% 
    belt() %>% 
    options(
        belt = "Beltline",
        oz = "Opportunity Zones", 
        ph = "Public Housing", 
        is = "Industrial Sites") %>% 
    setView(lng = -84.3, lat = 33.749, zoom = 10)

# save map
htmlwidgets::saveWidget(atlanta, file="~/git/displacement-typologies/maps/atlanta_udp.html")

# Chicago, IL
chicago <- 
    map_it("Chicago", 'IL') %>% 
    ind(st = "IL") %>% 
    # ci(city_name = "Chicago") %>% 
    oz(city_name = "Chicago") %>% 
    options(
        oz = "Opportunity Zones", 
        ph = "Public Housing", 
        is = "Industrial Sites") %>% 
    setView(lng = -87.7, lat = 41.9, zoom = 10)
# save map
htmlwidgets::saveWidget(chicago, file="~/git/displacement-typologies/maps/chicago_udp.html")

# Denver, CO
denver <- 
    map_it("Denver", 'CO') %>% 
    # ci(city_name = "Denver") %>% 
    oz(city_name = "Denver") %>%     
    options(
        oz = "Opportunity Zones", 
        ph = "Public Housing") %>% 
    setView(lng = -104.9, lat = 39.7, zoom = 10)
# # save map
htmlwidgets::saveWidget(denver, file="~/git/displacement-typologies/maps/denver_udp.html")

# San Francisco, CA
la <- 
    map_it("LosAngeles", 'CA') %>% 
    # ind(st = "CA") %>% 
    # ci(city_name = "LosAngeles") %>% 
    oz(city_name = "LosAngeles") %>% 
    ucla(city_name = "LosAngeles") %>% 
    options(
        oz = "Opportunity Zones", 
        ph = "Public Housing",
        ucla1 = "Job Displacement Risk",
        ucla2 = "Without Unemployment Insurance",
        ucla3 = "Shelter-in-Place Burden",
        ucla4 = "Renter Vulnerability Index", 
        ucla5 = "Census Non-Response Rate"
        # is = "Industrial Sites"
        ) %>% 
    setView(lng = -118.2, lat = 34, zoom = 10)
# save map
htmlwidgets::saveWidget(la, file="~/git/displacement-typologies/maps/losangeles_udp.html")

# San Francisco, CA
sf <- 
    map_it("SanFrancisco", 'CA') %>% 
    # ind(st = "CA") %>% 
    # ci(city_name = "SanFrancisco") %>% 
    oz(city_name = "SanFrancisco") %>% 
    options(
        oz = "Opportunity Zones", 
        ph = "Public Housing" 
        # is = "Industrial Sites"
        ) %>% 
    setView(lng = -118.2, lat = 34, zoom = 10)
# save map
htmlwidgets::saveWidget(la, file="~/git/displacement-typologies/maps/sanfrancisco_udp.html")

# Memphis, TN
# memphis <- 
#     map_it("Memphis", 'TN') %>% 
#     ind(st = "TN") %>% 
#     # ci(city_name = "Memphis") %>% 
#     oz(city_name = "Memphis") %>%     
#     options(
#         ci = "Community Input", 
#         oz = "Opportunity Zones", 
#         ph = "Public Housing", 
#         is = "Industrial Sites") %>% 
#     setView(lng = -89.9, lat = 35.2, zoom = 10)
# # # save map
# htmlwidgets::saveWidget(memphis, file="~/git/displacement-typologies/maps/memphis_udp.html")