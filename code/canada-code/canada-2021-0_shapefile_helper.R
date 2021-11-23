# ==========================================================================
# Helper file to download the desired city from national Canadian shapefile
# Author: Hannah Moore - hmoore@berkeley.edu
# Created: 2021.08.05
# 1.0 code: 2021.11.01
# download the national canadian shapefile from here:
# https://www12.statcan.gc.ca/census-recensement/2011/geo/bound-limit/bound-limit-2016-eng.cfm
# pick cartographic boundary file for census tracts

# ==========================================================================

rm(list = ls())
city_name = commandArgs(trailingOnly = TRUE)
# ==========================================================================
# Load Libraries
# ==========================================================================
pacman::p_load(R.utils, sf, sp, tidyverse)

canada_tracts <- st_read("E:\\canada_data/canada_shapefiles/lct_000b16a_e.shp")

canada_tracts <- st_transform(canada_tracts, st_crs("+proj=longlat +datum=WGS84"))
saveRDS(canada_tracts, "E:\\forked_canada_udp/data/inputs/shp/Canada/canada.rds")
# canada_tracts <- readRDS("E:\\forked_canada_udp/data/inputs/shp/Canada/canada.rds")
city_tracts <- canada_tracts %>% dplyr::filter(CMANAME == city_name)

saveRDS(city_tracts, paste("E:\\forked_canada_udp/data/inputs/shp/Canada/", city_name, ".rds", sep = ""))
st_write(city_tracts, paste(city_name, ".shp", sep = ""))
# city_tracts <- readRDS(paste("E:\\forked_canada_udp/data/inputs/shp/Canada/", city_name, ".rds", sep = ""))

