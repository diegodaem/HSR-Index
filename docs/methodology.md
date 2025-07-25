# Methodology - Hidden Species Richness (HSR) Index

## Overview

Accurately estimating undescribed species richness remains a fundamental challenge in biodiversity science, particularly when sampling efforts are unevenly distributed across geographic regions. The HSR index addresses this problem by standardizing hidden diversity estimates across biogeographic provinces while correcting for systematic biases in genetic data collection. When integrated with ecological niche models (ENMs) and rasters of human-induced landscape modification, the HSR framework enables identification of hidden diversity hotspots where conservation urgency intersects with high discovery potential, allowing researchers to prioritize taxonomic efforts in regions where new species are most likely yet face immediate threats.

## HSR Formula

```
HSR = (S_hidden / log(N_sequences + 1)) × (1 + w₁×Z_accessibility + w₂×Z_size)
```

### Parameters:
- **S_hidden**: Number of hidden species in province i
- **N_sequences**: Total genetic sequences in province i  
- **Z_accessibility**: Standardized accessibility score (roads, cities, protected areas)
- **Z_size**: Standardized province area score
- **w₁, w₂**: Adjustment weights (default: 0.2 each)

## Biological Rationale

### 1. Core Ratio: S_hidden / log(N_sequences + 1)
- **Numerator**: Raw count of potential undescribed species identified through molecular delimitation
- **Denominator**: Logarithmic transformation controls bias from unequal sampling effort between regions
- Genetic sampling varies dramatically due to proximity to research institutions, accessibility, and funding

### 2. Accessibility Correction: w₁×Z_accessibility  
Remote, inaccessible areas are systematically under-sampled, creating "accessibility bias." Our correction acknowledges that low sequence counts in remote areas likely reflect logistical challenges rather than low diversity. The accessibility metric considers distances to:
- Major road networks (GRIP4 data)
- Urban centers (>10,000 population)
- Protected areas

### 3. Size Correction: w₂×Z_size
Based on the species-area relationship - larger provinces typically support more species due to:
- Greater habitat heterogeneity
- More ecological niches
- Higher probability of geographic barriers promoting speciation
- Greater potential for sampling gaps

## Implementation Details

### Species Delimitation
- **Methods**: Consensus approach using 4 algorithms (ABGD, ASAP, GMYC, bPTP)
- **Genetic marker**: Cytochrome Oxidase I (COI) 
- **Consensus rule**: Hidden species identified when ≥3 algorithms agree
- **Data source**: GenBank and BOLD Systems sequences

### Parameter Calibration
- **Weights (w₁, w₂)**: Determined through sensitivity analysis across 80+ parameter combinations
- **Normalization**: Median Absolute Deviation (MAD) for robust Z-score calculation
- **Transformation**: Log transformation applied to accessibility and size metrics

### Spatial Analysis
- **Framework**: Morrone's Neotropical biogeographic provinces
- **Coordinate system**: WGS84, with reprojection as needed
- **Distance calculations**: Haversine formula for geographic distances
- **Assignment method**: Spatial intersection with nearest-province fallback

### Climate Integration
- **Scenarios**: SSP245 (moderate) and SSP585 (severe) to 2070
- **Modeling**: Ecological niche models using MaxEnt
- **Variables**: WorldClim bioclimatic variables (selected for low correlation)
- **Validation**: Partial ROC and omission rate metrics

### Critical Areas Calculation
Combined layers with weights:
- HSR Index: 33%
- Human footprint (Theobald et al. 2020): 34% 
- Climate habitat loss: 33%

## Example Applications

### Case 1: Accessibility Impact
**Province A** (accessible): 5 hidden species, 3,000 sequences → HSR = 0.48  
**Province B** (remote): 5 hidden species, 30 sequences → HSR = 2.12  
**Result**: Same diversity count, but Province B receives 4.4× higher priority

### Case 2: Size Effect  
**Small Province**: 10 hidden species, 500 sequences → HSR = 1.29  
**Large Province**: 10 hidden species, 500 sequences → HSR = 1.93  
**Result**: Large province receives 50% higher score, suggesting more undiscovered diversity

## Limitations and Assumptions

- **Single-gene approach**: COI alone may miss some cryptic diversity
- **Sampling bias**: Not all biases are fully corrected by accessibility metrics
- **Relative estimates**: HSR provides comparative rather than absolute diversity estimates  
- **Geographic boundaries**: Province assignments may not reflect true species distributions
- **Temporal assumptions**: Current sampling patterns assumed representative

## Data Requirements

- **Minimum sequences**: No hard threshold, but provinces with <10 sequences have high uncertainty
- **Missing data**: Provinces without genetic sequences are excluded from analysis

## Reference

For complete methodological details and biological context, see:  
Esquivel, D.A., Penagos, A., Feijó, A., Ramos Pereira, M. (2025). Racing Against Time to Unveil Hidden Bat Diversity. *Nature Communications*.
