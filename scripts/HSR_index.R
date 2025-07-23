# HSR Index Analysis - Main Script
# Esquivel et al. (2025) Nature Communications
# Script of "Racing Against Time to Unveil Hidden Bat Diversity"

#---------- 1. PACKAGE LOADING  ----------
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

#--------- 2. SET WORKING DIRECTORIES AND DATA ---------
# IMPORTANT: Modify these paths according to your file structure
root_dir <- "C:/Users/diego/Documents/Resultados PhD/Critical_Areas" 

# CSV with hidden species occurrences
hidden_points <- read.csv(file.path(root_dir, "Hidden_points.csv"))
print(paste("Total number of records:", nrow(hidden_points)))
print(paste("Number of unique IDs (hidden species):", length(unique(hidden_points$ID))))

# CSV with all coordinates of genetic sequences (only Hidden species)
all_coordinates <- read.csv(file.path(root_dir, "All_coordinates.csv"))
print(paste("Total number of genetic coordinates:", nrow(all_coordinates)))

# Shapefile biogeographic provinces
provinces <- st_read(file.path(root_dir, "Neotropic"), quiet = TRUE)

# Roads infrastructure data
roads <- st_read(file.path(root_dir, "GRIP4"), quiet = TRUE) %>% 
  filter(GP_RTP %in% c(1, 2))

# Cities locations
cities <- st_read(file.path(root_dir, "Cities"), quiet = TRUE)

# Protected areas
pas_raw <- st_read(file.path(root_dir, "WDPA_Data", "WDPA_neotropico.gpkg"), quiet = TRUE)
pas <- pas_raw %>%
  st_make_valid() %>%     # Fix invalid geometries
  st_buffer(0)

#---------- 3. CALCULATE HIDDEN SPECIES PER BIOGEOGRAPHIC PROVINCE ----------

# Fix invalid geometries
provinces <- provinces[, "Provincias", drop = FALSE]
provinces <- st_make_valid(provinces)

# Convert points to spatial format
hidden_points_sf <- hidden_points %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)

# Ensure same CRS (Coordinate Reference System)
provinces <- st_transform(provinces, st_crs(hidden_points_sf))

point_in_poly <- st_within(hidden_points_sf, provinces, sparse = FALSE)
province_indices <- apply(point_in_poly, 1, function(x) if(any(x)) which(x)[1] else NA)
province_names <- ifelse(is.na(province_indices), NA, provinces$Provincias[province_indices])

# Create dataframe with assignments
points_assigned <- data.frame(
  ID = hidden_points_sf$ID,
  Provincias = province_names,
  stringsAsFactors = FALSE
)

# Count unique species per province (excluding duplicates)
species_by_province <- points_assigned %>%
  filter(!is.na(Provincias)) %>%
  # Remove duplicates (same ID within the same province)
  distinct(ID, Provincias) %>%
  # Group and count
  group_by(Provincias) %>%
  summarize(
    num_hidden_species = n(),
    species_list = paste(sort(ID), collapse=", ")
  )

print(species_by_province %>% arrange(desc(num_hidden_species)) %>% head(10))
write.csv(species_by_province, file.path(root_dir, "hidden_species_by_province.csv"), row.names = FALSE)

#---------- 4. CREATE MAP OF HIDDEN SPECIES BY PROVINCE ----------
# Join species count with the province layer
provinces_with_hidden <- provinces %>%
  left_join(species_by_province %>% dplyr::select(Provincias, num_hidden_species), by = "Provincias") %>%
  # Replace NA with 0 for provinces without hidden species
  mutate(num_hidden_species = ifelse(is.na(num_hidden_species), 0, num_hidden_species))

# Create map of hidden species by province
map_hidden_species <- ggplot(provinces_with_hidden) +
  geom_sf(aes(fill = num_hidden_species), color = "white", size = 0.2) +
  scale_fill_gradient2(
    low = "blue",         # Few species (blue)
    mid = "white",        # Average value (white)
    high = "red",         # Many species (red)
    midpoint = mean(provinces_with_hidden$num_hidden_species, na.rm = TRUE),
    name = "Number \nHidden Species"
  ) +
  theme_minimal() +
  labs(
    title = "Distribution of Hidden Species by Province",
    subtitle = paste("Total hidden species:", length(unique(hidden_points$ID))),
    caption = NULL
  )

# Map
print(map_hidden_species)

# Save
ggsave(file.path(root_dir, "Raw Hidden Species.png"), map_hidden_species, width = 10, height = 8, dpi = 300)

#---------- 5. CALCULATE AND VISUALIZE SIMPLE RATIO ----------

# Convert all genetic sequences to spatial format
all_points_sf <- all_coordinates %>%
  st_as_sf(coords = c("Longitude", "Latitude"), crs = 4326)

# Ensure the same CRS is used for the provinces
all_points_sf <- st_transform(all_points_sf, st_crs(provinces))

# Assign all sequences to provinces using the same method that worked previously
point_in_poly <- st_within(all_points_sf, provinces, sparse = FALSE)
province_indices <- apply(point_in_poly, 1, function(x) if(any(x)) which(x)[1] else NA)
province_names <- ifelse(is.na(province_indices), NA, provinces$Provincias[province_indices])

# Identify unassigned points
unassigned_indices <- which(is.na(province_names))
cat("Number of initially unassigned points:", length(unassigned_indices), "\n")

# FAST METHOD: Use province centroids to speed up the calculation
if(length(unassigned_indices) > 0) {
  # Calculate province centroids for faster computations
  province_centroids <- st_centroid(provinces)
  
  # Extract unassigned points
  unassigned_points <- all_points_sf[unassigned_indices, ]
  
  # Calculate distance matrix all at once
  dist_matrix <- st_distance(unassigned_points, province_centroids)
  
  # For each point, find the index of the nearest province
  nearest_indices <- apply(dist_matrix, 1, which.min)
  
  # Assign province names
  nearest_province_names <- provinces$Provincias[nearest_indices]
  
  # Update assignments
  province_names[unassigned_indices] <- nearest_province_names
  
  cat("Points assigned to the nearest province:", length(unassigned_indices), "\n")
}

# Check if all points now have an assignment
cat("Points without assignment after correction:", sum(is.na(province_names)), "\n")

# Create dataframe with assignments for all sequences
all_points_assigned <- data.frame(
  row_id = 1:nrow(all_points_sf),  # Create a unique ID for each sequence
  Provincias = province_names,
  stringsAsFactors = FALSE
)

# Count total sequences per province
sequences_by_province <- all_points_assigned %>%
  filter(!is.na(Provincias)) %>%
  group_by(Provincias) %>%
  summarize(
    num_genetic_sequences = n()
  )

# Calculate ratio: hidden species / log(total sequences + 1)
province_ratio <- species_by_province %>%
  dplyr::select(Provincias, num_hidden_species) %>%
  left_join(sequences_by_province, by = "Provincias") %>%
  # If any provinces have no total sequences, use 0
  mutate(
    num_genetic_sequences = ifelse(is.na(num_genetic_sequences), 0, num_genetic_sequences),
    simple_ratio = num_hidden_species / log(num_genetic_sequences+1)
  )

# Join the ratio with the province layer for visualization
provinces_with_ratio <- provinces %>%
  left_join(province_ratio %>% dplyr::select(Provincias, num_hidden_species, num_genetic_sequences, simple_ratio), 
            by = "Provincias") %>%
  # Replace NA with 0 for provinces without data
  mutate(
    num_hidden_species = ifelse(is.na(num_hidden_species), 0, num_hidden_species),
    num_genetic_sequences = ifelse(is.na(num_genetic_sequences), 0, num_genetic_sequences),
    simple_ratio = ifelse(is.na(simple_ratio), 0, simple_ratio)
  )

# Create map of the simple ratio
map_ratio <- ggplot(provinces_with_ratio) +
  geom_sf(aes(fill = simple_ratio), color = "white", size = 0.2) +
  scale_fill_gradient2(
    low = "blue",         
    mid = "white",        
    high = "red",         
    midpoint = mean(provinces_with_ratio$simple_ratio, na.rm = TRUE),
    name = "Ratio"
  ) +
  theme_minimal() +
  labs(
    title = NULL,
    subtitle = "S hidden / log(N sequences + 1)",
    caption = NULL
  )

# Map
print(map_ratio)

# Save
ggsave(file.path(root_dir, "Raw Ratio.png"), map_hidden_species, width = 10, height = 8, dpi = 300)

#---------- 6. CALCULATE DISTANCES USING NEIGHBORING PROVINCES ----------

# Ensure all spatial layers use the same CRS
roads <- st_transform(roads, st_crs(provinces))
cities <- st_transform(cities, st_crs(provinces))
pas <- st_transform(pas, st_crs(provinces))

# Check if distance data has already been saved
distance_file <- file.path(root_dir, "all_points_with_distances.rds")
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
      
      # For each point in this province, calculate distances
      for(point_idx in points_in_province) {
        point <- all_points_sf[point_idx, ]
        
        # Distance to roads
        if(nrow(local_roads) > 0) {
          min_dist_road[point_idx] <- min(st_distance(point, local_roads)[1,])
        } else {
          min_dist_road[point_idx] <- min(st_distance(point, roads)[1,])
        }
        
        # Distance to cities
        if(nrow(local_cities) > 0) {
          min_dist_city[point_idx] <- min(st_distance(point, local_cities)[1,])
        } else {
          min_dist_city[point_idx] <- min(st_distance(point, cities)[1,])
        }
        
        # Distance to protected areas
        if(nrow(local_pas) > 0) {
          min_dist_pa[point_idx] <- min(st_distance(point, local_pas)[1,])
        } else {
          min_dist_pa[point_idx] <- min(st_distance(point, pas)[1,])
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
  
  # Save in CVS
  points_with_dist_csv <- all_points_with_distances %>%
    mutate(
      Longitude = st_coordinates(.)[,1],
      Latitude = st_coordinates(.)[,2]
    ) %>%
    st_drop_geometry()
  
  write.csv(points_with_dist_csv, file.path(root_dir, "all_points_with_distances.csv"), row.names = FALSE)
}

# Summary of distances
cat("\nSummary of minimum distances (km):\n")
summary_data <- data.frame(
  "Tipo" = c("Carreteras", "Ciudades", "Áreas Protegidas"),
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

#---------- 7. Calculate Accessibility Index ----------

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
    n_points = n()
  )

# Calculate average accessibility for each province (average of the three medians)
median_by_province <- median_by_province %>%
  mutate(
    mean_accessibility = (median_dist_road + median_dist_city + median_dist_pa) / 3
  )

#---------- 8. Calculate Global Media ----------
# Apply logarithmic transformation to mean_accessibility
median_by_province <- median_by_province %>%
  mutate(
    mean_accessibility_log = log1p(mean_accessibility)
  )

# Calculate the global median of logarithmic accessibility
A_global_median <- median(median_by_province$mean_accessibility_log, na.rm = TRUE)

cat("Global median of logarithmic accessibility (global):", A_global_median, "\n")

# También mostramos las estadísticas básicas para entender mejor la distribución
cat("\nbasic statistics to better understand the distribution:\n")
summary(median_by_province$mean_accessibility_log)

# Save
median_by_province_global <- median_by_province
median_by_province_global$A_global_median <- A_global_median

#---------- 9. CALCULATE ACCESSIBILITY MAD ----------

# MAD is the median of the absolute deviations from the overall median

# Calculate the absolute deviations
absolute_deviations <- abs(median_by_province$mean_accessibility_log - A_global_median)

# Calculate the MAD (median absolute deviation)
MAD_accessibility <- median(absolute_deviations, na.rm = TRUE)

# Save
median_by_province_global$MAD_accessibility <- MAD_accessibility

#---------- 10. CALCULATE ACCESSIBILITY Z-SCORE ----------

# Calculate accessibility Z-score for each province
# Z = (Ai - Ãglobal) / MADAccessibility

# Add Z-score to our provinces dataframe
median_by_province <- median_by_province %>%
  mutate(
    Z_accessibility = (mean_accessibility_log - A_global_median) / MAD_accessibility
  )

# Show some examples of Z-scores
cat("Accessibility Z-scores for some provinces::\n")
print(median_by_province %>% 
        dplyr::select(Provincias, mean_accessibility, mean_accessibility_log, Z_accessibility) %>%
        arrange(desc(Z_accessibility)) %>%
        head(10))

#---------- 11. CALCULATE Z-SCORE OF SIZE ----------

# 1. Calculate the area of each province in km²
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

# 2. Calculate the global median of the logarithmic size
S_global_median <- median(median_by_province$area_km2_log, na.rm = TRUE)
cat("Global median of logarithmic size:", S_global_median, "\n")

# 4. Calculate the MAD 
absolute_deviations_size <- abs(median_by_province$area_km2_log - S_global_median)
MAD_size <- median(absolute_deviations_size, na.rm = TRUE)
cat("MAD del tamaño logarítmico:", MAD_size, "\n")

# 5. Calculate the Z-Score
median_by_province <- median_by_province %>%
  mutate(
    Z_size = (area_km2_log - S_global_median) / MAD_size
  )

# Show some examples of Z-scores
cat("\nSize Z-scores for some provinces:\n")
print(median_by_province %>% 
        dplyr::select(Provincias, area_km2, area_km2_log, Z_size) %>%
        arrange(desc(Z_size)) %>%
        head(10))

# Save
write.csv(median_by_province, file.path(root_dir, "provinces_with_z_scores.csv"), row.names = FALSE)

#---------- 12. CALCULATE HSR INDEX ----------
# Tomamos datos de numero de hidden species desde archivo
# "hidden_species_by_province" y la colocamos manualmente en una
# nueva columna llamada "num_hidden_species" en el archivo
# "provinces_with_z_scores". Este archivo contiene todo
# lo que necesitamos para calcular HSR

# Upload the CSV file with the data
provinces_with_all_z_scores <- read.csv(file.path(root_dir, "provinces_with_z_scores.csv"), stringsAsFactors = FALSE)

# Check column names
print(colnames(provinces_with_all_z_scores))

# Calculate HSR for each province according to the formula
provinces_with_all_z_scores <- provinces_with_all_z_scores %>%
  mutate(
    HSR = num_hidden_species/(log(n_points+1)) * (1 + (0.2 * Z_accessibility) + (0.2 * Z_size))
  )

# Check the results for some provinces
print(provinces_with_all_z_scores %>% 
        dplyr::select(Provincias, num_hidden_species, Z_accessibility, Z_size, n_points, HSR) %>%
        head(10))

# Save
write.csv(provinces_with_all_z_scores, file.path(root_dir, "HSR_scores.csv"), row.names = FALSE)

#---------- 13. CREATE HSR MAP ----------
# Join HSR values to spatial data
provinces_map <- provinces %>%
  left_join(provinces_with_all_z_scores %>% 
              dplyr::select(Provincias, HSR), 
            by = "Provincias")

# Assign 0 to NA values in the HSR
provinces_map$HSR[is.na(provinces_map$HSR)] <- 0

ggplot() +
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
  # Tittle
  labs(title = NULL) +
  annotate("text",label = "A", 
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

ggsave("mapa_HSR_neotropico.png", width = 10, height = 8, dpi = 300)

#---------- 14. RASTERIZE HSR ----------
# Load the human footprint raster as a reference
huella_humana <- rast("C:/Users/diego/Documents/Resultados PhD/Priority_species/Maps/Human_footprint/HF_neotropico_final.tif")

png("Human_Footprint.png", width = 10, height = 8, units = "in", res = 300)
plot(huella_humana,
     col = hcl.colors(100, "YlGnBu"),
     axes = FALSE,  
     box = FALSE,   
     main = "") 
dev.off()

print("Checking NA values in provinces_map")
na_provinces <- provinces_map %>% 
  filter(is.na(HSR)) %>% 
  pull(Provincias)
print(na_provinces)

# If there are provinces with NA, assign them value 0 or another appropriate value
if(length(na_provinces) > 0) {
  provinces_map <- provinces_map %>%
    mutate(HSR = ifelse(is.na(HSR), 0, HSR))
  print("NA values replaced with 0")
}

# Check geometry
print("Check geometry:")
invalid_geoms <- !st_is_valid(provinces_map)
if(any(invalid_geoms)) {
  print(paste("Found", sum(invalid_geoms), "invalid geometries"))
  # Correct geometries
  provinces_map <- st_make_valid(provinces_map)
  print("Corrected geometries")
}

# Transform provinces_map to the same CRS as human_footprint
provinces_sf <- st_transform(provinces_map, crs(huella_humana))

# Convert to terra format and rasterize 
provinces_vect <- vect(provinces_sf)
indice_especies_ocultas <- rasterize(provinces_vect, huella_humana, field = "HSR")

# Check range of values for documentation
hsr_min <- minmax(indice_especies_ocultas)[1]
hsr_max <- minmax(indice_especies_ocultas)[2]

# Save the raster keeping the original values
writeRaster(indice_especies_ocultas, file.path(root_dir, "indice_HSR.tif"), overwrite=TRUE)

#---------- 15. Loss area ssp245 ----------

# Define directories
loss_dir <- "C:/Users/diego/Documents/Hidden/Final Areas"

# Load raster template (add the path to your raster template)
raster_plantilla <- rast("C:/Users/diego/Documents/Hidden/Model/Anoura_cultrata/Final_Model_Stats/Statistics_NE/Current_med.tif")
print(raster_plantilla)

# List all species folders
especies_folders <- list.dirs(loss_dir, full.names = TRUE, recursive = FALSE)
print(paste("Número de carpetas de especies encontradas:", length(especies_folders)))

# Create list to store paths to Loss_ssp245 files
archivos_perdida <- c()

# Find the Loss_ssp245.tif file in each species folder
for (folder in especies_folders) {
  loss_file <- file.path(folder, "Loss_ssp245.tif")
  if (file.exists(loss_file)) {
    archivos_perdida <- c(archivos_perdida, loss_file)
  }
}
print(paste("Number of loss files found:", length(archivos_perdida)))

# Simple method with rast() and sum()
print("loading all rasters into a single SpatRaster...")
perdida_rasters <- rast(archivos_perdida)

# Sum all rasters
print("Adding rasters...")
perdida_acumulativa <- sum(perdida_rasters, na.rm=TRUE)

# Check the result
print(perdida_acumulativa)
print(paste("Rango de valores:", minmax(perdida_acumulativa)[1], "a", minmax(perdida_acumulativa)[2]))

# Create a full raster using the template as a base
print("Creating final raster using the template...")
perdida_final <- raster_plantilla  # Create a copy of the template (which has zeros)
perdida_final[!is.na(perdida_acumulativa)] <- perdida_acumulativa[!is.na(perdida_acumulativa)]  # Transfer values

# Check the final result
print("Final raster created:")
print(perdida_final)
print(paste("Range of values:", minmax(perdida_final)[1], "a", minmax(perdida_final)[2]))
print(paste("Number of NA cells:", sum(is.na(values(perdida_final)))))

# Save final raster
writeRaster(perdida_final, file.path(root_dir, "Loss area ssp245.tif"), overwrite=TRUE)

# View final result
plot(perdida_final, main="Loss area ssp245")

# Save
png("Loss_area_ssp245.png", width = 10, height = 8, units = "in", res = 300)
plot(perdida_final, 
     main= "", 
     axes=FALSE,   
     box=FALSE)    
dev.off()

#---------- 16. Loss area ssp585 ----------

loss_dir_585 <- "C:/Users/diego/Documents/Hidden/Final Areas"

# Load raster template (add the path to your raster template)
raster_plantilla_585 <- rast("C:/Users/diego/Documents/Hidden/Model/Anoura_cultrata/Final_Model_Stats/Statistics_NE/Current_med.tif")
print(raster_plantilla_585)

# List all species folders
especies_folders_585 <- list.dirs(loss_dir_585, full.names = TRUE, recursive = FALSE)
print(paste("Número de carpetas de especies encontradas para SSP585:", length(especies_folders_585)))

# Create list to store paths to Loss_ssp585 files
archivos_perdida_585 <- c()

# Find the Loss_ssp585.tif file in each species folder
for (folder in especies_folders_585) {
  loss_file_585 <- file.path(folder, "Loss_ssp585.tif")
  if (file.exists(loss_file_585)) {
    archivos_perdida_585 <- c(archivos_perdida_585, loss_file_585)
  }
}
print(paste("Number of SSP585 loss files found:", length(archivos_perdida_585)))

# Simple method with rast() and sum()
print("Loading all SSP585 rasters into a single SpatRaster...")
perdida_rasters_585 <- rast(archivos_perdida_585)

# Sum all rasters
print("Adding SSP585 rasters...")
perdida_acumulativa_585 <- sum(perdida_rasters_585, na.rm=TRUE)

# Check result
print(perdida_acumulativa_585)
print(paste("SSP585 Value Range:", minmax(perdida_acumulativa_585)[1], "a", minmax(perdida_acumulativa_585)[2]))

# Create a full raster using the template as a base
print("Creating final SSP585 raster using the template...")
perdida_final_585 <- raster_plantilla_585  # Create a copy of the template (which has zeros)
perdida_final_585[!is.na(perdida_acumulativa_585)] <- perdida_acumulativa_585[!is.na(perdida_acumulativa_585)]  # Transfer values

# Check final result
print("Final SSP585 raster created:")
print(perdida_final_585)
print(paste("SSP585 Value Range:", minmax(perdida_final_585)[1], "a", minmax(perdida_final_585)[2]))
print(paste("Number of NA cells in SSP585:", sum(is.na(values(perdida_final_585)))))

# Save final raster
writeRaster(perdida_final_585, file.path(root_dir, "Loss_area_ssp585.tif"), overwrite=TRUE)

# View final result
plot(perdida_final_585, main="Loss area SSP585")
png("Loss_area_ssp585.png", width = 10, height = 8, units = "in", res = 300)
plot(perdida_final_585, 
     main="", 
     axes=FALSE,   
     box=FALSE)   
dev.off()

#---------- 17. Critical Areas Map spp245 ----------
# 1. Prepare all layers to the same resolution
# Create a template raster with the final_loss resolution
template <- rast(ext(perdida_final), resolution=res(perdida_final), crs=crs(perdida_final))

# Resample the high resolution layers to the coarsest resolution (5 km)
indice_resampled <- resample(indice_especies_ocultas, template, method="bilinear")
huella_resampled <- resample(huella_humana, template, method="bilinear")

# Normalize each layer individually, explicitly handling NAs
normalize <- function(x) {
  mn <- min(x, na.rm = TRUE)
  mx <- max(x, na.rm = TRUE)
  if(is.finite(mn) && is.finite(mx) && mx > mn) {
    return((x - mn) / (mx - mn))
  } else {
    return(x)
  }
}

# Normalize each layer
indice_norm <- app(indice_resampled, normalize)
huella_norm <- app(huella_resampled, normalize)
perdida_norm <- app(perdida_final, normalize)

writeRaster(indice_norm, "indice_especies_ocultas_normalizado.tif", overwrite=TRUE)
writeRaster(huella_norm, "huella_humana_normalizada.tif", overwrite=TRUE)
writeRaster(perdida_norm, "perdida_normalizada_ssp245.tif", overwrite=TRUE)

# 3. Combine the layers to obtain the map of critical areas

weights <- c(0.33, 0.34, 0.33)  # Weights for index, human footprint, climate loss
areas_criticas <- (indice_norm * weights[1]) + 
  (huella_norm * weights[2]) + 
  (perdida_norm * weights[3])

# 4. View results
# Visualizing the critical areas map (method 1)
plot(areas_criticas, main = "Critical Areas - SSP245",
     col = rev(hcl.colors(100, "spectral")))

# Overlay biogeographic provinces with borders only
if (inherits(provinces, "sf")) {
  provinces_vect <- vect(provinces)
  plot(provinces_vect, add = TRUE, border = "black", col = NA, lwd = 0.1)
} else if (inherits(provinces, "SpatVector")) {
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.1)
} else {
  # For sp objects
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.1)
}

# 5. Save results
writeRaster(areas_criticas, "Critical_areas_ssp245.tif", overwrite=TRUE)

# Save
png("Critical_areas_ssp245.png", width = 10, height = 8, units = "in", res = 300)
plot(areas_criticas, 
     main = "",
     col = rev(hcl.colors(100, "spectral")),
     axes = FALSE,   
     box = FALSE)    

# Then add the provinces
if (inherits(provinces, "sf")) {
  provinces_vect <- vect(provinces)
  plot(provinces_vect, add = TRUE, border = "black", col = NA, lwd = 0.4)
} else if (inherits(provinces, "SpatVector")) {
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.4)
} else {
  # For sp objects
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.4)
}

dev.off()

#---------- 18. Critical Areas Map spp585 ----------
# 1. Prepare all layers to the same resolution
template_585 <- rast(ext(perdida_final_585), resolution=res(perdida_final_585), crs=crs(perdida_final_585))

# 2. Normalize the values of each layer to have a common scale (0-1)
# Normalization function with explicit NA handling
normalize <- function(x) {
  mn <- min(x, na.rm = TRUE)
  mx <- max(x, na.rm = TRUE)
  if(is.finite(mn) && is.finite(mx) && mx > mn) {
    return((x - mn) / (mx - mn))
  } else {
    return(x)
  }
}

# Normalize each layer
perdida_norm_585 <- app(perdida_final_585, normalize)

# Save normalized layers
writeRaster(perdida_norm_585, "perdida_normalizada_ssp585.tif", overwrite=TRUE)

# 3. Combine the layers to obtain the map of critical areas
weights <- c(0.33, 0.34, 0.33)  # Weights for index, human footprint, climate loss
areas_criticas_585 <- (indice_norm * weights[1]) + 
  (huella_norm * weights[2]) + 
  (perdida_norm_585 * weights[3])

# 4. View results
# Visualizing the critical areas map (method 1)
plot(areas_criticas_585, main = "Critical Areas - SSP585",
     col = rev(hcl.colors(100, "spectral")))

# Overlay biogeographic provinces with borders only
if (inherits(provinces, "sf")) {
  provinces_vect <- vect(provinces)
  plot(provinces_vect, add = TRUE, border = "black", col = NA, lwd = 0.1)
} else if (inherits(provinces, "SpatVector")) {
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.1)
} else {
  # For sp objects
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.1)
}

# 5. Save results
writeRaster(areas_criticas_585, "Critical_areas_ssp585.tif", overwrite=TRUE)

# Save
png("Critical_areas_ssp585.png", width = 10, height = 8, units = "in", res = 300)
plot(areas_criticas_585, 
     main = "",
     col = rev(hcl.colors(100, "spectral")),
     axes = FALSE,   
     box = FALSE)    

# Then add the provinces
if (inherits(provinces, "sf")) {
  provinces_vect <- vect(provinces)
  plot(provinces_vect, add = TRUE, border = "black", col = NA, lwd = 0.4)
} else if (inherits(provinces, "SpatVector")) {
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.4)
} else {
  # Para objetos sp
  plot(provinces, add = TRUE, border = "black", col = NA, lwd = 0.4)
}

dev.off()

#---------- 19. Priority Provinces ----------
# 1. Load the raster file directly
areas_criticas_raster <- raster("Critical_areas_ssp245.tif")  # Ajusta esta ruta

# 2. Extract median values by province
province_values <- extract(areas_criticas_raster, provinces, fun = median, na.rm = TRUE)

# 3. Create dataframe with results
priority_provinces <- data.frame(
  Provincia = provinces$Provincias,
  Valor_Critico_Mediano = province_values
)

# 4. Order from highest to lowest
priority_provinces <- priority_provinces[order(priority_provinces$Valor_Critico_Mediano, decreasing = TRUE), ]

# 5. Save as CVS
write.csv(priority_provinces, "provincias_prioritarias-ssp245.csv", row.names = FALSE)

# 6. Show the 10 most important provinces
head(priority_provinces, 10)

####################### END ###########################
