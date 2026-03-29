write_artifact_rds <- function(obj, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = TRUE)
  readr::write_rds(obj, path)
  path
}
