# 📊 Data Requirements for HSR Analysis

## Required Input Files

### 1. 🦇 Hidden Species Coordinates
**File**: `data/input/Hidden_points.csv`

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `ID` | character | Unique species identifier | `"Anoura_cultrata_clade_1"` |
| `Longitude` | numeric | Decimal degrees, WGS84 | `-74.5` |
| `Latitude` | numeric | Decimal degrees, WGS84 | `-4.2` |

**Example file content**:
```csv
ID,Longitude,Latitude
Anoura_cultrata_cryptic_1,-74.5,-4.2
Anoura_cultrata_cryptic_2,-75.1,-3.8
Carollia_perspicillata_hidden_1,-76.2,-2.1
Sturnira_lilium_cryptic_1,-74.8,-3.9
