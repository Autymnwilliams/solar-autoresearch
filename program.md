# AutoResearch Agent Instructions

## Objective

Minimize **validation RMSE** on the daily solar irradiance (GHI) prediction task across 3 US cities: Phoenix AZ, Chicago IL, and Seattle WA.

**Background:** Solar energy output varies significantly by location, season, and weather conditions. Grid operators need accurate daily forecasts to decide how much backup power to keep on standby. Inaccurate forecasts lead to wasted energy and unnecessary reliance on fossil fuel reserves. This project builds a machine learning model that predicts how much solar irradiance (GHI, measured in kWh/m²/day) will be available on a given day, using only weather and seasonal variables from the NASA POWER API.

**What the agent is optimizing:** The agent iterates over feature combinations, model types, and hyperparameters in `train.R` to find the configuration that produces the lowest RMSE on the 2019–2020 validation set. The three cities were chosen to represent maximum US climate diversity — Phoenix represents hot desert (high solar, minimal clouds), Chicago represents the continental midwest (strong seasonality, cold winters), and Seattle represents the marine Pacific Northwest (persistent cloud cover, low solar output). A model that performs well across all three cities has genuinely learned the underlying weather-to-solar relationship rather than memorizing one climate's patterns.

**Baseline to beat:** A simple linear regression using day-of-year (cyclically encoded) and mean temperature only. Expected baseline RMSE is approximately 1.0–1.5 kWh/m²/day. The agent's goal is to reduce this by at least 15%.

## Rules

1. You may **ONLY** modify `train.R`
2. `prepare.R` and `evaluate.R` are **FROZEN** — do not touch them
3. `train_model()` must return predictions on the validation set as a numeric vector
4. Training + evaluation must complete in **under 60 seconds** on CPU
5. No additional data sources or external downloads

## Workflow

```
1. Read current train.R
2. Propose a modification
3. Edit train.R
4. Run:  Rscript run.R "description of change"
5. Check val_rmse in output
6. If improved:  git add train.R && git commit -m "feat: <description>"
7. If worse:     git checkout train.R   (revert)
8. Repeat from step 1
```

## Ideas to Explore

* Different regressors: lm, ridge, lasso, ElasticNet
* Ensemble methods: randomForest, xgboost, gbm
* Feature engineering: interaction terms, polynomial features
* Preprocessing: scaling, log-transforming GHI
* City as a factor variable to capture location-specific effects
* Hyperparameter tuning within the pipeline

## What NOT to Do

* Do not modify `prepare.R` or `evaluate.R` (data split, metric)
* Do not access `data/processed/test.csv` — it is locked until final evaluation
* Do not add new data sources or external downloads
* Do not hard-code validation data into the model
* Do not change the function signature of `train_model()`

## Context

* **Target variable:** GHI — Global Horizontal Irradiance (kWh/m²/day)
* **Metric:** RMSE on validation set (lower is better)
* **Baseline to beat:** linear regression using day-of-year and temperature only
* **Cities:** Phoenix AZ (desert), Chicago IL (continental), Seattle WA (marine)
* **Train:** 2010–2018 | **Val:** 2019–2020 | **Test:** 2021–2023 (locked)
* **Available features:** see `data/processed/feature_cols.txt`
