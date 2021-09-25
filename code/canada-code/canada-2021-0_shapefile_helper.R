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
pacman::p_load(readxl, R.utils, sf, sp, geojsonsf, scales, data.table, tidyverse)

tracts <- st_read("E:\\canada_data/canada_shapefiles/lct_000b16a_e.shp")

tracts <- st_transform(tracts, st_crs("+proj=longlat +datum=WGS84"))

city_tracts <- tracts %>% dplyr::filter(CMANAME == "Toronto")


st_write(city_tracts, "toronto.shp")
write_csv(vancouver_sf %>% st_set_geometry(NULL), "E:\\forked_canada_udp//data/outputs/vancouver_final_output_not_urban.csv")

