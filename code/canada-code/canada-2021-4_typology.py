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

lag = pd.read_csv(output_path+'/lags/vancouver_lag.csv') ### Read file
typology_input = pd.read_csv(output_path+'/databases/'+str.lower(city_name)+'_database_2016.csv', index_col = 0) ### Read file
geo_data = gpd.read_file(input_path + "shp/vancouver/vancouver.shp")
geo_data['CTUID'] = geo_data['CTUID'].astype(float)
typology_input['GeoUID'] = typology_input['GeoUID'].astype(float)
geo_data = geo_data.rename(columns = {"CTUID" : "GeoUID"})

geo_typology_input = geo_data.merge(typology_input, on = "GeoUID")

data = geo_typology_input.copy(deep=True)

## Summarize Income Categorization Data
# --------------------------------------------------------------------------

data.groupby('inc_cat_medhhinc_16').count()['GeoUID']

data.groupby('inc_cat_medhhinc_06').count()['GeoUID']

#### Flag for sufficient pop in tract by 2006
data['pop06flag'] = np.where((data['pop_06'].astype(float) >500), 1, 0)

####
# Begin Test
####

# ax = data.plot(color = 'white')
# ax = data.plot(ax = ax, column = 'pop06flag', legend = True)
# plt.title('POPULATION OVER 500 FOR YEAR 2006')
# plt.show()
# print('There are ', len(data[data['pop06flag']==0]), 'census tract with pop<500 in 2006')
####
# End Test
####

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
# did the tract have a higher percentage of visible minorities than the rest of the vancouver CMA?
# did the tract have a higher percentage of renters than the rest of the vancouver CMA? 
# did the tract have a higher percentage of low income households than the rest of the vancouver CMA? 
# fewer than 100% of the tract has a college education

data['vul_gent_96'] = np.where(((data['aboveravg_real_avgrent_96']==0)|(data['aboveravg_real_avghval_96']==0))&
                                 ((data['aboverm_per_all_li_96']+
                                   data['aboverm_per_visible_minority_96']+
                                   data['aboveravg_per_rent_96']+
                                   (1-data['aboverm_per_col_96']))>2), 1, 0)


### ***** 2006 *****
### 3/4 Criteria that needs to be met
data['vul_gent_06'] = np.where(((data['aboveravg_real_avgrent_06']==0)|(data['aboveravg_real_avghval_06']==0))&
                                 ((data['aboverm_per_all_li_06']+
                                   data['aboverm_per_visible_minority_06']+
                                   data['aboveravg_per_rent_06']+
                                   (1-data['aboverm_per_col_06']))>2), 1, 0)

### ***** 2016 *****
### 3/4 Criteria that needs to be met
data['vul_gent_16'] = np.where(((data['aboveravg_real_avgrent_16']==0)|(data['aboveravg_real_avghval_16']==0))&
                                 ((data['aboverm_per_all_li_16']+
                                   data['aboverm_per_visible_minority_16']+
                                   data['aboveravg_per_rent_16']+
                                   (1-data['aboverm_per_col_16']))>2), 1, 0)

####
# Begin Test
####

#ax = data.plot(color = 'grey')
#ax = data[~data['vul_gent_96'].isna()].plot(ax = ax, column = 'vul_gent_96', legend = True)
#plt.title('VULNERABLE IN 1996')
#plt.show()
#print('There are ', data['vul_gent_96'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['vul_gent_96']==1).sum(), 'census tracts vulnerable in 1996')
####
# End Test
####

####
# Begin Test
####

#ax = data.plot(color = 'grey')
#ax = data[~data['vul_gent_06'].isna()].plot(ax = ax, column = 'vul_gent_06', legend = True)
#plt.title('VULNERABLE IN 2006')
#plt.show()
#print('There are ', data['vul_gent_06'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['vul_gent_06']==1).sum(), 'census tracts vulnerable in 2006')
####
# End Test
####

####
# Begin Test
####

#ax = data.plot(color = 'grey')
#ax = data[~data['vul_gent_16'].isna()].plot(ax = ax, column = 'vul_gent_16', legend = True)
#plt.title('VULNERABLE IN 2016')
#plt.show()
#print('There are ', data['vul_gent_16'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['vul_gent_16']==1).sum(), 'census tracts vulnerable in 2016')
####
# End Test
####

####
# Begin Test
####

#ax = data.plot(color = 'grey')
#ax = data[~data['vul_gent_16'].isna()].plot(ax = ax, column = 'vul_gent_16', legend = True)
#plt.title('VULNERABLE IN 2016')
#plt.show()
#print('There are ', data['vul_gent_16'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['vul_gent_16']==1).sum(), 'census tracts vulnerable in 2016')
####
# End Test
####

data['vulnerable'] = data['vul_gent_96']*data['vul_gent_06']

####
# Begin Test
####

#ax = data.plot(color = 'grey')
#ax = data[~data['vulnerable'].isna()].plot(ax = ax, column = 'vulnerable', legend = True)
#plt.title('VULNERABLE IN 1996 and 2006')
#plt.show()
#print('There are ', data['vulnerable'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['vulnerable']==1).sum(), 'census tracts vulnerable in both years')
####
# End Test
####

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

data['hotmarket_16'] = np.where((data['aboveravg_pctch_real_avghval_06_16']==1)|
                                  (data['aboveravg_pctch_real_avgrent_06_16']==1), 1, 0)
data['hotmarket_16'] = np.where((data['aboveravg_pctch_real_avghval_06_16'].isna())|
                                  (data['aboveravg_pctch_real_avgrent_06_16'].isna()), np.nan, data['hotmarket_16'])

####
# Begin Test
####

#ax = data.plot(color = 'white')
#ax = data[~data['hotmarket_16'].isna()].plot(ax = ax, column = 'hotmarket_16', legend = True)
#plt.title('HOT MARKET 2016')
#plt.show()
#print('There are ', data['hotmarket_16'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['hotmarket_16']==1).sum(), 'census tracts with hot market in 2016')
####
# End Test
####

####
# Begin Test
####

#ax = data.plot(color = 'white')
#ax = data[~data['hotmarket_06'].isna()].plot(ax = ax, column = 'hotmarket_06', legend = True)
#plt.title('HOT MARKET 2006')
#plt.show()
#print('There are ', data['hotmarket_06'].isna().sum(), 'census tract with NaN as data')
#print('There are ', (data['hotmarket_06']==1).sum(), 'census tracts with hot market in 2006')
####
# End Test
####

# ==========================================================================
# Define Experienced Gentrification Variable
# ==========================================================================

### 1996 - 2006
data['gent_96_06'] = np.where((data['vul_gent_96']==1)&
                                (data['aboverm_ch_per_col_96_06']==1)&
                                (data['aboverm_pctch_real_mhhinc_96_06']==1)&
                                (data['lostli_06']==1)&
                                (data['hotmarket_06']==1), 1, 0)

data['gent_96_06_urban'] = np.where((data['vul_gent_96']==1)&
                                (data['aboverm_ch_per_col_96_06']==1)&
                                (data['aboverm_pctch_real_mhhinc_96_06']==1)&
                                # next line was commented out
                                # (data['lostli_06']==1)&
                                (data['hotmarket_06']==1), 1, 0)


# # 2006 - 2016
data['gent_06_16'] = np.where((data['vul_gent_06']==1)&
                                (data['aboverm_ch_per_col_06_16']==1)&
                                (data['aboverm_pctch_real_mhhinc_06_16']==1)&
                                (data['lostli_16']==1)&
                                # need move-in/out for this
                                # (data['ch_per_limove_06_16']<0)&
                                (data['hotmarket_16']==1), 1, 0)

data['gent_06_16_urban'] = np.where((data['vul_gent_06']==1)&
                                (data['aboverm_ch_per_col_06_16']==1)&
                                (data['aboverm_pctch_real_mhhinc_06_16']==1)&
                                (data['lostli_16']==1)&
                                # (data['ch_per_limove_06_16']<0)&
                                (data['hotmarket_16']==1), 1, 0)


# Add lag variables
data = pd.merge(data,lag[['dp_PChRent','dp_RentGap','GeoUID', 'tr_rent_gap', 'rm_rent_gap',]],on='GeoUID')

####
# Begin Test
####

#ax = data.plot(color = 'white')
#ax = data[~data['gent_96_06'].isna()].plot(ax = ax, column = 'gent_96_06', legend = True)
#plt.title('GENTRIFICATION 1996 - 2006')
#plt.show()
#print('There are ', data['gent_96_06'].isna().sum(), 'census tract with NaN as data')
#print(str((data['gent_96_06']==1).sum()), 'census tracts were gentrified 1996-2006')
####
# End Test
####


####
# Begin Test
####

#ax = data.plot(color = 'white')
#ax = data[~data['gent_06_16'].isna()].plot(ax = ax, column = 'gent_06_16', legend = True)
#plt.title('GENTRIFICATION 2006 - 2016')
#plt.show()
#print('There are ', data['gent_06_16'].isna().sum(), 'census tract with NaN as data')
#print(str((data['gent_06_16']==1).sum()), 'census tracts were gentrified 2006-2016')
####
# End Test
####

(data['gent_06_16']*data['gent_96_06']).sum()



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
                     (df['high_pdmt_medhhinc_16'] == 1))) | #   High-income tract in 2016;     
                     (df['real_mhhinc_16'] > df['real_mhhinc_96']) & # first cell  Median income higher in 2016 than in 1996  --- first cell
                     (df['lmh_flag_encoded'] == 3) & #  Affordable to high income households in 2016                          --- second cell
                     ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2)| # Marginal change, increase, 
                     (df['change_flag_encoded'] == 3)) # or rapid increase in housing costs                                    --- third cell
                      , 1, 0)

# nan protection
df['SAE'] = np.where((df['pop06flag'].isna())|
                     (df['high_pdmt_medhhinc_06'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['real_mhhinc_96'].isna())|
                     (df['real_mhhinc_16'].isna()), np.nan, df['SAE'])

# replace SAE=1 if A==1 & (A==1) & (B==1) & (C==5| D==6)& (E==18 | F==19 | G==20)

# ==========================================================================
# Very high income exclusion
# ==========================================================================

### ********* Super gentrification or exclusion *************
df['VHI'] = 0

df['VHI'] = np.where((df['super_high_mhinc'] == 1) & # median income > 200% regional median in 2016
                     (df['SAE'] == 1) # stable / advanced exclusive
                      , 1, 0)

# nan protection
df['VHI'] = np.where(df['pop06flag'].isna()|
                     df['super_high_mhinc'].isna()
                     , np.nan, df['VHI'])


df['VHI'] = np.where((df['SAE'] == 1)&(df['VHI']==1), df['VHI'], 0) ### This is to account for double classification

####
# Begin Test
####

#ax = data.plot(color = 'white')
#ax = data[~data['SAE'].isna()].plot(ax = ax, column = 'SAE', legend = True)
#plt.title('STABLE ADVANCED EXCLUSIVE')
#plt.show()
#print('There are ', data['SAE'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['SAE']==1).sum()), 'Stable Advanced Exclusive CT')
####
# End Test
####

### Filters only exclusive tracts
#exclusive = data[data['SAE']==1].reset_index(drop=True)

### Flags census tracts that touch exclusive tracts (excluding exclusive)
#proximity = df[df.geometry.touches(exclusive.unary_union)]

####
# Begin Test
####
#ax = data.plot()

#exclusive.plot(ax = ax, color = 'grey')
#proximity.plot(ax = ax, color = 'yellow')
#plt.title("Exclusive tracts (grey) and their neighbors (yellow)")
#plt.show()
####
# End Test
####

# ==========================================================================
# Advanced Gentrification
# ==========================================================================

### ************* Advanced gentrification **************
# why was this line commented out
# df = data

# moderate, mixed moderate, mixed high, high income tract in 2016
df['AdvG'] = 0
df['AdvG'] = np.where((df['pop06flag']==1)&
                    ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed moderate, 
                     (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))& # mixed high, high income tract in 2016           ---- first cell
                     ((df['lmh_flag_encoded'] == 2)|(df['lmh_flag_encoded'] == 3)| # Housing affordable to middle, high
                    (df['lmh_flag_encoded'] == 5)|(df['lmh_flag_encoded'] == 6))& #  mixed moderate, and mixed high-income households in 2016 ---- second cell
                    ((df['change_flag_encoded'] == 1)|(df['change_flag_encoded'] == 2)|(df['change_flag_encoded'] == 3))& #  mixed moderate, and mixed high-income households in 2016 --- third cell
                    # ((df['pctch_real_avghval_06_16'] > 0) | (df['pctch_real_avgrent_06_16'] > 0)) & 
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
                     (df['gent_96_06_urban'].isna())|
                     (df['gent_06_16_urban'].isna())|
                     (df['pctch_real_avghval_06_16'].isna())|
                     (df['pctch_real_avgrent_06_16'].isna())|
                     (df['gent_06_16'].isna()), np.nan, df['AdvG'])

df['AdvG'] = np.where((df['AdvG'] == 1)&(df['SAE']==1), 0, df['AdvG']) ### This is to account for double classification
df['AdvG'] = np.where((df['AdvG'] == 1)&(df['VHI']==1), 0, df['AdvG']) ### This is to account for double classification
####
# Begin Test
####
#print('ADVANCED GENTRIFICATION')
#ax = data.plot(color = 'white')
#ax = data[~data['AdvG'].isna()].plot(ax = ax, column = 'AdvG', legend = True)
#plt.show()
#print('There are ', data['AdvG'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['AdvG']==1).sum()), 'Advanced Gentrification CT')
####
# End Test
####

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
df['ARE'] = np.where((df['ARE'] == 1)&(df['VHI']==1), 0, df['ARE']) ### This is to account for double classification
####
# Begin Test
####
#print('AT RISK OF BECOMING EXCLUSIVE')
#ax = data.plot(color = 'white')
#ax = data[~data['ARE'].isna()].plot(ax = ax, column = 'ARE', legend = True)
#plt.show()
#print('There are ', data['ARE'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['ARE']==1).sum()), 'At Risk of Exclusive CT')
####
# End Test
####

# ==========================================================================
# Becoming Exclusive
# ==========================================================================

### *********** Becoming exclusive *************
df['BE'] = 0
df['BE'] = np.where((df['pop06flag']==1)&
                    ((df['mod_pdmt_medhhinc_16'] == 1)|(df['mix_mod_medhhinc_16'] == 1)| # Moderate, mixed-moderate,
                     (df['mix_high_medhhinc_16'] == 1)|(df['high_pdmt_medhhinc_16'] == 1))& #  mixed-high, high income tract in 2016 --- first cell
                     (df['lostli_16']==1)& # Absolute loss of low-income households 1996-2016 --- second cell
                    ((df['lmh_flag_encoded'] == 2)|(df['lmh_flag_encoded'] == 3)| # Housing affordable to middle, high, 
                    (df['lmh_flag_encoded'] == 5)|(df['lmh_flag_encoded'] == 6))& # mixed-moderate, and mixed-high income households in 2016 --- third cell
                     (df['change_flag_encoded'] == 3), 1, 0) # Rapid increase in housing costs --- fourth cell
                     # do not have per_limove_06 or per_limove_16
                    

df['BE'] = np.where((df['pop06flag'].isna())|
                     (df['mod_pdmt_medhhinc_16'].isna())|
                     (df['mix_mod_medhhinc_16'].isna())|
                     (df['mix_high_medhhinc_16'].isna())|
                     (df['high_pdmt_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['lostli_16'].isna())
                     #(df['per_limove_16'].isna())|
                     #(df['per_limove_06'].isna())|
                     #(df['real_mhhinc_16'].isna())|
                     #(df['real_mhhinc_06'].isna())
                     , np.nan, df['BE'])

df['BE'] = np.where((df['BE'] == 1)&((df['SAE']==1) | 
                                     (df['VHI'] == 1) |
                                     (df['ARE'] == 1) |
                                     (df['AdvG'] == 1)), 0, df['BE']) ### This is to account for double classification

####
# Begin Test
####
#print('BECOMING EXCLUSIVE')
#ax = data.plot(color = 'white')
#ax = data[~data['BE'].isna()].plot(ax = ax, column = 'BE', legend = True)
#plt.show()
#print('There are ', data['BE'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['BE']==1).sum()), 'Becoming Exclusive CT')
####
# End Test
####

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
####
# Begin Test
####
#print('Stable Moderate/Mixed Income')
#ax = data.plot(color = 'white')
#ax = data[~data['SMMI'].isna()].plot(ax = ax, column = 'SMMI', legend = True)
#plt.show()
#print('There are ', data['SMMI'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['SMMI']==1).sum()), 'Stable Moderate/Mixed Income CT')
####
# End Test
####

# ==========================================================================
# At Risk of Gentrification
# ==========================================================================

### ****ARG ****
df['ARG'] = 0
df['ARG'] = np.where((df['pop06flag']==1)&
                    ((df['low_pdmt_medhhinc_16']==1)|(df['mix_low_medhhinc_16']==1))& # Low income or mixed-low income tract in 2016 --- first cell
                    ((df['lmh_flag_encoded']==1)|(df['lmh_flag_encoded']==4))& # Housing affordable to low or mixed-low income households 2016 --- second cell
                    (df['change_flag_encoded'] == 1) & # Marginal change in housing costs, 2006-2016 --- third cell
                     #|(df['ab_90percentile_ch']==1)|(df['rent_90percentile_ch']==1))& # this was a part of OG typology
                    ((df['gent_96_06']==0) | (df['gent_06_16']==0)) & # Didn’t gentrify 1996-2006 OR 2006-2016 
                    ((df['dp_PChRent'] == 1)|(df['dp_RentGap'] == 1)) # 1) surrounding tracts saw rent increases above the regional median between 2012-2017, or 2) the difference between tract rental prices and the prices of surrounding areas in 2017 was higher than the regional median difference in rental prices between tracts (rent gap).
                    # (df['vul_gent_16']==1) # was in OG typology
                    , 1, 0)

df['ARG'] = np.where((df['pop06flag'].isna())|
                     (df['low_pdmt_medhhinc_16'].isna())|
                     (df['mix_low_medhhinc_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['rent_90percentile_ch'].isna())|
                     (df['gent_96_06'].isna())|
                     (df['vul_gent_06'].isna())|
                     (df['dp_PChRent'].isna())|
                     (df['dp_RentGap'].isna())|
                     (df['gent_06_16'].isna()), np.nan, df['ARG'])



####
# Begin Test
####
#print('AT RISK OF GENTRIFICATION')
#ax = data.plot(color = 'white')
#ax = data[~df['ARG'].isna()].plot(ax = ax, column = 'ARG', legend = True)
#plt.show()
#print('There are ', data['ARG'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['ARG']==1).sum()), 'At Risk of Gentrification CT')
####
# End Test
####

# ==========================================================================
# Early/Ongoing Gentrification
# ==========================================================================

###************* Early/ongoing gentrification **************
### ****EOG ****
df['EOG'] = 0
df['EOG'] = np.where((df['pop06flag']==1)& # pop > 500
                    ((df['low_pdmt_medhhinc_16']==1)|(df['mix_low_medhhinc_16']==1))& # Low income or mixed-low income tract in 2016 --- first cell
                     # (df['ch_per_limove_06_16']<0)& # do not have this           
                    ( 
                        (df['lmh_flag_encoded'] == 2)| # Housing affordable to moderate or
                        (df['lmh_flag_encoded'] == 5) # mixed moderate-income households in 2016
                        # (df['lmh_flag_encoded'] == 1)|  # were in OG typology
                        # (df['lmh_flag_encoded'] == 4) 
                        ) &
                    (
                        (df['change_flag_encoded'] == 2)| # Increase or 
                        (df['change_flag_encoded'] == 3)| # rapid increase in housing cost
                        #(df['ab_50pct_ch'] == 1)| # was in OG typology
                        #(df['rent_50pct_ch'] == 1) # was in OG typology
                        (df['hv_abravg_ch'] == 1)| # OR above regional avg change in home or rental values between 2006-2016 
                        (df['rent_abravg_ch'] == 1) #  rental values between 2006-2016  --- third cell
                        ) &
                     (
                        (df['gent_96_06']==1)| # Gentrified in 1996-2006 or
                        (df['gent_06_16']==1) # Gentrified in 2006-2016 --- fourth cell
                    ), 1, 0) # gentrified (includes hotmarket)

df['EOG'] = np.where((df['pop06flag'].isna())|
                     (df['low_pdmt_medhhinc_16'].isna())|
                     (df['mix_low_medhhinc_16'].isna())|
                     # (df['ch_per_limove_06_16'].isna())|
                     (df['lmh_flag_encoded'].isna())|
                     (df['change_flag_encoded'].isna())|
                     (df['gent_96_06'].isna())|
                     (df['gent_06_16'].isna())|                     
                     (df['gent_96_06_urban'].isna())|
                     (df['gent_06_16_urban'].isna())|
                     (df['ab_50pct_ch'].isna())|
                     (df['hv_abravg_ch'].isna())|
                     (df['rent_abravg_ch'].isna())|
                     (df['rent_50pct_ch'].isna()), np.nan, df['EOG'])

######
# Begin Test
######
#print('EARLY/ONGOING GENTRIFICATION')
#ax = data.plot(color = 'white')
#ax = data[~data['EOG'].isna()].plot(ax = ax, column = 'EOG', legend = True)
#plt.show()
#print('There are ', data['EOG'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['EOG']==1).sum()), 'Early/Ongoing Gentrification CT')
######
# End Test
######

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

######
# Begin Test
######
#print('ONGOING DISPLACEMENT')
#ax = data.plot(color = 'white')
#ax = data[~data['OD'].isna()].plot(ax = ax, column = 'OD', legend = True)
#plt.show()
#print('There are ', data['OD'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['OD']==1).sum()), 'Ongoing Displacement CT')
######
# End Test
######

# ==========================================================================
# Low-Income/Susceptible to Displacement
# ==========================================================================

df['LISD'] = 0
df['LISD'] = np.where((df['pop06flag'] == 1)&
                     ((df['low_pdmt_medhhinc_16'] == 1)|(df['mix_low_medhhinc_16'] == 1))& # Low or mixed low-income tract in 2016 --- first cell
                     (df['OD']!=1) & (df['ARG']!=1) & (df['EOG']!=1), 1, 0) 

######
# Begin Test
######
#print('STABLE LOW INCOME TRACTS')
#ax = data.plot(color = 'white')
#ax = data[~data['LISD'].isna()].plot(ax = ax, column = 'LISD', legend = True)
#plt.show()
#print('There are ', data['LISD'].isna().sum(), 'census tract with NaN as data')
#print('There are ',str((data['LISD']==1).sum()), 'Stable Low Income CT')
######
# End Test
######

# ==========================================================================
# Create Typology Variables for All Dummies
# ==========================================================================

df['double_counted'] = (df['LISD'].fillna(0) + df['OD'].fillna(0) + df['ARG'].fillna(0) + df['EOG'].fillna(0) +
                       df['AdvG'].fillna(0) + df['ARE'].fillna(0) + df['BE'].fillna(0) + df['SAE'] + df['VHI'] + df['SMMI'])
    
df['typology'] = np.nan
df['typology'] = np.where(df['LISD'] == 1, 1, df['typology'])
df['typology'] = np.where(df['OD'] == 1, 2, df['typology'])
df['typology'] = np.where(df['ARG'] == 1, 3, df['typology'])
df['typology'] = np.where(df['EOG'] == 1, 4, df['typology'])
df['typology'] = np.where(df['AdvG'] == 1, 5, df['typology'])
df['typology'] = np.where(df['SMMI'] == 1, 6, df['typology'])
df['typology'] = np.where(df['ARE'] == 1, 7, df['typology'])
df['typology'] = np.where(df['BE'] == 1, 8, df['typology'])
df['typology'] = np.where(df['SAE'] == 1, 9, df['typology'])
df['typology'] = np.where(df['VHI'] == 1, 10, df['typology'])
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
    if df['VHI'][i] == 1:
        categories.append('VHI')
    
    cat_i.append(str(categories))
    
df['typ_cat'] = cat_i
df.groupby('typ_cat').count()['GeoUID']
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

df.to_csv(output_path+'/typologies/'+str.lower(city_name) + '_typology_output.csv')
df.to_csv("E:\\canada_data/UDP/vancouver_typology_output.csv")
