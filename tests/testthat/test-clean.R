testthat::test_that("clean_dataset cleans names", {
  df <- data.frame("A Column" = c(" x "), check.names = FALSE)
  out <- clean_dataset(df)
  testthat::expect_true("a_column" %in% names(out))
  testthat::expect_equal(out$a_column[1], "x")
})
