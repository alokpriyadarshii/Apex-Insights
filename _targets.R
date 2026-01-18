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
  tar_target(model_path, write_artifact_rds(model, file.path(cfg$artifacts, "models", "model.rds")), format = "file"),
  tar_target(preds_path, write_artifact_rds(predictions, file.path(cfg$artifacts, "data", "preds.rds")), format = "file")
)
