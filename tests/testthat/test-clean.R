testthat::test_that("clean_dataset cleans names", {
  df <- data.frame("A Column" = c(" x "), check.names = FALSE)
  out <- clean_dataset(df)
  testthat::expect_true("a_column" %in% names(out))
  testthat::expect_equal(out$a_column[1], "x")
})

testthat::test_that("clean_dataset validates input type", {
  testthat::expect_error(clean_dataset(list(a = 1)), "must be a data.frame")
})

testthat::test_that("clean_dataset trims factor values", {
  df <- data.frame(category = factor(c(" a ", "b  ")))
  out <- clean_dataset(df)

  testthat::expect_type(out$category, "character")
  testthat::expect_equal(out$category, c("a", "b"))
})
