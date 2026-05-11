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
result     <- train_model(train, val)
elapsed    <- (proc.time() - start_time)[["elapsed"]]

# --- Validate that train.R returned required fields ---
# train.R must return a list with: predictions, model_type, features
if (!is.list(result) || is.null(result$predictions)) {
  stop("train.R must return a list with at least a 'predictions' element.")
}

preds      <- result$predictions
model_type <- if (!is.null(result$model_type)) result$model_type else "unknown"
features   <- if (!is.null(result$features))   result$features   else list()

# --- Compute RMSE ---
actual   <- val[[TARGET]]
val_rmse <- compute_rmse(actual, preds)

# --- Load best known RMSE to determine keep/revert ---
log_path <- "logs/experiments.json"
dir.create("logs", showWarnings = FALSE)

if (file.exists(log_path)) {
  existing    <- fromJSON(log_path, simplifyVector = FALSE)
  kept_runs   <- Filter(function(e) isTRUE(e$kept), existing)
  best_rmse   <- if (length(kept_runs) > 0) {
    min(sapply(kept_runs, function(e) e$val_rmse))
  } else Inf
} else {
  existing  <- list()
  best_rmse <- Inf
}

kept          <- val_rmse < best_rmse
revert_reason <- if (!kept) sprintf("val_rmse %.4f did not improve best %.4f", val_rmse, best_rmse) else NA

# --- Print result ---
cat("\n========================================\n")
cat(sprintf("  Description : %s\n", description))
cat(sprintf("  Model       : %s\n", model_type))
cat(sprintf("  Val RMSE    : %.4f kWh/m2/day\n", val_rmse))
cat(sprintf("  Best so far : %.4f kWh/m2/day\n", best_rmse))
cat(sprintf("  Kept        : %s\n", ifelse(kept, "YES", "NO")))
if (!kept) cat(sprintf("  Revert      : %s\n", revert_reason))
cat(sprintf("  Runtime     : %.2f seconds\n", elapsed))
cat("========================================\n\n")

# --- Log result (always, whether kept or not) ---
new_entry <- list(
  timestamp     = format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
  description   = description,
  model_type    = model_type,
  features      = features,
  val_rmse      = val_rmse,
  kept          = kept,
  revert_reason = revert_reason,
  runtime_sec   = elapsed
)

existing[[length(existing) + 1]] <- new_entry
write(toJSON(existing, pretty = TRUE, auto_unbox = TRUE), log_path)

cat(sprintf("Result logged to %s\n", log_path))