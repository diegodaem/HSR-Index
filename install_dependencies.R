# HSR Index - Automatic Dependencies Installation
# Esquivel et al. (2025) Nature Communications
# 
# This script automatically installs all required R packages
# to run the HSR Index analysis
#
# Usage: source("install_dependencies.R")

cat("================================================================\n")
cat("HSR INDEX - DEPENDENCIES INSTALLATION\n")
cat("Racing Against Time to Unveil Hidden Bat Diversity\n")
cat("Esquivel et al. (2025) Nature Communications\n")
cat("================================================================\n\n")

# List of required packages
required_packages <- c(
  # Spatial and geographic analysis
  "sf",           # Simple Features 
  "terra",        # Raster analysis 
  "raster",       # Raster analysis
  "units",        # Spatial units handling
  
  # Data manipulation and analysis
  "dplyr",        # Data manipulation
  "tidyr",        # Data organization
  "tidyverse",    # Complete tidy package suite
  "readr",        # Efficient file reading
  
  # Visualization
  "ggplot2",      # Advanced graphics
  "gridExtra"    # Multiple plot arrangements
  
)

# Function to install packages if they are not available
install_if_missing <- function(packages) {
  # Check which ones are missing
  missing_packages <- c()
  
  for (pkg in packages) {
    if (!require(pkg, character.only = TRUE, quietly = TRUE)) {
      missing_packages <- c(missing_packages, pkg)
    }
  }
  
  # Install missing ones
  if (length(missing_packages) > 0) {
    cat("Installing missing packages:\n")
    for (pkg in missing_packages) {
      cat(paste("  -> Installing:", pkg, "\n"))
      install.packages(pkg, dependencies = TRUE, repos = "https://cran.r-project.org/")
    }
  } else {
    cat("✓ All packages are already installed\n")
  }
}

# Install missing packages
cat("Checking and installing required packages...\n")
install_if_missing(required_packages)

# Final verification
cat("\n================================================================\n")
cat("INSTALLATION VERIFICATION:\n")
cat("================================================================\n")

installation_success <- TRUE
for (pkg in required_packages) {
  tryCatch({
    library(pkg, character.only = TRUE, quietly = TRUE)
    version_info <- packageVersion(pkg)
    cat(sprintf("✓ %-15s v%s\n", pkg, version_info))
  }, error = function(e) {
    cat(sprintf("✗ %-15s ERROR\n", pkg))
    installation_success <- FALSE
  })
}

cat("\n")
if (installation_success) {
  cat("✓ SUCCESSFUL INSTALLATION - All packages are ready\n")
  cat("✓ You can proceed to run the HSR analysis\n")
} else {
  cat("✗ INSTALLATION PROBLEMS DETECTED\n")
  cat("  Please check the errors above\n")
  cat("  Try manually installing the failed packages\n")
}

# System information for debugging
cat("\n================================================================\n")
cat("SYSTEM INFORMATION:\n")
cat("================================================================\n")
cat("R version:", R.version.string, "\n")
cat("Platform: ", R.version$platform, "\n")
cat("OS:       ", Sys.info()["sysname"], Sys.info()["version"], "\n")

cat("\n================================================================\n")
cat("DEPENDENCIES INSTALLATION COMPLETED\n")
cat("================================================================\n")
