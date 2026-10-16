# Lee el xlsx (lento) y guarda cada hoja como RDS para trabajar rápido
library(readxl)
f <- "data/raw/siniestros_viales_consolidados_bogota_dc.xlsx"
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
for (h in c("SINIESTROS", "ACTOR_VIAL", "DICCIONARIO")) {
  d <- read_excel(f, sheet = h, guess_max = 20000)
  saveRDS(d, file.path("data/processed", paste0(tolower(h), ".rds")))
  cat("\n==", h, ":", nrow(d), "filas x", ncol(d), "columnas\n")
  print(names(d))
}
