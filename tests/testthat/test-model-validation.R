testthat::test_that("classification metrics identify strong risk ordering", {
  actual <- c(0, 0, 1, 1)
  scores <- c(0.05, 0.20, 0.80, 0.95)

  testthat::expect_equal(roc_auc(actual, scores), 1)
  testthat::expect_gt(pr_auc(actual, scores), 0.9)
  testthat::expect_equal(ks_score(actual, scores), 1)
})

testthat::test_that("threshold tuning and decision rules produce review actions", {
  actual <- c(0, 0, 0, 1, 1, 1)
  scores <- c(0.10, 0.25, 0.35, 0.55, 0.72, 0.91)
  tuned <- tune_threshold(actual, scores, thresholds = c(0.30, 0.50, 0.70))
  decisions <- apply_decision_rules(scores, reject_threshold = 0.80, investigate_threshold = tuned$best_threshold)

  testthat::expect_true(tuned$best_threshold %in% c(0.30, 0.50, 0.70))
  testthat::expect_named(confusion_matrix_metrics(actual, scores, tuned$best_threshold))
  testthat::expect_setequal(unique(decisions), c("approve", "investigate", "reject"))
})

testthat::test_that("credit-risk validation report includes logistic model outputs", {
  df <- data.frame(
    fraud_flag = c(0, 1, 1, 0, 1, 0, 1, 0, 0, 1, 0, 1),
    x1 = c(0.10, 0.20, 0.62, 0.30, 0.68, 0.44, 0.75, 0.70, 0.35, 0.88, 0.40, 0.92),
    x2 = c(1.10, 1.00, 0.45, 0.80, 0.35, 0.62, 0.30, 0.28, 0.73, 0.25, 0.90, 0.20)
  )

  validation <- validate_credit_risk_models(df, "fraud_flag", c("x1", "x2"))
  report <- validation$reports$logistic_regression

  testthat::expect_equal(validation$row_count, nrow(df))
  testthat::expect_true(is.finite(report$roc_auc))
  testthat::expect_true(is.finite(report$pr_auc))
  testthat::expect_true(is.finite(report$ks_score))
  testthat::expect_true(is.finite(report$psi))
  testthat::expect_true(all(c("tp", "fp", "tn", "fn") %in% names(report$confusion_matrix)))
  testthat::expect_true(all(c("feature", "importance") %in% names(report$feature_importance)))
})

testthat::test_that("model validation report is written as markdown", {
  df <- data.frame(
    fraud_flag = c(0, 1, 1, 0, 1, 0, 1, 0),
    x1 = c(0.10, 0.22, 0.58, 0.35, 0.66, 0.40, 0.74, 0.82),
    x2 = c(0.90, 0.80, 0.35, 0.70, 0.30, 0.62, 0.25, 0.18)
  )
  validation <- validate_credit_risk_models(df, "fraud_flag", c("x1", "x2"))
  path <- tempfile(fileext = ".md")

  output <- write_model_validation_report(validation, path)

  testthat::expect_equal(output, path)
  testthat::expect_true(file.exists(path))
  testthat::expect_true(any(grepl("ROC-AUC", readLines(path))))
})
