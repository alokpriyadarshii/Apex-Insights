write_artifact_rds <- function(obj, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  readr::write_rds(obj, path)
  path
}
