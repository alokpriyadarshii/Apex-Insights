library(targets)

tar_option_set(
  packages = c("tidyverse", "readr", "janitor", "config", "logger")
)

source("R/logging.R")
source("R/io_read.R")
source("R/io_write.R")
source("R/clean.R")
source("R/validate.R")
source("R/model_train.R")
source("R/model_score.R")
source("R/model_validation.R")

cfg <- config::get()
setup_logging(cfg$log_level)

list(
  tar_target(
  raw_path,
  "data/raw/input.csv",
  format = "file"
),
  tar_target(raw_data, read_raw_csv(raw_path)),
  tar_target(clean_data, clean_dataset(raw_data)),
  tar_target(
    model,
    train_model(
      clean_data,
      target = "y",
      features = setdiff(names(clean_data), "y")
    )
  ),
  tar_target(predictions, score_model(model, clean_data)),
  tar_target(
    credit_risk_data,
    create_credit_risk_target(clean_data, source_col = "y", target_col = "fraud_flag")
  ),
  tar_target(
    model_validation,
    validate_credit_risk_models(
      credit_risk_data,
      target = "fraud_flag",
      features = setdiff(names(clean_data), "y")
    )
  ),
  tar_target(model_path, write_artifact_rds(model, file.path(cfg$artifacts, "models", "model.rds")), format = "file"),
  tar_target(preds_path, write_artifact_rds(predictions, file.path(cfg$artifacts, "data", "preds.rds")), format = "file"),
  tar_target(
    validation_report_path,
    write_model_validation_report(
      model_validation,
      file.path(cfg$artifacts, "reports", "model_validation_report.md")
    ),
    format = "file"
  )
)
