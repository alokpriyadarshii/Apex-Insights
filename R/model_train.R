train_model <- function(df, target, features) {
  validate_basic(df, c(target, features))
 if (length(features) == 0L) {
    formula <- stats::as.formula(paste(target, "~ 1"))
  } else {
    formula <- stats::as.formula(paste(target, "~", paste(features, collapse = "+")))
  }
  stats::lm(formula, data = df)
}
