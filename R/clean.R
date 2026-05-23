clean_dataset <- function(df) {
  if (!is.data.frame(df)) {
    stop("`df` must be a data.frame")
  }
  df |>
    janitor::clean_names() |>
    dplyr::mutate(dplyr::across(dplyr::where(is.factor), as.character)) |>
    dplyr::mutate(dplyr::across(dplyr::where(is.character), stringr::str_trim))
}
