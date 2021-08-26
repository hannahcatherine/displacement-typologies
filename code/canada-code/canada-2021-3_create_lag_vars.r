# ==========================================================================
# ==========================================================================
# ==========================================================================
# DISPLACEMENT TYPOLOGY SET UP
# ==========================================================================
# ==========================================================================
# ==========================================================================
library(sf)
library(dplyr)
library(sp)
library(spdep)
library(raster)
library(dbscan)
library(tidyverse)

# ==========================================================================
# Pull in data
# ==========================================================================

# load the data_curation csv into R
df <- read.csv("vancouver_database_2016.csv")
databases <- read.csv("vancouver_database_2016.csv")

tr_rent <- df %>%
  mutate(
    tr_avgrent16 = 
      case_when(
        is.na(real_avgrent_16) ~ mean(real_avgrent_16, na.rm = TRUE),
        TRUE ~ as.double(real_avgrent_16)),
    tr_avgrent06 = 
      case_when(
        is.na(real_avgrent_06) ~ mean(real_avgrent_06, na.rm = TRUE),
        TRUE ~ as.double(real_avgrent_06)),
    tr_chrent = tr_avgrent16 - tr_avgrent06,
    tr_pchrent = 
      case_when(
        tr_avgrent06 == 0 ~ 0,
        TRUE ~ tr_chrent / tr_avgrent06),
    ### CHANGE THIS TO INCLUDE RM of region rather than county
    tr_medrent16 = 
      case_when(
        is.na(mmhcosts_r_16) ~ median(mmhcosts_r_16, na.rm = TRUE),
        TRUE ~ as.double(mmhcosts_r_16)),
    rm_avgrent16 = mean(tr_avgrent16, na.rm = TRUE), 
    rm_avgrent06 = mean(tr_avgrent06, na.rm = TRUE)) %>% 
  dplyr::select(-real_avgrent_06, -real_avgrent_16, -mmhcosts_r_16) %>% 
  distinct() %>% 
  group_by(GeoUID) %>% 
  filter(row_number()==1) %>% 
  ungroup()

write.csv(tr_rent, "tr_rent.csv")
# ==========================================================================
# Create rent gap and extra local change in rent
# ==========================================================================

stsp <- st_read("Vancouver/vancouver.shp")
stsp$CTUID <- as.numeric(stsp$CTUID)

# join data to these tracts
tr_rent$GeoUID <- as.numeric(tr_rent$GeoUID)
stsp <- left_join(stsp, tr_rent, by = c("CTUID" = "GeoUID"))
# plot(st_geometry(stsp))
write.csv(stsp, "stsp_pre_edit.csv")
#
# Create neighbor matrix



# --------------------------------------------------------------------------
    
# changes because canadian data has multipolygons, not polygons
stsp %>%
  st_geometry() %>% 
  st_centroid(of_largest_polygon = TRUE) -> coords
  IDs <- row.names(as.data.frame(stsp))
  stsp_nb <- poly2nb(stsp) # nb
  lw_bin <- nb2listw(stsp_nb, style = "W", zero.policy = TRUE)
  kern1 <- knn2nb(knearneigh(coords, k = 1), row.names=IDs)
  dist <- unlist(nbdists(stsp_nb, coords))
  summary(dist)
  max_1nn <- max(dist)
  dist_nb <- dnearneigh(coords, d1=0, d2 = .1*max_1nn)
  spdep::set.ZeroPolicyOption(TRUE)
  spdep::set.ZeroPolicyOption(TRUE)
  dists <- nbdists(dist_nb, coords)
  idw <- lapply(dists, function(x) 1/(x^2))
  lw_dist_idwW <- nb2listw(dist_nb, glist = idw, style = "W")
    
#
# Create select lag variables
# --------------------------------------------------------------------------

stsp$tr_pchrent.lag <- lag.listw(lw_dist_idwW,stsp$tr_pchrent)
stsp$tr_chrent.lag <- lag.listw(lw_dist_idwW, stsp$tr_chrent)
stsp$tr_avgrent16.lag <- lag.listw(lw_dist_idwW,stsp$tr_avgrent16)
stsp$tr_medrent16.lag <- lag.listw(lw_dist_idwW,stsp$tr_medrent16)
write.csv(stsp, "stsp.csv")
# ==========================================================================
# Join lag vars with df
# ==========================================================================

lag <-  
    left_join(
        databases, 
        stsp %>% 
            mutate(CTUID = as.numeric(CTUID)) %>%
            dplyr::select(CTUID, tr_avgrent16:tr_medrent16.lag), by = c("GeoUID" = "CTUID")) %>%
    mutate(
        tr_rent_gap = tr_medrent16.lag - tr_medrent16, 
        tr_rent_gapprop = tr_rent_gap/((tr_medrent16 + tr_medrent16.lag)/2),
        
        rm_rent_gap = median(tr_rent_gap, na.rm = TRUE), 
        rm_rent_gapprop = median(tr_rent_gapprop, na.rm = TRUE), 
        
        ravg_pchrent = mean(tr_pchrent, na.rm = TRUE),
        ravg_pchrent.lag = mean(tr_pchrent.lag, na.rm = TRUE),
        
        ravg_chrent.lag = mean(tr_chrent.lag, na.rm = TRUE),
        ravg_avgrent16.lag = mean(tr_avgrent16.lag, na.rm = TRUE), 
        
        dp_PChRent = case_when(tr_pchrent > 0 & 
                               tr_pchrent > ravg_pchrent ~ 1, # ∆ within tract
                               tr_pchrent.lag > ravg_pchrent.lag ~ 1, # ∆ nearby tracts
                               TRUE ~ 0),
        dp_RentGap = case_when(tr_rent_gapprop > 0 & tr_rent_gapprop > rm_rent_gapprop ~ 1,
                               TRUE ~ 0),
    ) 
lag <- lag %>% dplyr::select(-geometry)
# ==========================================================================
# Export Data
# ==========================================================================
write.csv(lag, "E:\\forked_canada_udp/data/outputs/lags/vancouver_lag.csv")




