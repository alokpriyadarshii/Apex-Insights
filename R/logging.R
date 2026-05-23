setup_logging <- function(level = "INFO") {
  if (!requireNamespace("logger", quietly = TRUE)) {
    stop("Package 'logger' is required.")
  }

  lvl <- toupper(trimws(as.character(level)))
  if (length(lvl) != 1L || is.na(lvl)) lvl <- "INFO"

  valid <- c("TRACE", "DEBUG", "INFO", "SUCCESS", "WARN", "ERROR", "FATAL")
  if (!nzchar(lvl) || !(lvl %in% valid)) lvl <- "INFO"

  logger::log_threshold(logger::as.loglevel(lvl))
  logger::log_appender(logger::appender_console)
  logger::log_layout(logger::layout_glue_colors)

  invisible(TRUE)
}
