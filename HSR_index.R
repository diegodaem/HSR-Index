# HSR Index Analysis - Main Script
# Esquivel et al. (2025) Nature Communications
# Script of "Racing Against Time to Unveil Hidden Bat Diversity"

#---------- 1. PACKAGE LOADING ----------
library(sf)
library(dplyr)
library(tidyr)
library(units)
library(ggplot2)
library(readr)
library(terra)
library(tidyverse)
library(raster)
library(gridExtra)

#---------- 2. SET WORKING DIRECTORIES AND DATA ----------
# Set project root directory 
root_dir <- getwd()  # Current working directory should be HSR-Index/
print(paste("Project root:", root_dir))

# Create output directories
dir.create(file.path(root_dir, "output", "figures"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "output", "tables"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(root_dir, "output", "rasters"), recursive = TRUE, showWarnings = FALSE)

# CSV with hidden species occurrences
hidden_points <- read.csv(file.path(root_dir, "data", "input", "Hidden_points.csv"))

# CSV with all coordinates of genetic sequences
all_coordinates <- read.csv(file.path(root_dir, "data", "input", "All_coordinates.csv"))

# Shapefile biogeographic provinces
provinces <- st_read(file.path(root_dir, "data", "input", "Neotropic"), quiet = TRUE)

# Roads infrastructure data
roads <- st_read(file.path(root_dir, "data", "input", "GRIP4"), quiet = TRUE) %>% 
  filter(GP_RTP %in% c(1, 2))

# Cities locations
cities <- st_read(file.path(root_dir, "data", "input", "Cities"), quiet = TRUE)

# Protected areas
pas_raw <- st_read(file.path(root_dir, "data", "input", "WDPA_Data", "WDPA_neotropico.gpkg"), quiet = TRUE)
pas <- pas_raw %>% st_make_valid() %>% st_buffer(0)

cat("=== LOADING INPUT DATA ===\n")
cat("✓ Hidden species occurrences:", nrow(hidden_points), "\n")
cat("✓ Genetic coordinates:", nrow(all_coordinates), "\n")
cat("✓ Provinces loaded:", nrow(provinces), "\n")
cat("✓ Roads loaded:", nrow(roads), "\n")
cat("✓ Cities loaded:", nrow(cities), "\n")
cat("✓ Protected areas loaded:", nrow(pas), "\n")

cat("=== STARTING THE HIDDEN SPECIES RICHNESS INDEX ===\n")

#---------- 3. CALCULATE HIDDEN SPECIES PER BIOGEOGRAPHIC PROVINCE ----------
cat("=== ✓ Counting hidden species per province ===\n")

# Fix invalid geometries and prepare provinces
provinces <- provinces[, "Provincias", drop = FALSE]
provinces <- st_make_valid(provinces)

# Convert points to spatial format
hidden_points_sf <- hidden_points %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)

# Ensure same CRS
provinces <- st_transform(provinces, st_crs(hidden_points_sf))

# Assign points to provinces
point_province_assignment <- st_within(hidden_points_sf, provinces)
province_indices <- sapply(point_province_assignment, function(x) if(length(x) > 0) x[1] else NA)
province_names <- ifelse(is.na(province_indices), NA, provinces$Provincias[province_indices])

# Create assignment dataframe
points_assigned <- data.frame(
  ID = hidden_points_sf$ID,
  Provincias = province_names,
  stringsAsFactors = FALSE
)

# Count unique species per province
species_by_province <- points_assigned %>%
  filter(!is.na(Provincias)) %>%
  distinct(ID, Provincias) %>%
  group_by(Provincias) %>%
  summarize(
    num_hidden_species = n(),
    species_list = paste(sort(ID), collapse = ", "),
    .groups = 'drop'
  )

# Display top provinces
print("Top 10 Provinces Rich in hidden Species:")
print(species_by_province %>% arrange(desc(num_hidden_species)) %>% head(10))

# Save results
write.csv(species_by_province, file.path(root_dir, "output", "tables", "hidden_species_by_province.csv"), row.names = FALSE)

# Convert all genetic sequences to spatial format
all_points_sf <- all_coordinates %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)

# Ensure same CRS
all_points_sf <- st_transform(all_points_sf, st_crs(provinces))

# Assign all sequences to provinces
all_point_assignment <- st_within(all_points_sf, provinces)
all_province_indices <- sapply(all_point_assignment, function(x) if(length(x) > 0) x[1] else NA)
all_province_names <- ifelse(is.na(all_province_indices), NA, provinces$Provincias[all_province_indices])

# Handle unassigned points using nearest province centroids
unassigned_indices <- which(is.na(all_province_names))
if(length(unassigned_indices) > 0) {
  province_centroids <- st_centroid(provinces)
  unassigned_points <- all_points_sf[unassigned_indices, ]
  dist_matrix <- st_distance(unassigned_points, province_centroids)
  nearest_indices <- apply(dist_matrix, 1, which.min)
  all_province_names[unassigned_indices] <- provinces$Provincias[nearest_indices]
}

# Create assignment dataframe for all sequences
all_points_assigned <- data.frame(
  row_id = 1:nrow(all_points_sf),
  Provincias = all_province_names,
  stringsAsFactors = FALSE
)

# Count total sequences per province
sequences_by_province <- all_points_assigned %>%
  filter(!is.na(Provincias)) %>%
  group_by(Provincias) %>%
  summarize(num_genetic_sequences = n(), .groups = 'drop')
cat("=== ✓ Number of genetic sequences per province ===\n")

#---------- 4. CALCULATE DISTANCES USING NEIGHBORING PROVINCES ----------
cat("=== ✓ Starting spatial analyses ===\n")

# Ensure all spatial layers use the same CRS
roads <- st_transform(roads, st_crs(provinces))
cities <- st_transform(cities, st_crs(provinces))
pas <- st_transform(pas, st_crs(provinces))

# Check if distance data has already been saved
distance_file <- file.path(root_dir, "output", "tables", "all_points_with_distances.rds")
if (file.exists(distance_file)) {
  cat("Loading previously calculated distance data...\n")
  all_points_with_distances <- readRDS(distance_file)
} else {
  cat("Calculating distances by province and neighboring provinces...\n")
  
  # 1. Find neighboring provinces for each province
  cat("Identifying neighboring provinces...\n")
  province_neighbors <- st_touches(provinces)
  
  # 2. Create indices to link province names with their position in the dataframe
  province_names <- provinces$Provincias
  province_name_to_idx <- setNames(1:length(province_names), province_names)
  
  # 3. Use the previous assignment to create province indices for each point
  province_indices <- province_name_to_idx[all_points_assigned$Provincias]
  
  # 4. Create vectors to store results
  min_dist_road <- numeric(nrow(all_points_sf))
  min_dist_city <- numeric(nrow(all_points_sf))
  min_dist_pa <- numeric(nrow(all_points_sf))
  
  # 5. Process by province and its neighbors
  cat("Calculating distances by province and its neighbors...\n")
  provinces_count <- nrow(provinces)
  pb <- txtProgressBar(min = 0, max = provinces_count, style = 3)
  
  for(province_idx in 1:provinces_count) {
    # Get the current province and its neighbors
    neighbor_indices <- c(province_idx, province_neighbors[[province_idx]])
    current_province_geom <- st_union(provinces[neighbor_indices, ])
    
    # Find points in this province
    points_in_province <- which(province_indices == province_idx)
    
    if(length(points_in_province) > 0) {
      # Filter features in this province and its neighbors using spatial intersection
      local_roads <- roads[st_intersects(roads, current_province_geom, sparse = FALSE), ]
      local_cities <- cities[st_intersects(cities, current_province_geom, sparse = FALSE), ]
      local_pas <- pas[st_intersects(pas, current_province_geom, sparse = FALSE), ]
      
      batch_size <- 100  # Process 100 points at once
      n_points <- length(points_in_province)
      
      for(batch_start in seq(1, n_points, by = batch_size)) {
        batch_end <- min(batch_start + batch_size - 1, n_points)
        batch_indices <- points_in_province[batch_start:batch_end]
        batch_points <- all_points_sf[batch_indices, ]
        
        # Distance to roads
        if(nrow(local_roads) > 0) {
          dist_matrix_roads <- st_distance(batch_points, local_roads)
          min_dist_road[batch_indices] <- apply(dist_matrix_roads, 1, min)
        } else {
          dist_matrix_roads <- st_distance(batch_points, roads)
          min_dist_road[batch_indices] <- apply(dist_matrix_roads, 1, min)
        }
        
        # Distance to cities
        if(nrow(local_cities) > 0) {
          dist_matrix_cities <- st_distance(batch_points, local_cities)
          min_dist_city[batch_indices] <- apply(dist_matrix_cities, 1, min)
        } else {
          dist_matrix_cities <- st_distance(batch_points, cities)
          min_dist_city[batch_indices] <- apply(dist_matrix_cities, 1, min)
        }
        
        # Distance to protected areas
        if(nrow(local_pas) > 0) {
          dist_matrix_pas <- st_distance(batch_points, local_pas)
          min_dist_pa[batch_indices] <- apply(dist_matrix_pas, 1, min)
        } else {
          dist_matrix_pas <- st_distance(batch_points, pas)
          min_dist_pa[batch_indices] <- apply(dist_matrix_pas, 1, min)
        }
      }
    }
    
    # Update progress bar
    setTxtProgressBar(pb, province_idx)
  }
  
  close(pb)
  
  # 6. Convert units to kilometers
  min_dist_road <- as.numeric(min_dist_road) / 1000
  min_dist_city <- as.numeric(min_dist_city) / 1000
  min_dist_pa <- as.numeric(min_dist_pa) / 1000
  
  # 7. Add the calculated distances to the points
  all_points_with_distances <- all_points_sf %>%
    mutate(
      dist_road = min_dist_road,
      dist_city = min_dist_city,
      dist_pa = min_dist_pa
    )
  
  # 8. Save results
  saveRDS(all_points_with_distances, distance_file)
  
  # Save as CSV
  points_with_dist_csv <- all_points_with_distances %>%
    mutate(
      Longitude = st_coordinates(.)[,1],
      Latitude = st_coordinates(.)[,2]
    ) %>%
    st_drop_geometry()
  
  write.csv(points_with_dist_csv, file.path(root_dir, "output", "tables", "all_points_with_distances.csv"), row.names = FALSE)
}

# Summary of distances
summary_data <- data.frame(
  "Type" = c("Roads", "Cities", "Protected Areas"),
  "Min" = c(min(all_points_with_distances$dist_road), 
            min(all_points_with_distances$dist_city), 
            min(all_points_with_distances$dist_pa)),
  "Median" = c(median(all_points_with_distances$dist_road), 
               median(all_points_with_distances$dist_city), 
               median(all_points_with_distances$dist_pa)),
  "Mean" = c(mean(all_points_with_distances$dist_road), 
             mean(all_points_with_distances$dist_city), 
             mean(all_points_with_distances$dist_pa)),
  "Max" = c(max(all_points_with_distances$dist_road), 
            max(all_points_with_distances$dist_city), 
            max(all_points_with_distances$dist_pa))
)
print(summary_data)

#---------- 5. CALCULATE ACCESSIBILITY INDEX ----------

# Ensure each point with distances has its assigned province
points_with_dist_and_province <- all_points_with_distances %>%
  cbind(Provincias = all_points_assigned$Provincias)

# Calculate medians by province
median_by_province <- points_with_dist_and_province %>%
  st_drop_geometry() %>%
  group_by(Provincias) %>%
  summarize(
    median_dist_road = median(dist_road, na.rm = TRUE),
    median_dist_city = median(dist_city, na.rm = TRUE),
    median_dist_pa = median(dist_pa, na.rm = TRUE),
    n_points = n(),
    .groups = 'drop'
  )

# Calculate average accessibility for each province (average of the three medians)
median_by_province <- median_by_province %>%
  mutate(
    mean_accessibility = (median_dist_road + median_dist_city + median_dist_pa) / 3
  )

#---------- 6. Calculate Global Media ----------
# Apply logarithmic transformation to mean_accessibility
median_by_province <- median_by_province %>%
  mutate(
    mean_accessibility_log = log1p(mean_accessibility)
  )

# Calculate the global median of logarithmic accessibility
A_global_median <- median(median_by_province$mean_accessibility_log, na.rm = TRUE)

# Show basic statistics
cat("\nBasic statistics of logarithmic accessibility:\n")
print(summary(median_by_province$mean_accessibility_log))

#---------- 7. CALCULATE ACCESSIBILITY MAD ----------
# Calculate MAD (Median Absolute Deviation)
absolute_deviations <- abs(median_by_province$mean_accessibility_log - A_global_median)
MAD_accessibility <- median(absolute_deviations, na.rm = TRUE)

cat("MAD of accessibility:", MAD_accessibility, "\n")

#---------- 8. CALCULATE ACCESSIBILITY Z-SCORE ----------
# Calculate accessibility Z-score for each province
median_by_province <- median_by_province %>%
  mutate(
    Z_accessibility = (mean_accessibility_log - A_global_median) / MAD_accessibility
  )

cat("=== ✓ Z-SCORE FOR ACCESSIBILITY===\n")

#---------- 9. CALCULATE Z-SCORE OF SIZE ----------

# Calculate the area of each province in km²
provinces_with_area <- provinces %>%
  mutate(
    area_km2 = as.numeric(units::set_units(st_area(geometry), km^2))
  )

# Join the area to our province dataframe with Z-scores
median_by_province <- median_by_province %>%
  left_join(provinces_with_area %>% 
              st_drop_geometry() %>% 
              dplyr::select(Provincias, area_km2), 
            by = "Provincias")

# Apply logarithmic transformation to the area
median_by_province <- median_by_province %>%
  mutate(
    area_km2_log = log1p(area_km2)
  )

# Calculate the global median of the logarithmic size
S_global_median <- median(median_by_province$area_km2_log, na.rm = TRUE)
cat("Global median of logarithmic size:", S_global_median, "\n")

# Calculate the MAD for size
absolute_deviations_size <- abs(median_by_province$area_km2_log - S_global_median)
MAD_size <- median(absolute_deviations_size, na.rm = TRUE)
cat("MAD of logarithmic size:", MAD_size, "\n")

# Calculate the Z-Score for size
median_by_province <- median_by_province %>%
  mutate(
    Z_size = (area_km2_log - S_global_median) / MAD_size
  )

# Show examples of size Z-scores
cat("=== ✓ Z-SCORE FOR SIZE ===\n")

#---------- 10. CALCULATE HSR INDEX ----------
# FORMULA: HSR = (S_hidden / log(N_sequences + 1)) * (1 + (0.2 * Z_accessibility) + (0.2 * Z_size))
# Where:
#   S_hidden = Number of hidden species per province
#   N_sequences = Number of genetic sequences per province  
#   Z_accessibility = Accessibility Z-score per province
#   Z_size = Size Z-score per province

# Required data sources for HSR calculation:
# 1. species_by_province: Hidden species count per province (from section 3)
# 2. sequences_by_province: Genetic sequences count per province (from section 5) 
# 3. median_by_province: Z-scores for accessibility and size (from sections 7-11)

cat("Calculating HSR Index using the following data sources:\n")
cat("- Hidden species per province: species_by_province\n")
cat("- Genetic sequences per province: sequences_by_province\n") 
cat("- Z-scores per province: median_by_province\n\n")

# Verify all required objects exist
required_objects <- c("species_by_province", "sequences_by_province", "median_by_province")
missing_objects <- required_objects[!sapply(required_objects, exists)]

if(length(missing_objects) > 0) {
  stop("Missing required objects: ", paste(missing_objects, collapse = ", "), 
       "\nPlease ensure all previous sections have been executed.")
}

# Combine all data sources for HSR calculation
provinces_with_all_data <- median_by_province %>%
  # Add hidden species count (S_hidden)
  left_join(species_by_province %>% 
              dplyr::select(Provincias, num_hidden_species), 
            by = "Provincias") %>%
  # Add genetic sequences count (N_sequences)  
  left_join(sequences_by_province %>%
              dplyr::select(Provincias, num_genetic_sequences),
            by = "Provincias") %>%
  # Replace NA values with 0 for provinces without data
  mutate(
    num_hidden_species = ifelse(is.na(num_hidden_species), 0, num_hidden_species),
    num_genetic_sequences = ifelse(is.na(num_genetic_sequences), 0, num_genetic_sequences)
  )

# Calculate HSR index using the formula
provinces_with_all_data <- provinces_with_all_data %>%
  mutate(
    # Base ratio: hidden species / log(sequences + 1)
    base_ratio = num_hidden_species / log(num_genetic_sequences + 1),
    # Adjustment factor: 1 + (0.2 * Z_accessibility) + (0.2 * Z_size)
    adjustment_factor = 1 + (0.2 * Z_accessibility) + (0.2 * Z_size),
    # Final HSR index
    HSR = base_ratio * adjustment_factor
  )

# Display results summary
cat("HSR Index calculation completed!\n")
cat("Formula components:\n")
cat("- Base ratio = num_hidden_species / log(num_genetic_sequences + 1)\n")
cat("- Adjustment factor = 1 + (0.2 * Z_accessibility) + (0.2 * Z_size)\n")

# Show top provinces by HSR index
cat("Top 10 provinces by HSR index:\n")
print(provinces_with_all_data %>% 
        dplyr::select(Provincias, num_hidden_species, num_genetic_sequences, 
                      Z_accessibility, Z_size, HSR) %>%
        arrange(desc(HSR)) %>%
        head(10))

# Verify data completeness
total_provinces <- nrow(provinces_with_all_data)
provinces_with_hsr <- sum(provinces_with_all_data$HSR > 0, na.rm = TRUE)
cat("\nData completeness check:\n")
cat("Total provinces:", total_provinces, "\n")
cat("Provinces with HSR > 0:", provinces_with_hsr, "\n")
cat("Provinces with HSR = 0:", total_provinces - provinces_with_hsr, "\n")

# Save final HSR results
write.csv(provinces_with_all_data, file.path(root_dir, "output", "tables", "HSR_scores.csv"), row.names = FALSE)
cat("\nHSR scores saved to: output/tables/HSR_scores.csv\n")

#---------- 11. CREATE HSR MAP ----------

# Join HSR values to spatial data for mapping
provinces_map <- provinces %>%
  left_join(provinces_with_all_data %>% 
              dplyr::select(Provincias, HSR), 
            by = "Provincias") %>%
  # Replace NA values with 0 for provinces without HSR data
  mutate(HSR = ifelse(is.na(HSR), 0, HSR))

# Create HSR map
map_hsr <- ggplot() +
  geom_sf(data = provinces_map, aes(fill = HSR), color = "white", size = 0.2) +
  scale_fill_gradientn(
    colors = colorRampPalette(c("#E8EAF6", "#9FA8DA", "#5C6BC0", "#3949AB", "#1A237E"))(100),
    name = NULL,
    guide = guide_colorbar(
      barwidth = 0.5,      # Bar width
      barheight = 32,      # Bar height
      title.position = "top",
      title.hjust = 0.5,
      ticks.linewidth = 0.5,
      frame.colour = "black",
      frame.linewidth = 0.5
    )
  ) +
  theme_minimal() +
  # Title
  labs(title = NULL) +
  annotate("text", label = "A", 
           hjust = -0.5, vjust = 1.5, size = 10, fontface = "bold") +
  theme(
    legend.position = c(0.99, 0.5),   
    legend.justification = c(1, 0.5), 
    legend.key.height = unit(15, "cm"),  
    legend.key.width = unit(0.5, "cm"),
    legend.direction = "vertical",
    legend.box.just = "right",
    axis.text = element_blank(),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_blank(),
    axis.ticks = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(1, 2, 0, 0, "cm")
  ) +
  coord_sf()

# Display the map
print(map_hsr)

# Save HSR map
ggsave(file.path(root_dir, "output", "figures", "Figure 3A. HSR_index_map.png"), 
       map_hsr, width = 10, height = 8, dpi = 300)

#---------- 12. RASTERIZE HSR ----------
cat("=== ✓ RASTERIZING HSR — PLEASE CHECK RASTERS ===\n")

# Load the human footprint raster as a reference template
human_footprint_file <- file.path(root_dir, "data", "input", "Human_Footprint", "HF_neotropics")
if (!file.exists(paste0(human_footprint_file, ".tif"))) {
  # Try common extensions if .tif doesn't exist
  extensions <- c(".tif", ".tiff", ".img", ".grd")
  found_file <- NULL
  for (ext in extensions) {
    test_file <- paste0(human_footprint_file, ext)
    if (file.exists(test_file)) {
      found_file <- test_file
      break
    }
  }
  if (is.null(found_file)) {
    stop("Human footprint raster not found. Please check the file exists in data/input/Human_Footprint/")
  }
  human_footprint_file <- found_file
} else {
  human_footprint_file <- paste0(human_footprint_file, ".tif")
}

cat("=== ✓ INTEGRATION WITH HUMAN-INDUCED LANDSCAPE MODIFICATIONS ===\n")
# Load human footprint raster
cat("Loading human footprint raster from:", human_footprint_file, "\n")
huella_humana <- rast(human_footprint_file)

# Save human footprint visualization
png(file.path(root_dir, "output", "figures", "Figure 3B. Human_Footprint.png"), 
    width = 10, height = 8, units = "in", res = 300)
plot(huella_humana,
     col = hcl.colors(100, "YlGnBu"),
     axes = FALSE,  
     box = FALSE,   
     main = "") 
dev.off()

# Check for NA values in provinces_map
cat("Checking for NA values in HSR data...\n")
na_provinces <- provinces_map %>% 
  filter(is.na(HSR)) %>% 
  pull(Provincias)

if(length(na_provinces) > 0) {
  cat("Found provinces with NA HSR values:", paste(na_provinces, collapse = ", "), "\n")
  provinces_map <- provinces_map %>%
    mutate(HSR = ifelse(is.na(HSR), 0, HSR))
  cat("Replaced NA values with 0\n")
} else {
  cat("No NA values found in HSR data\n")
}

# Check and fix geometry validity
cat("Checking geometry validity...\n")
invalid_geoms <- !st_is_valid(provinces_map)
if(any(invalid_geoms)) {
  cat("Found", sum(invalid_geoms), "invalid geometries - fixing...\n")
  provinces_map <- st_make_valid(provinces_map)
  cat("Geometries corrected\n")
} else {
  cat("All geometries are valid\n")
}

# Transform provinces_map to the same CRS as human footprint
cat("Transforming CRS to match human footprint raster...\n")
provinces_sf <- st_transform(provinces_map, crs(huella_humana))

# Convert to terra format and rasterize
cat("Rasterizing HSR index...\n")
provinces_vect <- vect(provinces_sf)
indice_especies_ocultas <- rasterize(provinces_vect, huella_humana, field = "HSR")

# Check range of values
hsr_min <- minmax(indice_especies_ocultas)[1]
hsr_max <- minmax(indice_especies_ocultas)[2]
cat("HSR raster value range:", hsr_min, "to", hsr_max, "\n")

# Save the HSR raster
hsr_raster_file <- file.path(root_dir, "output", "rasters", "HSR_index_raster.tif")
writeRaster(indice_especies_ocultas, hsr_raster_file, overwrite = TRUE)

cat("HSR raster saved to:", hsr_raster_file, "\n")

#---------- 13. LOSS AREA SSP245 & SSP585 ----------
cat("=== ✓ INTEGRATION WITH ECOLOGICAL NICHE MODELS ===\n")

# Define directories
loss_dir <- file.path(root_dir, "data", "input", "Loss_Areas")

# Load raster template (using any single species file as template)
especies_folders <- list.dirs(loss_dir, full.names = TRUE, recursive = FALSE)
if (length(especies_folders) == 0) {
  stop("No species folders found in Loss_Areas")
}

# Find first available Loss_ssp245.tif file to use as template
template_file <- NULL
for (folder in especies_folders) {
  test_file <- file.path(folder, "Loss_ssp245.tif")
  if (file.exists(test_file)) {
    template_file <- test_file
    break
  }
}

if (is.null(template_file)) {
  stop("No Loss_ssp245.tif files found in any species folder")
}

cat("Using template from:", basename(dirname(template_file)), "\n")
raster_plantilla <- rast(template_file)

# Process both scenarios
scenarios <- c("ssp245", "ssp585")

for (scenario in scenarios) {
  cat("\n=== Processing", toupper(scenario), "===\n")
  
  # Find Loss files for this scenario
  archivos_perdida <- c()
  for (folder in especies_folders) {
    loss_file <- file.path(folder, paste0("Loss_", scenario, ".tif"))
    if (file.exists(loss_file)) {
      archivos_perdida <- c(archivos_perdida, loss_file)
    }
  }
  
  cat("Found", length(archivos_perdida), "loss files for", toupper(scenario), "\n")
  
  if (length(archivos_perdida) > 0) {
    # Sum all rasters (EXACT SAME LOGIC AS SECTION 15)
    cat("Loading and summing rasters...\n")
    perdida_rasters <- rast(archivos_perdida)
    perdida_acumulativa <- sum(perdida_rasters, na.rm = TRUE)
    
    # Mask to Neotropical region (EXACT SAME LOGIC AS SECTION 15)
    cat("Masking to Neotropical region...\n")
    neotrop_mask <- rasterize(vect(provinces), perdida_acumulativa, field = 1)
    perdida_acumulativa <- ifel(is.na(neotrop_mask), NA, 
                                ifel(is.na(perdida_acumulativa), 0, perdida_acumulativa))
    
    # Create final raster (EXACT SAME LOGIC AS SECTION 15)
    cat("Creating final raster using the template...\n")
    perdida_final <- raster_plantilla  # Create a copy of the template
    perdida_final[!is.na(perdida_acumulativa)] <- perdida_acumulativa[!is.na(perdida_acumulativa)]  # Transfer values
    
    cat("Range of values:", minmax(perdida_final)[1], "a", minmax(perdida_final)[2], "\n")
  } else {
    perdida_final <- raster_plantilla * 0
  }
  
  # Save results
  output_name <- paste0("Loss_area_", scenario)
  writeRaster(perdida_final, file.path(root_dir, "output", "rasters", paste0(output_name, ".tif")), overwrite = TRUE)
  
  # Save visualization
  png(file.path(root_dir, "output", "figures", paste0(output_name, ".png")), 
      width = 10, height = 8, units = "in", res = 300)
  plot(perdida_final, 
       main = "", 
       axes = FALSE,   
       box = FALSE,
       frame = FALSE)    
  dev.off()
  
  cat(toupper(scenario), "completed!\n")
}

cat("\nBoth scenarios processed successfully!\n")

#---------- 14. CRITICAL AREAS MAP SSP245 & SSP585 ----------
cat("=== ✓ HIDDEN DIVERSITY HOTSPOTS IDENTIFIED — PLEASE CHECK MAPS ===\n")

# Load the HSR raster (from section 14)
indice_especies_ocultas <- rast(file.path(root_dir, "output", "rasters", "HSR_index_raster.tif"))

# Load human footprint raster
template_files <- list.files(file.path(root_dir, "data", "input", "Human_Footprint"), 
                             pattern = "\\.(tif|tiff)$", full.names = TRUE)
huella_humana <- rast(template_files[1])

# Load loss rasters (from section 15)
perdida_ssp245 <- rast(file.path(root_dir, "output", "rasters", "Loss_area_ssp245.tif"))
perdida_ssp585 <- rast(file.path(root_dir, "output", "rasters", "Loss_area_ssp585.tif"))

# Process both scenarios
scenarios <- c("ssp245", "ssp585")
perdida_rasters <- list(perdida_ssp245, perdida_ssp585)

for (i in 1:length(scenarios)) {
  scenario <- scenarios[i]
  perdida_final <- perdida_rasters[[i]]
  
  cat("\n=== Creating Critical Areas Map for", toupper(scenario), "===\n")
  
  # 1. Prepare all layers to the same resolution
  template <- rast(ext(perdida_final), resolution = res(perdida_final), crs = crs(perdida_final))
  
  # Resample layers to match template
  indice_resampled <- resample(indice_especies_ocultas, template, method = "bilinear")
  huella_resampled <- resample(huella_humana, template, method = "bilinear")
  
  # 2. Normalize each layer (0-1 scale)
  normalize <- function(x) {
    mn <- min(x, na.rm = TRUE)
    mx <- max(x, na.rm = TRUE)
    if (is.finite(mn) && is.finite(mx) && mx > mn) {
      return((x - mn) / (mx - mn))
    } else {
      return(x)
    }
  }
  
  indice_norm <- app(indice_resampled, normalize)
  huella_norm <- app(huella_resampled, normalize)
  perdida_norm <- app(perdida_final, normalize)
  
  # 3. Combine layers with weights
  weights <- c(0.33, 0.34, 0.33)  # HSR, Human footprint, Climate loss
  areas_criticas <- (indice_norm * weights[1]) + 
    (huella_norm * weights[2]) + 
    (perdida_norm * weights[3])
  
  # 4. Save results
  output_name <- paste0("Critical_areas_", scenario)
  writeRaster(areas_criticas, file.path(root_dir, "output", "rasters", paste0(output_name, ".tif")), overwrite = TRUE)
  
  # 5. Create visualization
  png(file.path(root_dir, "output", "figures", paste0(output_name, ".png")), 
      width = 10, height = 8, units = "in", res = 300)
  plot(areas_criticas, 
       main = "",
       col = rev(hcl.colors(100, "spectral")),
       axes = FALSE,   
       box = FALSE,
       frame = FALSE)
  
  # Add province borders
  plot(vect(provinces), add = TRUE, border = "black", col = NA, lwd = 0.4)
  dev.off()
  
  cat("Critical areas map", toupper(scenario), "completed!\n")
}

cat("\nAll critical areas maps completed!\n")

#---------- 15. PRIORITY PROVINCES SSP245 & SSP585 ----------
cat("=== ✓ PRIORITY PROVINCES IDENTIFIED — PLEASE CHECK TABLES ===\n")

# Process both scenarios
scenarios <- c("ssp245", "ssp585")

for (scenario in scenarios) {
  cat("\n=== Calculating Priority Provinces for", toupper(scenario), "===\n")
  
  # Load the critical areas raster for this scenario
  areas_criticas_raster <- rast(file.path(root_dir, "output", "rasters", paste0("Critical_areas_", scenario, ".tif")))
  
  # Extract median values by province
  cat("Extracting median values by province...\n")
  province_values <- extract(areas_criticas_raster, vect(provinces), fun = median, na.rm = TRUE)
  
  # Create dataframe with results
  priority_provinces <- data.frame(
    Provincia = provinces$Provincias,
    Valor_Critico_Mediano = province_values[,2]  # Second column contains the values
  )
  
  # Order from highest to lowest
  priority_provinces <- priority_provinces[order(priority_provinces$Valor_Critico_Mediano, decreasing = TRUE), ]
  
  # Save results
  output_name <- paste0("priority_provinces_", scenario, ".csv")
  write.csv(priority_provinces, file.path(root_dir, "output", "tables", output_name), row.names = FALSE)
  
  # Show top 10 provinces
  cat("Top 10 priority provinces for", toupper(scenario), ":\n")
  print(head(priority_provinces, 10))
  
  cat("Priority provinces", toupper(scenario), "saved to:", output_name, "\n")
}

cat("\nAll priority provinces analyses completed!\n")

