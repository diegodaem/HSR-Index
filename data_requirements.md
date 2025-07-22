# 📊 Data Requirements for HSR Analysis

## Overview

The Hidden Species Ratio (HSR) analysis requires specific input data formats to identify priority areas for hidden species. This document details all required and optional data inputs.

## Required Input Files

### 1. 🦇 Hidden Species Coordinates
**File**: `Hidden_points.csv`  
**Description**: Geographic coordinates of cryptic/hidden species occurrences  
**Format**: CSV with UTF-8 encoding  

| Column | Type | Description | Example | Required |
|--------|------|-------------|---------|----------|
| `ID` | character | Unique species identifier | `"Anoura_cultrata_clade_1"` | ✅ Yes |
| `Longitude` | numeric | Decimal degrees, WGS84 | `-74.5` | ✅ Yes |
| `Latitude` | numeric | Decimal degrees, WGS84 | `-4.2` | ✅ Yes |

**Example file content**:
```csv
ID,Longitude,Latitude
Anoura_cultrata_clade_1,-74.5,-4.2
Anoura_cultrata_clade_2,-75.1,-3.8
Lophostoma_silvicola_clade_1,-74.8,-3.9
Lophostoma_silvicola_clade_3,-76.0,-3.2
Desmodus_rotundus_clade_1,-77.2,-2.8
```

**Data specifications**:
- Coordinates must be in decimal degrees (not degrees/minutes/seconds)
- Longitude range: -180 to 180
- Latitude range: -90 to 90
- No missing values allowed in required columns
- Species IDs should be unique and descriptive

---

### 2. 🧬 All Genetic Coordinates
**File**: `All_coordinates.csv`  
**Description**: Represents the complete set of geographic coordinates for all available COI gene sequences of the target taxonomic group, obtained from GenBank and BOLD Systems.  
**Format**: CSV with UTF-8 encoding  

| Column | Type | Description | Example | Required |
|--------|------|-------------|---------|----------|
| `Longitude` | numeric | Decimal degrees, WGS84 | `-74.5` | ✅ Yes |
| `Latitude` | numeric | Decimal degrees, WGS84 | `-4.2` | ✅ Yes |

**Example file content**:
```csv
Longitude,Latitude
-74.5,-4.2
-75.1,-3.8
-76.2,-2.1
-77.0,-1.5
-74.8,-3.9
-75.5,-4.0
-76.0,-3.2
-77.2,-2.8
-75.8,-3.5
-76.5,-2.8
```

**Data specifications**:
- Should include ALL genetic sampling points (both hidden and known species)
- Same coordinate format as hidden species file
- Can contain duplicate coordinates (multiple species at same location)
- Typically larger dataset than hidden species file

---

### 3. 🗺️ Biogeographic Provinces
**Directory**: `Neotropic/` (or custom name)  
**Description**: Biogeographic boundaries as vector polygons; any regionalization can be used as needed.  
**Format**: Shapefile (.shp) or GeoPackage (.gpkg)  

**Required attributes**:
| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `Provincias` | character | Province name identifier | `"Amazonia"` |

**Spatial specifications**:
- Valid polygon geometries
- Any coordinate reference system (will be reprojected automatically)
- No overlapping polygons
- Complete coverage of study area
- Province names should be unique

**Common data sources**:
- [WWF Terrestrial Ecoregions](https://www.worldwildlife.org/publications/terrestrial-ecoregions-of-the-world)
- Morrone, J. J., Escalante, T., Rodríguez-Tapia, G., Carmona, A., Arana, M., & Mercado-Gómez, J. D. Biogeographic regionalization of the Neotropical region: New map and shapefile. Anais da Academia Brasileira de Ciências, 94, e20211167. DOI: https://doi.org/10.1590/0001-3765202220211167 (2022). 

---

### 4. 🛣️ Road Network
**Directory**: `GRIP4/` (or custom name)  
**Description**: Road infrastructure for accessibility analysis; users should clip and extract data based on their area of interest.  
**Format**: Shapefile (.shp) or GeoPackage (.gpkg)  

**Required attributes**:
| Field | Type | Description | Values |
|-------|------|-------------|--------|
| `GP_RTP` | integer | Road type classification | `1` (highways), `2` (primary roads) |

**Spatial specifications**:
- Line geometries representing road network
- Focus on major roads (highways, primary roads)
- Should cover the entire study region
- Coordinate system will be reprojected automatically

**Data source**:
- [GRIP4 Global Roads Dataset](https://www.globio.info/download-grip-dataset)

---

### 5. 🏙️ Urban Centers
**Directory**: `Cities/` (or custom name)  
**Description**: Urban centers and populated places; users should clip and extract data based on their area of interest.  
**Format**: Shapefile (.shp) or GeoPackage (.gpkg)  

**Spatial specifications**:
- Point geometries representing city locations
- Should include major cities and towns in study area
- Any attribute fields (not specifically required)
- Population data helpful but not mandatory

**Common data sources**:
- [Natural Earth Populated Places](https://www.naturalearthdata.com/)
- [GeoNames](http://www.geonames.org/)
- National statistical databases

---

### 6. 🛡️ Protected Areas
**Directory**: `WDPA_Data/` (or custom name)  
**Description**: Protected areas for accessibility analysis; users should clip and extract data based on their area of interest.  
**Format**: Shapefile (.shp) or GeoPackage (.gpkg)  

**Spatial specifications**:
- Polygon geometries representing protected area boundaries
- Should cover study region
- Any attribute fields accepted
- Multiple protected area types can be included

**Data source**:
- [World Database on Protected Areas (WDPA)](https://www.protectedplanet.net/en/thematic-areas/wdpa)

---

### 7. 👥 Human Footprint
**File**: `HF_neotropico_final.tif` (or custom name)  
**Description**: Human footprint raster for critical areas analysis; users should clip and extract data based on their area of interest.  
**Format**: GeoTIFF (.tif)  

**Specifications**:
- Raster format with numeric values
- Should cover study area extent
- Higher values = greater human impact
- Any spatial resolution (will be resampled if needed)

**Data source**:
- Theobald, D. M., Kennedy, C., Chen, B., Oakleaf, J., Baruch-Mordo, S., & Kiesecker, J. (2020). Earth transformed: detailed mapping of global human modification from 1990 to 2017. Earth System Science Data, 12(3), 1953–1972. DOI: https://doi.org/10.5194/essd-12-1953-2020 (2020). 

---

### 8. 🌡️ Climate Loss Data (Optional)
**Directory**: `Final_Areas/` (or custom name)  
**Description**: Species-specific habitat loss projections under climate change; Species and areas can be modified based on user needs.  
**Format**: Species folders containing GeoTIFF files  

**Directory structure**:
```
Loss_Areas/
├── Species_1/
│   ├── Loss_ssp245.tif
│   └── Loss_ssp585.tif
├── Species_2/
│   ├── Loss_ssp245.tif
│   └── Loss_ssp585.tif
└── Species_N/
    ├── Loss_ssp245.tif
    └── Loss_ssp585.tif
```

**File specifications**:
- `Loss_ssp245.tif`: Habitat loss under SSP2-4.5 scenario
- `Loss_ssp585.tif`: Habitat loss under SSP5-8.5 scenario
- Values typically 0-1 (proportion of habitat lost)
- Same spatial extent and resolution preferred

---

## Complete Data Directory Structure

```
data/input/
├── Hidden_points.csv                    # Required
├── All_coordinates.csv                  # Required
├── Neotropic/                          # Required 
│   ├── provinces.shp
│   ├── provinces.shx
│   ├── provinces.dbf
│   ├── provinces.prj
│   └── [other shapefile components]
├── Human_Footprint/                    # Required
│   ├── HF_neotropics
├── GRIP4/                              # Required 
│   ├── roads.shp
│   └── [associated files]
├── Cities/                             # Required 
│   ├── cities.shp
│   └── [associated files]
├── WDPA_Data/                          # Required 
│   ├── WDPA_neotropico.gpkg
│   └── [associated files]
└── Loss_Areas/                        # Optional 
    ├── Species_1/
    │   ├── Loss_ssp245.tif
    │   └── Loss_ssp585.tif
    └── [additional species folders]
```

---

## Data Validation Checklist

### ✅ Before Running Analysis

**CSV Files**:
- [ ] All required columns present with exact names
- [ ] Coordinates in decimal degrees (-180 to 180, -90 to 90)
- [ ] No missing values in required fields
- [ ] File encoding is UTF-8
- [ ] Species IDs are unique and descriptive

**Spatial Files**:
- [ ] All shapefiles have complete file sets (.shp, .shx, .dbf, .prj)
- [ ] Files load without errors in R/QGIS
- [ ] Coordinate systems are properly defined
- [ ] No invalid geometries
- [ ] Required attribute fields present

**File Paths**:
- [ ] All directories and files exist at specified locations
- [ ] File paths in configuration match actual data structure
- [ ] No special characters or spaces in file/folder names
- [ ] Read permissions available for all files

**Data Coverage**:
- [ ] All spatial layers cover the same geographic extent
- [ ] Coordinate points fall within biogeographic province boundaries
- [ ] No major gaps in spatial coverage

---

## Troubleshooting Common Issues

### CSV File Problems
```r
# Read with specific encoding
read.csv("file.csv", fileEncoding = "UTF-8")

# Check for special characters
unique(stringr::str_extract_all(data$ID, "[^A-Za-z0-9_-]"))
```

### Spatial File Problems
```r
# Test if spatial files load
library(sf)
provinces <- st_read("path/to/shapefile.shp")

# Check coordinate system
st_crs(provinces)

# Validate geometries
any(!st_is_valid(provinces))
```

### Coordinate Issues
```r
# Check coordinate ranges
summary(data$Longitude)  # Should be -180 to 180
summary(data$Latitude)   # Should be -90 to 90

# Plot coordinates for visual check
plot(data$Longitude, data$Latitude)
```

---

## Getting Help

### Support Resources
- **Example datasets**: Check `data/input/` folder in repository
- **GitHub Issues**: [Report data problems](https://github.com/YOURUSERNAME/HSR-Index/issues)
- **R Spatial Community**: [r-spatial.org](https://r-spatial.org/)

### Data Preparation Tools
- **QGIS**: Free GIS software for viewing and preparing spatial data
- **R packages**: `sf`, `terra`, `raster` for spatial data handling
- **Online converters**: For coordinate system transformations

---
Remember to check licensing requirements for each dataset and cite accordingly in your publications.
