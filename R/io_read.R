read_raw_csv <- function(path) {
  stopifnot(file.exists(path))
  readr::read_csv(path, show_col_types = FALSE)
}
