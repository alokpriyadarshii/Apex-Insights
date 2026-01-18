clean_dataset <- function(df) {
  df |>
    janitor::clean_names() |>
    dplyr::mutate(dplyr::across(dplyr::where(is.character), stringr::str_trim))
}
