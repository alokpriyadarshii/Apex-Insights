# Apex Insights

set -euo pipefail

---

## 1) Go to project folder (adjust if you're already there)

cd "Apex Insights"

---

## 2) Install R (>= 4.x) and ensure it’s on PATH (macOS/Homebrew)

brew install r
R --version

---

## 3) Install deps (incl dev deps for tests) using renv

R --vanilla -q -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv", repos="https://cloud.r-project.org"); renv::restore()'

---

## 4) Run tests

R --vanilla -q -e 'renv::load(); testthat::test_dir("tests/testthat")'

---

## 5) Lint (optional but recommended)

R --vanilla -q -e 'renv::load(); lintr::lint_dir("R")'

---

## 6) Run the pipeline (targets)

R --vanilla -q -e 'renv::load(); targets::tar_make()'

---

## 7) Verify pipeline outputs

ls -1 artifacts/models/model.rds artifacts/data/preds.rds

---

## 8) Render the Quarto report (optional)

# If Quarto CLI isn't available:
brew install quarto

# Render the report (either way works if Quarto is installed):
quarto render reports/report.qmd
# OR:
R --vanilla -q -e 'renv::load(); quarto::quarto_render("reports/report.qmd")'

---

## 9) Check the rendered report

ls -1 reports/report.html

---

## 10) Clean / reset the pipeline (optional)

R --vanilla -q -e 'renv::load(); targets::tar_destroy(destroy="all")'
