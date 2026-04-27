# train.R — Baseline Model
# =============================================================================
# This is the ONLY file the agent is allowed to modify.
# prepare.R and evaluate.R are FROZEN — do not touch them.
#
# Function signature must stay the same:
#   train_model(train, val) -> numeric vector of predictions on val set
#
# Current model: simple linear regression (baseline)
# Features used: doy_sin, doy_cos, T2M
# =============================================================================

train_model <- function(train, val) {

  TARGET <- "ALLSKY_SFC_SW_DWN"

  formula <- as.formula(paste(
    TARGET,
    "~ doy_sin + doy_cos + month_sin + month_cos +",
    "CLRSKY_SFC_SW_DWN + lat + lon +",
    "T2M + I(T2M^2) + RH2M + I(RH2M^2) + WS2M + PRECTOTCORR + temp_range +",
    "T2M_7d_avg + RH2M_7d_avg + WS2M_7d_avg + PRECTOTCORR_7d_avg +",
    "CLRSKY_SFC_SW_DWN:RH2M + CLRSKY_SFC_SW_DWN:PRECTOTCORR"
  ))

  # --- Fit model ---
  model <- lm(formula, data = train)

  # --- Predict on validation set ---
  preds <- predict(model, newdata = val)

  return(preds)
}
