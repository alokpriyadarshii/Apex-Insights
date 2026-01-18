root <- rprojroot::find_root(rprojroot::has_file("_targets.R"), path = getwd())
r_dir <- file.path(root, "R")
for (f in list.files(r_dir, pattern = "\\.R$", full.names = TRUE)) source(f, local = globalenv())
