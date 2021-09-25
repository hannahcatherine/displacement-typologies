# Code processing outline

Currently, the Canadian typology is set up for:

* Vancouver
* Toronto

Each of the files are named in order of operation. To run the code, navigate to the folder that contains the scripts (for now, canada-code) do the following in a terminal window.  

```
Rscript canada-2021-1-data-download.R CityName CensusLevel Year
```
(for example, Rscript canada-2021-1-data-download.R Vancouver CT 2006 would download and save the census tract data for Vancouver in 2006)
python3 2021-2_data-curation.py CityName

```
Rscript sparcc-2017-3-create-lag-vars.r CityName
python3 sparcc-2017-4-typology.py CityName
Rscript sparcc-2017-5-SPARCC-Maps.r CityName
```
Downloading external datasets:

While much of the data used in this methodology is pulled from the CensusMapper API, 
others will need to be downloaded separately, as follows:

**Vancouver:**
    Visit the URL http://www.metrovancouver.org/data

    The overlays used were: Frequent Transit Development Areas
                            2015 Industrial Land Inventory 
                            Metro Vancouver Regional Parks – Park Boundaries
                            Non-market housing
**Toronto: TBD**
    likely will be used: https://www.toronto.ca/city-government/data-research-maps/open-data/