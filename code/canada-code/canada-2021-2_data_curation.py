# ==========================================================================
# ==========================================================================
# ==========================================================================
# DATA CURATION
# ==========================================================================
# ==========================================================================
# ==========================================================================
# Note: (input needed) in title bars indicates that in order to bring in new city information 
# users must input new code in the section

# ==========================================================================
# Import Libraries
# ==========================================================================

import pandas as pd
import numpy as np
import sys
import os
from pathlib import Path
import geopandas as gpd
from shapely.geometry import Point
from pyproj import Proj
import matplotlib.pyplot as plt

pd.set_option("display.max_columns", None)
pd.set_option("display.max_rows", None)
pd.options.display.float_format = "{:.2f}".format # avoid scientific notation

home = str(Path.home())
input_path ="data/inputs/"
output_path = "data/outputs/"

city_name = "Vancouver"
# city_name = str(sys.argv[1])

# ==========================================================================
# ==========================================================================
# ==========================================================================
# Crosswalk Files
# ==========================================================================
# ==========================================================================
# ==========================================================================

# ==========================================================================
# Read Files 
# ==========================================================================

census_96 = pd.read_csv(output_path+"downloads/_" + city_name + "_96_CT_data.csv")
census_06 = pd.read_csv(output_path+"downloads/_" + city_name + "_06_CT_data.csv")
census_11 = pd.read_csv(output_path+"downloads/_" + city_name + "_11_CT_data.csv")
census_16 = pd.read_csv(output_path+"downloads/_" + city_name + "_16_CT_data.csv")

cma_96 = pd.read_csv(output_path+"downloads/_" + city_name + "_96_CMA_data.csv")
cma_06 = pd.read_csv(output_path+"downloads/_" + city_name + "_06_CMA_data.csv")
cma_11 = pd.read_csv(output_path+"downloads/_" + city_name + "_11_CMA_data.csv")
cma_16 = pd.read_csv(output_path+"downloads/_" + city_name + "_16_CMA_data.csv")

# Crosswalk files
xwalk_96_16 = pd.read_csv(input_path + "cw_96_to_16_ct.csv")
xwalk_06_16 = pd.read_csv(input_path + "cw_06_to_16_ct.csv")
xwalk_11_16 = pd.read_csv(input_path + "cw_11_to_16_ct.csv")
# ==========================================================================
# Create Crosswalk Functions / Files
# ==========================================================================    

def crosswalk_files(df, xwalk, counts, df_ctuid_source, xwalk_ctuid_source, xwalk_ctuid_target):
    # merge dataframe with xwalk file
    df_merge = df.merge(xwalk[["w", xwalk_ctuid_source, xwalk_ctuid_target]], left_on = df_ctuid_source, right_on = xwalk_ctuid_source, how="left")
    df = df_merge
    # apply interpolation weight
    for var in counts:
        df[var] = df[var]*df["w"]
    # aggregate by horizon census tracts fips
    df = df.groupby(xwalk_ctuid_target).sum().reset_index()
    df = df.rename(columns = {"GeoUID":"trtid_base",
                              "ctuid_t":"GeoUID"})  
    # drop weight column
    df = df.drop(columns = ["w"])
    return df

# Crosswalking
# --------------------------------------------------------------------------

## 1996 Census Data
df_ctuid_source = "GeoUID"
xwalk_ctuid_source = "ctuid_s"
xwalk_ctuid_target = "ctuid_t"

counts96 = census_96.columns.drop(["GeoUID", "Type", "Region Name", "Area (sq km)", "CMA_UID", "PR_UID", "CSD_UID", "CD_UID", 
                                 "v_CA1996_1627: Median household income $",
                                 "v_CA1996_1701: Average gross rent $",
                                 "v_CA1996_1704: Average owner's major payments $",
                                 "v_CA1996_1454: Median income $",
                                 "v_CA1996_1681: Average value of dwelling $",
                                 ])

census_96_xwalked = crosswalk_files(census_96, xwalk_96_16, counts96, df_ctuid_source, xwalk_ctuid_source, xwalk_ctuid_target)

## 2006 Census Data
counts06 = census_06.columns.drop(["GeoUID", "Type", "Region Name", "Area (sq km)", "CMA_UID", "PR_UID", "CSD_UID", "CD_UID", 
                                 "v_CA06_2000: Median household income $", 
                                 "v_CA06_2054: Average value of dwelling $", 
                                 "v_CA06_2050: Average gross rent $", 
                                 "v_CA06_2055: Average owner major payments $",
                                 "v_CA06_1583: Median income $"])
census_06_xwalked = crosswalk_files(census_06, xwalk_06_16, counts06, df_ctuid_source, xwalk_ctuid_source, xwalk_ctuid_target )

# 2011 Census Data
counts11 = census_11.columns.drop(["GeoUID", "Type", "Region Name", "Area (sq km)", "CMA_UID", "PR_UID", "CSD_UID", "CD_UID", 
                                 "v_CA11N_2284: Median monthly shelter costs for owned dwellings ($)", 
                                 "v_CA11N_2286: Median value of dwellings ($)"])
census_11_xwalked = crosswalk_files(census_11, xwalk_11_16, counts11, df_ctuid_source, xwalk_ctuid_source, xwalk_ctuid_target )




# ==========================================================================
# ==========================================================================
# ==========================================================================
# Variable Creation
# ==========================================================================
# ==========================================================================
# ==========================================================================

# ==========================================================================
# Setup / Read Files (inputs needed)
# ==========================================================================
# Note: Below is the Google File Drive Stream pathway for a Mac. 
# input_path = "~/git/displacement-typologies/data/inputs/"
# Use this to draw in the "input_path" variable needed below
# You will need to redesignate this path if you have a Windows 
# output_path = output_path

shp_folder = input_path+"shp/"+str.lower(city_name)+"/"
data_1996 = census_96_xwalked
data_2006 = census_06_xwalked
data_2011 = census_11_xwalked

# ==========================================================================
# Read Shapefile Data (inputs needed)
# ==========================================================================
# Note: Similar to above, add a "elif" for you city here
# Pull cartographic boundary files from here: 
# (this link is for the entirety of Canada, the files in the shp folder have already been filtered by city)
# https://www12.statcan.gc.ca/census-recensement/2011/geo/bound-limit/bound-limit-2016-eng.cfm

city_shp = gpd.read_file(shp_folder+str.lower(city_name) + ".shp")

# ==========================================================================
# Income Interpolation
# ==========================================================================

# Merge census data in single file
# --------------------------------------------------------------------------
data_1996 = data_1996.rename(columns = {"Population" : "pop_96",
                                  "Dwellings" : "dwellings_96",
                                  "Households" : "hh_96"})
data_2006 = data_2006.rename(columns = {"Population" : "pop_06",
                                  "Dwellings" : "dwellings_06",
                                  "Households" : "hh_06"})
data_2011 = data_2011.rename(columns = {"Population" : "pop_11",
                                  "Dwellings" : "dwellings_11",
                                  "Households" : "hh_11",})

census_16 = census_16.rename(columns = {"Population" : "pop_16",
                                  "Dwellings" : "dwellings_16",
                                  "Households" : "hh_16"})

all_census = census_16.merge(data_2011, left_on = "GeoUID", right_on = "GeoUID", how = "outer").merge(data_2006, left_on = "GeoUID", right_on = "GeoUID", how = "outer").merge(data_1996, on = "GeoUID", how = "outer")

# rename variables to be consistent with vast majority of this file
cma_96 = cma_96.rename(columns = {"Population" : "pop_96",
                                  "Dwellings" : "dwellings_96",
                                  "Households" : "hh_96"})
cma_06 = cma_06.rename(columns = {"Population" : "pop_06",
                                  "Dwellings" : "dwellings_06",
                                  "Households" : "hh_06"})
cma_11 = cma_11.rename(columns = {"Population" : "pop_11",
                                  "Dwellings" : "dwellings_11",
                                  "Households" : "hh_11"})

cma_16 = cma_16.rename(columns = {"Population" : "pop_16",
                                  "Dwellings" : "dwellings_16",
                                  "Households" : "hh_16"})

all_cma = cma_16.merge(cma_11, on = "GeoUID", how = "outer").merge(cma_06, on = "GeoUID", how = "outer").merge(cma_96, on = "GeoUID", how = "outer")

rename_all_cols = {

                             # Median HH income
                             "v_CA1996_1627: Median household income $":"mhhinc_96",
                             "v_CA06_2000: Median household income $":"mhhinc_06",
                             "v_CA16_2397: Median total income of households in 2015 ($)":"mhhinc_16",

                             # Median individual income
                             "v_CA1996_1454: Median income $":"miinc_96",
                             "v_CA06_1583: Median income $":"miinc_06",
                             "v_CA16_2207: Median total income in 2015 among recipients ($)":"miinc_16",

                             # Household income of all private households (20% sample data)
                             "v_CA1996_1614: Household income of all private households":"income_denom_96",
                             "v_CA06_1988: Household income in 2005 of private households - 20% sample data":"income_denom_06",
                             "v_CA16_2405: Total - Household total income groups in 2015 for private households - 100% data":"income_denom_16",

                             # Average value of dwellings
                             "v_CA1996_1681: Average value of dwelling $":"avghval_96",
                             "v_CA06_2054: Average value of dwelling $":"avghval_06",
                             "v_CA16_4896: Average value of dwellings ($)":"avghval_16",

                             # median value of dwellings
                             "v_CA11N_2286: Median value of dwellings ($)" : "mhval_11",
                             "v_CA16_4895: Median value of dwellings ($)":"mhval_16",

                             # Median monthly shelter costs for rented/owned dwellings:
                             "v_CA11N_2284: Median monthly shelter costs for owned dwellings ($)" : "mhcosts_o_11",
                             "v_CA11N_2291: Median monthly shelter costs for rented dwellings ($)" : "mhcosts_r_11",
                             "v_CA16_4900: Median monthly shelter costs for rented dwellings ($)" : "mhcosts_r_16",
                             "v_CA16_4893: Median monthly shelter costs for owned dwellings ($)" : "mhcosts_o_16",
                         
                             # Total visible minority population
                             "v_CA1996_784: Total visible minority population":"visible_minority_96",
                             "v_CA06_1303: Total visible minority population":"visible_minority_06",
                             "v_CA16_3957: Total visible minority population":"visible_minority_16",

                             # of uni educated HH
                             "v_CA1996_1356: University":"uni_hh_96",
                             "v_CA06_1254: University certificate, diploma or degree":"uni_hh_25_64_06",
                             "v_CA06_1240: University certificate, diploma or degree": "uni_hh_15_24_06",
                             "v_CA06_1268: University certificate, diploma or degree": "uni_hh_65_over_06",
                             "v_CA16_5105: Postsecondary certificate, diploma or degree":"uni_hh_16",

                             # renter HH
                             "v_CA1996_1683: Rented":"rhu_96",
                             "v_CA06_103: Rented":"rhu_06",
                             "v_CA11N_2288: Number of tenant households in non-farm, non-reserve private dwellings" : "rhu_11",
                             "v_CA16_4838: Renter":"rhu_16",

                             # owner HH
                             "v_CA1996_1682: Owned":"ohu_96",
                             "v_CA06_102: Owned":"ohu_06",
                             "v_CA11N_2281: Number of owner households in non-farm, non-reserve private dwellings": "ohu_11",
                             "v_CA16_4837: Owner":"ohu_16",

                             # population over 15, reporting education
                             # the 
                             "v_CA1996_1347: Total population 15 years and over by highest level of schooling" : "tot_15_edu_96",
                             "v_CA06_1234: Total population 15 to 24 years by highest certificate, diploma or degree - 20% sample data" : "tot_15_24_edu_06",
                             "v_CA06_1248: Total population 25 to 64 years by highest certificate, diploma or degree - 20% sample data" : "tot_25_64_edu_06",
                             "v_CA06_1262: Total population 65 years and over by highest certificate, diploma or degree - 20% sample data" : "tot_65_over_edu_06",
                             "v_CA16_5051: Total - Highest certificate, diploma or degree for the population aged 15 years and over in private households - 25% sample data" : "tot_15_edu_16",

                             # owner households spending 30% or more of its income on shelter costs
                             "v_CA1996_1705: Owner's major payments spending 30% or more of household income on shelter costs" : "o_30_pct_96",
                             "v_CA06_2056: Owner households spending 30% or more of household income on owner's major payments" : "o_30_pct_06",
                             "v_CA16_4892: % of owner households spending 30% or more of its income on shelter costs" : "o_30_pct_16",
                             
                             # tenant households spending 30% or more of its income on shelter costs
                             "v_CA1996_1702: Gross rent spending  30% or more of household income on shelter costs" : "t_30_pct_96",
                             "v_CA06_2051: Tenant-occupied households spending 30% or more of household income on gross rent" : "t_30_pct_06",
                             "v_CA16_4899: % of tenant households spending 30% or more of its income on shelter costs" : "t_30_pct_16",

                             # average monthly shelter costs for owned dwellings ($)
                             "v_CA1996_1704: Average owner's major payments $":"avg_o_shelter_96",
                             "v_CA06_2055: Average owner major payments $" : "avg_o_shelter_06",
                             "v_CA16_4894: Average monthly shelter costs for owned dwellings ($)":"avg_o_shelter_16",

                             # average monthly shelter costs for rented dwellings ($)
                             "v_CA1996_1701: Average gross rent $":"avgrent_96",
                             "v_CA06_2050: Average gross rent $" : "avgrent_06",
                             "v_CA16_4901: Average monthly shelter costs for rented dwellings ($)":"avgrent_16",

                             # total visible minority population by group
                             "v_CA06_1302: Total population by visible minority groups - 20% sample data":"visible_minority_group_06",

                             # total population in private HHs
                             "v_CA16_3954: Total - Visible minority for the population in private households - 25% sample data":"visible_minority_private_hh_16",
                             
                             # tenant one fam HH spending >30% or more of HH income on shelter
                             "v_CA06_2060: Tenant one-family households without additional persons spending 30% or more of household income on shelter costs" : "tenant_one_family_30_pct_06",
                   
                             # owner one fam HH spending >30% or more of HH income on shelter
                             "v_CA06_2063: Owner one-family households without additional persons spending 30% or more of household income on shelter costs" : "owner_one_family_30_pct_06",
                             
                             # mobility status 1 year ago:
                             "v_CA1996_1385: Total by mobility status 1 year ago" : "total_mob_96",
                             "v_CA1996_1387: Movers" : "movers_96",

                             "v_CA06_451: Total - Mobility status 1 year ago - 20% sample data":"total_mob_06",
                             "v_CA06_453: Movers":"movers_06",

                             "v_CA16_6692: Total - Mobility status 1 year ago - 25% sample data":"total_mob_16",
                             "v_CA16_6698: Movers":"movers_16",
                            
                             # buildings built pre 1960 - 2016 census only
                             "v_CA16_4862: Total - Occupied private dwellings by period of construction - 25% sample data":"old_building_denom_16",
                             "v_CA16_4863: 1960 or before":"dwellings_built_pre_1960_16",

                             # income renaming
                             # numbers refer to upper threshhold of census income categories
                             "v_CA1996_1615: Under $10,000":"I_10000_96",
                             "v_CA1996_1616: $  10,000 - $19,999":"I_20000_96",
                             "v_CA1996_1617: $  20,000 - $29,999":"I_30000_96",
                             "v_CA1996_1618: $  30,000 - $39,999":"I_40000_96",
                             "v_CA1996_1619: $  40,000 - $49,999":"I_50000_96",
                             "v_CA1996_1620: $  50,000 - $59,999":"I_60000_96",
                             "v_CA1996_1621: $  60,000 - $69,999":"I_70000_96",
                             "v_CA1996_1622: $  70,000 - $79,999":"I_80000_96",
                             "v_CA1996_1623: $  80,000 - $89,999":"I_90000_96",
                             "v_CA1996_1624: $  90,000 - $99,999":"I_100000_96",
                             "v_CA1996_1625: $100,000 and over":"I_101000_96",

                             "v_CA06_1989: Under $10,000":"I_10000_06",
                             "v_CA06_1990: $10,000 to $19,999":"I_20000_06",
                             "v_CA06_1991: $20,000 to $29,999":"I_30000_06",
                             "v_CA06_1992: $30,000 to $39,999":"I_40000_06",
                             "v_CA06_1993: $40,000 to $49,999":"I_50000_06",
                             "v_CA06_1994: $50,000 to $59,999":"I_60000_06",
                             "v_CA06_1995: $60,000 to $69,999":"I_70000_06",
                             "v_CA06_1996: $70,000 to $79,999":"I_80000_06",
                             "v_CA06_1997: $80,000 to $89,999":"I_90000_06",
                             "v_CA06_1998: $90,000 to $99,999":"I_100000_06",
                             "v_CA06_1999: $100,000 and over":"I_101000_06",
                             
                             # 2016 separates categories into 5k intervals
                             "v_CA16_2406: Under $5,000":"I_5000_16",
                             "v_CA16_2407: $5,000 to $9,999":"I_10000_16",
                             "v_CA16_2408: $10,000 to $14,999":"I_15000_16",
                             "v_CA16_2409: $15,000 to $19,999":"I_20000_16",
                             "v_CA16_2410: $20,000 to $24,999":"I_25000_16",
                             "v_CA16_2411: $25,000 to $29,999":"I_30000_16",
                             "v_CA16_2412: $30,000 to $34,999":"I_35000_16",
                             "v_CA16_2413: $35,000 to $39,999":"I_40000_16",
                             "v_CA16_2414: $40,000 to $44,999":"I_45000_16",
                             "v_CA16_2415: $45,000 to $49,999":"I_50000_16",
                             "v_CA16_2416: $50,000 to $59,999":"I_60000_16",
                             "v_CA16_2417: $60,000 to $69,999":"I_70000_16",
                             "v_CA16_2418: $70,000 to $79,999":"I_80000_16",
                             "v_CA16_2419: $80,000 to $89,999":"I_90000_16",
                             "v_CA16_2420: $90,000 to $99,999":"I_100000_16",
                             "v_CA16_2422: $100,000 to $124,999":"I_125000_16",
                             "v_CA16_2423: $125,000 to $149,999":"I_150000_16",
                             "v_CA16_2424: $150,000 to $199,999":"I_200000_16",
                             "v_CA16_2425: $200,000 and over":"I_200100_16",
                             }



all_census = all_census.rename(columns = rename_all_cols)

all_cma = all_cma.rename(columns = rename_all_cols)

all_cma.to_csv("with_colnames.csv")
## CPI indexing values

# downloaded from here: https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1810000501&pickMembers%5B0%5D=1.27&cubeTimeFrame.startYear=1995&cubeTimeFrame.endYear=2016&referencePeriods=19950101%2C20160101
# the 0 index is all, 1 is shelter

CPI = pd.read_csv("data/inputs/CPI_vancouver.csv")
CPI_95_16 = (CPI["2016"] - CPI["1995"])[1] / (2016 - 1995)
CPI_10_16 = (CPI["2016"] - CPI["2010"])[1] / (2016 - 2010)
CPI_05_16 = (CPI["2016"] - CPI["2005"])[1] / (2016 - 2005)


# Income Interpolation
# --------------------------------------------------------------------------

all_census["mhhinc_96"][all_census["mhhinc_96"]<0]=np.nan
all_census["mhhinc_06"][all_census["mhhinc_06"]<0]=np.nan
all_census["mhhinc_16"][all_census["mhhinc_16"]<0]=np.nan

# regional median income : use CMA data
rm_hhinc_96 = np.nanmedian(all_cma["mhhinc_96"])
rm_hhinc_06 = np.nanmedian(all_cma["mhhinc_06"])
rm_hhinc_16 = np.nanmedian(all_cma["mhhinc_16"])
rm_iinc_96 = np.nanmedian(all_cma["miinc_96"])
rm_iinc_06 = np.nanmedian(all_cma["miinc_06"])
rm_iinc_16 = np.nanmedian(all_cma["miinc_16"])

print(rm_hhinc_16, rm_hhinc_06, rm_hhinc_96, rm_iinc_16, rm_iinc_06, rm_iinc_96)

## Income Interpolation Function 
## This function interpolates population counts using income buckets provided by the Census
def income_interpolation (census_df, year, cutoff, minc, tot_var, var_suffix, out):

    """
        census_df : the all_census dataframe
        year: a 2 digit string indicating what year to do income interpolation
        cutoff: the cutoff for .8 / 1.2 measurements. use regional average income for now
        tot_var: a NUMBER indicating the denominator for total number of households by income bracket
        var_suffix: a string indicating what to look for in the column label. ("I" is used by default)
        out: the label for the new column with interpolated population count by income bracket
    """

    name = []
    for c in list(census_df.columns):
        if (c[0]==var_suffix):
            if c.split("_")[2]==year:
                name.append(c)
    name.append("GeoUID")
    name.append(tot_var)
    income_cat = census_df[name]
    income_group = income_cat.drop(columns = ["GeoUID", tot_var]).columns
    income_group = income_group.str.split("_")
    number = []
    for i in range (0, len(income_group)):
        number.append(income_group[i][1])
    column = []
    for i in number:
        column.append("prop_"+str(i))
        income_cat["prop_"+str(i)] = income_cat[var_suffix+"_"+str(i)+"_"+year]/income_cat[tot_var]          
    reg_avg_cutoff = cutoff*minc
    cumulative = out+str(int(cutoff*100))+"_cumulative"
    income = out+str(int(cutoff*100))+"_"+year 
    df = income_cat
    df[cumulative] = 0
    df[income] = 0
    for i in range(0,(len(number)-1)):
        a = (number[i])
        b = float(number[i+1])-0.01

        prop = str(number[i+1])
        df[cumulative] = df[cumulative]+df["prop_"+a]
        ## this is skipping inc120_16, because the regional average >= 100k, so it never passes this check
        if (out != "inc"):
            a = int(a) / 12
            b = b / 12
        if (reg_avg_cutoff>=int(a))&(reg_avg_cutoff<b):
            df[income] = ((reg_avg_cutoff - int(a))/(b-int(a)))*df["prop_"+prop] + df[cumulative] 
    df = df.drop(columns = [cumulative])
    prop_col = df.columns[df.columns.str[0:4]=="prop"] 
    df = df.drop(columns = prop_col)     
    census_df = census_df.merge (df[["GeoUID", income]], on = "GeoUID")
    return census_df

# some census tracts don"t add up to 100% by category because their total # of households is +/- 10-15 off of the summed brackets


all_census = income_interpolation (all_census, "16", 0.8, rm_hhinc_16, "income_denom_16", "I", "inc")
all_census = income_interpolation (all_census, "16", 1.2, rm_hhinc_16, "income_denom_16", "I", "inc")
all_census = income_interpolation (all_census, "06", 0.8, rm_hhinc_06, "income_denom_06", "I", "inc")
all_census = income_interpolation (all_census, "06", 1.2, rm_hhinc_06, "income_denom_06", "I", "inc")
all_census = income_interpolation (all_census, "96", 0.8, rm_hhinc_96, "income_denom_96", "I", "inc")
all_census = income_interpolation (all_census, "96", 1.2, rm_hhinc_96, "income_denom_96", "I", "inc")

all_cma = income_interpolation (all_cma, "16", 0.8, rm_hhinc_16, "income_denom_16", "I", "inc")
all_cma = income_interpolation (all_cma, "16", 1.2, rm_hhinc_16, "income_denom_16", "I", "inc")
all_cma = income_interpolation (all_cma, "06", 0.8, rm_hhinc_06, "income_denom_06", "I", "inc")
all_cma = income_interpolation (all_cma, "06", 1.2, rm_hhinc_06, "income_denom_06", "I", "inc")
all_cma = income_interpolation (all_cma, "96", 0.8, rm_hhinc_96, "income_denom_96", "I", "inc")
all_cma = income_interpolation (all_cma, "96", 1.2, rm_hhinc_96, "income_denom_96", "I", "inc")


income_col = all_census.columns[all_census.columns.str[0:2]=="I_"] 
all_census = all_census.drop(columns = income_col)

income_col_cma = all_cma.columns[all_cma.columns.str[0:2]=="I_"] 
all_cma = all_cma.drop(columns = income_col_cma)


# ==========================================================================
# Generate Income Categories 
# ==========================================================================

def income_categories (df, year, minc, hinc, geog):
    df["mhhinc_"+year] = np.where(df["mhhinc_"+year]<0, 0, df["mhhinc_"+year])  
    reg_med_inc80 = 0.8 * minc
    reg_med_inc120 = 1.2 * minc
    low = "low_80120_" + year 
    mod = "mod_80120_" + year
    high = "high_80120_" + year
    df[low] = df["inc80_" + year]
    df[mod] = df["inc120_" + year] - df["inc80_" + year]
    df[high] = 1 - df["inc120_" + year]  
    ## Low income
    df["low_pdmt_medhhinc_"+year] = np.where((df["low_80120_"+year]>=0.55)&(df["mod_80120_"+year]<0.45)&(df["high_80120_"+year]<0.45),1,0)
    ## High income
    df["high_pdmt_medhhinc_"+year] = np.where((df["low_80120_"+year]<0.45)&(df["mod_80120_"+year]<0.45)&(df["high_80120_"+year]>=0.55),1,0)
    ## Moderate income
    df["mod_pdmt_medhhinc_"+year] = np.where((df["low_80120_"+year]<0.45)&(df["mod_80120_"+year]>=0.55)&(df["high_80120_"+year]<0.45),1,0)
    ## Mixed-Low income
    df["mix_low_medhhinc_"+year] = np.where((df["low_pdmt_medhhinc_"+year]==0)&
                                                  (df["mod_pdmt_medhhinc_"+year]==0)&
                                                  (df["high_pdmt_medhhinc_"+year]==0)&
                                                  (df[hinc]<reg_med_inc80),1,0)
    ## Mixed-Moderate income
    df["mix_mod_medhhinc_"+year] = np.where((df["low_pdmt_medhhinc_"+year]==0)&
                                                  (df["mod_pdmt_medhhinc_"+year]==0)&
                                                  (df["high_pdmt_medhhinc_"+year]==0)&
                                                  (df[hinc]>=reg_med_inc80)&
                                                  (df[hinc]<reg_med_inc120),1,0)
    ## Mixed-High income
    df["mix_high_medhhinc_"+year] = np.where((df["low_pdmt_medhhinc_"+year]==0)&
                                                  (df["mod_pdmt_medhhinc_"+year]==0)&
                                                  (df["high_pdmt_medhhinc_"+year]==0)&
                                                  (df[hinc]>=reg_med_inc120),1,0)   
    df["inc_cat_medhhinc_"+year] = 0
    df.loc[df["low_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 1
    df.loc[df["mix_low_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 2
    df.loc[df["mod_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 3
    df.loc[df["mix_mod_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 4
    df.loc[df["mix_high_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 5
    df.loc[df["high_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_"+year] = 6    
    df["inc_cat_medhhinc_encoded"+year] = 0
    df.loc[df["low_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "low_pdmt"
    df.loc[df["mix_low_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "mix_low"
    df.loc[df["mod_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "mod_pdmt"
    df.loc[df["mix_mod_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "mix_mod"
    df.loc[df["mix_high_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "mix_high"
    df.loc[df["high_pdmt_medhhinc_"+year]==1, "inc_cat_medhhinc_encoded"+year] = "high_pdmt"
    df.loc[df["mhhinc_"+year]==0, "low_pdmt_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "mix_low_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "mod_pdmt_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "mix_mod_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "mix_high_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "high_pdmt_medhhinc_"+year] = np.nan
    df.loc[df["mhhinc_"+year]==0, "inc_cat_medhhinc_"+year] = np.nan
    if (geog == "ct"):
        return all_census
    elif (geog == "cma"):
        return all_cma
    else:
        return

all_census = income_categories(all_census, "16", rm_hhinc_16, "mhhinc_16", "ct")
all_census = income_categories(all_census, "06", rm_hhinc_06, "mhhinc_06", "ct")
all_census = income_categories(all_census, "96", rm_hhinc_96, "mhhinc_96", "ct")

all_cma = income_categories(all_cma, "16", rm_hhinc_16, "mhhinc_16", "cma")
all_cma = income_categories(all_cma, "06", rm_hhinc_06, "mhhinc_06", "cma")
all_cma = income_categories(all_cma, "96", rm_hhinc_96, "mhhinc_96", "cma")


all_census.groupby("inc_cat_medhhinc_06").count()["GeoUID"]
all_census.groupby("inc_cat_medhhinc_16").count()["GeoUID"]

## Percentage of low-income households - under 80% AMI
all_census ["per_all_li_96"] = all_census["inc80_96"]
all_census ["per_all_li_06"] = all_census["inc80_06"]
all_census ["per_all_li_16"] = all_census["inc80_16"]
all_cma ["per_all_li_96"] = all_cma["inc80_96"]
all_cma ["per_all_li_06"] = all_cma["inc80_06"]
all_cma ["per_all_li_16"] = all_cma["inc80_16"]

# Total low-income households - under 80% AMI
all_census["all_li_count_96"] = all_census["per_all_li_96"] * all_census["income_denom_96"]
all_census["all_li_count_06"] = all_census["per_all_li_06"] * all_census["income_denom_06"]
all_census["all_li_count_16"] = all_census["per_all_li_16"] * all_census["income_denom_16"]
all_cma["all_li_count_96"] = all_cma["per_all_li_96"] * all_cma["income_denom_96"]
all_cma["all_li_count_06"] = all_cma["per_all_li_06"] * all_cma["income_denom_06"]
all_cma["all_li_count_16"] = all_cma["per_all_li_16"] * all_cma["income_denom_16"]

len(all_census)

# ==========================================================================
# Rent, Median income, Home Value Data 
# ==========================================================================

# canadian census has averages, not medians for housing value / housing costs

# 1996
all_cma["real_avghval_96"] = all_cma["avghval_96"] * CPI_95_16
all_cma["real_avgrent_96"] = all_cma["avgrent_96"] * CPI_95_16
all_cma["real_mhhinc_96"] = all_cma["mhhinc_96"] * CPI_95_16

all_census["real_avghval_96"] = all_census["avghval_96"] * CPI_95_16
all_census["real_avgrent_96"] = all_census["avgrent_96"] * CPI_95_16
all_census["real_mhhinc_96"] = all_census["mhhinc_96"] * CPI_95_16

# 2006
all_cma["real_avghval_06"] = all_cma["avghval_06"] * CPI_05_16
all_cma["real_avgrent_06"] = all_cma["avgrent_06"] * CPI_05_16
all_cma["real_mhhinc_06"] = all_cma["mhhinc_06"] * CPI_05_16

all_census["real_avghval_06"] = all_census["avghval_06"] * CPI_05_16
all_census["real_avgrent_06"] = all_census["avgrent_06"] * CPI_05_16
all_census["real_mhhinc_06"] = all_census["mhhinc_06"] * CPI_05_16

# 2011
all_cma["real_mhval_11"] = all_cma["mval_11"] * CPI_10_16
all_cma["real_mrent_11"] = all_cma["mhcosts_r_11"] * CPI_10_16

all_census["real_mhval_11"] = all_census["mval_11"] * CPI_10_16
all_census["real_mrent_11"] = all_census["mhcosts_r_11"] * CPI_10_16

# 2016
all_cma["real_avghval_16"] = all_cma["avghval_16"]
all_cma["real_avgrent_16"] = all_cma["avgrent_16"]
all_cma["real_mhhinc_16"] = all_cma["mhhinc_16"]
all_cma["real_mhval_16"] = all_cma["mhval_16"]
all_cma["real_mrent_16"] = all_cma["mhcosts_r_16"]

all_census["real_avghval_16"] = all_census["avghval_16"]
all_census["real_avgrent_16"] = all_census["avgrent_16"]
all_census["real_mhhinc_16"] = all_census["mhhinc_16"]
all_census["real_mhval_16"] = all_census["mhval_16"]
all_census["real_mrent_16"] = all_census["mhcosts_r_16"]
# ==========================================================================
# Demographic Data 
# ==========================================================================

df = all_census

# --------------------------------------------------------------------------
## 1996 - does not have a vector in google sheets doc, though there is potentially an option in the census
df["per_visible_minority_96"] = df["visible_minority_96"]/df["pop_96"]

## 2006
df["per_visible_minority_06"] = df["visible_minority_06"]/df["pop_06"]

## 2016
df["per_visible_minority_16"] = df["visible_minority_16"]/df["pop_16"]


all_cma["per_visible_minority_96"] = all_cma["visible_minority_96"]/all_cma["pop_96"]

## 2006
all_cma["per_visible_minority_06"] = all_cma["visible_minority_06"]/all_cma["pop_06"]

## 2016
all_cma["per_visible_minority_16"] = all_cma["visible_minority_16"]/all_cma["pop_16"]


# % of owner and renter-occupied housing units
# --------------------------------------------------------------------------

# housing units, percentage of renters 
## 1996
df["hu_96"] = df["ohu_96"] + df["rhu_96"]
df["per_rent_96"] = df["rhu_96"] / df["hu_96"]

## 2006
df["hu_06"] = df["ohu_06"] + df["rhu_06"]
df["per_rent_06"] = df["rhu_06"] / df["hu_06"]

## 2016
df["hu_16"] = df["ohu_16"] + df["rhu_16"]
df["per_rent_16"] = df["rhu_16"] / df["hu_16"]

## 1996
all_cma["hu_96"] = all_cma["ohu_96"] + all_cma["rhu_96"]
all_cma["per_rent_96"] = all_cma["rhu_96"] / all_cma["hu_96"]

## 2006
all_cma["hu_06"] = all_cma["ohu_06"] + all_cma["rhu_06"]
all_cma["per_rent_06"] = all_cma["rhu_06"] / all_cma["hu_06"]

## 2016
all_cma["hu_16"] = all_cma["ohu_16"] + all_cma["rhu_16"]
all_cma["per_rent_16"] = all_cma["rhu_16"] / all_cma["hu_16"]


# % of uni educated HHs / over 25 reporting education == percent_college_educated
# --------------------------------------------------------------------------

# 1996
df["per_col_96"] = df["uni_hh_96"] / df["tot_15_edu_96"]

df["tot_15_edu_06"] = df["tot_15_24_edu_06"] + df["tot_25_64_edu_06"] + df["tot_65_over_edu_06"]

df["uni_hh_06"] = df["uni_hh_15_24_06"] + df["uni_hh_25_64_06"] + df["uni_hh_65_over_06"]
## 2006
df["per_col_06"] = df["uni_hh_06"] / df["tot_15_edu_06"] 

## 2016
df["per_col_16"] = df["uni_hh_16"] / df["tot_15_edu_16"]

# 1996
all_cma["per_col_96"] = all_cma["uni_hh_96"] / all_cma["tot_15_edu_96"]

## 2006
all_cma["tot_15_edu_06"] = all_cma["tot_15_24_edu_06"] + all_cma["tot_25_64_edu_06"] + all_cma["tot_65_over_edu_06"]
all_cma["uni_hh_06"] = all_cma["uni_hh_15_24_06"] + all_cma["uni_hh_25_64_06"] + all_cma["uni_hh_65_over_06"]
all_cma["per_col_06"] = all_cma["uni_hh_06"] / all_cma["tot_15_edu_06"]

## 2016
all_cma["per_col_16"] = all_cma["uni_hh_16"] / all_cma["tot_15_edu_16"]


# Housing units built
# --------------------------------------------------------------------------

# only in the 2016 data as well
# percent of old buildings = 1960 or before / total dwelling units

df["per_units_pre60_16"] = df["dwellings_built_pre_1960_16"] / df["old_building_denom_16"]

all_cma["per_units_pre60_16"] = all_cma["dwellings_built_pre_1960_16"] / all_cma["old_building_denom_16"]

## Percent of people who have moved who are low-income
# This function interpolates in mover population counts using income buckets provided by the Census

def income_interpolation_movein (census, year, cutoff, rm_iinc):
    # SUM EVERY CATEGORY BY INCOME
    ## Filter only move-in variables
    name = []
    for c in list(census.columns):
        if (c[0:3] == "mov") & (c[-2:]==year):
            name.append(c)
    name.append("GeoUID")
    income_cat = census[name]
    ## Pull income categories
    income_group = income_cat.drop(columns = ["GeoUID"]).columns
    number = []
    for c in name[:9]:
        number.append(c.split("_")[2])
    ## Sum move-in in last 5 years by income category, including total w/ income
    column_name_totals = []
    for i in number:
        column_name = []
        for j in income_group:
            if j.split("_")[2] == i:
                column_name.append(j)
        if i == "w":
            i = "w_income"
        income_cat["mov_tot_"+i+"_"+year] = income_cat[column_name].sum(axis = 1)
        column_name_totals.append("mov_tot_"+i+"_"+year)
    # DO INCOME INTERPOLATION
    column = []
    number = [n for n in number if n != "w"] ## drop total
    for i in number:
        column.append("prop_mov_"+i)
        income_cat["prop_mov_"+i] = income_cat["mov_tot_"+i+"_"+year]/income_cat["mov_tot_w_income_"+year]
    reg_avg_cutoff = cutoff*rm_iinc
    cumulative = "inc"+str(int(cutoff*100))+"_cumulative"
    per_limove = "per_limove_"+year
    df = income_cat
    df[cumulative] = 0
    df[per_limove] = 0
    for i in range(0,(len(number)-1)):

        a = (number[i])
        b = float(number[i+1])-0.01
        prop = str(number[i+1])
        df[cumulative] = df[cumulative]+df["prop_mov_"+a]
        if (reg_avg_cutoff>=int(a))&(reg_avg_cutoff<b):
            df[per_limove] = ((reg_avg_cutoff - int(a))/(b-int(a)))*df["prop_mov_"+prop] + df[cumulative]           
    df = df.drop(columns = [cumulative])
    prop_col = df.columns[df.columns.str[0:4]=="prop"] 
    df = df.drop(columns = prop_col)     
    col_list = [per_limove]+["mov_tot_w_income_"+year]
    census = census.merge (df[["GeoUID"] + col_list], on = "GeoUID")
    return census


# move in income interp uses regional individual income
# cannot do this for canadian data

# all_census = income_interpolation_movein(all_census, "16", 0.8, rm_iinc_16)
# all_census = income_interpolation_movein(all_census, "06", 0.8, rm_iinc_06)

len(all_census)

# ==========================================================================
# Housing Affordability Variables
# ==========================================================================  
# this was formerly pums. for canadian data, used renters / owners # of households and median monthly shelter costs for renters / owners
# to do what pums was doing 

 # divide by twelve to turn annumal median income - > monthly for comparison with median monthly shelter costs
aff_16 = rm_hhinc_16*0.3/12

all_census["rent_burdened_hh_16"] = (all_census["t_30_pct_16"] / 100) * all_census["rhu_16"]
all_census["owner_burdened_hh_16"] = (all_census["o_30_pct_16"] / 100) * all_census["ohu_16"]
all_census["pct_all_burdened_hh_16"] = (all_census["rent_burdened_hh_16"] + all_census["owner_burdened_hh_16"]) / all_census["hu_16"]

all_census["pct_low_16"] = all_census["low_80120_16"] * all_census["pct_all_burdened_hh_16"]
all_census["pct_mod_16"] = all_census["mod_80120_16"] * all_census["pct_all_burdened_hh_16"]
all_census["pct_high_16"] = all_census["high_80120_16"] * all_census["pct_all_burdened_hh_16"]


# Classifying tracts by housing afforablde by income  
# --------------------------------------------------------------------------

## Low income
all_census["predominantly_LI"] = np.where((all_census["low_80120_16"]>=0.55)&
                                        (all_census["mod_80120_16"]<0.45)&
                                        (all_census["high_80120_16"]<0.45),1,0)

## High income
all_census["predominantly_HI"] = np.where((all_census["low_80120_16"]<0.45)&
                                        (all_census["mod_80120_16"]<0.45)&
                                        (all_census["high_80120_16"]>=0.55),1,0)

## Moderate income
all_census["predominantly_MI"] = np.where((all_census["low_80120_16"]<0.45)&
                                        (all_census["mod_80120_16"]>=0.55)&
                                        (all_census["high_80120_16"]<0.45),1,0)

## Mixed-Low income
all_census["mixed_low"] = np.where((all_census["predominantly_LI"]==0)&
                               (all_census["predominantly_MI"]==0)&
                               (all_census["predominantly_HI"]==0)&
                               ((all_census["mhcosts_r_16"]<aff_16*0.6) | (all_census["mhcosts_o_16"]<aff_16*0.6)),1,0)

## Mixed-Moderate income
all_census["mixed_mod"] = np.where((all_census["predominantly_LI"]==0)&
                               (all_census["predominantly_MI"]==0)&
                               (all_census["predominantly_HI"]==0)&
                               ((all_census["mhcosts_r_16"]>=aff_16*0.6) | (all_census["mhcosts_o_16"]>=aff_16*0.6))&
                               ((all_census["mhcosts_r_16"]<aff_16*1.2) | (all_census["mhcosts_o_16"]<aff_16*1.2)),1,0)

## Mixed-High income
all_census["mixed_high"] = np.where((all_census["predominantly_LI"]==0)&
                               (all_census["predominantly_MI"]==0)&
                               (all_census["predominantly_HI"]==0)&
                               ((all_census["mhcosts_r_16"]>=aff_16*1.2) | (all_census["mhcosts_o_16"]>=aff_16*1.2)),1,0)

all_census["lmh_flag_encoded"] = 0
all_census.loc[all_census["predominantly_LI"]==1, "lmh_flag_encoded"] = 1
all_census.loc[all_census["predominantly_MI"]==1, "lmh_flag_encoded"] = 2
all_census.loc[all_census["predominantly_HI"]==1, "lmh_flag_encoded"] = 3
all_census.loc[all_census["mixed_low"]==1, "lmh_flag_encoded"] = 4
all_census.loc[all_census["mixed_mod"]==1, "lmh_flag_encoded"] = 5
all_census.loc[all_census["mixed_high"]==1, "lmh_flag_encoded"] = 6

all_census["lmh_flag_category"] = 0
all_census.loc[all_census["lmh_flag_encoded"]==1, "lmh_flag_category"] = "aff_predominantly_LI"
all_census.loc[all_census["lmh_flag_encoded"]==2, "lmh_flag_category"] = "aff_predominantly_MI"
all_census.loc[all_census["lmh_flag_encoded"]==3, "lmh_flag_category"] = "aff_predominantly_HI"
all_census.loc[all_census["lmh_flag_encoded"]==4, "lmh_flag_category"] = "aff_mix_low"
all_census.loc[all_census["lmh_flag_encoded"]==5, "lmh_flag_category"] = "aff_mix_mod"
all_census.loc[all_census["lmh_flag_encoded"]==6, "lmh_flag_category"] = "aff_mix_high"

len(all_census)

# ==========================================================================
# Setting "Market Types"
# ==========================================================================

# averages to compare across time. there is no census tract level housing data for median costs / home value

# 1996 - 2016 (averages)
all_cma["pctch_real_avghval_96_16"] = (all_cma["real_avghval_16"]-all_cma["real_avghval_96"])/all_cma["real_avghval_96"]
all_cma["pctch_real_avgrent_96_16"] = (all_cma["real_avgrent_16"]-all_cma["real_avgrent_96"])/all_cma["real_avgrent_96"]
all_census["pctch_real_avghval_96_16"] = (all_census["real_avghval_16"]-all_census["real_avghval_96"])/all_census["real_avghval_96"]
all_census["pctch_real_avgrent_96_16"] = (all_census["real_avgrent_16"]-all_census["real_avgrent_96"])/all_census["real_avgrent_96"]
ravg_pctch_real_avghval_96_16_increase = np.nanmean(all_cma["pctch_real_avghval_96_16"][all_cma["pctch_real_avghval_96_16"] > 0.05])
ravg_pctch_real_avgrent_96_16_increase = np.nanmean(all_cma["pctch_real_avgrent_96_16"][all_cma["pctch_real_avgrent_96_16"] > 0.05])



# 2006 - 2016 (averages)
all_cma["pctch_real_avghval_06_16"] = (all_cma["real_avghval_16"]-all_cma["real_avghval_06"])/all_cma["real_avghval_06"]
all_cma["pctch_real_avgrent_06_16"] = (all_cma["real_avgrent_16"]-all_cma["real_avgrent_06"])/all_cma["real_avgrent_06"]
all_census["pctch_real_avghval_06_16"] = (all_census["real_avghval_16"]-all_census["real_avghval_06"])/all_census["real_avghval_06"]
all_census["pctch_real_avgrent_06_16"] = (all_census["real_avgrent_16"]-all_census["real_avgrent_06"])/all_census["real_avgrent_06"]
ravg_pctch_real_avghval_06_16_increase = np.nanmean(all_census["pctch_real_avghval_06_16"][all_census["pctch_real_avghval_06_16"] > 0.05])
ravg_pctch_real_avgrent_06_16_increase = np.nanmean(all_census["pctch_real_avgrent_06_16"][all_census["pctch_real_avgrent_06_16"] > 0.05])

# 2011 - 2016 (medians)
all_cma["pctch_real_mhval_11_16"] = (all_cma["real_mhval_16"]-all_cma["real_mhval_11"])/all_cma["real_mhval_11"]
all_cma["pctch_real_mrent_11_16"] = (all_cma["real_mrent_16"]-all_cma["real_mrent_11"])/all_cma["real_mrent_11"]
all_census["pctch_real_mhval_11_16"] = (all_census["real_mhval_16"]-all_census["real_mhval_11"])/all_census["real_mhval_11"]
all_census["pctch_real_mrent_11_16"] = (all_census["real_mrent_16"]-all_census["real_mrent_11"])/all_census["real_mrent_11"]
rm_pctch_real_mhval_11_16_increase=np.nanmedian(all_census['pctch_real_mhval_11_16'][all_census['pctch_real_mhval_11_16']>0.05])
rm_pctch_real_mrent_11_16_increase=np.nanmedian(all_census['pctch_real_mrent_11_16'][all_census['pctch_real_mrent_11_16']>0.05])
# removed check for > .05, otherwise rent_increase is always negative since it can"t both be >= .05 and < 0
all_census = all_census.replace(np.inf, np.nan)
all_cma = all_cma.replace(np.inf, np.nan)


all_census["rent_decrease"] = np.where((all_census["pctch_real_avgrent_06_16"]<=-0.05), 1, 0)
all_census["rent_marginal"] = np.where((all_census["pctch_real_avgrent_06_16"]>-0.05)&
                                          (all_census["pctch_real_avgrent_06_16"]<0.05), 1, 0)
all_census["rent_increase"] = np.where((all_census["pctch_real_avgrent_06_16"]>=0.05)&
                                          (all_census["pctch_real_avgrent_06_16"]<ravg_pctch_real_avgrent_06_16_increase), 1, 0)
all_census["rent_rapid_increase"] = np.where((all_census["pctch_real_avgrent_06_16"]>=0.05)&
                                          (all_census["pctch_real_avgrent_06_16"]>=ravg_pctch_real_avgrent_06_16_increase), 1, 0)

all_census["house_decrease"] = np.where((all_census["pctch_real_avghval_96_16"]<=-0.05), 1, 0)
all_census["house_marginal"] = np.where((all_census["pctch_real_avghval_96_16"]>-0.05)&
                                          (all_census["pctch_real_avghval_96_16"]<0.05), 1, 0)
all_census["house_increase"] = np.where((all_census["pctch_real_avghval_96_16"]>=0.05)&
                                          (all_census["pctch_real_avghval_96_16"]<ravg_pctch_real_avghval_96_16_increase), 1, 0)
all_census["house_rapid_increase"] = np.where((all_census["pctch_real_avghval_96_16"]>=0.05)&
                                          (all_census["pctch_real_avghval_96_16"]>=ravg_pctch_real_avghval_96_16_increase), 1, 0)

all_census["tot_decrease"] = np.where((all_census["rent_decrease"]==1)|(all_census["house_decrease"]==1), 1, 0)
all_census["tot_marginal"] = np.where((all_census["rent_marginal"]==1)|(all_census["house_marginal"]==1), 1, 0)
all_census["tot_increase"] = np.where((all_census["rent_increase"]==1)|(all_census["house_increase"]==1), 1, 0)
all_census["tot_rapid_increase"] = np.where((all_census["rent_rapid_increase"]==1)|(all_census["house_rapid_increase"]==1), 1, 0)

all_census["change_flag_encoded"] = 0
all_census.loc[(all_census["tot_decrease"]==1)|(all_census["tot_marginal"]==1), "change_flag_encoded"] = 1
all_census.loc[all_census["tot_increase"]==1, "change_flag_encoded"] = 2
all_census.loc[all_census["tot_rapid_increase"]==1, "change_flag_encoded"] = 3

all_census["change_flag_category"] = 0
all_census.loc[all_census["change_flag_encoded"]==1, "change_flag_category"] = "ch_decrease_marginal"
all_census.loc[all_census["change_flag_encoded"]==2, "change_flag_category"] = "ch_increase"
all_census.loc[all_census["change_flag_encoded"]==3, "change_flag_category"] = "ch_rapid_increase"

all_census.groupby("change_flag_category").count()["GeoUID"]
len(all_census)


# ==========================================================================
# Zillow Data
# ==========================================================================

# Load Zillow Data 
# --------------------------------------------------------------------------

def filter_ZILLOW(df, FIPS):
    if (city_name not in ("Memphis", "Boston")):
        FIPS_pre = [state+county for county in FIPS]
        df = df[(df["FIPS"].astype(str).str.zfill(11).str[:5].isin(FIPS_pre))].reset_index(drop = True)
    else:
        fips_list = []
        for i in state:
            county = FIPS[str(i)]
            FIPS_pre = [str(i)+county for county in county]         
        df = df[(df["FIPS"].astype(str).str.zfill(11).str[:5].isin(FIPS_pre))].reset_index(drop = True)
    return df

## Import Zillow data
# zillow = pd.read_csv(input_path+"Zip_Zhvi_AllHomes.csv", encoding = "ISO-8859-1")
# zillow_xwalk = pd.read_csv(input_path+"TRACT_ZIP_032015.csv")

# Calculate Zillow Measures
# --------------------------------------------------------------------------

## Compute change over time
# zillow["ch_zillow_12_18"] = zillow["2018-01"] - zillow["2012-01"]*CPI_12_18



# zillow["per_ch_zillow_12_18"] = zillow["ch_zillow_12_18"]/zillow["2012-01"]
# zillow = zillow[zillow["State"].isin(state_init)].reset_index(drop = True)
# zillow = zillow_xwalk[["TRACT", "ZIP", "RES_RATIO"]].merge(zillow[["RegionName", "ch_zillow_12_18", "per_ch_zillow_12_18"]], left_on = "ZIP", right_on = "RegionName", how = "outer")
# zillow = zillow.rename(columns = {"TRACT":"FIPS"})

# Filter only data of interest
# zillow = filter_ZILLOW(zillow, FIPS)

## Keep only data for largest xwalk value, based on residential ratio
# zillow = zillow.sort_values(by = ["FIPS", "RES_RATIO"], ascending = False).groupby("FIPS").first().reset_index(drop = False)

## Compute 90th percentile change in region
percentile_90 = all_census["pctch_real_avghval_06_16"].quantile(q = 0.9)
# print(percentile_90)

# Create Flags
# --------------------------------------------------------------------------

## Change over 50% of change in region
# zillow["ab_50pct_ch"] = np.where(zillow["per_ch_zillow_12_18"]>0.5, 1, 0)

## Change over 90th percentile change
# zillow["ab_90percentile_ch"] = np.where(zillow["per_ch_zillow_12_18"]>percentile_90, 1, 0)

# merge with all_census here!!
# variables from zillow: percent change between 2012 and 2018, what fraction had a 50+ % change, what had 90+ % change


# zillow compares housing value, so do the same to assign ab_50pct_ch / ab_90percentile_ch to all_census

all_census["ab_50pct_ch"] = np.where(all_census["pctch_real_avghval_06_16"]>0.5, 1, 0)
all_census["ab_90percentile_ch"] = np.where(all_census["pctch_real_avghval_06_16"]>percentile_90, 1, 0)

# census_zillow = all_census.merge(zillow[["FIPS", "per_ch_zillow_12_18", "ab_50pct_ch", "ab_90percentile_ch"]], on = "FIPS")

## Create 90th percentile for rent - 
all_census["rent_percentile_90"] = all_census["pctch_real_avgrent_06_16"].quantile(q = 0.9)
all_census["rent_50pct_ch"] = np.where(all_census["pctch_real_avgrent_06_16"]>=0.5, 1, 0)
all_census["rent_90percentile_ch"] = np.where(all_census["pctch_real_avgrent_06_16"]>=0.9, 1, 0)

# ==========================================================================
# Calculate Regional Medians
# ==========================================================================

# Calculate medians necessary for typology designation
# --------------------------------------------------------------------------
# do cma instead


rm_per_all_li_96 = np.nanmedian(all_cma["per_all_li_96"])
rm_per_all_li_06 = np.nanmedian(all_cma["per_all_li_06"])
rm_per_all_li_16 = np.nanmedian(all_cma["per_all_li_16"])
rm_per_visible_minority_96 = np.nanmedian(all_cma["per_visible_minority_96"])
rm_per_visible_minority_06 = np.nanmedian(all_cma["per_visible_minority_06"])
rm_per_visible_minority_16 = np.nanmedian(all_cma["per_visible_minority_16"])
rm_per_col_96 = np.nanmedian(all_cma["per_col_96"])
rm_per_col_06 = np.nanmedian(all_cma["per_col_06"])
rm_per_col_16 = np.nanmedian(all_cma["per_col_16"])
ravg_per_rent_96= np.nanmean(all_cma["per_rent_96"])
ravg_per_rent_06= np.nanmean(all_cma["per_rent_06"])
ravg_per_rent_16= np.nanmean(all_cma["per_rent_16"])
ravg_real_avgrent_96 = np.nanmean(all_cma["real_avgrent_96"])
ravg_real_avgrent_06 = np.nanmean(all_cma["real_avgrent_06"])
ravg_real_avgrent_16 = np.nanmean(all_cma["real_avgrent_16"])
ravg_real_avghval_96 = np.nanmean(all_cma["real_avghval_96"])
ravg_real_avghval_06 = np.nanmean(all_cma["real_avghval_06"])
ravg_real_avghval_16 = np.nanmean(all_cma["real_avghval_16"])
rm_real_mhhinc_96 = np.nanmedian(all_cma["real_mhhinc_96"])
rm_real_mhhinc_06 = np.nanmedian(all_cma["real_mhhinc_06"])
rm_real_mhhinc_16 = np.nanmedian(all_cma["real_mhhinc_16"])

rm_real_mrent_16 = np.nanmedian(all_cma["mhcosts_r_16"])
rm_real_mhval_16 = np.nanmedian(all_cma["mhval_16"])

all_census["super_high_mhinc"] = np.where((all_census["real_mhhinc_16"] > 2 * rm_real_mhhinc_16), 1, 0)
rm_per_units_pre50_16 = np.nanmedian(all_cma["per_units_pre60_16"])

# only 2 use zillow variables
ravg_per_ch_avghval_06_16 = np.nanmean(all_cma["pctch_real_avghval_06_16"])
ravg_pctch_real_avgrent_06_16 = np.nanmean(all_cma["pctch_real_avgrent_06_16"])

## Above regional median change home value and rent
# these use zillow
all_census["hv_abravg_ch"] = np.where(all_census["pctch_real_avghval_06_16"] > ravg_per_ch_avghval_06_16, 1, 0)
all_census["rent_abravg_ch"] = np.where(all_census["pctch_real_avgrent_06_16"] > ravg_pctch_real_avgrent_06_16, 1, 0)

## Percent changes
# use census only data
all_census["pctch_real_avghval_96_06"] = (all_census["real_avghval_06"] - all_census["real_avghval_96"]) / all_census["real_avghval_96"]
all_census["pctch_real_avgrent_96_06"] = (all_census["real_avgrent_06"] - all_census["real_avgrent_96"]) / all_census["real_avgrent_96"]
all_census["pctch_real_mhhinc_96_06"] = (all_census["real_mhhinc_06"] - all_census["real_mhhinc_96"]) / all_census["real_mhhinc_96"]
# uses census only data
all_census["pctch_real_avghval_06_16"] = (all_census["real_avghval_16"] - all_census["real_avghval_06"]) / all_census["real_avghval_06"]
all_census["pctch_real_avgrent_96_16"] = (all_census["real_avgrent_16"] - all_census["real_avgrent_06"]) / all_census["real_avgrent_06"]
all_census["pctch_real_mhhinc_06_16"] = (all_census["real_mhhinc_16"] - all_census["real_mhhinc_06"]) / all_census["real_mhhinc_06"]




## Regional Medians
# variables derived from census only data
pctch_ravg_real_avghval_96_06 = (ravg_real_avghval_06-ravg_real_avghval_96)/ravg_real_avghval_96
pctch_ravg_real_avgrent_96_06 = (ravg_real_avgrent_06-ravg_real_avgrent_96)/ravg_real_avgrent_96
pctch_ravg_real_avgrent_96_16 = (ravg_real_avgrent_16-ravg_real_avgrent_96)/ravg_real_avgrent_96

pctch_ravg_real_avghval_06_16 = (ravg_real_avghval_16-ravg_real_avghval_06)/ravg_real_avghval_06
pctch_ravg_real_avgrent_06_16 = (ravg_real_avgrent_16-ravg_real_avgrent_06)/ravg_real_avgrent_06
pctch_rm_real_mhhinc_96_06 = (rm_real_mhhinc_06-rm_real_mhhinc_96)/rm_real_mhhinc_96
pctch_rm_real_mhhinc_06_16 = (rm_real_mhhinc_16-rm_real_mhhinc_06)/rm_real_mhhinc_06

## Absolute changes
# census only
all_census["ch_all_li_count_96_06"] = all_census["all_li_count_06"]-all_census["all_li_count_96"]
all_census["ch_all_li_count_06_16"] = all_census["all_li_count_16"]-all_census["all_li_count_06"]
all_census["ch_all_li_count_96_16"] = all_census["all_li_count_16"]-all_census["all_li_count_96"]
all_census["ch_per_col_96_06"] = all_census["per_col_06"]-all_census["per_col_96"]
all_census["ch_per_col_06_16"] = all_census["per_col_16"]-all_census["per_col_06"]


# need low income mover data for this
# all_census["ch_per_limove_06_16"] = all_census["per_limove_16"] - all_census["per_limove_06"]

## Regional Medians
# census only
ch_rm_per_col_96_06 = rm_per_col_06-rm_per_col_96
ch_rm_per_col_06_16 = rm_per_col_16-rm_per_col_06

# Calculate flags
# --------------------------------------------------------------------------
# census only
df = all_census
df["pop06flag"] = np.where(df["pop_06"]>400, 1, 0)
df["aboverm_per_all_li_96"] = np.where(df["per_all_li_96"]>=rm_per_all_li_96, 1, 0)
df["aboverm_per_all_li_06"] = np.where(df["per_all_li_06"]>=rm_per_all_li_06, 1, 0)
df["aboverm_per_all_li_16"] = np.where(df["per_all_li_16"]>=rm_per_all_li_16, 1, 0)
df["aboverm_per_visible_minority_16"] = np.where(df["per_visible_minority_16"]>=rm_per_visible_minority_16, 1, 0)
df["aboverm_per_visible_minority_96"] = np.where(df["per_visible_minority_96"]>=rm_per_visible_minority_96, 1, 0)
df["aboverm_per_visible_minority_06"] = np.where(df["per_visible_minority_06"]>=rm_per_visible_minority_06, 1, 0)
df["aboveravg_per_rent_96"] = np.where(df["per_rent_96"]>=ravg_per_rent_96, 1, 0)
df["aboveravg_per_rent_06"] = np.where(df["per_rent_06"]>=ravg_per_rent_06, 1, 0)
df["aboveravg_per_rent_16"] = np.where(df["per_rent_16"]>=ravg_per_rent_16, 1, 0)
df["aboverm_per_col_96"] = np.where(df["per_col_96"]>=rm_per_col_96, 1, 0)
df["aboverm_per_col_06"] = np.where(df["per_col_06"]>=rm_per_col_06, 1, 0)
df["aboverm_per_col_16"] = np.where(df["per_col_16"]>=rm_per_col_16, 1, 0)
df["aboveravg_real_avgrent_96"] = np.where(df["real_avgrent_96"]>=ravg_real_avgrent_96, 1, 0)
df["aboveravg_real_avgrent_06"] = np.where(df["real_avgrent_06"]>=ravg_real_avgrent_06, 1, 0)
df["aboveravg_real_avgrent_16"] = np.where(df["real_avgrent_16"]>=ravg_real_avgrent_16, 1, 0)
df["aboveravg_real_avghval_96"] = np.where(df["real_avghval_96"]>=ravg_real_avghval_96, 1, 0)
df["aboveravg_real_avghval_06"] = np.where(df["real_avghval_06"]>=ravg_real_avghval_06, 1, 0)
df["aboveravg_real_avghval_16"] = np.where(df["real_avghval_16"]>=ravg_real_avghval_16, 1, 0)

df["aboverm_real_mrent_16"] = np.where(df["mhcosts_r_16"]>=rm_real_mrent_16, 1, 0)
df["aboverm_real_mhval_16"] = np.where(df["mhval_16"]>=rm_real_mhval_16, 1, 0)


df["aboveravg_pctch_real_avghval_06_16"] = np.where(df["pctch_real_avghval_06_16"]>=pctch_ravg_real_avghval_06_16, 1, 0)
df["aboveravg_pctch_real_avgrent_96_16"] = np.where(df["pctch_real_avgrent_96_16"]>=pctch_ravg_real_avgrent_96_16, 1, 0)
df["aboveravg_pctch_real_avgrent_06_16"] = np.where(df["pctch_real_avgrent_06_16"]>=pctch_ravg_real_avgrent_06_16, 1, 0)
df["aboveravg_pctch_real_avghval_96_06"] = np.where(df["pctch_real_avghval_96_06"]>=pctch_ravg_real_avghval_96_06, 1, 0)
df["aboveravg_pctch_real_avgrent_96_06"] = np.where(df["pctch_real_avgrent_96_06"]>=pctch_ravg_real_avgrent_96_06, 1, 0)
df["lostli_06"] = np.where(df["ch_all_li_count_96_06"]<0, 1, 0)
df["lostli_16"] = np.where(df["ch_all_li_count_96_16"]<0, 1, 0)
df["aboverm_pctch_real_mhhinc_96_06"] = np.where(df["pctch_real_mhhinc_96_06"]>pctch_rm_real_mhhinc_96_06, 1, 0)
df["aboverm_pctch_real_mhhinc_06_16"] = np.where(df["pctch_real_mhhinc_06_16"]>pctch_rm_real_mhhinc_06_16, 1, 0)
df["aboverm_ch_per_col_96_06"] = np.where(df["ch_per_col_96_06"]>ch_rm_per_col_96_06, 1, 0)
df["aboverm_ch_per_col_06_16"] = np.where(df["ch_per_col_06_16"]>ch_rm_per_col_06_16, 1, 0)
df["aboverm_per_units_pre60_16"] = np.where(df["per_units_pre60_16"]>rm_per_units_pre50_16, 1, 0)


# ==========================================================================
# Merge Census and Zillow Data 
# ==========================================================================
# city_shp["CTUID"] = city_shp["CTUID"].astype(str).str[:7]
# city_shp["CTUID"] = city_shp["CTUID"].astype("int64")
# city_shp = city_shp.rename(columns = {"CTUID" : "GeoUID"})

# all_census = all_census.merge(city_shp[["GeoUID","geometry"]])
# census_zillow.query("FIPS == 13121011100")
# ==========================================================================
# Export Data 
# ==========================================================================
all_census.to_csv("E:\\canada_data/UDP/vancouver_database_2016.csv")

all_census.to_csv("data/outputs/databases/vancouver_database_2016.csv")


# pq.write_table(output_path+"downloads/"+city_name.replace(" ", "")+"_database.parquet")
