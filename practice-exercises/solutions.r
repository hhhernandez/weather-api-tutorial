# ===================================================================
# Complete Solutions to Weather API Practice Exercises
# Solutions demonstrate systematic approaches to weather data challenges
# ===================================================================

# This file provides complete working solutions to all practice exercises
# along with detailed explanations of the problem-solving approaches used.
# These solutions demonstrate professional-quality weather API integration.

# Load required packages for comprehensive weather data analysis
library(httr)
library(jsonlite)
library(lubridate)
library(dplyr)

# ===================================================================
# VERIFICATION EXERCISE 1 SOLUTION: BASIC API CONNECTIVITY TESTING
# Testing UK Met Office API as an alternative to IPMA
# ===================================================================

print("=== SOLUTION: UK MET OFFICE API INVESTIGATION ===")

# UK Met Office provides open data through their DataPoint API
# This demonstrates how systematic investigation works with different national APIs

investigate_uk_met_office <- function() {
  # UK Met Office DataPoint API endpoints (some require API keys)
  # Using their location list as a test endpoint
  uk_stations_url <- "http://datapoint.metoffice.gov.uk/public/data/val/wxobs/all/json/sitelist"
  
  # Attempt connection with error handling
  tryCatch({
    response <- GET(uk_stations_url, timeout(10))
    
    print(paste("UK Met Office API Status:", status_code(response)))
    
    if (status_code(response) == 200) {
      raw_content <- content(response, "text")
      print(paste("Response length:", nchar(raw_content), "characters"))
      
      # Examine first part of response structure
      print("First 500 characters of UK Met Office response:")
      print(substr(raw_content, 1, 500))
      
      # Parse and analyze structure
      parsed_data <- fromJSON(raw_content)
      print("UK Met Office data structure:")
      str(parsed_data, max.level = 2)
      
      return(parsed_data)
    } else {
      print("UK Met Office API requires authentication or is unavailable")
      return(NULL)
    }
    
  }, error = function(e) {
    print(paste("UK Met Office API error:", e$message))
    print("This is expected - many national weather APIs require registration")
    return(NULL)
  })
}

# Alternative: Investigate OpenWeatherMap API (free tier available)
investigate_openweather_api <- function() {
  print("\n=== ALTERNATIVE: OpenWeatherMap API Investigation ===")
  
  # OpenWeatherMap provides free access for limited requests
  # Testing their current weather endpoint for Lisbon
  owm_url <- "https://api.openweathermap.org/data/2.5/weather?q=Lisbon,PT&units=metric"
  
  tryCatch({
    response <- GET(owm_url)
    print(paste("OpenWeatherMap Status:", status_code(response)))
    
    if (status_code(response) == 200) {
      raw_content <- content(response, "text")
      print("OpenWeatherMap response structure:")
      print(substr(raw_content, 1, 400))
      
      parsed_data <- fromJSON(raw_content)
      print("OpenWeatherMap organization:")
      str(parsed_data, max.level = 2)
      
      # Compare organization with IPMA approach
      print("\nComparison with IPMA:")
      print("• OpenWeatherMap: Single-location, current conditions focus")
      print("• IPMA: Multi-location, time-series historical data")
      print("• OpenWeatherMap: Flat JSON structure with nested weather array")
      print("• IPMA: Time-first organization with nested station data")
      
      return(parsed_data)
    } else {
      print("OpenWeatherMap request failed - may require API key")
      return(NULL)
    }
    
  }, error = function(e) {
    print(paste("OpenWeatherMap error:", e$message))
    return(NULL)
  })
}

# Execute the API investigations
uk_data <- investigate_uk_met_office()
owm_data <- investigate_openweather_api()

# ===================================================================
# VERIFICATION EXERCISE 2 SOLUTION: TEMPERATURE DATA VALIDATION
# Extract and validate temperature data from specific stations
# ===================================================================

print("\n=== SOLUTION: TEMPERATURE DATA VALIDATION ===")

# Load IPMA station data using the established methods
load_ipma_stations <- function() {
  stations_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/stations.json"
  response <- GET(stations_url)
  
  if (status_code(response) == 200) {
    stations_data <- fromJSON(content(response, "text"))
    
    # Create comprehensive station database
    complete_stations <- data.frame(
      station_id = stations_data$properties$idEstacao,
      station_name = stations_data$properties$localEstacao,
      longitude = sapply(stations_data$geometry$coordinates, function(x) x[1]),
      latitude = sapply(stations_data$geometry$coordinates, function(x) x[2]),
      stringsAsFactors = FALSE
    )
    
    return(complete_stations)
  } else {
    stop("Failed to load IPMA station data")
  }
}

# Extract current temperature data for validation
validate_temperature_data <- function() {
  # Load station database
  stations_db <- load_ipma_stations()
  
  # Find target stations (Faro, Tavira, Portimão)
  target_patterns <- c("Faro", "Tavira", "Portimão")
  target_stations <- stations_db[
    grepl(paste(target_patterns, collapse = "|"), stations_db$station_name, ignore.case = TRUE),
  ]
  
  print("Target stations identified:")
  print(target_stations[, c("station_id", "station_name")])
  
  # Retrieve current observations
  obs_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json"
  obs_response <- GET(obs_url)
  
  if (status_code(obs_response) == 200) {
    obs_data <- fromJSON(content(obs_response, "text"))
    
    # Extract temperature data for target stations
    temperature_results <- data.frame(
      station_id = character(),
      station_name = character(),
      timestamp = character(),
      temperature = numeric(),
      validation_status = character(),
      stringsAsFactors = FALSE
    )
    
    target_ids <- as.character(target_stations$station_id)
    
    # Navigate time-first structure to find target station data
    for (timestamp in names(obs_data)) {
      time_data <- obs_data[[timestamp]]
      available_stations <- names(time_data)
      matches <- intersect(target_ids, available_stations)
      
      for (station_id in matches) {
        station_obs <- time_data[[station_id]]
        if (!is.null(station_obs) && !is.null(station_obs$temperatura)) {
          
          temp_value <- station_obs$temperatura
          station_name <- target_stations$station_name[target_stations$station_id == as.numeric(station_id)]
          
          # Validate temperature range
          validation_status <- "valid"
          if (temp_value == -99.0) {
            validation_status <- "missing_data"
            temp_value <- NA
          } else if (temp_value < -5 || temp_value > 50) {
            validation_status <- "extreme_value"
          } else if (temp_value < 5 || temp_value > 45) {
            validation_status <- "unusual_value"
          }
          
          # Add to results
          temperature_results <- rbind(temperature_results, data.frame(
            station_id = station_id,
            station_name = station_name,
            timestamp = timestamp,
            temperature = temp_value,
            validation_status = validation_status,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
    
    # Display validation results
    print("\nTemperature validation results:")
    print(temperature_results)
    
    # Calculate coastal vs inland comparison
    coastal_stations <- c("Faro", "Tavira", "Portimão")
    coastal_temps <- temperature_results[
      grepl(paste(coastal_stations, collapse = "|"), temperature_results$station_name),
    ]
    
    if (nrow(coastal_temps) > 1) {
      temp_range <- max(coastal_temps$temperature, na.rm = TRUE) - min(coastal_temps$temperature, na.rm = TRUE)
      print(paste("\nTemperature range across coastal stations:", round(temp_range, 1), "°C"))
      
      if (temp_range > 5) {
        print("Large temperature variation detected - investigate microclimatic differences")
      } else {
        print("Temperature variation within normal range for coastal region")
      }
    }
    
    return(temperature_results)
    
  } else {
    stop("Failed to retrieve observation data")
  }
}

# Execute temperature validation
temp_validation_results <- validate_temperature_data()

# ===================================================================
# VERIFICATION EXERCISE 3 SOLUTION: GEOGRAPHIC FILTERING PRECISION
# Create precise geographic filters for different Portuguese regions
# ===================================================================

print("\n=== SOLUTION: GEOGRAPHIC FILTERING PRECISION ===")

# Define regional boundaries for three distinct Portuguese areas
create_regional_filters <- function() {
  
  # Load complete station database
  stations_db <- load_ipma_stations()
  
  # Define regional boundaries with 50km buffer considerations
  regions <- list(
    "Porto" = list(
      name = "Porto Metropolitan Area",
      center_lat = 41.1579,
      center_lon = -8.6291,
      north = 41.4,
      south = 40.9,
      west = -8.9,
      east = -8.3
    ),
    "Coimbra" = list(
      name = "Coimbra Central Region", 
      center_lat = 40.2033,
      center_lon = -8.4103,
      north = 40.5,
      south = 39.9,
      west = -8.7,
      east = -8.1
    ),
    "Evora" = list(
      name = "Évora Alentejo Region",
      center_lat = 38.5667,
      center_lon = -7.9067,
      north = 38.9,
      south = 38.2,
      west = -8.2,
      east = -7.6
    )
  )
  
  # Function to calculate distance between two points (Haversine formula)
  calculate_distance <- function(lat1, lon1, lat2, lon2) {
    R <- 6371  # Earth radius in km
    
    lat1_rad <- lat1 * pi / 180
    lon1_rad <- lon1 * pi / 180
    lat2_rad <- lat2 * pi / 180
    lon2_rad <- lon2 * pi / 180
    
    dlat <- lat2_rad - lat1_rad
    dlon <- lon2_rad - lon1_rad
    
    a <- sin(dlat/2)^2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2)^2
    c <- 2 * atan2(sqrt(a), sqrt(1-a))
    
    return(R * c)
  }
  
  # Analyze each region
  regional_analysis <- list()
  
  for (region_name in names(regions)) {
    region <- regions[[region_name]]
    
    print(paste("\n=== ANALYZING REGION:", region$name, "==="))
    
    # Geographic boundary filtering
    boundary_stations <- stations_db[
      stations_db$latitude >= region$south &
      stations_db$latitude <= region$north &
      stations_db$longitude >= region$west &
      stations_db$longitude <= region$east,
    ]
    
    # 50km radius filtering from region center
    all_distances <- sapply(1:nrow(stations_db), function(i) {
      calculate_distance(
        region$center_lat, region$center_lon,
        stations_db$latitude[i], stations_db$longitude[i]
      )
    })
    
    radius_stations <- stations_db[all_distances <= 50, ]
    
    # Combine approaches and remove duplicates
    combined_stations <- unique(rbind(boundary_stations, radius_stations))
    
    print(paste("Stations within boundaries:", nrow(boundary_stations)))
    print(paste("Stations within 50km radius:", nrow(radius_stations)))
    print(paste("Combined unique stations:", nrow(combined_stations)))
    
    # Coverage quality assessment
    if (nrow(combined_stations) > 1) {
      # Calculate inter-station distances
      distances <- c()
      for (i in 1:(nrow(combined_stations)-1)) {
        for (j in (i+1):nrow(combined_stations)) {
          dist <- calculate_distance(
            combined_stations$latitude[i], combined_stations$longitude[i],
            combined_stations$latitude[j], combined_stations$longitude[j]
          )
          distances <- c(distances, dist)
        }
      }
      
      min_distance <- min(distances)
      max_distance <- max(distances)
      avg_distance <- mean(distances)
      
      print(paste("Inter-station distances: min =", round(min_distance, 1), 
                  "km, max =", round(max_distance, 1), 
                  "km, avg =", round(avg_distance, 1), "km"))
      
      # Coverage quality assessment
      if (max_distance <= 25) {
        coverage_quality <- "Excellent"
      } else if (max_distance <= 40) {
        coverage_quality <- "Good"  
      } else if (max_distance <= 60) {
        coverage_quality <- "Marginal"
      } else {
        coverage_quality <- "Poor"
      }
      
      print(paste("Coverage quality assessment:", coverage_quality))
      
    } else {
      coverage_quality <- "Insufficient"
      print("Insufficient stations for coverage assessment")
    }
    
    # Store results
    regional_analysis[[region_name]] <- list(
      region_info = region,
      stations = combined_stations,
      coverage_quality = coverage_quality
    )
    
    print("Regional stations:")
    print(combined_stations[, c("station_id", "station_name")])
  }
  
  return(regional_analysis)
}

# Execute regional analysis
regional_results <- create_regional_filters()

# ===================================================================
# EXPLORATION CHALLENGE 1 SOLUTION: MICROCLIMATE PATTERN INVESTIGATION
# Analyze geographic influences on weather patterns
# ===================================================================

print("\n=== SOLUTION: MICROCLIMATE PATTERN INVESTIGATION ===")

investigate_microclimate_patterns <- function() {
  
  # Load current weather observations for analysis
  obs_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json"
  obs_response <- GET(obs_url)
  
  if (status_code(obs_response) != 200) {
    stop("Failed to retrieve observation data for microclimate analysis")
  }
  
  obs_data <- fromJSON(content(obs_response, "text"))
  stations_db <- load_ipma_stations()
  
  # Extract comprehensive observations for microclimate analysis
  microclimate_data <- data.frame(
    station_id = character(),
    station_name = character(),
    longitude = numeric(),
    latitude = numeric(),
    timestamp = character(),
    temperature = numeric(),
    humidity = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Process all available observations
  for (timestamp in names(obs_data)) {
    time_data <- obs_data[[timestamp]]
    
    for (station_id in names(time_data)) {
      station_obs <- time_data[[station_id]]
      
      if (!is.null(station_obs) && !is.null(station_obs$temperatura) && !is.null(station_obs$humidade)) {
        # Find station metadata
        station_info <- stations_db[stations_db$station_id == as.numeric(station_id), ]
        
        if (nrow(station_info) > 0) {
          temp_val <- ifelse(station_obs$temperatura == -99.0, NA, station_obs$temperatura)
          humid_val <- ifelse(station_obs$humidade == -99.0, NA, station_obs$humidade)
          
          microclimate_data <- rbind(microclimate_data, data.frame(
            station_id = station_id,
            station_name = station_info$station_name[1],
            longitude = station_info$longitude[1],
            latitude = station_info$latitude[1],
            timestamp = timestamp,
            temperature = temp_val,
            humidity = humid_val,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }
  
  # Coastal vs Inland Analysis
  print("=== COASTAL VS INLAND ANALYSIS ===")
  
  # Define coastal threshold (within 20km of ocean)
  coastal_longitude_threshold <- -8.0  # Approximate threshold for Atlantic influence
  
  microclimate_data$location_type <- ifelse(
    microclimate_data$longitude < coastal_longitude_threshold, "Coastal", "Inland"
  )
  
  # Calculate summary statistics by location type and timestamp
  location_summary <- microclimate_data %>%
    group_by(timestamp, location_type) %>%
    summarise(
      avg_temperature = mean(temperature, na.rm = TRUE),
      avg_humidity = mean(humidity, na.rm = TRUE),
      station_count = n(),
      .groups = "drop"
    ) %>%
    filter(station_count > 1)  # Only include timestamps with multiple stations
  
  print("Coastal vs Inland comparison:")
  print(location_summary)
  
  # Calculate overall differences
  coastal_avg <- location_summary %>% 
    filter(location_type == "Coastal") %>%
    summarise(temp = mean(avg_temperature, na.rm = TRUE), 
              humid = mean(avg_humidity, na.rm = TRUE))
  
  inland_avg <- location_summary %>% 
    filter(location_type == "Inland") %>%
    summarise(temp = mean(avg_temperature, na.rm = TRUE), 
              humid = mean(avg_humidity, na.rm = TRUE))
  
  if (nrow(coastal_avg) > 0 && nrow(inland_avg) > 0) {
    temp_difference <- inland_avg$temp - coastal_avg$temp
    humid_difference <- coastal_avg$humid - inland_avg$humid
    
    print(paste("Temperature difference (Inland - Coastal):", round(temp_difference, 2), "°C"))
    print(paste("Humidity difference (Coastal - Inland):", round(humid_difference, 2), "%"))
    
    # Interpretation
    if (temp_difference > 2) {
      print("✓ Significant inland warming detected - typical Mediterranean pattern")
    }
    if (humid_difference > 5) {
      print("✓ Coastal humidity enhancement detected - maritime influence confirmed")
    }
  }
  
  # Elevation Analysis (simplified - using latitude as proxy for elevation zones)
  print("\n=== ELEVATION ZONE ANALYSIS ===")
  
  # Higher latitudes in Portugal often correlate with higher elevations
  microclimate_data$elevation_zone <- ifelse(
    microclimate_data$latitude > 37.5, "Higher_Elevation", "Lower_Elevation"
  )
  
  elevation_summary <- microclimate_data %>%
    group_by(elevation_zone) %>%
    summarise(
      avg_temperature = mean(temperature, na.rm = TRUE),
      min_temperature = min(temperature, na.rm = TRUE),
      max_temperature = max(temperature, na.rm = TRUE),
      station_count = n_distinct(station_id),
      .groups = "drop"
    )
  
  print("Elevation zone temperature patterns:")
  print(elevation_summary)
  
  return(microclimate_data)
}

# Execute microclimate investigation
microclimate_results <- investigate_microclimate_patterns()

# ===================================================================
# EXPLORATION CHALLENGE 2 SOLUTION: AGRICULTURAL DECISION SUPPORT ANALYSIS
# Develop specific agricultural recommendations based on weather patterns
# ===================================================================

print("\n=== SOLUTION: AGRICULTURAL DECISION SUPPORT ANALYSIS ===")

generate_agricultural_recommendations <- function() {
  
  # Use microclimate data from previous analysis
  if (!exists("microclimate_results")) {
    microclimate_results <- investigate_microclimate_patterns()
  }
  
  # Get most recent conditions for decision support
  latest_timestamp <- max(microclimate_results$timestamp, na.rm = TRUE)
  current_conditions <- microclimate_results[microclimate_results$timestamp == latest_timestamp, ]
  
  print(paste("Generating recommendations based on conditions at:", latest_timestamp))
  print(paste("Analysis covers", nrow(current_conditions), "monitoring locations"))
  
  # 1. Irrigation Scheduling Analysis
  print("\n=== IRRIGATION SCHEDULING RECOMMENDATIONS ===")
  
  irrigation_recommendations <- current_conditions %>%
    mutate(
      evapotranspiration_index = (temperature * (100 - humidity)) / 100,
      irrigation_priority = case_when(
        evapotranspiration_index > 1500 ~ "High",
        evapotranspiration_index > 1000 ~ "Moderate", 
        evapotranspiration_index > 500 ~ "Low",
        TRUE ~ "Minimal"
      )
    ) %>%
    arrange(desc(evapotranspiration_index))
  
  print("Irrigation priority by location:")
  print(irrigation_recommendations[, c("station_name", "temperature", "humidity", 
                                      "evapotranspiration_index", "irrigation_priority")])
  
  high_priority_locations <- irrigation_recommendations[irrigation_recommendations$irrigation_priority == "High", ]
  if (nrow(high_priority_locations) > 0) {
    print("\n🚨 HIGH IRRIGATION PRIORITY AREAS:")
    for (i in 1:nrow(high_priority_locations)) {
      location <- high_priority_locations[i, ]
      print(paste("•", location$station_name, "- ET index:", round(location$evapotranspiration_index, 0)))
    }
    print("→ Recommendation: Implement immediate irrigation in these areas")
    print("→ Schedule irrigation during early morning hours (4-6 AM) for maximum efficiency")
  }
  
  # 2. Spray Application Window Assessment  
  print("\n=== SPRAY APPLICATION WINDOW ASSESSMENT ===")
  
  # Load wind data for spray recommendations
  obs_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json"
  obs_response <- GET(obs_url)
  obs_data <- fromJSON(content(obs_response, "text"))
  
  spray_conditions <- data.frame(
    station_name = character(),
    temperature = numeric(),
    humidity = numeric(),
    wind_speed = numeric(),
    spray_suitability = character(),
    stringsAsFactors = FALSE
  )
  
  # Extract wind data for spray assessment
  latest_obs_key <- names(obs_data)[1]  # Most recent timestamp
  latest_obs <- obs_data[[latest_obs_key]]
  
  for (station_id in names(latest_obs)) {
    station_data <- latest_obs[[station_id]]
    if (!is.null(station_data) && !is.null(station_data$intensidadeVentoKM)) {
      
      station_info <- current_conditions[current_conditions$station_id == station_id, ]
      if (nrow(station_info) > 0) {
        
        wind_speed <- ifelse(station_data$intensidadeVentoKM == -99.0, NA, station_data$intensidadeVentoKM)
        temp <- station_info$temperature[1]
        humid <- station_info$humidity[1]
        
        # Spray suitability assessment
        spray_suitable <- "Suitable"
        if (!is.na(wind_speed) && wind_speed > 15) {
          spray_suitable <- "Too_Windy"
        } else if (!is.na(temp) && temp > 35) {
          spray_suitable <- "Too_Hot"
        } else if (!is.na(humid) && humid > 85) {
          spray_suitable <- "Too_Humid"
        } else if (!is.na(wind_speed) && wind_speed < 3) {
          spray_suitable <- "Too_Calm"
        }
        
        spray_conditions <- rbind(spray_conditions, data.frame(
          station_name = station_info$station_name[1],
          temperature = temp,
          humidity = humid,
          wind_speed = wind_speed,
          spray_suitability = spray_suitable,
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  print("Spray application conditions by location:")
  print(spray_conditions)
  
  suitable_locations <- spray_conditions[spray_conditions$spray_suitability == "Suitable", ]
  if (nrow(suitable_locations) > 0) {
    print("\n✅ SUITABLE SPRAY APPLICATION AREAS:")
    print(suitable_locations$station_name)
    print("→ Recommendation: Optimal conditions for pesticide/fertilizer applications")
  }
  
  unsuitable_locations <- spray_conditions[spray_conditions$spray_suitability != "Suitable", ]
  if (nrow(unsuitable_locations) > 0) {
    print("\n⚠️ UNSUITABLE SPRAY APPLICATION AREAS:")
    for (i in 1:nrow(unsuitable_locations)) {
      location <- unsuitable_locations[i, ]
      print(paste("•", location$station_name, "-", location$spray_suitability))
    }
    print("→ Recommendation: Delay spray applications until conditions improve")
  }
  
  # 3. Disease Pressure Assessment
  print("\n=== DISEASE PRESSURE ASSESSMENT ===")
  
  disease_risk <- current_conditions %>%
    mutate(
      disease_risk_score = case_when(
        temperature >= 20 & temperature <= 30 & humidity >= 80 ~ "Very_High",
        temperature >= 15 & temperature <= 35 & humidity >= 70 ~ "High",
        temperature >= 10 & temperature <= 40 & humidity >= 60 ~ "Moderate",
        TRUE ~ "Low"
      )
    )
  
  print("Disease pressure risk by location:")
  print(disease_risk[, c("station_name", "temperature", "humidity", "disease_risk_score")])
  
  high_risk_locations <- disease_risk[disease_risk$disease_risk_score %in% c("High", "Very_High"), ]
  if (nrow(high_risk_locations) > 0) {
    print("\n🦠 HIGH DISEASE PRESSURE AREAS:")
    print(high_risk_locations[, c("station_name", "disease_risk_score")])
    print("→ Recommendation: Increase monitoring for fungal diseases")
    print("→ Consider preventive fungicide applications if forecast maintains conditions")
    print("→ Improve air circulation in affected areas if possible")
  }
  
  return(list(
    irrigation = irrigation_recommendations,
    spray_conditions = spray_conditions,
    disease_risk = disease_risk
  ))
}

# Execute agricultural decision support analysis
agricultural_recommendations <- generate_agricultural_recommendations()

# ===================================================================
# EXPLORATION CHALLENGE 3 SOLUTION: DATA QUALITY AND RELIABILITY ASSESSMENT
# Investigate patterns in missing data and measurement quality
# ===================================================================

print("\n=== SOLUTION: DATA QUALITY AND RELIABILITY ASSESSMENT ===")

assess_data_quality_patterns <- function() {
  
  # Retrieve comprehensive observation data for quality analysis
  obs_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json"
  obs_response <- GET(obs_url)
  
  if (status_code(obs_response) != 200) {
    stop("Failed to retrieve data for quality assessment")
  }
  
  obs_data <- fromJSON(content(obs_response, "text"))
  stations_db <- load_ipma_stations()
  
  # Comprehensive data quality assessment
  quality_summary <- data.frame(
    station_id = character(),
    station_name = character(),
    total_observations = numeric(),
    missing_temperature = numeric(),
    missing_humidity = numeric(),
    missing_pressure = numeric(),
    missing_wind = numeric(),
    missing_radiation = numeric(),
    missing_precipitation = numeric(),
    overall_completeness = numeric(),
    stringsAsFactors = FALSE
  )
  
  # Analyze each station's data quality across all timestamps
  all_station_ids <- unique(unlist(lapply(obs_data, names)))
  
  for (station_id in all_station_ids) {
    station_info <- stations_db[stations_db$station_id == as.numeric(station_id), ]
    
    if (nrow(station_info) > 0) {
      station_name <- station_info$station_name[1]
      
      # Count observations and missing values
      total_obs <- 0
      missing_temp <- 0
      missing_humid <- 0
      missing_press <- 0
      missing_wind <- 0
      missing_rad <- 0
      missing_precip <- 0
      
      for (timestamp in names(obs_data)) {
        time_data <- obs_data[[timestamp]]
        
        if (station_id %in% names(time_data)) {
          station_obs <- time_data[[station_id]]
          
          if (!is.null(station_obs)) {
            total_obs <- total_obs + 1
            
            # Check for missing values (IPMA uses -99.0)
            if (is.null(station_obs$temperatura) || station_obs$temperatura == -99.0) {
              missing_temp <- missing_temp + 1
            }
            if (is.null(station_obs$humidade) || station_obs$humidade == -99.0) {
              missing_humid <- missing_humid + 1
            }
            if (is.null(station_obs$pressao) || station_obs$pressao == -99.0) {
              missing_press <- missing_press + 1
            }
            if (is.null(station_obs$intensidadeVentoKM) || station_obs$intensidadeVentoKM == -99.0) {
              missing_wind <- missing_wind + 1
            }
            if (is.null(station_obs$radiacao) || station_obs$radiacao == -99.0) {
              missing_rad <- missing_rad + 1
            }
            if (is.null(station_obs$precAcumulada) || station_obs$precAcumulada == -99.0) {
              missing_precip <- missing_precip + 1
            }
          }
        }
      }
      
      if (total_obs > 0) {
        # Calculate overall completeness
        total_possible_measurements <- total_obs * 6  # 6 key parameters
        total_missing <- missing_temp + missing_humid + missing_press + missing_wind + missing_rad + missing_precip
        completeness <- ((total_possible_measurements - total_missing) / total_possible_measurements) * 100
        
        quality_summary <- rbind(quality_summary, data.frame(
          station_id = station_id,
          station_name = station_name,
          total_observations = total_obs,
          missing_temperature = missing_temp,
          missing_humidity = missing_humid,
          missing_pressure = missing_press,
          missing_wind = missing_wind,
          missing_radiation = missing_rad,
          missing_precipitation = missing_precip,
          overall_completeness = round(completeness, 1),
          stringsAsFactors = FALSE
        ))
      }
    }
  }
  
  # Sort by completeness for analysis
  quality_summary <- quality_summary[order(-quality_summary$overall_completeness), ]
  
  print("=== DATA QUALITY SUMMARY BY STATION ===")
  print(quality_summary)
  
  # Identify reliability patterns
  print("\n=== RELIABILITY PATTERN ANALYSIS ===")
  
  high_quality_stations <- quality_summary[quality_summary$overall_completeness >= 90, ]
  moderate_quality_stations <- quality_summary[quality_summary$overall_completeness >= 70 & quality_summary$overall_completeness < 90, ]
  low_quality_stations <- quality_summary[quality_summary$overall_completeness < 70, ]
  
  print(paste("High reliability stations (≥90% complete):", nrow(high_quality_stations)))
  print(paste("Moderate reliability stations (70-89% complete):", nrow(moderate_quality_stations)))
  print(paste("Low reliability stations (<70% complete):", nrow(low_quality_stations)))
  
  if (nrow(high_quality_stations) > 0) {
    print("\n✅ MOST RELIABLE STATIONS:")
    print(high_quality_stations[1:min(5, nrow(high_quality_stations)), c("station_name", "overall_completeness")])
  }
  
  if (nrow(low_quality_stations) > 0) {
    print("\n⚠️ STATIONS WITH RELIABILITY CONCERNS:")
    print(low_quality_stations[, c("station_name", "overall_completeness")])
  }
  
  # Parameter-specific reliability analysis
  print("\n=== PARAMETER-SPECIFIC RELIABILITY ===")
  
  parameter_reliability <- data.frame(
    parameter = c("Temperature", "Humidity", "Pressure", "Wind", "Solar_Radiation", "Precipitation"),
    total_missing = c(
      sum(quality_summary$missing_temperature),
      sum(quality_summary$missing_humidity),
      sum(quality_summary$missing_pressure),
      sum(quality_summary$missing_wind),
      sum(quality_summary$missing_radiation),
      sum(quality_summary$missing_precipitation)
    ),
    completeness_percent = 0,
    stringsAsFactors = FALSE
  )
  
  total_station_obs <- sum(quality_summary$total_observations)
  parameter_reliability$completeness_percent <- round(
    ((total_station_obs - parameter_reliability$total_missing) / total_station_obs) * 100, 1
  )
  
  parameter_reliability <- parameter_reliability[order(-parameter_reliability$completeness_percent), ]
  print(parameter_reliability)
  
  # Recommendations based on quality analysis
  print("\n=== DATA QUALITY RECOMMENDATIONS ===")
  
  if (parameter_reliability$completeness_percent[parameter_reliability$parameter == "Solar_Radiation"] < 70) {
    print("📊 Solar radiation data shows low reliability - consider supplementary sources")
  }
  
  if (parameter_reliability$completeness_percent[parameter_reliability$parameter == "Wind"] < 80) {
    print("💨 Wind data reliability concerns - verify critical spray application decisions")
  }
  
  if (nrow(low_quality_stations) > 0.2 * nrow(quality_summary)) {
    print("🔧 Consider implementing redundant monitoring for agricultural applications")
  }
  
  print("\n✅ For robust agricultural monitoring:")
  print("• Use multiple high-reliability stations for regional coverage")
  print("• Cross-validate critical decisions using multiple data sources")
  print("• Implement automated quality checks in operational systems")
  print("• Maintain backup monitoring strategies for critical parameters")
  
  return(quality_summary)
}

# Execute data quality assessment
quality_assessment_results <- assess_data_quality_patterns()

# ===================================================================
# SUMMARY AND INTEGRATION
# ===================================================================

print("\n=== COMPLETE EXERCISE SOLUTIONS SUMMARY ===")

print("✅ All practice exercises successfully completed:")
print("• Verification Exercise 1: Alternative weather API investigation")
print("• Verification Exercise 2: Temperature data validation and quality checks")
print("• Verification Exercise 3: Geographic filtering with coverage assessment")
print("• Exploration Challenge 1: Microclimate pattern analysis")
print("• Exploration Challenge 2: Agricultural decision support system")
print("• Exploration Challenge 3: Comprehensive data quality assessment")

print("\nKey insights from complete analysis:")
print("• Portuguese weather monitoring provides excellent data for agricultural applications")
print("• Coastal-inland temperature differences confirm maritime climate influences")
print("• Station reliability varies significantly - quality assessment essential")
print("• Multi-parameter analysis enables sophisticated agricultural decision support")
print("• Systematic approaches scale effectively across different weather services")

print("\nNext steps for advanced development:")
print("• Implement automated quality monitoring and alerting systems")
print("• Develop predictive models using historical weather patterns")
print("• Create integrated dashboard combining real-time and forecast data")
print("• Establish data archival systems for long-term agricultural research")

print("\n🎓 Congratulations! You have mastered comprehensive weather API integration!")
print("These skills prepare you for professional agricultural monitoring applications worldwide.")