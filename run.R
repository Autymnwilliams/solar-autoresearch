# run.R — End-to-End Pipeline Runner
# =============================================================================
# FROZEN FILE — do not modify this file. The agent may not touch this file.
#
# Usage:
#   Rscript run.R "description of what changed"
#
# What this does:
#   1. Loads train and val sets from data/processed/
#   2. Sources train.R to get train_model()
#   3. Runs train_model() and measures runtime
#   4. Computes RMSE on validation set
#   5. Logs result to logs/experiments.json
#   6. Prints result to console
#
# The agent uses this output to decide keep / revert.
# =============================================================================

library(readr)
library(jsonlite)

# --- FROZEN: evaluation function ---
compute_rmse <- function(actual, predicted) {
  sqrt(mean((actual - predicted)^2))
}

# --- Get experiment description from command line ---
args        <- commandArgs(trailingOnly = TRUE)
description <- if (length(args) > 0) args[1] else "no description provided"

TARGET <- "ALLSKY_SFC_SW_DWN"

# --- Load data ---
cat("Loading data...\n")
train <- read_csv("data/processed/train.csv", show_col_types = FALSE)
val   <- read_csv("data/processed/val.csv",   show_col_types = FALSE)

# --- Source train.R ---
cat("Loading model from train.R...\n")
source("train.R")

# --- Run and time the model ---
cat("Training model...\n")
start_time <- proc.time()
preds      <- train_model(train, val)
elapsed    <- (proc.time() - start_time)[["elapsed"]]

# --- Compute RMSE ---
actual    <- val[[TARGET]]
val_rmse  <- compute_rmse(actual, preds)

# --- Print result ---
cat("\n========================================\n")
cat(sprintf("  Description : %s\n", description))
cat(sprintf("  Val RMSE    : %.4f kWh/m2/day\n", val_rmse))
cat(sprintf("  Runtime     : %.2f seconds\n", elapsed))
cat("========================================\n\n")

# --- Log result ---
dir.create("logs", showWarnings = FALSE)
log_path <- "logs/experiments.json"

new_entry <- list(
  timestamp   = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  description = description,
  val_rmse    = round(val_rmse, 4),
  runtime_sec = round(elapsed, 2)
)

# Load existing log or start fresh
if (file.exists(log_path)) {
  existing <- fromJSON(log_path, simplifyVector = FALSE)
} else {
  existing <- list()
}

existing[[length(existing) + 1]] <- new_entry
write(toJSON(existing, pretty = TRUE, auto_unbox = TRUE), log_path)

cat(sprintf("Result logged to %s\n", log_path))
