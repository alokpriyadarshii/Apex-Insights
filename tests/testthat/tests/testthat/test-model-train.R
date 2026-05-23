testthat::test_that("train_model supports empty feature lists", {
  df <- data.frame(y = c(1, 2, 3))
  model <- train_model(df, "y", character())
  preds <- stats::predict(model, newdata = df)
  testthat::expect_equal(length(preds), nrow(df))
})
