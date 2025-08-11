# ===================================================================
# Basic API Exploration with IPMA Weather Service
# Part 1: Understanding how to systematically investigate unknown APIs
# ===================================================================

# This script demonstrates systematic approaches to exploring complex APIs
# using Portugal's IPMA weather service as a practical example. The techniques
# shown here apply broadly to any weather API or complex data service.

# Load required packages for API communication and data manipulation
library(httr)      # Handles HTTP requests to web APIs
library(jsonlite)  # Converts JSON responses into R data structures
library(lubridate) # Manages dates, times, and time zones
library(dplyr)     # Provides data manipulation functions

# ===================================================================
# SYSTEMATIC API INVESTIGATION APPROACH
# ===================================================================

# When encountering an unfamiliar API, start with basic connectivity testing
# before attempting complex data extraction. This systematic approach prevents
# confusion between network problems and data structure challenges.

print("=== BASIC API CONNECTIVITY TEST ===")

# IPMA provides open access to Portuguese weather data through REST APIs
# Start by testing the most basic endpoint to verify connectivity
base_url <- "https://api.ipma.pt/open-data/"

# Test basic connectivity with a simple GET request
test_response <- GET(paste0(base_url, "observation/meteorology/stations/stations.json"))

# Always check HTTP status codes before attempting to parse response data
# Status code 200 indicates successful data retrieval
if (status_code(test_response) == 200) {
  print("✓ Successfully connected to IPMA API")
  print(paste("Response time:", round(test_response$times[["total"]], 2), "seconds"))
} else {
  print(paste("✗ Connection failed with status code:", status_code(test_response)))
  stop("Cannot proceed without API connectivity")
}

# ===================================================================
# RAW DATA EXAMINATION TECHNIQUE
# ===================================================================

# Before parsing JSON responses, examine the raw content to understand
# the fundamental data organization. This prevents assumptions about
# structure that might not match reality.

print("\n=== RAW DATA STRUCTURE ANALYSIS ===")

# Retrieve raw response content as text before any automatic parsing
raw_content <- content(test_response, "text")

# Basic content characteristics provide initial insights about data organization
print(paste("Total response length:", nchar(raw_content), "characters"))

# Examine the beginning of the response to identify JSON structure type
first_500_chars <- substr(raw_content, 1, 500)
print("First 500 characters of raw JSON:")
print(first_500_chars)

# Identify whether the response contains a JSON array or object
first_non_whitespace <- substr(trimws(raw_content), 1, 1)
if (first_non_whitespace == "[") {
  print("✓ Data appears to be a JSON array (list of elements)")
} else if (first_non_whitespace == "{") {
  print("✓ Data appears to be a JSON object (key-value pairs)")
} else {
  print("⚠ Data may not be in standard JSON format")
}

# ===================================================================
# CONTROLLED JSON PARSING
# ===================================================================

# Parse the JSON response using systematic error handling to catch
# formatting problems before they disrupt your analysis workflow

print("\n=== CONTROLLED JSON PARSING ===")

# Attempt JSON parsing with error handling to catch malformed responses
parsed_data <- tryCatch({
  fromJSON(raw_content)
}, error = function(e) {
  print(paste("JSON parsing error:", e$message))
  return(NULL)
})

# Verify successful parsing before proceeding with structure analysis
if (!is.null(parsed_data)) {
  print("✓ JSON parsing successful")
  
  # Examine the top-level structure that R created from the JSON
  print(paste("Parsed data type:", class(parsed_data)))
  
  if (is.data.frame(parsed_data)) {
    print(paste("Data frame dimensions:", nrow(parsed_data), "rows x", ncol(parsed_data), "columns"))
    print("Column names:")
    print(names(parsed_data))
  } else if (is.list(parsed_data)) {
    print(paste("List with", length(parsed_data), "elements"))
    print("Element names:")
    print(names(parsed_data))
  }
} else {
  stop("Cannot proceed without successful JSON parsing")
}

# ===================================================================
# SYSTEMATIC STRUCTURE EXPLORATION
# ===================================================================

# Use systematic exploration to understand nested data organization
# without making assumptions about how information should be structured

print("\n=== SYSTEMATIC STRUCTURE EXPLORATION ===")

# The str() function provides hierarchical views of complex data structures
# Limit depth to avoid overwhelming output from deeply nested structures
print("Overall data structure (limited to 2 levels deep):")
str(parsed_data, max.level = 2)

# For GeoJSON data (common in weather APIs), look for geographic feature patterns
if (is.data.frame(parsed_data) && "geometry" %in% names(parsed_data)) {
  print("\n✓ Data appears to follow GeoJSON format")
  print("GeoJSON typically separates spatial and attribute information")
  
  # Examine geometry structure for coordinate information
  if ("geometry" %in% names(parsed_data)) {
    print("Geometry structure:")
    str(parsed_data$geometry, max.level = 1)
  }
  
  # Examine properties structure for descriptive attributes
  if ("properties" %in% names(parsed_data)) {
    print("Properties structure:")
    str(parsed_data$properties, max.level = 1)
  }
}

# ===================================================================
# SAMPLE DATA EXAMINATION
# ===================================================================

# Examine actual data content to understand values and formats
# rather than just structural organization

print("\n=== SAMPLE DATA EXAMINATION ===")

# For data frames, show sample rows to understand content patterns
if (is.data.frame(parsed_data)) {
  print("Sample of the first 3 rows:")
  print(head(parsed_data, 3))
  
  # If this appears to be station data, look for common meteorological patterns
  if ("properties" %in% names(parsed_data)) {
    properties_sample <- head(parsed_data$properties, 3)
    print("Sample properties data:")
    print(properties_sample)
    
    # Look for station identification patterns
    if ("idEstacao" %in% names(properties_sample)) {
      print("✓ Found station ID field: idEstacao")
    }
    if ("localEstacao" %in% names(properties_sample)) {
      print("✓ Found station location field: localEstacao")
    }
  }
}

# ===================================================================
# VALIDATION AND QUALITY CHECKS
# ===================================================================

# Implement basic validation to verify that the data contains reasonable
# meteorological information rather than test data or error messages

print("\n=== DATA VALIDATION CHECKS ===")

# Count the number of records to assess data completeness
if (is.data.frame(parsed_data)) {
  record_count <- nrow(parsed_data)
  print(paste("Total number of weather stations:", record_count))
  
  # Reasonable range for a national weather network
  if (record_count > 50 && record_count < 1000) {
    print("✓ Station count appears reasonable for a national network")
  } else if (record_count < 10) {
    print("⚠ Very few stations - might indicate API problems")
  } else if (record_count > 1000) {
    print("⚠ Very many stations - might include test or historical data")
  }
}

# Check for coordinate data that falls within Portuguese geographic bounds
if ("geometry" %in% names(parsed_data) && "coordinates" %in% names(parsed_data$geometry)) {
  coordinates_list <- parsed_data$geometry$coordinates
  
  # Extract longitude and latitude values for geographic validation
  if (length(coordinates_list) > 0) {
    longitudes <- sapply(coordinates_list, function(x) x[1])
    latitudes <- sapply(coordinates_list, function(x) x[2])
    
    print(paste("Longitude range:", round(min(longitudes), 2), "to", round(max(longitudes), 2)))
    print(paste("Latitude range:", round(min(latitudes), 2), "to", round(max(latitudes), 2)))
    
    # Portugal's approximate geographic bounds for validation
    portugal_west <- -9.6    # Westernmost point
    portugal_east <- -6.2    # Easternmost point  
    portugal_south <- 36.9   # Southernmost point
    portugal_north <- 42.2   # Northernmost point
    
    # Check if coordinates fall within reasonable Portuguese bounds
    coords_valid <- all(longitudes >= portugal_west & longitudes <= portugal_east &
                       latitudes >= portugal_south & latitudes <= portugal_north)
    
    if (coords_valid) {
      print("✓ Coordinates appear to be within Portuguese territory")
    } else {
      print("⚠ Some coordinates may be outside Portuguese territory")
    }
  }
}

# ===================================================================
# EXPLORATION SUMMARY AND NEXT STEPS
# ===================================================================

print("\n=== EXPLORATION SUMMARY ===")

# Summarize what we've learned about the API structure
print("Key discoveries from systematic API exploration:")
print("1. IPMA uses GeoJSON format for geographic weather station data")
print("2. Station information is organized in nested properties objects")
print("3. Geographic coordinates are stored in separate geometry objects")
print("4. The API provides comprehensive coverage of Portuguese weather stations")

print("\nNext steps for data extraction:")
print("- Navigate nested structures to extract station identifications")
print("- Convert GeoJSON coordinates to usable latitude/longitude pairs")
print("- Filter stations by geographic region for targeted monitoring")
print("- Test observations API to understand current weather data structure")

# ===================================================================
# DIAGNOSTIC FUNCTION FOR REUSE
# ===================================================================

# Create a reusable function that applies this systematic exploration
# approach to any weather API endpoint

explore_weather_api <- function(endpoint_url, description = "Unknown endpoint") {
  cat("\n=== EXPLORING:", description, "===\n")
  
  # Test connectivity and basic response characteristics
  response <- GET(endpoint_url)
  cat("Status code:", status_code(response), "\n")
  
  if (status_code(response) == 200) {
    # Examine content characteristics
    raw_content <- content(response, "text")
    cat("Content length:", nchar(raw_content), "characters\n")
    
    # Parse and examine structure
    parsed_data <- fromJSON(raw_content)
    cat("Data type:", class(parsed_data), "\n")
    
    if (is.data.frame(parsed_data)) {
      cat("Dimensions:", nrow(parsed_data), "x", ncol(parsed_data), "\n")
    } else if (is.list(parsed_data)) {
      cat("List elements:", length(parsed_data), "\n")
    }
    
    return(parsed_data)
  } else {
    cat("Request failed - cannot examine structure\n")
    return(NULL)
  }
}

# Example usage of the diagnostic function
print("\n=== TESTING DIAGNOSTIC FUNCTION ===")
stations_data <- explore_weather_api(
  "https://api.ipma.pt/open-data/observation/meteorology/stations/stations.json",
  "IPMA Weather Stations"
)

print("\n✓ Basic API exploration complete!")
print("You now have the foundation for systematic weather API investigation")
print("Proceed to station data extraction to build geographic filtering capabilities")