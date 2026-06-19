as_binary_target <- function(values) {
  if (is.logical(values)) {
    return(as.integer(values))
  }

  if (is.numeric(values) || is.integer(values)) {
    unique_values <- sort(unique(stats::na.omit(values)))
    if (all(unique_values %in% c(0, 1))) {
      return(as.integer(values))
    }
  }

  if (is.factor(values) || is.character(values)) {
    levels <- sort(unique(stats::na.omit(as.character(values))))
    if (length(levels) != 2L) {
      stop("Binary target must contain exactly two non-missing classes.")
    }
    return(as.integer(as.character(values) == levels[[2L]]))
  }

  stop("Binary target must be logical, 0/1 numeric, or a two-class factor/character column.")
}

create_credit_risk_target <- function(df, source_col, target_col = "fraud_flag") {
  validate_basic(df, source_col)
  output <- df

  if (is.numeric(output[[source_col]]) || is.integer(output[[source_col]])) {
    unique_values <- sort(unique(stats::na.omit(output[[source_col]])))
    if (all(unique_values %in% c(0, 1))) {
      output[[target_col]] <- as.integer(output[[source_col]])
      return(output)
    }

    cutoff <- stats::median(output[[source_col]], na.rm = TRUE)
    output[[target_col]] <- as.integer(output[[source_col]] >= cutoff)
    return(output)
  }

  output[[target_col]] <- as_binary_target(output[[source_col]])
  output
}

train_credit_risk_models <- function(df, target, features) {
  validate_basic(df, c(target, features))
  if (length(features) == 0L) {
    stop("Credit-risk validation requires at least one feature column.")
  }

  model_df <- df[, c(target, features), drop = FALSE]
  model_df[[target]] <- as_binary_target(model_df[[target]])
  model_df <- stats::na.omit(model_df)

  formula <- stats::as.formula(paste(target, "~", paste(features, collapse = "+")))
  models <- list(
    logistic_regression = stats::glm(formula, data = model_df, family = stats::binomial())
  )

  if (requireNamespace("randomForest", quietly = TRUE)) {
    rf_df <- model_df
    rf_df[[target]] <- factor(rf_df[[target]], levels = c(0, 1))
    models$random_forest <- randomForest::randomForest(formula, data = rf_df, ntree = 200, importance = TRUE)
  }

  if (requireNamespace("xgboost", quietly = TRUE)) {
    matrix_x <- stats::model.matrix(formula, model_df)[, -1, drop = FALSE]
    models$xgboost <- xgboost::xgboost(
      data = matrix_x,
      label = model_df[[target]],
      objective = "binary:logistic",
      nrounds = 50,
      verbose = 0
    )
    attr(models$xgboost, "feature_names") <- colnames(matrix_x)
  }

  structure(models, target = target, features = features)
}

predict_credit_risk_scores <- function(model, model_name, newdata, target, features) {
  if (identical(model_name, "logistic_regression")) {
    return(as.numeric(stats::predict(model, newdata = newdata, type = "response")))
  }

  if (identical(model_name, "random_forest")) {
    predictions <- stats::predict(model, newdata = newdata, type = "prob")
    return(as.numeric(predictions[, "1"]))
  }

  if (identical(model_name, "xgboost")) {
    formula <- stats::as.formula(paste(target, "~", paste(features, collapse = "+")))
    matrix_x <- stats::model.matrix(formula, newdata)[, -1, drop = FALSE]
    return(as.numeric(stats::predict(model, matrix_x)))
  }

  stop("Unsupported model type: ", model_name)
}

roc_auc <- function(actual, scores) {
  actual <- as_binary_target(actual)
  positives <- sum(actual == 1L)
  negatives <- sum(actual == 0L)

  if (positives == 0L || negatives == 0L) {
    return(NA_real_)
  }

  ranks <- rank(scores, ties.method = "average")
  (sum(ranks[actual == 1L]) - positives * (positives + 1L) / 2) / (positives * negatives)
}

pr_auc <- function(actual, scores) {
  actual <- as_binary_target(actual)
  positives <- sum(actual == 1L)

  if (positives == 0L) {
    return(NA_real_)
  }

  order_idx <- order(scores, decreasing = TRUE)
  sorted_actual <- actual[order_idx]
  tp <- cumsum(sorted_actual == 1L)
  fp <- cumsum(sorted_actual == 0L)
  recall <- tp / positives
  precision <- tp / pmax(tp + fp, 1L)

  recall <- c(0, recall)
  precision <- c(1, precision)
  sum(diff(recall) * (utils::head(precision, -1L) + utils::tail(precision, -1L)) / 2)
}

ks_score <- function(actual, scores) {
  actual <- as_binary_target(actual)
  positives <- sum(actual == 1L)
  negatives <- sum(actual == 0L)

  if (positives == 0L || negatives == 0L) {
    return(NA_real_)
  }

  order_idx <- order(scores, decreasing = TRUE)
  sorted_actual <- actual[order_idx]
  tpr <- cumsum(sorted_actual == 1L) / positives
  fpr <- cumsum(sorted_actual == 0L) / negatives
  max(abs(tpr - fpr))
}

confusion_matrix_metrics <- function(actual, scores, threshold = 0.5) {
  actual <- as_binary_target(actual)
  predicted <- as.integer(scores >= threshold)

  tp <- sum(actual == 1L & predicted == 1L)
  fp <- sum(actual == 0L & predicted == 1L)
  tn <- sum(actual == 0L & predicted == 0L)
  fn <- sum(actual == 1L & predicted == 0L)

  precision <- if ((tp + fp) == 0L) 0 else tp / (tp + fp)
  recall <- if ((tp + fn) == 0L) 0 else tp / (tp + fn)
  specificity <- if ((tn + fp) == 0L) 0 else tn / (tn + fp)
  f1 <- if ((precision + recall) == 0) 0 else 2 * precision * recall / (precision + recall)

  data.frame(
    threshold = threshold,
    tp = tp,
    fp = fp,
    tn = tn,
    fn = fn,
    accuracy = (tp + tn) / length(actual),
    precision = precision,
    recall = recall,
    specificity = specificity,
    f1 = f1
  )
}

tune_threshold <- function(actual, scores, thresholds = seq(0.05, 0.95, by = 0.05), metric = "f1") {
  results <- do.call(rbind, lapply(thresholds, function(threshold) {
    confusion_matrix_metrics(actual, scores, threshold)
  }))

  if (!metric %in% names(results)) {
    stop("Threshold tuning metric not found: ", metric)
  }

  list(
    best_threshold = results$threshold[which.max(results[[metric]])],
    best_metric = metric,
    threshold_table = results
  )
}

psi_score <- function(expected_scores, actual_scores, bins = 10L) {
  breaks <- unique(stats::quantile(expected_scores, probs = seq(0, 1, length.out = bins + 1L), na.rm = TRUE))
  score_range <- range(c(expected_scores, actual_scores), na.rm = TRUE)
  if (!all(is.finite(score_range)) || score_range[[1L]] == score_range[[2L]]) {
    return(0)
  }

  if (length(breaks) < 3L) {
    breaks <- seq(score_range[[1L]], score_range[[2L]], length.out = bins + 1L)
  } else {
    breaks[[1L]] <- score_range[[1L]]
    breaks[[length(breaks)]] <- score_range[[2L]]
  }

  expected_bins <- cut(expected_scores, breaks = breaks, include.lowest = TRUE)
  actual_bins <- cut(actual_scores, breaks = breaks, include.lowest = TRUE)
  expected_pct <- as.numeric(table(expected_bins)) / length(expected_scores)
  actual_pct <- as.numeric(table(actual_bins)) / length(actual_scores)
  expected_pct <- pmax(expected_pct, 0.0001)
  actual_pct <- pmax(actual_pct, 0.0001)

  sum((actual_pct - expected_pct) * log(actual_pct / expected_pct))
}

feature_importance <- function(model, model_name) {
  if (identical(model_name, "logistic_regression")) {
    coefficients <- stats::coef(model)
    coefficients <- coefficients[names(coefficients) != "(Intercept)"]
    importance <- abs(coefficients)
    if (sum(importance, na.rm = TRUE) > 0) {
      importance <- importance / sum(importance, na.rm = TRUE)
    }
    return(data.frame(feature = names(importance), importance = as.numeric(importance), row.names = NULL))
  }

  if (identical(model_name, "random_forest")) {
    importance <- randomForest::importance(model)
    importance_col <- if ("MeanDecreaseGini" %in% colnames(importance)) "MeanDecreaseGini" else colnames(importance)[[1L]]
    return(data.frame(feature = rownames(importance), importance = as.numeric(importance[, importance_col]), row.names = NULL))
  }

  if (identical(model_name, "xgboost")) {
    importance <- xgboost::xgb.importance(model = model)
    return(data.frame(feature = importance$Feature, importance = importance$Gain, row.names = NULL))
  }

  data.frame(feature = character(), importance = numeric())
}

apply_decision_rules <- function(scores, reject_threshold = 0.8, investigate_threshold = 0.5) {
  if (investigate_threshold >= reject_threshold) {
    stop("Investigate threshold must be lower than reject threshold.")
  }

  ifelse(
    scores >= reject_threshold,
    "reject",
    ifelse(scores >= investigate_threshold, "investigate", "approve")
  )
}

validate_credit_risk_models <- function(df, target, features, thresholds = seq(0.05, 0.95, by = 0.05)) {
  validate_basic(df, c(target, features))

  model_df <- stats::na.omit(df[, c(target, features), drop = FALSE])
  model_df[[target]] <- as_binary_target(model_df[[target]])
  models <- train_credit_risk_models(model_df, target, features)

  reports <- lapply(names(models), function(model_name) {
    scores <- predict_credit_risk_scores(models[[model_name]], model_name, model_df, target, features)
    threshold_result <- tune_threshold(model_df[[target]], scores, thresholds = thresholds)
    best_threshold <- threshold_result$best_threshold
    reject_threshold <- max(0.8, min(1, best_threshold + 0.1))
    decisions <- apply_decision_rules(scores, reject_threshold = reject_threshold, investigate_threshold = best_threshold)

    list(
      model = model_name,
      roc_auc = roc_auc(model_df[[target]], scores),
      pr_auc = pr_auc(model_df[[target]], scores),
      ks_score = ks_score(model_df[[target]], scores),
      psi = psi_score(scores[model_df[[target]] == 0L], scores[model_df[[target]] == 1L]),
      confusion_matrix = confusion_matrix_metrics(model_df[[target]], scores, best_threshold),
      threshold_tuning = threshold_result$threshold_table,
      best_threshold = best_threshold,
      feature_importance = feature_importance(models[[model_name]], model_name),
      decision_counts = sort(table(decisions), decreasing = TRUE)
    )
  })

  names(reports) <- names(models)
  list(target = target, features = features, row_count = nrow(model_df), reports = reports)
}

write_model_validation_report <- function(validation, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  lines <- c(
    "# Fraud And Credit-Risk Model Validation Report",
    "",
    paste0("- Target: `", validation$target, "`"),
    paste0("- Rows evaluated: ", validation$row_count),
    paste0("- Features: `", paste(validation$features, collapse = "`, `"), "`"),
    ""
  )

  for (report in validation$reports) {
    confusion <- report$confusion_matrix
    top_features <- utils::head(report$feature_importance[order(report$feature_importance$importance, decreasing = TRUE), ], 5L)
    lines <- c(
      lines,
      paste0("## ", gsub("_", " ", report$model)),
      "",
      paste0("- ROC-AUC: ", round(report$roc_auc, 4L)),
      paste0("- PR-AUC: ", round(report$pr_auc, 4L)),
      paste0("- KS score: ", round(report$ks_score, 4L)),
      paste0("- PSI: ", round(report$psi, 4L)),
      paste0("- Tuned threshold: ", round(report$best_threshold, 4L)),
      paste0("- Confusion matrix: TP=", confusion$tp, ", FP=", confusion$fp, ", TN=", confusion$tn, ", FN=", confusion$fn),
      paste0("- Decision rules: ", paste(names(report$decision_counts), as.integer(report$decision_counts), sep = "=", collapse = ", ")),
      "",
      "### Top Feature Importance",
      "",
      if (nrow(top_features) == 0L) {
        "No feature-importance output is available for this model."
      } else {
        c("| Feature | Importance |", "| --- | ---: |", paste0("| ", top_features$feature, " | ", round(top_features$importance, 4L), " |"))
      },
      ""
    )
  }

  writeLines(lines, path)
  path
}
