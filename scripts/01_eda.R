library(dplyr)
s   <- readRDS("data/processed/siniestros.rds")
dic <- readRDS("data/processed/diccionario.rds")
loc <- dic %>% filter(CAMPO == "CODIGO_LOCALIDAD") %>%
  transmute(CODIGO_LOCALIDAD = as.numeric(CODIGO), localidad = DESCRIPCION)

s <- s %>%
  mutate(FECHA = as.Date(FECHA, format = "%d/%m/%Y"),
         anio  = as.integer(format(FECHA, "%Y")),
         fatal = as.integer(GRAVEDAD == 1)) %>%
  left_join(loc, by = "CODIGO_LOCALIDAD")
saveRDS(s, "data/processed/siniestros_limpio.rds")

cat("Rango fechas:", format(range(s$FECHA, na.rm = TRUE)), " | NA fechas:", sum(is.na(s$FECHA)), "\n")
cat("\nBogotá por año (n, fatales, tasa):\n")
print(s %>% group_by(anio) %>%
  summarise(n = n(), fatales = sum(fatal), tasa = round(fatales / n, 4)) %>% as.data.frame())

cat("\nLocalidad (todo el periodo):\n")
print(s %>% group_by(localidad) %>%
  summarise(n = n(), fatales = sum(fatal), tasa = round(fatales / n, 4)) %>%
  arrange(desc(n)) %>% as.data.frame())

p0 <- mean(s$fatal); cat("\nTasa Bogotá global:", round(p0, 5), "\n")

cat("\nPeriodo 2015-2019 vs 2020-2021, por localidad:\n")
print(s %>% mutate(per = ifelse(anio <= 2019, "2015-19", "2020-21")) %>%
  group_by(localidad, per) %>%
  summarise(n = n(), fat = sum(fatal), tasa = round(fat / n, 4), .groups = "drop") %>%
  tidyr::pivot_wider(names_from = per, values_from = c(n, fat, tasa)) %>%
  as.data.frame())
