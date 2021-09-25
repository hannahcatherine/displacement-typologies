#!/usr/bin/env python
# coding: utf-8

# ==========================================================================
# Import Libraries
# ==========================================================================

import pandas as pd
from shapely import wkt
import geopandas as gpd
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import sys

# ==========================================================================
# Choose City to Run (inputs needed)
# ==========================================================================
# Note: Code is set up to run one city at a time

### Choose city and census tracts of interest
# To get city data, run the following code in the terminal
# `python data.py <city name>`
# Example: python data.py Atlanta

# city_name = str(sys.argv[1])


###
# When testing city analysis, use: 
# comment this out later when this is ready for multiple canadian cities
city_name = "Vancouver"

# Run create_lag_vars.r to create lag variables
# --------------------------------------------------------------------------
# Note: If additional cities are added, make sure to change create_lag_vars.r
# accordingly. 

input_path = 'data/inputs/'
output_path ='data/outputs/'

lag = pd.read_csv(output_path+'/lags/' +str.lower(city_name)+ '_lag.csv') ### Read file
typology_input = pd.read_csv(output_path+'/databases/'+str.lower(city_name)+'_database_2016.csv', index_col = 0) ### Read file
geo_data = gpd.read_file(input_path + "shp/" +str.lower(city_name)+ "/" + str.lower(city_name)+ ".shp")
geo_data['CTUID'] = geo_data['CTUID'].astype(float)
typology_input['GeoUID'] = typology_input['GeoUID'].astype(float)
geo_data = geo_data.rename(columns = {"CTUID" : "GeoUID"})

geo_typology_input = geo_data.merge(typology_input, on = "GeoUID")

data = geo_typology_input.copy(deep=True)

## Summarize Income Categorization Data
# --------------------------------------------------------------------------

print(data.groupby('inc_cat_medhhinc_16').count()['GeoUID'].sum())

print(data.groupby('inc_cat_medhhinc_06').count()['GeoUID'].sum())

#### Flag for sufficient pop in tract by 2006
data['pop06flag'] = np.where((data['pop_06'].astype(float) >= 400), 1, 0)

# ==========================================================================
# Define Vulnerability to Gentrification Variable
# ==========================================================================
# Note: Code is set up to run one city at a time

# Vulnerable to gentrification index, for both '96 and '06 - make it a flag
# --------------------------------------------------------------------------

### ***** 1996 *****
### 3/4 Criteria that needs to be met

# one of these:
# average rent in CT < average rent in CMA?
# average housing value in CT < average housing value of CMA?

# at LEAST 3 of these: 
# did the tract have a higher percentage of visible minorities than the rest of the toronto CMA?
# did the tract have a higher percentage of renters than the rest of the toronto CMA? 
# did the tract have a higher percentage of low income households than the rest of the toronto CMA? 
# did the tract have a lower  percentage of college educated households than the rest of the toronto CMA?

data['vul_gent_96'] = np.where(((data['aboveravg_real_avgrent_96']==0)|(data['aboveravg_real_avghval_96']==0))& # below regional average housing value or rent
                                 ((data['aboverm_per_all_li_96']+ # above regional median percent of population that is low income
                                   data['aboverm_per_visible_minority_96']+ # above regional median percent of population that is non-white
                                   data['aboverm_per_rent_96']+ # above regional median percent of population that rents
                                   (1-data['aboverm_per_col_96']))>2), 1, 0) # below regional median of population that is college educated

### ***** 2006 *****
### 3/4 Criteria that needs to be met
data['vul_gent_06'] = np.where(((data['aboveravg_real_avgrent_06']==0)|(data['aboveravg_real_avghval_06']==0))&
                                 ((data['aboverm_per_all_li_06']+
                                   data['aboverm_per_visible_minority_06']+
                                   data['aboverm_per_rent_06']+
                                   (1-data['aboverm_per_col_06']))>2), 1, 0)

### ***** 2016 *****
### 3/4 Criteria that needs to be met
data['vul_gent_16'] = np.where(((data['aboveravg_real_avgrent_16']==0)|(data['aboveravg_real_avghval_16']==0))&
                                 ((data['aboverm_per_all_li_16']+
                                   data['aboverm_per_visible_minority_16']+
                                   data['aboverm_per_rent_16']+
                                   (1-data['aboverm_per_col_16']))>2), 1, 0)

# ==========================================================================
# Define Hot Market Variable
# ==========================================================================

# Hot market in '06 and '16 - make it a flag
# --------------------------------------------------------------------------
# was there an above CMA average change in real housing value *or* rent?

data['hotmarket_06'] = np.where((data['aboveravg_pctch_real_avghval_96_06']==1)|
                                  (data['aboveravg_pctch_real_avgrent_96_06']==1), 1, 0)
data['hotmarket_06'] = np.where((data['aboveravg_pctch_real_avghval_96_06'].isna())|
                                  (data['aboveravg_pctch_real_avgrent_96_06'].isna()), np.nan, data['hotmarket_06'])

data['hotmarket_16'] = np.where((data['aboverm_pctch_real_mhval_11_16']==1)|
                                  (data['aboverm_pctch_real_mrent_11_16']==1), 1, 0)
data['hotmarket_16'] = np.where((data['aboverm_pctch_real_mhval_11_16'].isna())|
                                  (data['aboverm_pctch_real_mrent_11_16'].isna()), np.nan, data['hotmarket_16'])

# ==========================================================================
# Define Experienced Gentrification Variable
# ==========================================================================


### 1996 - 2006

# between year A and year B, did the tract experience:
    # an above regional median change in percent college educated population?
    # an above regional median percent change in median income?
    # an above regional average percent change in housing values or rents?
    # 
data['gent_96_06'] = np.where((data['vul_gent_96']==1)&
                                (data['aboverm_ch_per_col_96_06']==1)&
                                (data['aboverm_pctch_real_mhhinc_96_06']==1)&
                                (data['hotmarket_06']==1), 1, 0)


# # 2006 - 2016
data['gent_06_16'] = np.where((data['vul_gent_06']==1)&
                                (data['aboverm_ch_per_col_06_16']==1)&
                                (data['aboverm_pctch_real_mhhinc_06_16']==1)&
                                (data['hotmarket_16']==1), 1, 0)

# Add lag variables
data = pd.merge(data,lag[['GeoUID','dp_PChRent','dp_RentGap', 'tr_rent_gap', 'rg_rent_gap']],on='GeoUID')

# ==========================================================================
# ==========================================================================
# ==========================================================================
# Construct Typology
# ==========================================================================
# ==========================================================================
# ==========================================================================
# Note: Make flags for each typology definition
# goal is to make them flags so we can compare across typologies to check 
# if any are being double counted or missed. 
# Note on missing data: will code it so that the typology is missing if any 
# of the core data elements are missing, but for any additional risk or stability 
# criteria, will be coded so that it pulls from a shorter list 
# if any are missing so as not to throw it all out

df = data

# ==========================================================================
# Very high income exclusion
# ==========================================================================

### ********* Super gentrification or exclusion *************

df["SGE"] = np.where((df['pop06flag']==1)&
                     (((df['VHI_pdmt_medhhinc_96'] == 1)& # High-income tract in 1996 and
                     (df['VHI_pdmt_medhhinc_16'] == 1))) & #   High-income tract in 2016;     
                     (df['real_mhhinc_16'] > df['real_mhhinc_96']) & #  Median income higher in 2016 than in 1996             --- first cell
                     (df['lmh_flag_encoded'] == 3) & #  Affordable to high income households in 2016                          --- second cell
                     ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2)| # Marginal change, increase, 
                     (df['change_flag_encoded'] == 3)) # or rapid increase in housing costs                                   --- third cell
                      , 1, 0)
# nan protection
df["SGE"] = np.where((df['pop06flag'].isna())|
                     (df['VHI_pdmt_medhhinc_96'].isna())|
                     (df['VHI_pdmt_medhhinc_16'].isna())|
                     (df['real_mhhinc_96'].isna())|
                     (df['real_mhhinc_16'].isna()), np.nan, df['VHI'])



# ==========================================================================
# Stable/Advanced Exclusive
# ==========================================================================

### ********* Stable/advanced exclusive *************
df['SAE'] = 0

# first cell:

# lmh flag encoded is housing affordability to low, moderate, or high income households
# tot_anything refers to housing_ch | renter_ch
# change flag encoded 1 - tot_decrease or marginal change in housing costs
# change flag encoded 2 - tot_increase in housing costs
# change flag encoded 3 - rapid increase in housing costs
df['SAE'] = np.where((df['pop06flag']==1)&
                     (((df['high_pdmt_medhhinc_96'] == 1)& # High-income tract in 1996 and
                     (df['high_pdmt_medhhinc_16'] == 1))) & #   High-income tract in 2016;     
                     (df['real_mhhinc_16'] > df['real_mhhinc_96']) & #  Median income higher in 2016 than in 1996             --- first cell
                     (df['lmh_flag_encoded'] == 3) & #  Affordable to high income households in 2016                          --- second cell
                     ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2)| # Marginal change, increase, 
                     (df['change_flag_encoded'] == 3)) # or rapid increase in housing costs                                   --- third cell
                      , 1, 0)

# nan protection
df['SAE'] = np.where((df['pop06flag'].isna())|
                     (df['high_pdmt_medhhinc_96'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['real_mhhinc_96'].isna())|
                     (df['real_mhhinc_16'].isna()), np.nan, df['SAE'])

# replace SAE=1 if A==1 & (A==1) & (B==1) & (C==5| D==6)& (E==18 | F==19 | G==20)




# ==========================================================================
# Advanced Gentrification
# ==========================================================================

### ************* Advanced gentrification **************

df['AdvG'] = 0
df['AdvG'] = np.where((df['pop06flag']==1)&
                    ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed moderate, 
                    (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))& # mixed high, high income tract in 2016           ---- first cell
                    ((df['lmh_flag_encoded'] == 2)|(df['lmh_flag_encoded'] == 3)| # Housing affordable to middle, high
                    (df['lmh_flag_encoded'] == 5)|(df['lmh_flag_encoded'] == 6))& #  mixed moderate, and mixed high-income households in 2016 ---- second cell
                    ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2))& #  Marginal change or increase in housing costs     ---- third cell
                    (
                        (df['gent_96_06']==1)| # Gentrified in 1996-2006 or
                        (df['gent_06_16']==1) # Gentrified in or 2006-2016 --- fourth cell
                     ), 1, 0)

df['AdvG'] = np.where((df['pop06flag'].isna())|
                     (df['mod_pdmt_medhhinc_16'].isna())|
                     (df['mix_mod_medhhinc_16'].isna())|
                     (df['mix_high_medhhinc_16'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     
                     (df['gent_96_06'].isna())|
                     (df['gent_06_16'].isna()), np.nan, df['AdvG'])

df['AdvG'] = np.where((df['AdvG'] == 1)&(df['SAE']==1) , 0, df['AdvG']) ### This is to account for double classification

# ==========================================================================
# At Risk of Becoming Exclusive 
# ==========================================================================

# df = data
df['ARE'] = 0
df['ARE'] = np.where((df['pop06flag']==1)&
                    ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed-moderate, 
                    (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))& # mixed-high, high income tract in 2016           --- first cell                   
                    ((df['lmh_flag_encoded'] == 2)|(df['lmh_flag_encoded'] == 3)| # Housing affordable to middle, high, 
                    (df['lmh_flag_encoded'] == 5)|(df['lmh_flag_encoded'] == 6))& # mixed-moderate, and mixed-high income households in 2016  --- second cell
                    ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2)), 1, 0) # Marginal change or increase in housing costs --- third cell

df['ARE'] = np.where((df['pop06flag'].isna())|
                     (df['mod_pdmt_medhhinc_16'].isna())|
                     (df['mix_mod_medhhinc_16'].isna())|
                     (df['mix_high_medhhinc_16'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna()), np.nan, df['ARE'])

df['ARE'] = np.where((df['ARE'] == 1)&(df['AdvG']==1), 0, df['ARE']) ### This is to account for double classification
df['ARE'] = np.where((df['ARE'] == 1)&(df['SAE']==1), 0, df['ARE']) ### This is to account for double classification

# ==========================================================================
# Becoming Exclusive
# ==========================================================================

### *********** Becoming exclusive *************
df['BE'] = 0
df['BE'] = np.where((df['pop06flag']==1)&
                    ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed-moderate,
                    (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))& #  mixed-high, high income tract in 2016 --- first cell
                    (df['lostli_16']==1) & # Absolute loss of low-income households 1996-2016 --- second cell
                    ((df['lmh_flag_encoded'] == 2)|(df['lmh_flag_encoded'] == 3)| # Housing affordable to middle, high, 
                    (df['lmh_flag_encoded'] == 5)|(df['lmh_flag_encoded'] == 6)) & # mixed-moderate, and mixed-high income households in 2016 --- third cell
                    (df['change_flag_encoded'] == 3)   # Rapid increase in housing costs --- fourth cell
                    , 1, 0)
                     # do not have per_limove_06 or per_limove_16
                    
df['BE'] = np.where((df['pop06flag'].isna())|
                     (df['mod_pdmt_medhhinc_16'].isna())|
                     (df['mix_mod_medhhinc_16'].isna())|
                     (df['mix_high_medhhinc_16'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['lostli_16'].isna())
                     , np.nan, df['BE'])

df['BE'] = np.where((df['BE'] == 1)&(df['SAE']==1), 0, df['BE']) ### This is to account for double classification


# ==========================================================================
# Stable Moderate/Mixed Income
# ==========================================================================

df['SMMI'] = 0

df['SMMI'] = np.where((df['pop06flag']==1)&
                     ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed-moderate, 
                      (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))&  # mixed-high, high income tract 2016 --- first cell
                     (df['ARE']==0)&(df['BE']==0)&(df['SAE']==0)&(df['AdvG']==0), 1, 0) # and not all the others with that req

df['SMMI'] = np.where((df['pop06flag'].isna())|
                      (df['mod_pdmt_medhhinc_16'].isna())|
                      (df['mix_mod_medhhinc_16'].isna())|
                      (df['mix_high_medhhinc_16'].isna())|
                      (df['high_pdmt_medhhinc_16'].isna()), np.nan, df['SMMI'])

# ==========================================================================
# At Risk of Gentrification
# ==========================================================================

### ****ARG ****
df['ARG'] = 0
df['ARG'] = np.where((df['pop06flag']==1)&
                    ((df['low_pdmt_medhhinc_16']==1)|(df['mix_low_medhhinc_16']==1))& # Low income or mixed-low income tract in 2016 --- first cell
                    ((df['lmh_flag_encoded']==1)|(df['lmh_flag_encoded']==4))& # Housing affordable to low or mixed-low income households 2016 --- second cell
                    (df['change_flag_encoded'] == 1) & # Marginal change in housing costs, 2006-2016 --- third cell
                    ((df['gent_96_06']==0) & (df['gent_06_16']==0)) & # Didn’t gentrify 1996-2006 OR 2006-2016 
                    ((df['dp_PChRent'] == 1)|(df['dp_RentGap'] == 1))  # 1) surrounding tracts saw rent increases above the regional avg between 2006-2016, or 2) the difference between tract rental prices and the prices of surrounding areas in 2016 was higher than the regional avg difference in rental prices between tracts (rent gap).
                    , 1, 0)

df['ARG'] = np.where((df['pop06flag'].isna())|
                     (df['low_pdmt_medhhinc_16'].isna())|
                     (df['mix_low_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['gent_96_06'].isna())|
                     (df['dp_PChRent'].isna())|
                     (df['dp_RentGap'].isna())|
                     (df['gent_06_16'].isna()), np.nan, df['ARG'])

# ==========================================================================
# Early/Ongoing Gentrification
# ==========================================================================

###************* Early/ongoing gentrification **************
### ****EOG ****
df['EOG'] = 0
df['EOG'] = np.where((df['pop06flag']==1)& # pop > 500
                    ((df['low_pdmt_medhhinc_16']==1)|(df['mix_low_medhhinc_16']==1))& # Low income or mixed-low income tract in 2016 --- first cell
                   
                    ( 
                        (df['lmh_flag_encoded'] == 2)| # Housing affordable to moderate or
                        (df['lmh_flag_encoded'] == 5) # mixed moderate-income households in 2016
                        ) &
                    (
                        (df['change_flag_encoded'] == 2)| # Increase or 
                        (df['change_flag_encoded'] == 3)| # rapid increase in housing cost
                        #((df['hv_abravg_ch'] == 1)| # OR above regional avg change in home values between  2006 -2016  or above regional avg change in rent between 2006 - 2016
                        #(df['rent_abravg_ch'] == 1)) |
                        ((df['hv_abrm_ch'] == 1)| # OR above regional median change in home values between  2011 -2016  or above regional median change in rent between 2011 - 2016
                        (df['rent_abrm_ch'] == 1))
                        ) &
                     (
                        (df['gent_96_06']==1)| # Gentrified in 1996-2006 or
                        (df['gent_06_16']==1) # Gentrified in 2006-2016 --- fourth cell
                    ), 1, 0) # gentrified (includes hotmarket)

df['EOG'] = np.where((df['pop06flag'].isna())|
                     (df['low_pdmt_medhhinc_16'].isna())|
                     (df['mix_low_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['gent_96_06'].isna())|
                     (df['gent_06_16'].isna())|                     
                     (df['hv_abrm_ch'].isna())|
                     (df['rent_abrm_ch'].isna()
                    
                      ), np.nan, df['EOG'])

# ==========================================================================
# Ongoing Displacement
# ==========================================================================

# df = data

df['OD'] = 0
df['OD'] = np.where((df['pop06flag']==1)&
                ((df['low_pdmt_medhhinc_16']==1)|(df['mix_low_medhhinc_16']==1)) & # Low or mixed low-income tract in 2016 -- first cell
                (df['lostli_16']==1), 1, 0) # Absolute loss of low-income households 1996-2016 --- second cell

df['OD_loss'] = np.where((df['pop06flag'].isna())|
                    (df['low_pdmt_medhhinc_16'].isna())|
                    (df['mix_low_medhhinc_16'].isna())|
                    (df['lostli_16'].isna()), np.nan, df['OD'])

df['OD'] = np.where((df['OD'] == 1)&(df['ARG']==1), 0, df['OD']) ### This is to account for double classification
df['OD'] = np.where((df['OD'] == 1)&(df['EOG']==1), 0, df['OD']) ### This is to account for double classification

# ==========================================================================
# Low-Income/Susceptible to Displacement
# ==========================================================================

df['LISD'] = 0
df['LISD'] = np.where((df['pop06flag'] == 1)&
                     ((df['low_pdmt_medhhinc_16'] == 1)|(df['mix_low_medhhinc_16'] == 1))& # Low or mixed low-income tract in 2016 --- first cell
                     (df['OD']!=1) & (df['ARG']!=1) & (df['EOG']!=1), 1, 0) 

# ==========================================================================
# Create Typology Variables for All Dummies
# ==========================================================================

df['double_counted'] = (df['LISD'].fillna(0) + df['OD'].fillna(0) + df['ARG'].fillna(0) + df['EOG'].fillna(0) +
                       df['AdvG'].fillna(0) + df['ARE'].fillna(0) + df['BE'].fillna(0) + df['SAE'] + df['SMMI'])
    
df['typology'] = np.nan

typologies = ["LISD", "OD", "ARG", "EOG", "AdvG", "SMMI", "ARE", "BE", "SAE", "SGE"]


df['typology'] = np.where(df['LISD'] == 1, 1, df['typology'])
df['typology'] = np.where(df['OD'] == 1, 2, df['typology'])
df['typology'] = np.where(df['ARG'] == 1, 3, df['typology'])
df['typology'] = np.where(df['EOG'] == 1, 4, df['typology'])
df['typology'] = np.where(df['AdvG'] == 1, 5, df['typology'])
df['typology'] = np.where(df['SMMI'] == 1, 6, df['typology'])
df['typology'] = np.where(df['ARE'] == 1, 7, df['typology'])
df['typology'] = np.where(df['BE'] == 1, 8, df['typology'])
df['typology'] = np.where(df['SAE'] == 1, 9, df['typology'])
df['typology'] = np.where(df['SGE'] == 1, 10, df['typology'])
df['typology'] = np.where(df['double_counted']>1, 99, df['typology'])


# Double Classification Check
# --------------------------------------------------------------------------

cat_i = list()

# df = data
for i in range (0, len (df)):
    categories = list()
    if df['LISD'][i] == 1:
        categories.append('LISD')
    if df['OD'][i] == 1:
        categories.append('OD')
    if df['ARG'][i] == 1:
        categories.append('ARG')
    if df['EOG'][i] == 1:
        categories.append('EOG')
    if df['AdvG'][i] == 1:
        categories.append('AdvG')
    if df['SMMI'][i] == 1:
        categories.append('SMMI')
    if df['ARE'][i] == 1:
        categories.append('ARE')
    if df['BE'][i] == 1:
        categories.append('BE')
    if df['SAE'][i] == 1:
        categories.append('SAE')
    if df['SGE'][i] == 1:
        categories.append('SGE')
    cat_i.append(str(categories))
    
df['typ_cat'] = cat_i

print('TYPOLOGIES')

######
# Begin Test
######
f, ax = plt.subplots(1, figsize=(8, 8))
data.plot(ax=ax, color = 'lightgrey')
lims = plt.axis('equal')
df[~data['typology'].isna()].plot(ax = ax, column = 'typ_cat', legend = True)
plt.show()
print('There are ', data['typology'].isna().sum(), 'census tract with NaN as data')

######
# End Test
######



# ==========================================================================
# Export Date
# ==========================================================================
# Note: You'll need to change the 'output path' variable above in order to output 
# to your desired location



df['GeoUID'] = df['GeoUID'].astype(str)
df = df.drop(columns = 'geometry')
print(df.groupby('typ_cat').size())
df.to_csv(output_path+'/typologies/'+str.lower(city_name) + '_typology_output.csv')