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
  TARGET   <- "ALLSKY_SFC_SW_DWN"
  FEATURES <- c("doy_sin", "doy_cos", "T2M", "RH2M", "WS2M", "city")
  
  train$city <- as.factor(train$city)
  val$city   <- as.factor(val$city)
  
  formula <- as.formula(paste(TARGET, "~", paste(FEATURES, collapse = " + ")))
  model   <- lm(formula, data = train)
  preds   <- predict(model, newdata = val)
  return(preds)
}
