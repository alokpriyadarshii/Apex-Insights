score_model <- function(model, newdata) {
  stats::predict(model, newdata = newdata)
}
