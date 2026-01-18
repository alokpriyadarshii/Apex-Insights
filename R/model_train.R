train_model <- function(df, target, features) {
  validate_basic(df, c(target, features))
  formula <- stats::as.formula(paste(target, "~", paste(features, collapse = "+")))
  stats::lm(formula, data = df)
}
