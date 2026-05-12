
# ---INSTALL & LOAD PACKAGES ---
#install.packages(c("dplyr", "randomForest", "caret"))
library(dplyr)
library(randomForest)
library(caret)
library(jsonlite)


# ---INGEST FORECAST CSV FROM DATABRIDGE ---
forecast <- read.csv("C:/Users/Dicks/ProgramingProjects/ProjectDataBridge/data/ensemble_input.csv", stringsAsFactors = FALSE)
forecast$forecast_datetime <- as.POSIXct(forecast$forecast_datetime, format="%Y-%m-%d %H:%M")
forecast$hour <- as.integer(format(forecast$forecast_datetime, "%H"))

#cat("Forecast rows loaded:", nrow(forecast), "\n")
#print(head(forecast))


# --- READ USER PROFILE ---
profile <- fromJSON("user_profile.json")

cat("\nUser:", profile$name, "\n")
cat("Location:", profile$location, "\n")
cat("Temp sensitivity:", profile$temperature_sensitivity, "\n")
cat("Rain aversion:", profile$rain_aversion, "\n")
cat("Occasion:", profile$occasion, "\n")


# ---DERIVE DAY-LEVEL FEATURES FROM 24 HOURLY ROWS ---
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

#cat("\nDay Summary:\n")
#print(day_summary)


# ---GENERATE SYNTHETIC TRAINING DATA ---
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
#cat("\nSynthetic data label distribution:\n")
#print(table(synthetic$outfit))

# ---APPLY USER PREFERENCE MODIFIERS ---
temp_offset <- case_when(
  profile$temperature_sensitivity == "runs_cold" ~ 5,
  profile$temperature_sensitivity == "runs_warm" ~ -5,
  TRUE ~ 0
)

rain_threshold <- case_when(
  profile$rain_aversion == "high"   ~ 30,
  profile$rain_aversion == "medium" ~ 50,
  TRUE                              ~ 70
)

#cat("\nUser modifier — temp offset:", temp_offset, "°F | Rain threshold:", rain_threshold, "%\n")


# ---TRAIN RANDOM FOREST MODEL ---
set.seed(42)
train_index <- createDataPartition(synthetic$outfit, p = 0.8, list = FALSE)
train_data  <- synthetic[train_index, ]
test_data   <- synthetic[-train_index, ]

rf_model <- randomForest(
  outfit ~ morning_temp + afternoon_temp + evening_temp +
    max_precip + any_rain + temp_swing + avg_wind + avg_humidity,
  data       = train_data,
  ntree      = 100,
  importance = TRUE
)

#cat("\nModel trained on", nrow(train_data), "rows.\n")
#print(rf_model)


# ---VALIDATE MODEL ---
predictions     <- predict(rf_model, test_data)
conf_matrix     <- confusionMatrix(predictions, test_data$outfit)

#cat("\nValidation Accuracy:", round(conf_matrix$overall["Accuracy"] * 100, 1), "%\n")
#print(conf_matrix$table)


# ---. INFERENCE — RUN TODAY'S FORECAST THROUGH THE MODEL ---
# Apply user temp offset to day summary before prediction
inference_input <- day_summary
inference_input$morning_temp   <- inference_input$morning_temp   + temp_offset
inference_input$afternoon_temp <- inference_input$afternoon_temp + temp_offset
inference_input$evening_temp   <- inference_input$evening_temp   + temp_offset

# Override any_rain based on user's rain aversion threshold
inference_input$any_rain <- as.integer(day_summary$max_precip >= rain_threshold)

raw_prediction  <- predict(rf_model, inference_input, type = "prob")
outfit_label    <- predict(rf_model, inference_input)
confidence      <- round(max(raw_prediction) * 100, 1)

cat("\n============================================\n")
cat("  ENSEMBLE — WARDROBE RECOMMENDATION\n")
cat("============================================\n")
cat("  User:       ", profile$name, "\n")
cat("  Location:   ", profile$location, "\n")
cat("  Occasion:   ", profile$occasion, "\n")
cat("--------------------------------------------\n")
cat("  Morning temp:  ", round(day_summary$morning_temp, 1), "°F\n")
cat("  Afternoon temp:", round(day_summary$afternoon_temp, 1), "°F\n")
cat("  Rain chance:   ", day_summary$max_precip, "%\n")
cat("  Temp swing:    ", round(day_summary$temp_swing, 1), "°F\n")
cat("--------------------------------------------\n")

# --- NATURAL LANGUAGE OUTPUT ---
outfit_phrase <- case_when(
  as.character(outfit_label) == "heavy_coat"       ~ "Bundle up — it's going to be a fridgid. You'll want a heavy coat today.",
  as.character(outfit_label) == "coat_and_rain_gear" ~ "Cold and wet — grab your heaviest coat and don't forget rain gear.",
  as.character(outfit_label) == "light_coat"       ~ "It's a bit chilly out there. A light coat should keep you comfortable.",
  as.character(outfit_label) == "jacket_and_umbrella" ~ "Cool and rainy — a jacket and umbrella will cover you.",
  as.character(outfit_label) == "jacket"           ~ "A jacket is the smart move today. You'll appreciate it in the morning.",
  as.character(outfit_label) == "umbrella_reminder" ~ "Temperatures are looking mild but there is a chance of rain — don't leave without an umbrella.",
  as.character(outfit_label) == "light_layers"     ~ "Nice day ahead. Light layers will keep you flexible as temperatures shift.",
  TRUE ~ "Check the forecast and dress accordingly."
)

swing_note <- if (day_summary$temp_swing >= 20) {
  paste0("  Note: A ", round(day_summary$temp_swing, 0),
         "°F swing is expected today — dress in layers you can remove.\n")
} else ""

rain_note <- if (inference_input$any_rain == 1) {
  paste0("  Rain alert: ", day_summary$max_precip,
         "% chance of precipitation — plan accordingly.\n")
} else ""

cat("  Recommendation:", toupper(gsub("_", " ", as.character(outfit_label))), "\n")
cat("  Confidence:    ", confidence, "%\n")
cat("============================================\n")
cat("\n", outfit_phrase, "\n")
if (nchar(swing_note) > 0) cat(swing_note)
if (nchar(rain_note)  > 0) cat(rain_note)
cat("\n")
