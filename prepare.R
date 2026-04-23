# prepare.R — Solar Irradiance Forecasting Project
# =============================================================================
# FROZEN FILE — do not modify this file. The agent may not touch this file.
#
# What this script does:
#   1. Pulls daily solar + weather data from NASA POWER API for 3 US cities
#   2. Engineers features (cyclical encoding, lag variables, rolling averages)
#   3. Splits data into train / validation / test sets (deterministic)
#   4. Saves all splits as CSVs to data/processed/
#
# Run this once before anything else:
#   source("prepare.R")
#
# After running, you will have:
#   data/raw/phoenix_raw.csv         — raw NASA POWER data for Phoenix AZ
#   data/raw/chicago_raw.csv         — raw NASA POWER data for Chicago IL
#   data/raw/seattle_raw.csv         — raw NASA POWER data for Seattle WA
#   data/processed/train.csv         — 2010–2018 (training)
#   data/processed/val.csv           — 2019–2020 (validation) <- agent sees this
#   data/processed/test.csv          — 2021–2023 (test) <- LOCKED, never used until final eval
#   data/processed/feature_cols.txt  — list of available input features
#
# FROZEN CONSTANTS (never change — changing breaks experiment comparability):
#   TARGET     = "GHI"       what we are predicting (kWh/m2/day)
#   METRIC     = "RMSE"      the one evaluation metric
#   TEST_YEARS = 2021-2023   held-out, never touched during agent loop
#   VAL_YEARS  = 2019-2020   used by agent to evaluate experiments
#   TRAIN_YEARS= 2010-2018   used to fit models
# =============================================================================

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)
library(readr)
library(zoo)

# =============================================================================
# FROZEN CONSTANTS — do not change
# =============================================================================

CITIES <- list(
  phoenix = list(name = "Phoenix",  state = "AZ", lat =  33.45, lon = -112.07),
  chicago = list(name = "Chicago",  state = "IL", lat =  41.88, lon =  -87.63),
  seattle = list(name = "Seattle",  state = "WA", lat =  47.61, lon = -122.33)
)

START_DATE    <- "20100101"
END_DATE      <- "20231231"
TRAIN_END     <- 2018
VAL_END       <- 2020
TARGET        <- "GHI"
RANDOM_SEED   <- 42

# NASA POWER parameters:
# GHI                  = Global Horizontal Irradiance (TARGET, kWh/m2/day)
# T2M                  = Mean temperature at 2m (C)
# T2M_MAX              = Max temperature at 2m (C)
# T2M_MIN              = Min temperature at 2m (C)
# RH2M                 = Relative humidity at 2m (%)
# WS2M                 = Wind speed at 2m (m/s)
# PRECTOTCORR          = Precipitation (mm/day)
# ALLSKY_SFC_SW_DWN    = All-sky surface shortwave downward irradiance
# CLRSKY_SFC_SW_DWN    = Clear-sky surface shortwave downward irradiance
NASA_PARAMS <- "GHI,T2M,T2M_MAX,T2M_MIN,RH2M,WS2M,PRECTOTCORR,ALLSKY_SFC_SW_DWN,CLRSKY_SFC_SW_DWN"

RAW_DIR       <- "data/raw"
PROCESSED_DIR <- "data/processed"

# =============================================================================
# STEP 1: Fetch data from NASA POWER API
# =============================================================================

fetch_nasa_power <- function(city_info) {
  cat(sprintf("  Fetching data for %s, %s (%.2fN, %.2fE)...\n",
              city_info$name, city_info$state, city_info$lat, city_info$lon))

  url <- sprintf(
    paste0("https://power.larc.nasa.gov/api/temporal/daily/point",
           "?parameters=%s",
           "&community=RE",
           "&longitude=%.4f",
           "&latitude=%.4f",
           "&start=%s",
           "&end=%s",
           "&format=JSON"),
    NASA_PARAMS,
    city_info$lon,
    city_info$lat,
    START_DATE,
    END_DATE
  )

  response <- GET(url, timeout(120))

  if (status_code(response) != 200) {
    stop(sprintf("NASA POWER API returned status %d for %s",
                 status_code(response), city_info$name))
  }

  data      <- fromJSON(content(response, "text", encoding = "UTF-8"))
  params    <- data$properties$parameter

  # Build a wide data frame: one row per day, one column per parameter
  df <- as.data.frame(lapply(params, function(x) unlist(x)))
  df$date <- as.Date(rownames(df), format = "%Y%m%d")
  rownames(df) <- NULL

  # NASA POWER uses -999 for missing — replace with NA
  df[df == -999] <- NA

  # Add city identifier
  df$city  <- city_info$name
  df$state <- city_info$state
  df$lat   <- city_info$lat
  df$lon   <- city_info$lon

  cat(sprintf("    Pulled %d daily records. Missing GHI values: %d\n",
              nrow(df), sum(is.na(df$GHI))))

  return(df)
}

# =============================================================================
# STEP 2: Feature engineering
# =============================================================================

engineer_features <- function(df) {
  df <- df %>%
    arrange(city, date) %>%
    group_by(city) %>%
    mutate(
      # --- Cyclical encoding of day-of-year (no cliff at Dec 31) ---
      day_of_year = yday(date),
      doy_sin     = sin(2 * pi * day_of_year / 365.25),
      doy_cos     = cos(2 * pi * day_of_year / 365.25),

      # --- Cyclical encoding of month ---
      month       = month(date),
      month_sin   = sin(2 * pi * month / 12),
      month_cos   = cos(2 * pi * month / 12),

      # --- Year (for long-term trend) ---
      year        = year(date),

      # --- Temperature range ---
      temp_range  = T2M_MAX - T2M_MIN,

      # --- 7-day rolling averages (lagged 1 day to avoid leakage) ---
      T2M_7d_avg         = rollmeanr(lag(T2M, 1),         7, fill = NA),
      RH2M_7d_avg        = rollmeanr(lag(RH2M, 1),        7, fill = NA),
      WS2M_7d_avg        = rollmeanr(lag(WS2M, 1),        7, fill = NA),
      PRECTOTCORR_7d_avg = rollmeanr(lag(PRECTOTCORR, 1), 7, fill = NA),

      # --- Lag features for GHI (yesterday and 7 days ago) ---
      GHI_lag1    = lag(GHI, 1),
      GHI_lag7    = lag(GHI, 7),

      # --- Clear-sky ratio (fraction of max possible solar achieved) ---
      clearsky_ratio = GHI / (CLRSKY_SFC_SW_DWN + 1e-6)
    ) %>%
    ungroup() %>%
    filter(!is.na(GHI_lag7))   # drop rows with NA from lag features

  return(df)
}

# =============================================================================
# STEP 3: Combine cities and split train / val / test
# =============================================================================

split_and_save <- function(df) {
  df$year_num <- year(df$date)

  train <- df %>% filter(year_num <= TRAIN_END)
  val   <- df %>% filter(year_num > TRAIN_END & year_num <= VAL_END)
  test  <- df %>% filter(year_num > VAL_END)

  cat(sprintf("\n  Train set : %d rows (%d-%d)\n", nrow(train),
              min(year(train$date)), max(year(train$date))))
  cat(sprintf("  Val set   : %d rows (%d-%d)\n", nrow(val),
              min(year(val$date)), max(year(val$date))))
  cat(sprintf("  Test set  : %d rows (%d-%d)\n", nrow(test),
              min(year(test$date)), max(year(test$date))))
  cat("  WARNING: Test set is LOCKED. Do not use until final evaluation.\n\n")

  dir.create(PROCESSED_DIR, recursive = TRUE, showWarnings = FALSE)

  write_csv(train, file.path(PROCESSED_DIR, "train.csv"))
  write_csv(val,   file.path(PROCESSED_DIR, "val.csv"))
  write_csv(test,  file.path(PROCESSED_DIR, "test.csv"))

  # Save feature column names for agent reference
  exclude_cols <- c("date", TARGET, "day_of_year", "month",
                    "year_num", "city", "state")
  feature_cols <- setdiff(names(df), exclude_cols)
  writeLines(feature_cols, file.path(PROCESSED_DIR, "feature_cols.txt"))

  cat(sprintf("  Feature columns saved to %s/feature_cols.txt\n", PROCESSED_DIR))
  cat(sprintf("  Available features (%d total):\n", length(feature_cols)))
  cat(paste(" ", feature_cols, collapse = "\n"), "\n\n")

  return(list(train = train, val = val, test = test))
}

# =============================================================================
# MAIN
# =============================================================================

cat("================================================================\n")
cat("  prepare.R — Solar Irradiance Forecast Data Pipeline\n")
cat("================================================================\n\n")

dir.create(RAW_DIR,       recursive = TRUE, showWarnings = FALSE)
dir.create(PROCESSED_DIR, recursive = TRUE, showWarnings = FALSE)

# --- Pull or load each city ---
all_city_data <- list()

for (city_key in names(CITIES)) {
  city_info <- CITIES[[city_key]]
  raw_path  <- file.path(RAW_DIR, paste0(city_key, "_raw.csv"))

  if (file.exists(raw_path)) {
    cat(sprintf("  Cache found for %s. Loading from %s...\n",
                city_info$name, raw_path))
    df_city <- read_csv(raw_path, show_col_types = FALSE)
    df_city$date <- as.Date(df_city$date)
  } else {
    df_city <- fetch_nasa_power(city_info)
    write_csv(df_city, raw_path)
    cat(sprintf("    Raw data saved to %s\n", raw_path))
    Sys.sleep(2)  # be polite to NASA API between calls
  }

  all_city_data[[city_key]] <- df_city
}

# --- Combine all cities ---
cat("\nCombining all cities...\n")
df_all <- bind_rows(all_city_data)
cat(sprintf("  Combined dataset: %d rows across %d cities\n\n",
            nrow(df_all), length(CITIES)))

# --- Feature engineering ---
cat("Engineering features...\n")
df_all <- engineer_features(df_all)
cat(sprintf("  %d rows after dropping NA from lag features.\n\n", nrow(df_all)))

# --- Split and save ---
cat("Splitting into train / val / test...\n")
splits <- split_and_save(df_all)

cat("================================================================\n")
cat("  prepare.R complete. Your data is ready.\n")
cat(sprintf("  Target variable  : %s (kWh/m2/day)\n", TARGET))
cat("  Evaluation metric: RMSE (lower is better)\n")
cat("  Cities           : Phoenix AZ | Chicago IL | Seattle WA\n")
cat("  Train            : 2010-2018\n")
cat("  Val              : 2019-2020  <- agent uses this\n")
cat("  Test             : 2021-2023  <- LOCKED\n")
cat("================================================================\n")
cat("\nNext step: run baseline.R to establish your benchmark RMSE.\n")
