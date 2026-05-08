# HSR Index 
## Hidden Species Richness Index

![R](https://img.shields.io/badge/R-%23276DC3.svg?style=flat&logo=r&logoColor=white)
![GitHub issues](https://img.shields.io/github/issues/diegodaem/HSR-Index)

### 🔬 Research Context
**Paper**: Esquivel, D.A., Penagos, A., Feijó, A., Ramos Pereira, M. (2026). Racing Against Time to Unveil Hidden Bat Diversity in the Neotropics. Submitted to "Nature Communications" 

---

## 📋 Description

The **Hidden Species Richness (HSR) Index** is a quantitative framework designed to identify biogeographic areas with the highest potential for hidden species discovery. By integrating biodiversity and accessibility factors, the HSR offers a data-driven tool to guide field surveys and taxonomic research. When combined with ecological niche models and variables representing human-induced landscape modification, the HSR helps pinpoint regions of critical importance for unveil hidden diversity. The model is flexible and can be adapted for any taxonomic group, across all biomes and ecosystems globally.

### Key Features
- **Priority Region Identification**: Identifies biogeographic provinces with highest potential for undiscovered species
- **Sampling Bias Correction:** Adjusts for uneven genetic sampling across regions
- **Accessibility analysis**: Considers geographic and logistical access constraints
- **Geographic Scalability**: Province-based analysis easily adaptable to any biogeographic regionalization
- **Climate Integration**: Optional critical areas mapping incorporating human footprint and species loss projections
- **Automated Workflow**: Single-command execution with organized outputs (maps, tables, rasters)

---

## 🚀 Quick Start

### Prerequisites
- **R** ≥ 4.3.0 (recommended: R 4.5.0)
- **RStudio** (optional but recommended)
- **4GB RAM minimum** (16GB+ recommended for large datasets)

### Installation

1. **Download this repository**
   ```bash
   # Download ZIP
   # Click green "Code" button → "Download ZIP"
   
     ```
2. **Open R/RStudio from the HSR-Index/ directory**
   - Navigate to the extracted HSR-Index/ folder
   - Set this as your working directory
   - You should see four folders: auxiliary scripts/ data/, docs/, output/

   **Large Files Notice:**
   Some large datasets used in this repository exceed GitHub's file size limits and are **not included directly in the repository**. To access these files:
   - Go to the following Google Drive folder:  
   **🔗 [https://drive.google.com/drive/folders/1kB37m4OioDumWwPyu8Mxe2gZpvDKtGok?usp=drive_link]**
   - Download the required file(s).
   - **Manually place each downloaded file in the appropriate subfolder** as described in this file.  
   For example:  
   - `WDPA_neotropico.gpkg` → `data/input/WDPA_Data/`  
   - `roads.shp` and associated files → `data/input/GRIP4/`

   Please **preserve the folder structure** to ensure the scripts run properly. See structure below
     
3. **Install R dependencies**
   ```r
   # Automatically install all required packages
   source("install_dependencies.R")
   ```

4. **Prepare your data**
   - Read [`data_requirements.md`](data/data_requirements.md) for detailed format specifications
   - Use files in [`data/input/`](data/input/) as templates
   - Replace your data in `data/input/` following the structure

5. **Run the analysis**
   ```r
   # Execute main HSR analysis
   source("HSR_index.R")
   ```

### Expected Runtime
- **Small datasets** (<1,000 geographic coordinates): 30-60 minutes
- **Medium datasets** (1,000-10,000 geographic coordinates): 2-3 hours  
- **Large datasets** (>10,000 geographic coordinates): 3-5 hours

---

## 📊 Methodology

### HSR Formula

The core HSR calculation combines multiple factors:

```
HSR = (S_hidden / log(N_sequences + 1)) × (1 + w₁×Z_accessibility + w₂×Z_size)
```

**Parameters**:
- `S_hidden`: Number of hidden species in province i
- `N_sequences`: Total genetic sequences in province i
- `Z_accessibility`: Standardized accessibility score (roads, cities, protected areas)
- `Z_size`: Standardized province area score
- `w₁, w₂`: Adjustment weights (default: 0.2 each)

### Critical Areas Integration
Optionally, combine HSR with additional layers:

```
Critical_Areas = α×HSR + β×Human_Footprint + γ×Climate_Loss
```

Default weights: α=0.33, β=0.34, γ=0.33

### Expected results
- Priority Map: Shows which regions need urgent actions
- Province Rankings: List of areas ranked by discovery potential
- HSR Raster: High-resolution spatial data for GIS integration and further analysis
- Accessibility Profiles: Distance analysis tables for roads, cities, and protected areas by province
- Critical Areas Maps: Combined risk assessment including climate change impacts

---

## 📁 Repository Structure

```
HSR-Index/
├── 📄 README.md                    # This documentation
├── 📄 LICENSE                      # MIT License
├── 📄 .gitignore                   # Git ignore rules
├── 💻 HSR_index.R                  # Main script
├── 💻 install_dependencies.R       # Dependencies
├── 📁 auxiliary scripts/          
│   ├── 💻 genbi.py                 # Python script to download genetic data
│   ├── 💻 Priorization.py          # Python script for species prioritization
├── 📁 docs/                        # Additional documentation
│   ├── methodology.md              # Detailed methodology
├── 📁 data/                        
│   ├── 📄 data_requirements.md     # Data format specifications
│   ├── 📁 input/                   # Datasets
│   │   ├── Hidden_points.csv
│   │   ├── All_coordinates.csv
│   │   ├── 📁 Neotropic/           # Neotropical provinces used for analyses. Users can replace with their own regionalization.
│   │   │   ├── provinces.shp
│   │   │   ├── provinces.shx
│   │   │   ├── provinces.dbf
│   │   │   ├── provinces.prj
│   │   │   └── ... [associated files]
│   │   ├── 📁 Human_Footprint/    # Data from Theobald et al. (2020). Users may clip the raster layer to match their area of interest.
│   │   │   └── HF_neotropics.tif
│   │   ├── 📁 GRIP4/              # Data from Meijer et al. (2018). Users may clip the shp. layer to match their area of interest.
│   │   │   ├── roads.shp           
│   │   │   └── ... [associated files]  
│   │   ├── 📁 Cities/             # Data from geonames.org. Users may clip the shp. layer to match their area of interest.
│   │   │   └── cities.shp
│   │   │   └── ... [associated files]          
│   │   ├── 📁 WDPA_Data/          # Data from World Database on Protected Areas. Users may clip the raster layer to match their area of interest.
│   │   │   └── WDPA_neotropico.gpkg
│   │   │   └── ... [associated files] 
│   │   ├── 📁 Loss_Areas/         # Users must load the "area loss" files for each species.
│   │   │   ├── 📁 Species_1/
│   │   │   │   ├── Loss_ssp245.tif
│   │   │   │   └── Loss_ssp585.tif
│   │   │   ├── 📁 Species_2/
│   │   │   │   ├── Loss_ssp245.tif
│   │   │   │   └── Loss_ssp585.tif
│   │   │   └── 📁 Species_N/
│   │   │       ├── Loss_ssp245.tif
│   │   │       └── Loss_ssp585.tif
├── 📁 output/                      # Generated results
│   ├── 📊 figures/                 # Maps and plots
│   ├── 📋 tables/                  # CSV results
│   └── 🗺️ rasters/                # Spatial outputs
---
```
## 🔧 System Requirements

### Software Dependencies
| Package | Version | Purpose |
|---------|---------|---------|
| `sf` | ≥1.0.0 | Spatial data handling |
| `dplyr` | ≥1.0.0 | Data manipulation |
| `tidyr` | ≥1.0.0 | Data tidying |
| `ggplot2` | ≥3.0.0 | Data visualization |
| `terra` | ≥1.6.0 | Raster operations |
| `raster` | ≥3.0.0 | Legacy raster support |
| `units` | ≥0.8.0 | Unit conversions |
| `gridExtra` | ≥2.3 | Plot arrangements |

### Hardware Recommendations
- **CPU**: Multi-core processor (4+ cores recommended)
- **RAM**: 4GB minimum, 16GB+ recommended
- **Storage**: 4GB+ free space for data and outputs
- **OS**: Windows 10+, macOS 10.14+, or Linux (Ubuntu 18.04+)

---

## 📖 Documentation

### Quick References
- **[📊 Data Requirements](data/data_requirements.md)**: Complete data format specifications
- **[🔬 Methodology](docs/methodology.md)**: Scientific background and mathematical details

---
## 🔬 Scientific Applications

### Use Cases

**Conservation & Planning**
- **Biodiversity Hotspot Identification**: Prioritize regions with highest potential for species discovery
- **Conservation Resource Allocation**: Guide funding decisions for maximum biodiversity protection impact
- **Protected Area Expansion**: Identify underrepresented regions for new conservation zones

**Scientific Research**
- **Targeted Field Expeditions**: Optimize survey locations to maximize discovery potential while minimizing costs
- **Taxonomic Research Direction**: Focus systematic biology efforts on provinces with highest hidden diversity
- **Sampling Strategy Design**: Balance accessibility constraints with scientific discovery potential

**Climate & Risk Assessment**
- **Climate Vulnerability Mapping**: Identify regions where hidden species face highest extinction risk

**Policy & Management**
- **International Collaboration**: Identify cross-border priority regions for joint conservation efforts

---

## 📝 Citation

### Primary Citation
When using the HSR Index, please cite:

```bibtex
@article{esquivel2025hsr,
  title={Racing Against Time to Unveil Hidden Bat Diversity},
  author={Esquivel, Diego A.},
  journal={Nature Communications},
  volume={XX},
  number={XX},
  pages={eXXXXXXX},
  year={2025},
  publisher={XXX},
  doi={XXX}
}
```

## 🤝 Contributing

We welcome contributions from the research community!

### Ways to Contribute
- **🐛 Bug Reports**: [Open an issue](../../issues) for bugs or unexpected behavior
- **💡 Feature Requests**: Suggest new functionality or improvements
- **📖 Documentation**: Help improve documentation and examples
- **🔬 Validation**: Share results from new taxonomic groups or regions
- **💻 Code**: Submit pull requests for bug fixes or enhancements

## 🆘 Support & Troubleshooting

### Common Issues
- **Spatial data loading errors**: Check coordinate systems and file integrity
- **Memory issues**: Consider processing smaller regions or using more RAM
- **Long computation times**: Enable parallel processing in configuration

### Getting Help
1. **Check existing issues**: Browse [GitHub Issues](../../issues) for similar problems
2. **Review documentation**: Consult detailed guides in the `docs/` folder
3. **Create new issue**: Provide detailed error messages and system information

### Issue Template
When reporting bugs, please include:
- R version and operating system
- Complete error messages
- Minimal reproducible example
- Session information (`sessionInfo()`)

---

## 📊 Performance Benchmarks

### Computation Times (approximate)
| Dataset Size | Provinces | geographic coordinates | Runtime | RAM Usage |
|--------------|-----------|-----------|---------|-----------|
| Small | 10-50 | <1,000 | 30-60 min | 2-3 GB |
| Medium | 50-100 | 1,000-10,000 | 2-3 hours | 4-8 GB |
| Large | 100+ | 10,000-20,000 | 3-5 hours | 8-16 GB |

*Times measured on Intel i7 processor with 16GB RAM*

### Optimization Tips
- Enable parallel processing for distance calculations
- Use SSD storage for large raster datasets
- Consider cloud computing for very large analyses
- Process regions separately for continental-scale studies

---

## 🌍 Global Applications

### Adaptability
While developed for Neotropical bats, the HSR framework can be adapted for:
- **Other taxonomic groups**: Mammals, birds, reptiles, insects
- **Different regions**: Any biogeographic classification system
- **Various scales**: Local, regional, or continental analyses
- **Time periods**: Historical or future projections

### International Collaborations
We encourage researchers worldwide to:
- Apply HSR to their study systems
- Share methodological improvements
- Contribute validation datasets
- Develop regional case studies

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

### License Summary
- ✅ **Commercial use**
- ✅ **Modification**  
- ✅ **Distribution**
- ✅ **Private use**
- ❗ **License and copyright notice required**
- ❌ **No warranty**

---

## 📧 Contact

**Diego A. Esquivel**  
📧 **Email**: diegodaem@gmail.com 
🏛️ **Institution**: Universidade Federal do Rio Grande do Sul 
🔗 **ORCID**: (https://orcid.org/0000-0001-7098-4517)  
🔬 **ResearchGate**: [Diego A. Esquivel](https://www.researchgate.net/profile/Diego-Esquivel-2)

---

## 🏆 Acknowledgments

### Funding
- Coordenação de Aperfeiçoamento de Pessoal de Nível Superior, Brazil – (CAPES)
- The Field Museum Science Scholarships Program
- Bat Conservation International
- The Rufford Foundation
- Graduate Student Research Awards, The Society of Systematic Biologists

---

**⭐ Star this repository if you find it useful for your research!**

**🔄 Share it with colleagues working on biodiversity and systematics!**

---

*Last updated: [07/21/2025]*  
*Version: 1.0.0*
