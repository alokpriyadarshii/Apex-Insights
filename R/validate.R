validate_basic <- function(df, required_cols) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop("Missing required columns: ", paste(missing, collapse = ", "))
  }
  TRUE
}
