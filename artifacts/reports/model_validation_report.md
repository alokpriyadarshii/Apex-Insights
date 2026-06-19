# Fraud And Credit-Risk Model Validation Report

- Target: `fraud_flag`
- Rows evaluated: 200
- Features: `x1`, `x2`

## logistic regression

- ROC-AUC: 0.5599
- PR-AUC: 0.5453
- KS score: 0.17
- PSI: 0.2322
- Tuned threshold: 0.05
- Confusion matrix: TP=100, FP=100, TN=0, FN=0
- Decision rules: investigate=200

### Top Feature Importance

| Feature | Importance |
| --- | ---: |
| x1 | 0.8499 |
| x2 | 0.1501 |

