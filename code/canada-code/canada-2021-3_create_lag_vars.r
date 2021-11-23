# ==========================================================================
# ==========================================================================
# ==========================================================================
# DISPLACEMENT TYPOLOGY SET UP
# ==========================================================================
# ==========================================================================
# ==========================================================================

pacman::p_load(sf, dplyr, sp, spdep, raster, dbscan, tidyverse)


# ==========================================================================
# Pull in data
# ==========================================================================
# city_name = commandArgs(trailingOnly = TRUE)
city_name = "Vancouver"
# load the data_curation csv into R
df <- read.csv(paste("E:\\forked_canada_udp/data/outputs/databases/", city_name, "_database_2016.csv", sep = ""))
databases <- read.csv(paste("E:\\forked_canada_udp/data/outputs/databases/", city_name, "_database_2016.csv", sep = ""))
CMA_df <- read.csv(paste("E:\\forked_canada_udp/data/outputs/databases/", city_name, "_database_2016_CMA.csv", sep = ""))
tr_rent <- df %>%
  mutate(
    
    # median: 2011 - 2016 change
    rent16 = 
      case_when(
        is.na(real_mrent_16) ~ median(real_mrent_16, na.rm = TRUE),
        TRUE ~ as.double(real_mrent_16)),
    rent11 = 
      case_when(
        is.na(real_mrent_11) ~ median(real_mrent_11, na.rm = TRUE),
        TRUE ~ as.double(real_mrent_11)),
    
    tr_chrent = rent16 - rent11,
    tr_pchrent = tr_chrent / rent11,
    
    rg_rent16 = rm_real_mrent_16, 
    rg_rent11 = rm_real_mrent_11,
    rg_chrent = rg_rent16 - rg_rent11,
    rg_pchrent = rg_chrent / rg_rent11,
  ) %>% 
  dplyr::select(-real_mrent_11, -real_mrent_16) %>% 
  distinct() %>% 
  group_by(GeoUID) %>% 
  filter(row_number()==1) %>% 
  ungroup()
tr_rent$tr_pchrent[is.na(tr_rent$tr_pchrent)] <- 0
# write.csv(tr_rent, "tr_rent.csv")
# ==========================================================================
# Create rent gap and extra local change in rent
# ==========================================================================

stsp <- readRDS(paste("E:\\forked_canada_udp/data/inputs/shp/Canada/", city_name, ".rds", sep = ""))
stsp$CTUID <- as.numeric(stsp$CTUID)

# join data to these tracts
tr_rent$GeoUID <- as.numeric(tr_rent$GeoUID)
stsp <- left_join(stsp, tr_rent, by = c("CTUID" = "GeoUID"))
# Create neighbor matrix

# --------------------------------------------------------------------------

# changes because canadian data has multipolygons, not polygons
stsp <- stsp[is.finite(stsp$tr_pchrent),]
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

stsp$tr_pchrent.lag <- lag.listw(lw_dist_idwW, stsp$tr_pchrent)
stsp$tr_chrent.lag <- lag.listw(lw_dist_idwW, stsp$tr_chrent)
stsp$rent16.lag <- lag.listw(lw_dist_idwW,stsp$rent16)
# ==========================================================================
# Join lag vars with df
# ==========================================================================

lag <-  
  left_join(
    databases, 
    stsp %>% 
      mutate(CTUID = as.numeric(CTUID)) %>%
      dplyr::select(CTUID, rent16:rent16.lag), by = c("GeoUID" = "CTUID")) %>%
  mutate(
    # medians
    tr_rent_gap = rent16.lag - rent16, 
    tr_rent_gapprop = tr_rent_gap/((rent16 + rent16.lag)/2),
    
    rg_rent_gap = median(tr_rent_gap, na.rm = TRUE), 
    rg_rent_gapprop = median(tr_rent_gapprop, na.rm = TRUE), 
    
    rg_pchrent = median(tr_pchrent, na.rm = TRUE),
    rg_pchrent.lag = median(tr_pchrent.lag, na.rm = TRUE),
    
    rg_chrent.lag = median(tr_chrent.lag, na.rm = TRUE),
    rg_rent16.lag = median(rent16.lag, na.rm = TRUE), 
    
    dp_PChRent = case_when(tr_pchrent > 0 & tr_pchrent > rg_pchrent ~ 1, 
                           tr_pchrent.lag > rg_pchrent.lag ~ 1, 
                           TRUE ~ 0),
    dp_RentGap = case_when(tr_rent_gapprop > 0 & tr_rent_gapprop > rg_rent_gapprop ~ 1,
                           TRUE ~ 0)
  ) 
lag <- lag %>% dplyr::select(-geometry)
# ==========================================================================
# Export Data
# ==========================================================================
write.csv(lag, file = gzfile(paste("E:\\forked_canada_udp/data/outputs/lags/", city_name,"_lag.csv.gz", sep = "")))




