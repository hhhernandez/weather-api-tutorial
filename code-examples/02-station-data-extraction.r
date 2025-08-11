# ===================================================================
# Station Data Extraction and Geographic Filtering
# Part 2: Converting complex nested structures into analysis-ready data
# ===================================================================

# This script demonstrates how to navigate GeoJSON weather station data
# and create geographic filters for targeted regional monitoring.
# The techniques work with any weather API that follows GeoJSON standards.

# Load required packages
library(httr)
library(jsonlite)
library(dplyr)

# ===================================================================
# RETRIEVING STATION METADATA
# ===================================================================

# Start by retrieving the complete weather station dataset that we
# explored in the previous script. This forms the foundation for all
# subsequent geographic filtering and monitoring activities.

print("=== RETRIEVING COMPLETE STATION DATASET ===")

stations_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/stations.json"
stations_response <- GET(stations_url)

# Verify successful data retrieval before proceeding
if (status_code(stations_response) == 200) {
  print("✓ Successfully retrieved station metadata")
  
  # Parse the JSON response using the understanding gained from basic exploration
  stations_data <- fromJSON(content(stations_response, "text"))
  print(paste("Retrieved information for", nrow(stations_data), "weather stations"))
} else {
  stop(paste("Failed to retrieve station data. Status code:", status_code(stations_response)))
}

# ===================================================================
# UNDERSTANDING GEOJSON NESTED STRUCTURE
# ===================================================================

# GeoJSON organizes geographic information into logical components that
# separate spatial data from descriptive attributes. Understanding this
# organization enables efficient data extraction for analysis.

print("\n=== ANALYZING GEOJSON STRUCTURE ===")

# Examine the top-level organization that separates different data types
print("Top-level data organization:")
print(names(stations_data))

# The geometry component contains spatial information (coordinates, location type)
print("\nGeometry structure (spatial information):")
str(stations_data$geometry, max.level = 1)

# The properties component contains descriptive attributes (IDs, names, metadata)
print("\nProperties structure (descriptive attributes):")
str(stations_data$properties, max.level = 1)

# The type component indicates this follows GeoJSON feature format
print(paste("\nGeoJSON feature type:", unique(stations_data$type)))

# ===================================================================
# EXTRACTING STATION IDENTIFICATION DATA
# ===================================================================

# Convert the nested properties structure into a flat data frame
# that supports familiar data manipulation operations like filtering and sorting

print("\n=== EXTRACTING STATION IDENTIFICATION ===")

# Access the nested properties data frame directly
station_properties <- stations_data$properties

print("Available station identification fields:")
print(names(station_properties))

# Display sample station information to understand content patterns
print("\nSample station identification data:")
print(head(station_properties, 3))

# Verify that we have the essential identification fields needed for monitoring
required_fields <- c("idEstacao", "localEstacao")
available_fields <- names(station_properties)

if (all(required_fields %in% available_fields)) {
  print("✓ Found all required station identification fields")
} else {
  missing_fields <- setdiff(required_fields, available_fields)
  warning(paste("Missing required fields:", paste(missing_fields, collapse = ", ")))
}

# ===================================================================
# EXTRACTING COORDINATE INFORMATION
# ===================================================================

# Geographic coordinates require special handling because they're stored
# as nested lists within the geometry structure rather than simple columns

print("\n=== EXTRACTING COORDINATE INFORMATION ===")

# Access the nested coordinates list from the geometry structure
coordinates_list <- stations_data$geometry$coordinates

print(paste("Retrieved coordinates for", length(coordinates_list), "stations"))

# Each coordinate element contains a pair: [longitude, latitude]
# Examine the first few coordinates to understand the format
print("Sample coordinate pairs (longitude, latitude):")
for (i in 1:3) {
  coord_pair <- coordinates_list[[i]]
  print(paste("Station", i, ":", coord_pair[1], ",", coord_pair[2]))
}

# Convert the list of coordinate pairs into separate longitude and latitude vectors
# This transformation makes geographic calculations much easier to perform
longitudes <- sapply(coordinates_list, function(coord_pair) coord_pair[1])
latitudes <- sapply(coordinates_list, function(coord_pair) coord_pair[2])

print("Coordinate extraction results:")
print(paste("Longitude range:", round(min(longitudes), 3), "to", round(max(longitudes), 3)))
print(paste("Latitude range:", round(min(latitudes), 3), "to", round(max(latitudes), 3)))

# ===================================================================
# CREATING COMPREHENSIVE STATION DATABASE
# ===================================================================

# Combine identification and coordinate information into a single
# data frame that supports all subsequent analysis and filtering operations

print("\n=== CREATING COMPREHENSIVE STATION DATABASE ===")

# Build a complete station database with all essential information
complete_stations <- data.frame(
  station_id = station_properties$idEstacao,           # Unique numerical identifier
  station_name = station_properties$localEstacao,     # Human-readable location name
  longitude = longitudes,                             # East-west coordinate (degrees)
  latitude = latitudes,                              # North-south coordinate (degrees)
  stringsAsFactors = FALSE                          # Preserve text as character data
)

print("Complete station database structure:")
print(str(complete_stations))

print("\nSample entries from complete database:")
print(head(complete_stations))

# Validate that the data transformation preserved all information correctly
print(paste("Original station count:", nrow(stations_data)))
print(paste("Processed station count:", nrow(complete_stations)))

if (nrow(complete_stations) == nrow(stations_data)) {
  print("✓ Data transformation preserved all station records")
} else {
  warning("Data transformation may have lost some station records")
}

# ===================================================================
# GEOGRAPHIC FILTERING TECHNIQUES
# ===================================================================

# Implement systematic approaches for filtering weather stations by
# geographic criteria to focus monitoring on specific regions

print("\n=== GEOGRAPHIC FILTERING TECHNIQUES ===")

# Define the Algarve region boundaries as an example of targeted monitoring
# These coordinates encompass the southernmost region of Portugal
algarve_boundaries <- list(
  west = -9.0,     # Westernmost longitude of interest
  east = -7.0,     # Easternmost longitude of interest
  south = 36.9,    # Southernmost latitude of interest
  north = 37.5     # Northernmost latitude of interest
)

print("Algarve region boundaries:")
print(algarve_boundaries)

# Apply geographic boundary filtering to identify relevant stations
algarve_stations <- complete_stations[
  complete_stations$longitude >= algarve_boundaries$west &
  complete_stations$longitude <= algarve_boundaries$east &
  complete_stations$latitude >= algarve_boundaries$south &
  complete_stations$latitude <= algarve_boundaries$north,
]

print(paste("Stations within Algarve boundaries:", nrow(algarve_stations)))
print("Algarve region stations:")
print(algarve_stations[, c("station_id", "station_name", "longitude", "latitude")])

# ===================================================================
# NAME-BASED FILTERING TECHNIQUES
# ===================================================================

# Supplement geographic filtering with name-based searches to capture
# stations that might be just outside boundary boxes but still relevant

print("\n=== NAME-BASED FILTERING TECHNIQUES ===")

# Define target city patterns for agricultural monitoring
# Include variations and abbreviations commonly used in station names
target_cities_pattern <- "Faro|Tavira|Olhão|EPPO|Lagos|Portimão|Sagres|Albufeira"

# Apply pattern matching to station names (case-insensitive)
nearby_stations <- complete_stations[
  grepl(target_cities_pattern, complete_stations$station_name, ignore.case = TRUE),
]

print(paste("Stations matching target city patterns:", nrow(nearby_stations)))
print("Target city stations:")
print(nearby_stations[, c("station_id", "station_name", "longitude", "latitude")])

# ===================================================================
# COMBINING FILTERING APPROACHES
# ===================================================================

# Merge geographic and name-based filtering to ensure comprehensive
# coverage without duplicating stations that meet multiple criteria

print("\n=== COMBINING FILTERING APPROACHES ===")

# Use rbind to combine both filtering results, then remove duplicates
combined_stations <- unique(rbind(algarve_stations, nearby_stations))

print(paste("Total relevant stations after combining approaches:", nrow(combined_stations)))
print("Combined station list:")
print(combined_stations[order(combined_stations$station_name), ])

# Create a final curated list for agricultural monitoring
relevant_stations <- combined_stations
print(paste("Final monitoring network:", nrow(relevant_stations), "stations"))

# ===================================================================
# DISTANCE CALCULATIONS FOR SPATIAL ANALYSIS
# ===================================================================

# Implement distance calculations to understand spatial coverage
# and identify potential gaps in your monitoring network

print("\n=== SPATIAL COVERAGE ANALYSIS ===")

# Haversine formula for calculating distances on Earth's surface
calculate_distance_km <- function(lat1, lon1, lat2, lon2) {
  # Earth's radius in kilometers
  R <- 6371
  
  # Convert coordinates to radians
  lat1_rad <- lat1 * pi / 180
  lon1_rad <- lon1 * pi / 180
  lat2_rad <- lat2 * pi / 180
  lon2_rad <- lon2 * pi / 180
  
  # Calculate coordinate differences
  dlat <- lat2_rad - lat1_rad
  dlon <- lon2_rad - lon1_rad
  
  # Apply Haversine formula
  a <- sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1-a))
  distance <- R * c
  
  return(round(distance, 1))
}

# Calculate distances between all pairs of monitoring stations
if (nrow(relevant_stations) > 1) {
  print("Distances between monitoring stations:")
  
  for (i in 1:(nrow(relevant_stations)-1)) {
    for (j in (i+1):nrow(relevant_stations)) {
      distance <- calculate_distance_km(
        relevant_stations$latitude[i], relevant_stations$longitude[i],
        relevant_stations$latitude[j], relevant_stations$longitude[j]
      )
      
      station1 <- relevant_stations$station_name[i]
      station2 <- relevant_stations$station_name[j]
      
      print(paste(station1, "↔", station2, ":", distance, "km"))
      
      # Identify potential coverage gaps (stations more than 50km apart)
      if (distance > 50) {
        print(paste("  ⚠ Large gap detected:", distance, "km"))
      }
    }
  }
}

# ===================================================================
# MONITORING NETWORK OPTIMIZATION
# ===================================================================

# Analyze your station network to ensure optimal coverage for
# agricultural monitoring applications

print("\n=== MONITORING NETWORK OPTIMIZATION ===")

# Calculate geographic statistics for coverage assessment
center_longitude <- mean(relevant_stations$longitude)
center_latitude <- mean(relevant_stations$latitude)

print("Network geographic center:")
print(paste("Longitude:", round(center_longitude, 4)))
print(paste("Latitude:", round(center_latitude, 4)))

# Calculate the geographic extent of your monitoring network
longitude_range <- max(relevant_stations$longitude) - min(relevant_stations$longitude)
latitude_range <- max(relevant_stations$latitude) - min(relevant_stations$latitude)

print("Network geographic extent:")
print(paste("Longitude span:", round(longitude_range, 3), "degrees"))
print(paste("Latitude span:", round(latitude_range, 3), "degrees"))

# Assess station density for agricultural monitoring suitability
total_area_approx <- longitude_range * latitude_range * (111 * 111)  # Rough conversion to km²
station_density <- nrow(relevant_stations) / total_area_approx

print(paste("Approximate station density:", round(station_density * 1000, 2), "stations per 1000 km²"))

# Agricultural monitoring typically requires stations within 25-50km for good coverage
if (station_density * 1000 > 1) {
  print("✓ Good station density for agricultural monitoring")
} else {
  print("⚠ Consider additional stations for comprehensive agricultural coverage")
}

# ===================================================================
# EXPORT FUNCTIONS FOR REUSE
# ===================================================================

# Create reusable functions that apply these filtering techniques
# to any geographic region or set of target locations

filter_stations_by_region <- function(stations_df, west, east, south, north) {
  # Filter stations within specified geographic boundaries
  filtered <- stations_df[
    stations_df$longitude >= west &
    stations_df$longitude <= east &
    stations_df$latitude >= south &
    stations_df$latitude <= north,
  ]
  return(filtered)
}

filter_stations_by_names <- function(stations_df, name_pattern) {
  # Filter stations matching specified name patterns
  filtered <- stations_df[
    grepl(name_pattern, stations_df$station_name, ignore.case = TRUE),
  ]
  return(filtered)
}

# ===================================================================
# SUMMARY AND NEXT STEPS
# ===================================================================

print("\n=== STATION EXTRACTION SUMMARY ===")

print("Successfully completed station data extraction with:")
print(paste("-", nrow(complete_stations), "total weather stations processed"))
print(paste("-", nrow(relevant_stations), "stations selected for agricultural monitoring"))
print("- Geographic and name-based filtering techniques demonstrated")
print("- Distance calculations implemented for spatial analysis")
print("- Reusable filtering functions created for future applications")

print("\nYour curated monitoring network includes:")
for (i in 1:nrow(relevant_stations)) {
  station <- relevant_stations[i, ]
  print(paste("-", station$station_name, "(ID:", station$station_id, ")"))
}

print("\nNext steps:")
print("- Use these station IDs to retrieve current weather observations")
print("- Implement automated data collection for continuous monitoring")
print("- Develop time-series analysis for agricultural decision support")

# Save the station database for use in subsequent scripts
save(relevant_stations, complete_stations, file = "station_database.RData")
print("\n✓ Station database saved to 'station_database.RData'")

print("Station data extraction complete! Proceed to observations data extraction.")