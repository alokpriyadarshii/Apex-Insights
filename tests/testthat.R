library(testthat)

# Load project functions
for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) source(f)

test_check("my_industry_r_project")
