# Apex-Insights

A reproducible R analytics pipeline for reading raw CSV data, cleaning it, training a baseline linear regression model, generating predictions, and saving artifacts for downstream reporting.

## Overview

Apex-Insights is organized as a lightweight data workflow built around:

- **`targets`** for pipeline orchestration
- **`renv`** for dependency management
- **`testthat`** for unit tests
- **`Quarto`** for reporting
- **GitHub Actions** for CI checks

The current pipeline reads a raw CSV file, standardizes column names and string values, fits a linear model using `y` as the target, produces predictions, and writes both the model and predictions to the `artifacts/` directory.

## What the project does

The codebase currently implements these core steps:

1. **Read raw input** from `data/raw/input.csv`
2. **Clean the dataset** by:
   - normalizing column names with `janitor::clean_names()`
   - converting factor columns to character
   - trimming whitespace from character values
3. **Validate required columns** before modeling
4. **Train a linear regression model** using `stats::lm()`
5. **Score the model** on the available dataset
6. **Write artifacts** to disk as `.rds` files
7. **Render a report** with Quarto

## Pipeline outputs

After a successful run, the main outputs are:

- `artifacts/models/model.rds` — trained model object
- `artifacts/data/preds.rds` — generated predictions

## Project structure

```text
Apex-Insights/
├── R/
│   ├── clean.R
│   ├── io_read.R
│   ├── io_write.R
│   ├── logging.R
│   ├── model_score.R
│   ├── model_train.R
│   ├── validate.R
│   ├── features.R
│   └── utils.R
├── data/
│   ├── raw/
│   │   └── input.csv
│   └── external/
├── artifacts/
│   ├── data/
│   ├── models/
│   └── reports/
├── reports/
│   └── report.qmd
├── tests/
│   └── testthat/
├── config.yml
├── _targets.R
├── renv.lock
└── README.md
```

## Requirements

- **R** 4.x or later
- **renv** for restoring the project library
- **Quarto** for report rendering

On macOS with Homebrew:

```bash
brew install r quarto
```

## Getting started

### 1. Clone the repository

```bash
git clone https://github.com/alokpriyadarshii/Apex-Insights.git && cd Apex-Insights
```

### 2. Restore project dependencies

```bash
R --vanilla -q -e 'if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv", repos = "https://cloud.r-project.org"); renv::restore()'
```

### 3. Run tests

```bash
R --vanilla -q -e 'renv::load(); testthat::test_dir("tests/testthat")'
```

### 4. Run the pipeline

```bash
R --vanilla -q -e 'renv::load(); targets::tar_make()'
```

### 5. Verify generated artifacts

```bash
ls -1 artifacts/models/model.rds artifacts/data/preds.rds
```

### 6. Render the report

```bash
quarto render reports/report.qmd
```

Or from R:

```bash
R --vanilla -q -e 'renv::load(); quarto::quarto_render("reports/report.qmd")'
```

## Input data expectations

The default pipeline reads:

```text
data/raw/input.csv
```

The current training target is hardcoded as:

```text
y
```

All remaining columns are used as features.

Example input format:

```csv
y,x1,x2
-0.5604756466,2.1988103489,-0.0735560191
-0.2301774895,1.3124129764,-1.1686514244
1.5587083141,-0.2651450567,-0.6347482649
```

## Configuration

Project configuration is stored in `config.yml`.

Current defaults:

```yaml
default:
  artifacts: "artifacts"
  log_level: "INFO"
```

This controls:

- where generated artifacts are written
- the logging verbosity used during pipeline execution

## Testing and quality checks

The repository includes:

- **unit tests** in `tests/testthat/`
- **linting** for the `R/` directory
- **GitHub Actions CI** to run tests and linting on push and pull request events

Run lint locally with:

```bash
R --vanilla -q -e 'renv::load(); lintr::lint_dir("R")'
```

## Current implementation notes

This project is a strong starter template for reproducible analytics workflows, but the present implementation is intentionally minimal.

Current characteristics:

- modeling uses a **single linear regression** via `stats::lm()`
- scoring is done on the same available dataset
- validation checks only for required column presence
- `features.R` and `utils.R` are scaffold files for future expansion
- the Quarto report is a starter report and can be extended with plots, metrics, and interpretation

## Suggested next improvements

Good next steps for the project would be:

- add a train/test split or cross-validation
- introduce richer feature engineering in `R/features.R`
- track evaluation metrics such as RMSE, MAE, or R²
- add visualizations to the Quarto report
- parameterize the target column and input path
- add stronger schema and missing-value validation

