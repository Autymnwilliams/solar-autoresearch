# train.R — Baseline Model
# =============================================================================
# This is the ONLY file the agent is allowed to modify.
# prepare.R and evaluate.R are FROZEN — do not touch them.
#
# Function signature must stay the same:
#   train_model(train, val) -> list with predictions, model_type, features
#
# Current model: simple linear regression (baseline)
# Features used: cyclical day-of-year + all Exp 3 weather features
# =============================================================================
train_model <- function(train, val) {
  TARGET <- "ALLSKY_SFC_SW_DWN"
  
  features <- c(
    "doy_sin", "doy_cos", "T2M", "T2M_MAX", "T2M_MIN",
    "RH2M", "WS2M", "PRECTOTCORR", "temp_range"
  )
  
  formula <- as.formula(paste(TARGET, "~", paste(features, collapse = " + ")))
  
  # --- Fit model ---
  model <- lm(formula, data = train)
  
  # --- Predict on validation set ---
  preds <- predict(model, newdata = val)
  
  # --- Return required list (do not change this structure) ---
  return(list(
    predictions = preds,
    model_type  = "lm",
    features    = features
  ))
}
