
# --- 1. INSTALL & LOAD PACKAGES ---
#install.packages(c("dplyr", "randomForest", "caret"))
library(dplyr)
library(randomForest)
library(caret)
library(jsonlite)


# --- 2. INGEST FORECAST CSV FROM DATABRIDGE ---
forecast <- read.csv("C:/Users/Dicks/ProgramingProjects/ProjectDataBridge/data/ensemble_input.csv", stringsAsFactors = FALSE)
forecast$forecast_datetime <- as.POSIXct(forecast$forecast_datetime, format="%Y-%m-%d %H:%M")
forecast$hour <- as.integer(format(forecast$forecast_datetime, "%H"))

cat("Forecast rows loaded:", nrow(forecast), "\n")
print(head(forecast))


# --- 3. READ USER PROFILE ---
profile <- fromJSON("user_profile.json")

cat("\nUser:", profile$name, "\n")
cat("Location:", profile$location, "\n")
cat("Temp sensitivity:", profile$temperature_sensitivity, "\n")
cat("Rain aversion:", profile$rain_aversion, "\n")
cat("Occasion:", profile$occasion, "\n")


# --- 4. DERIVE DAY-LEVEL FEATURES FROM 24 HOURLY ROWS ---
morning   <- forecast %>% filter(hour >= 6,  hour <= 9)
afternoon <- forecast %>% filter(hour >= 12, hour <= 15)
evening   <- forecast %>% filter(hour >= 17, hour <= 20)

day_summary <- data.frame(
  morning_temp    = mean(morning$apparent_temperature),
  afternoon_temp  = mean(afternoon$apparent_temperature),
  evening_temp    = mean(evening$apparent_temperature),
  max_precip      = max(forecast$precipitation_probability),
  any_rain        = as.integer(max(forecast$precipitation_probability) >= 50),
  temp_swing      = max(forecast$apparent_temperature) - min(forecast$apparent_temperature),
  avg_wind        = mean(forecast$wind_speed),
  avg_humidity    = mean(forecast$humidity)
)

cat("\nDay Summary:\n")
print(day_summary)


# --- 5. GENERATE SYNTHETIC TRAINING DATA ---
set.seed(42)
n <- 600

synthetic <- data.frame(
  morning_temp   = runif(n, 10, 95),
  afternoon_temp = runif(n, 15, 100),
  evening_temp   = runif(n, 10, 90),
  max_precip     = sample(0:100, n, replace = TRUE),
  any_rain       = sample(0:1, n, replace = TRUE),
  temp_swing     = runif(n, 0, 30),
  avg_wind       = runif(n, 0, 40),
  avg_humidity   = runif(n, 20, 95)
)

# Rule-based labeling — what a person would actually wear
synthetic$outfit <- case_when(
  synthetic$morning_temp < 35                                    ~ "heavy_coat",
  synthetic$morning_temp < 50 & synthetic$any_rain == 1         ~ "coat_and_rain_gear",
  synthetic$morning_temp < 50                                    ~ "light_coat",
  synthetic$morning_temp < 65 & synthetic$any_rain == 1         ~ "jacket_and_umbrella",
  synthetic$morning_temp < 65                                    ~ "jacket",
  synthetic$afternoon_temp >= 75 & synthetic$any_rain == 0      ~ "light_layers",
  synthetic$any_rain == 1                                        ~ "umbrella_reminder",
  TRUE                                                           ~ "light_layers"
)

synthetic$outfit <- as.factor(synthetic$outfit)
cat("\nSynthetic data label distribution:\n")
print(table(synthetic$outfit))


# --- 6. SANITY CHECK — CONFIRM MERGE SHAPE IS CORRECT ---
cat("\nSynthetic dataframe ready for model training.\n")
cat("Rows:", nrow(synthetic), "| Columns:", ncol(synthetic), "\n")
cat("\nDay 1 complete. Ready for model training in Day 2.\n")
