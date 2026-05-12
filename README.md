# Ensemble

Ensemble is an R-based wardrobe recommendation engine that ingests real-time weather forecast data and combines it with a user preference profile to suggest what to wear each day.

It is the analytical layer of a three-part portfolio project:

- **DataBridge** — Python ETL pipeline that fetches forecast data from the Open-Meteo API
- **Ensemble** — R machine learning engine (this project)
- **TelemetryVane** — JavaScript front-end (planned)



## How It Works

Ensemble reads a 24-hour hourly forecast CSV exported by DataBridge and derives a set of day-level summary features — morning, afternoon, and evening temperature blocks, maximum precipitation probability, temperature swing, average wind speed, and humidity.

These features are fed into a Random Forest classifier trained on a synthetic dataset of 600 labeled wardrobe scenarios. The synthetic data is generated using rule-based logic that maps weather conditions to outfit categories, providing a cold-start training baseline until real user feedback data is available in V2.

Before inference, the user's preference profile is applied as a modifier — a user who runs cold will have their temperature thresholds shifted upward, and a user with high rain aversion will trigger rain gear recommendations at a lower precipitation probability than the default.

The model outputs a wardrobe recommendation and a confidence score.



## Recommendation Categories

| Label | Conditions |
|---|---|
| `heavy_coat` | Morning below 35°F |
| `coat_and_rain_gear` | Morning below 50°F with rain |
| `light_coat` | Morning below 50°F, dry |
| `jacket_and_umbrella` | Morning below 65°F with rain |
| `jacket` | Morning below 65°F, dry |
| `light_layers` | Warm afternoon, dry |
| `umbrella_reminder` | Rain likely at any temperature |



## User Preference Profile

Ensemble reads a `user_profile.json` file with the following schema:

```json
{
  "name": "John",
  "location": "Bucks County",
  "temperature_sensitivity": "runs_cold",
  "rain_aversion": "high",
  "occasion": "casual"
}
```

| Field | Options |
|---|---|
| `temperature_sensitivity` | `runs_cold` / `neutral` / `runs_warm` |
| `rain_aversion` | `low` / `medium` / `high` |
| `occasion` | `work` / `casual` / `outdoor` |


## How to Run

1. Ensure DataBridge has been run and `ensemble_input.csv` exists at the configured path
2. Update the CSV path in `Ensemble.R` section 2 to match your local DataBridge location
3. Edit `user_profile.json` with your preferences
4. Open `Ensemble.R` in RStudio and run the full script



## Project Status

| Component | Status |
|---|---|
| Forecast ingestion | Complete |
| User profile reader | Complete |
| Feature engineering | Complete |
| Synthetic training data | Complete |
| Random Forest model | Complete |
| Inference + output | Complete |
| Natural language output | Planned (V1 Day 3) |
| Historical climate awareness | Planned (V2) |
| TelemetryVane integration (UI)| Planned (V2) |


## Related Projects

- [DataBridge](https://github.com/M-Dicks0n/ProjectDataBridge) — The ETL pipeline that
  feeds Ensemble's forecast data
