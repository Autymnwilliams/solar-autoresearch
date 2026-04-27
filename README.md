# Solar Irradiance Forecasting — AutoResearch Project

**STAT 390 Capstone | Spring 2026**

## Research Question

Which weather and seasonal variables best predict daily solar irradiance across 3 US cities with different climates, and can an AI agent discover those variables automatically?

## Cities

| City | State | Climate | Expected Solar |
|---|---|---|---|
| Phoenix | AZ | Hot desert | High |
| Chicago | IL | Continental | Seasonal |
| Seattle | WA | Marine/overcast | Low |

## Target Variable

`ALLSKY_SFC_SW_DWN` — All-sky surface solar irradiance (kWh/m²/day) from NASA POWER API

## Metric

**Validation RMSE** (lower is better). Frozen. Never changes.

## Data Splits

| Split | Years | Purpose |
|---|---|---|
| Train | 2010–2018 | Fit models |
| Validation | 2019–2020 | Evaluate experiments |
| Test | 2021–2023 | **LOCKED** — final evaluation only |

---

## How to Run (from scratch)

### 1. Install R packages (one time only)
```r
install.packages(c("httr", "jsonlite", "dplyr", "lubridate", "readr", "zoo"))
```

### 2. Pull data from NASA POWER API
```bash
Rscript prepare.R
```
This creates `data/raw/` and `data/processed/` with all CSVs. Takes ~2 minutes.

### 3. Run the baseline
```bash
Rscript run.R "baseline linear regression - doy + temperature"
```

This prints the validation RMSE and logs the result to `logs/experiments.json`.

---

## File Structure

```
solar-autoresearch/
├── prepare.R          FROZEN — pulls NASA data, engineers features, splits data
├── train.R            AGENT EDITS THIS — model code
├── run.R              FROZEN — runs pipeline, computes RMSE, logs result
├── program.md         Agent instructions
├── README.md          This file
├── data/
│   ├── raw/           Raw NASA POWER CSVs (one per city)
│   └── processed/     train.csv, val.csv, test.csv, feature_cols.txt
└── logs/
    └── experiments.json   Running log of all experiments
```

## What the Agent Can and Cannot Do

| | Files |
|---|---|
| ✅ May modify | `train.R` only |
| 🚫 Frozen | `prepare.R`, `run.R`, `evaluate.R` |
| 🔒 Locked | `data/processed/test.csv` — not opened until final evaluation |

## Agent Workflow

```
1. Read program.md
2. Read current train.R
3. Propose one change
4. Edit train.R
5. Run: Rscript run.R "description"
6. If RMSE improved: git commit
7. If RMSE worse: git checkout train.R
8. Repeat
```

## Current Best Result

## Current Best Result

| Experiment | Val RMSE | Notes |
|---|---|---|
| 1 - Baseline (lm, doy + T2M) | 1.2917 | Simple linear regression, doy + temperature only |
| 2 - Add humidity + wind speed | 1.0693 | ✅ Kept — 17% improvement |
| 3 - All weather features | 0.9716 | ✅ Best — 25% improvement over baseline |
| 4 - City as factor variable | 1.0526 | ❌ Reverted — hurt performance |
| 5 - Add lag features | 1.0276 | ❌ Reverted — hurt performance |

**Current best:** Experiment 3 — all weather features — Val RMSE 0.9716
**Baseline:** 1.2917 | **Improvement:** 24.8%
---

## Reproducibility Checklist

- [ ] `Rscript prepare.R` runs without errors
- [ ] `Rscript run.R "baseline"` returns a single RMSE number
- [ ] `logs/experiments.json` contains at least one entry
- [ ] Test set has never been opened
- [ ] Data split is deterministic (time-based, no randomness)
