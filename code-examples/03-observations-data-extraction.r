# ===================================================================
# Weather Observations Data Extraction and Processing
# Part 3: Navigating complex time-first data organization
# ===================================================================

# This script demonstrates how to extract current weather observations
# from APIs that use time-first data organization. This pattern appears
# in many meteorological APIs because it reflects how weather professionals
# think about simultaneous regional conditions.

# Load required packages
library(httr)
library(jsonlite)
library(lubridate)
library(dplyr)

# Load the station database created in the previous script
if (file.exists("station_database.RData")) {
  load("station_database.RData")
  print("✓ Loaded station database from previous script")
} else {
  stop("Station database not found. Please run 02-station-data-extraction.R first")
}

# ===================================================================
# UNDERSTANDING TIME-FIRST DATA ORGANIZATION
# ===================================================================

# Many weather APIs organize observations with timestamps as primary keys,
# containing all simultaneous station measurements within each time period.
# This structure initially appears complex but proves elegant for meteorological analysis.

print("=== INVESTIGATING OBSERVATIONS API STRUCTURE ===")

observations_url <- "https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json"
observations_response <- GET(observations_url)

# Verify successful data retrieval
if (status_code(observations_response) == 200) {
  print("✓ Successfully connected to observations API")
  
  # Examine raw content characteristics before parsing
  raw_content <- content(observations_response, "text")
  print(paste("Raw response length:", nchar(raw_content), "characters"))
  
  # Look at content structure to understand organization
  print("First 800 characters of raw observations data:")
  print(substr(raw_content, 1, 800))
  
} else {
  stop(paste("Failed to retrieve observations. Status code:", status_code(observations_response)))
}

# ===================================================================
# PARSING TIME-ORGANIZED OBSERVATIONS
# ===================================================================

# Parse the JSON response and examine the time-first organization structure
# This reveals how meteorological APIs prioritize temporal synchronization

print("\n=== PARSING TIME-ORGANIZED STRUCTURE ===")

observations_data <- fromJSON(raw_content)

print("Observations data structure:")
print(class(observations_data))
print(paste("Number of timestamp periods:", length(observations_data)))

# Examine the timestamp keys to understand temporal coverage
timestamp_keys <- names(observations_data)
print("Available observation timestamps:")
print(head(timestamp_keys, 10))  # Show first 10 timestamps

# Parse timestamps to understand time range and intervals
if (length(timestamp_keys) > 0) {
  # Convert timestamp strings to datetime objects
  parsed_timestamps <- ymd_hm(timestamp_keys, tz = "Europe/Lisbon")
  
  print("Temporal coverage analysis:")
  print(paste("Earliest observation:", min(parsed_timestamps, na.rm = TRUE)))
  print(paste("Latest observation:", max(parsed_timestamps, na.rm = TRUE)))
  
  # Calculate time intervals between observations
  if (length(parsed_timestamps) > 1) {
    time_intervals <- diff(parsed_timestamps)
    print(paste("Typical interval between observations:", 
                as.numeric(mode(time_intervals)), "hours"))
  }
}

# ===================================================================
# NAVIGATING NESTED STATION DATA
# ===================================================================

# Within each timestamp, station data is organized as key-value pairs
# where keys are station IDs and values are measurement objects

print("\n=== EXAMINING STATION DATA WITHIN TIMESTAMPS ===")

# Examine the structure within a single timestamp period
if (length(observations_data) > 0) {
  first_timestamp <- names(observations_data)[1]
  first_period_data <- observations_data[[first_timestamp]]
  
  print(paste("Examining data for timestamp:", first_timestamp))
  print(paste("Number of stations reporting:", length(first_period_data)))
  
  # Look at the station IDs reporting in this time period
  reporting_stations <- names(first_period_data)
  print("Sample of station IDs reporting:")
  print(head(reporting_stations, 10))
  
  # Examine the measurement structure for one station
  if (length(reporting_stations) > 0) {
    sample_station_id <- reporting_stations[1]
    sample_measurements <- first_period_data[[sample_station_id]]
    
    print(paste("Sample measurements from station", sample_station_id, ":"))
    if (!is.null(sample_measurements)) {
      print(names(sample_measurements))
      print(sample_measurements)
    } else {
      print("Station data is null (maintenance or sensor issues)")
    }
  }
}

# ===================================================================
# EXTRACTING TARGET STATION OBSERVATIONS
# ===================================================================

# Use the station database from the previous script to extract observations
# specifically from your agricultural monitoring network

print("\n=== EXTRACTING TARGET STATION OBSERVATIONS ===")

# Convert station IDs to character format for matching with API keys
target_station_ids <- as.character(relevant_stations$station_id)
print("Target station IDs for extraction:")
print(target_station_ids)

# Navigate through timestamps to find observations from target stations
target_observations <- list()
observation_count <- 0

for (timestamp in names(observations_data)) {
  time_period_data <- observations_data[[timestamp]]
  
  # Find which target stations have data in this time period
  available_stations <- names(time_period_data)
  target_matches <- intersect(target_station_ids, available_stations)
  
  if (length(target_matches) > 0) {
    print(paste("Timestamp", timestamp, "- Found data for", length(target_matches), "target stations"))
    
    # Extract observations from each target station
    for (station_id in target_matches) {
      station_obs <- time_period_data[[station_id]]
      
      # Only process non-null observations
      if (!is.null(station_obs)) {
        # Find station name from our database
        station_name <- relevant_stations$station_name[relevant_stations$station_id == as.numeric(station_id)]
        
        # Store the complete observation with metadata
        obs_key <- paste(timestamp, station_id, sep = "_")
        target_observations[[obs_key]] <- list(
          timestamp = timestamp,
          station_id = station_id,
          station_name = station_name,
          measurements = station_obs
        )
        
        observation_count <- observation_count + 1
      }
    }
  }
}

print(paste("Successfully extracted", observation_count, "observations from target stations"))

# ===================================================================
# UNDERSTANDING MEASUREMENT PARAMETERS
# ===================================================================

# Examine the measurement parameters available in the observations
# to understand what environmental data is provided

print("\n=== ANALYZING MEASUREMENT PARAMETERS ===")

if (length(target_observations) > 0) {
  # Examine measurement parameters from the first observation
  first_obs <- target_observations[[1]]
  measurements <- first_obs$measurements
  
  print("Available measurement parameters:")
  print(names(measurements))
  
  # Explain the meteorological parameters in agricultural context
  parameter_explanations <- list(
    "temperatura" = "Air temperature (°C) - affects plant growth rates and stress",
    "humidade" = "Relative humidity (%) - influences disease pressure and transpiration",
    "pressao" = "Atmospheric pressure (hPa) - indicates weather pattern stability",
    "intensidadeVento" = "Wind speed (m/s) - affects spray applications and pollination",
    "intensidadeVentoKM" = "Wind speed (km/h) - same as above in different units",
    "idDireccVento" = "Wind direction code - important for spray drift calculations",
    "radiacao" = "Solar radiation (W/m²) - drives photosynthesis and energy balance",
    "precAcumulada" = "Accumulated precipitation (mm) - critical for irrigation decisions"
  )
  
  print("\nParameter explanations for agricultural applications:")
  for (param in names(measurements)) {
    if (param %in% names(parameter_explanations)) {
      print(paste("•", param, ":", parameter_explanations[[param]]))
    }
  }
  
  # Identify missing data indicators
  print("\nExamining data quality indicators:")
  for (param in names(measurements)) {
    value <- measurements[[param]]
    if (value == -99.0) {
      print(paste("•", param, ": Missing data (sensor maintenance or malfunction)"))
    } else {
      print(paste("•", param, ":", value, "- Valid measurement"))
    }
  }
}

# ===================================================================
# CONVERTING TO STRUCTURED DATA FRAME
# ===================================================================

# Transform the nested observations into a clean data frame suitable
# for time-series analysis and agricultural decision-making

print("\n=== CREATING STRUCTURED OBSERVATIONS DATA FRAME ===")

if (length(target_observations) > 0) {
  # Initialize vectors to store data frame components
  df_timestamps <- character()
  df_station_ids <- character()
  df_station_names <- character()
  df_temperatures <- numeric()
  df_humidity <- numeric()
  df_pressure <- numeric()
  df_wind_speed <- numeric()
  df_radiation <- numeric()
  df_precipitation <- numeric()
  
  # Extract data from each observation into separate vectors
  for (obs_key in names(target_observations)) {
    obs <- target_observations[[obs_key]]
    measurements <- obs$measurements
    
    # Handle missing values (IPMA uses -99.0 for missing data)
    temp_val <- ifelse(measurements$temperatura == -99.0, NA, measurements$temperatura)
    humid_val <- ifelse(measurements$humidade == -99.0, NA, measurements$humidade)
    press_val <- ifelse(measurements$pressao == -99.0, NA, measurements$pressao)
    wind_val <- ifelse(measurements$intensidadeVentoKM == -99.0, NA, measurements$intensidadeVentoKM)
    rad_val <- ifelse(measurements$radiacao == -99.0, NA, measurements$radiacao)
    precip_val <- ifelse(measurements$precAcumulada == -99.0, NA, measurements$precAcumulada)
    
    # Append to our vectors
    df_timestamps <- c(df_timestamps, obs$timestamp)
    df_station_ids <- c(df_station_ids, obs$station_id)
    df_station_names <- c(df_station_names, obs$station_name)
    df_temperatures <- c(df_temperatures, temp_val)
    df_humidity <- c(df_humidity, humid_val)
    df_pressure <- c(df_pressure, press_val)
    df_wind_speed <- c(df_wind_speed, wind_val)
    df_radiation <- c(df_radiation, rad_val)
    df_precipitation <- c(df_precipitation, precip_val)
  }
  
  # Create the structured data frame with proper data types
  weather_observations <- data.frame(
    timestamp = as.POSIXct(df_timestamps, format = "%Y-%m-%dT%H:%M", tz = "Europe/Lisbon"),
    station_id = df_station_ids,
    station_name = df_station_names,
    temperature_c = df_temperatures,
    humidity_percent = df_humidity,
    pressure_hpa = df_pressure,
    wind_speed_kmh = df_wind_speed,
    solar_radiation_wm2 = df_radiation,
    precipitation_mm = df_precipitation,
    stringsAsFactors = FALSE
  )
  
  # Sort by timestamp for logical time-series organization
  weather_observations <- weather_observations[order(weather_observations$timestamp), ]
  
  print("Structured weather observations data frame created:")
  print(str(weather_observations))
  
  print("\nSample of extracted weather observations:")
  print(head(weather_observations))
  
} else {
  stop("No observations were successfully extracted from target stations")
}

# ===================================================================
# AGRICULTURAL CONDITION ANALYSIS
# ===================================================================

# Analyze current conditions to demonstrate agricultural decision support
# capabilities enabled by systematic weather data extraction

print("\n=== AGRICULTURAL CONDITIONS ANALYSIS ===")

# Calculate summary statistics for agricultural decision-making
current_conditions <- weather_observations %>%
  filter(timestamp == max(timestamp, na.rm = TRUE)) %>%
  summarise(
    observation_time = first(timestamp),
    avg_temperature = round(mean(temperature_c, na.rm = TRUE), 1),
    min_temperature = round(min(temperature_c, na.rm = TRUE), 1),
    max_temperature = round(max(temperature_c, na.rm = TRUE), 1),
    avg_humidity = round(mean(humidity_percent, na.rm = TRUE), 1),
    max_wind_speed = round(max(wind_speed_kmh, na.rm = TRUE), 1),
    total_stations = n()
  )

print("Current regional conditions summary:")
print(current_conditions)

# Agricultural decision support indicators
print("\nAgricultural decision indicators:")

# Temperature stress assessment
if (current_conditions$max_temperature > 35) {
  print("🌡️ HIGH TEMPERATURE ALERT: Potential heat stress conditions")
  print("   → Consider postponing field work during midday hours")
  print("   → Monitor irrigation needs closely")
} else if (current_conditions$max_temperature > 30) {
  print("🌡️ MODERATE HEAT: Monitor crop stress indicators")
} else {
  print("🌡️ TEMPERATURE: Favorable conditions for most operations")
}

# Humidity and disease pressure assessment
if (current_conditions$avg_humidity > 80) {
  print("💧 HIGH HUMIDITY: Increased disease pressure risk")
  print("   → Delay fungicide applications until humidity drops")
  print("   → Monitor for foliar disease development")
} else if (current_conditions$avg_humidity < 30) {
  print("💧 LOW HUMIDITY: Potential plant stress and increased irrigation needs")
} else {
  print("💧 HUMIDITY: Favorable conditions for most agricultural activities")
}

# Wind conditions for spray applications
if (current_conditions$max_wind_speed > 20) {
  print("💨 HIGH WIND WARNING: Unsuitable for spray applications")
  print("   → Risk of drift and uneven coverage")
  print("   → Postpone pesticide and fertilizer applications")
} else if (current_conditions$max_wind_speed > 10) {
  print("💨 MODERATE WIND: Use caution with spray applications")
  print("   → Consider wind direction and drift potential")
} else {
  print("💨 WIND: Favorable conditions for spray applications")
}

# ===================================================================
# TIME SERIES VISUALIZATION PREPARATION
# ===================================================================

# Prepare the data for time-series analysis and visualization
# to support agricultural monitoring dashboards

print("\n=== PREPARING TIME SERIES DATA ===")

# Calculate hourly averages across all stations for regional trends
hourly_averages <- weather_observations %>%
  group_by(timestamp) %>%
  summarise(
    avg_temperature = mean(temperature_c, na.rm = TRUE),
    avg_humidity = mean(humidity_percent, na.rm = TRUE),
    avg_pressure = mean(pressure_hpa, na.rm = TRUE),
    max_wind_speed = max(wind_speed_kmh, na.rm = TRUE),
    total_precipitation = sum(precipitation_mm, na.rm = TRUE),
    station_count = n(),
    .groups = "drop"
  )

print("Hourly regional averages prepared:")
print(str(hourly_averages))

# Identify temperature trends for agricultural planning
if (nrow(hourly_averages) > 1) {
  recent_temp_trend <- diff(tail(hourly_averages$avg_temperature, 2))
  if (recent_temp_trend > 2) {
    print("📈 TEMPERATURE TREND: Rapidly warming conditions")
  } else if (recent_temp_trend < -2) {
    print("📉 TEMPERATURE TREND: Rapidly cooling conditions")
  } else {
    print("📊 TEMPERATURE TREND: Stable conditions")
  }
}

# ===================================================================
# DATA EXPORT AND PERSISTENCE
# ===================================================================

# Save the extracted observations for use in dashboard development
# and long-term agricultural monitoring applications

print("\n=== SAVING EXTRACTED DATA ===")

# Save both detailed observations and hourly summaries
save(weather_observations, hourly_averages, relevant_stations, 
     file = "weather_monitoring_data.RData")

# Also export to CSV for use in other applications
write.csv(weather_observations, "detailed_weather_observations.csv", row.names = FALSE)
write.csv(hourly_averages, "hourly_weather_summaries.csv", row.names = FALSE)

print("✓ Weather data saved to multiple formats:")
print("  • weather_monitoring_data.RData (R format)")
print("  • detailed_weather_observations.csv")
print("  • hourly_weather_summaries.csv")

# ===================================================================
# AUTOMATED COLLECTION FUNCTION
# ===================================================================

# Create a reusable function for automated weather data collection
# that can be scheduled for continuous agricultural monitoring

collect_weather_observations <- function(station_ids, save_to_file = TRUE) {
  # Robust weather data collection with error handling
  tryCatch({
    # Retrieve current observations
    response <- GET("https://api.ipma.pt/open-data/observation/meteorology/stations/observations.json")
    
    if (status_code(response) == 200) {
      observations_data <- fromJSON(content(response, "text"))
      
      # Extract observations using the same logic as above
      target_observations <- list()
      
      for (timestamp in names(observations_data)) {
        time_period_data <- observations_data[[timestamp]]
        available_stations <- names(time_period_data)
        target_matches <- intersect(as.character(station_ids), available_stations)
        
        for (station_id in target_matches) {
          station_obs <- time_period_data[[station_id]]
          if (!is.null(station_obs)) {
            obs_key <- paste(timestamp, station_id, sep = "_")
            target_observations[[obs_key]] <- list(
              timestamp = timestamp,
              station_id = station_id,
              measurements = station_obs
            )
          }
        }
      }
      
      if (save_to_file) {
        timestamp_str <- format(Sys.time(), "%Y%m%d_%H%M%S")
        filename <- paste0("weather_data_", timestamp_str, ".RData")
        save(target_observations, file = filename)
      }
      
      return(target_observations)
      
    } else {
      warning(paste("API request failed with status:", status_code(response)))
      return(NULL)
    }
    
  }, error = function(e) {
    warning(paste("Data collection error:", e$message))
    return(NULL)
  })
}

# ===================================================================
# SUMMARY AND NEXT STEPS
# ===================================================================

print("\n=== OBSERVATIONS EXTRACTION SUMMARY ===")

print("Successfully completed weather observations extraction:")
print(paste("• Processed", length(observations_data), "temporal observation periods"))
print(paste("• Extracted", nrow(weather_observations), "individual station observations"))
print(paste("• Covered", length(unique(weather_observations$station_id)), "unique monitoring stations"))
print(paste("• Time range:", min(weather_observations$timestamp), "to", max(weather_observations$timestamp)))

print("\nKey agricultural monitoring capabilities enabled:")
print("• Real-time temperature and humidity monitoring for stress assessment")
print("• Wind speed tracking for spray application timing")
print("• Precipitation monitoring for irrigation scheduling")
print("• Solar radiation data for energy balance calculations")
print("• Multi-station regional averaging for microclimate analysis")

print("\nNext development steps:")
print("• Implement automated data collection scheduling")
print("• Develop SQLite database for long-term data storage")
print("• Create interactive dashboard for real-time monitoring")
print("• Add forecast data integration for predictive planning")
print("• Implement alert systems for critical agricultural conditions")

print("\n✓ Weather observations extraction complete!")
print("You now have comprehensive weather monitoring capabilities for agricultural applications.")