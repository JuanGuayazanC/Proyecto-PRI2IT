# EDA completo - Siniestros viales Bogotá D.C. (SDM, 2015-2020)
# Requiere: scripts/00_importar.R y scripts/01_eda.R ejecutados antes.
suppressMessages({library(dplyr); library(tidyr); library(ggplot2)})

dir.create("outputs/tables",  showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/figures", showWarnings = FALSE, recursive = TRUE)
guardar_tabla <- function(x, nombre) write.csv(x, file.path("outputs/tables", nombre), row.names = FALSE)
guardar_fig   <- function(p, nombre, w = 8, h = 5) ggsave(file.path("outputs/figures", nombre), p, width = w, height = h, dpi = 150)
theme_set(theme_minimal(base_size = 11))

s   <- readRDS("data/processed/siniestros_limpio.rds")
a   <- readRDS("data/processed/actor_vial.rds")
dic <- readRDS("data/processed/diccionario.rds")
cod <- function(campo, hoja = "SINIESTROS") {
  dic %>% filter(HOJA == hoja, CAMPO == campo) %>%
    transmute(codigo = as.numeric(CODIGO), etiqueta = DESCRIPCION)
}
p0 <- mean(s$fatal)

# ---- 1. Calidad de los datos -------------------------------------------------
calidad <- tibble(
  indicador = c("Siniestros", "Víctimas/actores (ACTOR_VIAL)", "IDs duplicados",
                "Fecha mínima", "Fecha máxima", "NA en GRAVEDAD", "NA en CODIGO_LOCALIDAD",
                "Actores sin siniestro en hoja SINIESTROS", "Localidad 'Sumapaz' (n)"),
  valor = c(nrow(s), nrow(a), sum(duplicated(s$CODIGO_ACCIDENTE)),
            format(min(s$FECHA)), format(max(s$FECHA)),
            sum(is.na(s$GRAVEDAD)), sum(is.na(s$CODIGO_LOCALIDAD)),
            sum(!a$CODIGO_ACCIDENTE %in% s$CODIGO_ACCIDENTE),
            sum(s$localidad == "Sumapaz", na.rm = TRUE)))
guardar_tabla(calidad, "01_calidad_datos.csv"); print(calidad)

# ---- 2. Gravedad -------------------------------------------------------------
grav <- s %>% count(GRAVEDAD) %>% left_join(cod("GRAVEDAD"), by = c("GRAVEDAD" = "codigo")) %>%
  mutate(prop = round(n / sum(n), 4))
guardar_tabla(grav, "02_gravedad.csv"); print(grav)
guardar_fig(ggplot(grav, aes(reorder(etiqueta, -n), n)) + geom_col(fill = "#2c7fb8") +
  geom_text(aes(label = scales::percent(prop, accuracy = 0.1)), vjust = -0.3) +
  labs(x = NULL, y = "Siniestros", title = "Gravedad de los siniestros, Bogotá 2015-2020"), "02_gravedad.png")

# ---- 3. Serie anual y mensual ------------------------------------------------
anual <- s %>% group_by(anio) %>%
  summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop")
guardar_tabla(anual, "03_anual.csv"); print(anual)
guardar_fig(ggplot(anual, aes(anio, tasa)) + geom_line() + geom_point(size = 2) +
  geom_hline(yintercept = p0, linetype = 2, colour = "grey40") +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  labs(x = "Año", y = "Proporción fatal", title = "Proporción de siniestros fatales por año",
       subtitle = "Línea punteada: proporción global de Bogotá"), "03_tasa_anual.png")

mensual <- s %>% mutate(mes = as.Date(format(FECHA, "%Y-%m-01"))) %>%
  group_by(mes) %>% summarise(n = n(), fatales = sum(fatal), .groups = "drop")
guardar_tabla(mensual, "03_mensual.csv")
guardar_fig(ggplot(mensual, aes(mes, n)) + geom_line(colour = "#2c7fb8") +
  geom_vline(xintercept = as.Date("2020-03-25"), linetype = 2, colour = "firebrick") +
  annotate("text", x = as.Date("2020-03-25"), y = max(mensual$n), label = " Cuarentena",
           hjust = 0, colour = "firebrick") +
  labs(x = NULL, y = "Siniestros por mes", title = "Siniestros mensuales y efecto de la pandemia"),
  "03_mensual.png")

# Homogeneidad de la proporción fatal entre años (¿es razonable un único p?)
chi_anio <- chisq.test(table(s$anio, s$fatal))
cat("\nChi-cuadrado homogeneidad por año: X2 =", round(chi_anio$statistic, 2),
    " gl =", chi_anio$parameter, " p =", signif(chi_anio$p.value, 3), "\n")

# ---- 4. Hora y día de la semana ---------------------------------------------
s <- s %>% mutate(hora = suppressWarnings(as.integer(substr(HORA, 1, 2))),
                  dow = as.integer(format(FECHA, "%u")),
                  dia = factor(dow, 1:7, c("Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom")))
por_hora <- s %>% filter(!is.na(hora)) %>% group_by(hora) %>%
  summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop")
por_dia <- s %>% group_by(dia) %>% summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop")
guardar_tabla(por_hora, "04_por_hora.csv"); guardar_tabla(por_dia, "04_por_dia.csv")
guardar_fig(ggplot(por_hora, aes(hora, tasa)) + geom_col(fill = "#41ab5d") +
  geom_hline(yintercept = p0, linetype = 2) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  labs(x = "Hora del día", y = "Proporción fatal", title = "Letalidad por hora (más alta de madrugada)"),
  "04_tasa_por_hora.png")
guardar_fig(ggplot(por_dia, aes(dia, tasa)) + geom_col(fill = "#41ab5d") +
  geom_hline(yintercept = p0, linetype = 2) +
  scale_y_continuous(labels = scales::percent_format(accuracy = 0.1)) +
  labs(x = NULL, y = "Proporción fatal", title = "Letalidad por día de la semana"), "04_tasa_por_dia.png")

# ---- 5. Clase de siniestro y diseño del lugar --------------------------------
por_clase <- s %>% group_by(CLASE) %>% summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop") %>%
  left_join(cod("CLASE"), by = c("CLASE" = "codigo")) %>% arrange(desc(n))
por_dis <- s %>% group_by(DISENO_LUGAR) %>% summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop") %>%
  left_join(cod("DISENO_LUGAR"), by = c("DISENO_LUGAR" = "codigo")) %>% arrange(desc(n))
guardar_tabla(por_clase, "05_por_clase.csv"); guardar_tabla(por_dis, "05_por_diseno_lugar.csv")
print(por_clase); print(head(por_dis, 6))
guardar_fig(ggplot(por_clase %>% filter(n >= 100), aes(reorder(etiqueta, tasa), tasa)) + geom_col(fill = "#d95f0e") +
  coord_flip() + scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(x = NULL, y = "Proporción fatal", title = "Letalidad por clase de siniestro"), "05_tasa_por_clase.png")

# ---- 6. Localidad: proporción fatal con IC exacto (Clopper-Pearson) ---------
loc <- s %>% group_by(localidad) %>% summarise(n = n(), fatales = sum(fatal), .groups = "drop") %>%
  mutate(tasa = fatales / n,
         lo = mapply(function(x, n) binom.test(x, n)$conf.int[1], fatales, n),
         hi = mapply(function(x, n) binom.test(x, n)$conf.int[2], fatales, n)) %>%
  arrange(desc(n))
guardar_tabla(loc, "06_localidad.csv"); print(loc)
guardar_fig(ggplot(loc, aes(reorder(localidad, tasa), tasa, ymin = lo, ymax = hi)) +
  geom_pointrange(colour = "#2c7fb8") + geom_hline(yintercept = p0, linetype = 2, colour = "firebrick") +
  coord_flip(ylim = c(0, 0.08)) + scale_y_continuous(labels = scales::percent_format(accuracy = 1)) +
  labs(x = NULL, y = "Proporción fatal (IC 95% exacto)",
       title = "Proporción de siniestros fatales por localidad",
       subtitle = "Línea roja: Bogotá. Sumapaz (n = 7) queda truncada: es el caso típico donde el prior importa"),
  "06_localidad_forest.png", h = 6.5)

# ---- 7. Periodo 2015-2019 vs 2020 por localidad (diseño prior / verosimilitud)
per <- s %>% mutate(periodo = ifelse(anio <= 2019, "p1519", "p2020")) %>%
  group_by(localidad, periodo) %>% summarise(n = n(), fat = sum(fatal), .groups = "drop") %>%
  pivot_wider(names_from = periodo, values_from = c(n, fat)) %>%
  mutate(tasa_1519 = fat_p1519 / n_p1519, tasa_2020 = fat_p2020 / n_p2020) %>% arrange(desc(n_p2020))
guardar_tabla(per, "07_localidad_periodos.csv"); print(per)
guardar_fig(ggplot(per %>% filter(localidad != "Sumapaz"), aes(tasa_1519, tasa_2020, size = n_p2020, label = localidad)) +
  geom_abline(slope = 1, intercept = 0, linetype = 2) + geom_point(alpha = .6, colour = "#2c7fb8") +
  geom_text(size = 3, vjust = -1, check_overlap = TRUE, show.legend = FALSE) +
  scale_x_continuous(labels = scales::percent) + scale_y_continuous(labels = scales::percent) +
  labs(x = "Proporción fatal 2015-2019", y = "Proporción fatal 2020", size = "Siniestros 2020",
       title = "¿Es estable la proporción fatal por localidad?"), "07_localidad_1519_vs_2020.png", w = 9, h = 6)

# ---- 8. Actor vial (hoja ACTOR_VIAL) ----------------------------------------
act <- a %>% count(CONDICION, ESTADO) %>% pivot_wider(names_from = ESTADO, values_from = n, values_fill = 0) %>%
  mutate(total = HERIDO + ILESO + MUERTO, letalidad = MUERTO / total) %>% arrange(desc(MUERTO))
guardar_tabla(act, "08_actor_vial.csv"); print(act)
guardar_fig(ggplot(act, aes(reorder(CONDICION, MUERTO), MUERTO)) + geom_col(fill = "#756bb1") + coord_flip() +
  labs(x = NULL, y = "Víctimas fatales (2015-2020)", title = "Fallecidos por condición del actor vial"),
  "08_muertos_por_actor.png")

# A nivel de siniestro: ¿el siniestro involucra a un motociclista?
moto <- a %>% filter(CONDICION == "MOTOCICLISTA") %>% distinct(CODIGO_ACCIDENTE) %>% mutate(con_moto = 1L)
s2 <- s %>% left_join(moto, by = "CODIGO_ACCIDENTE") %>% mutate(con_moto = coalesce(con_moto, 0L))
moto_tab <- s2 %>% group_by(con_moto) %>% summarise(n = n(), fatales = sum(fatal), tasa = fatales / n, .groups = "drop")
guardar_tabla(moto_tab, "08_motociclista_siniestro.csv"); print(moto_tab)

# Edad y sexo de los fallecidos
fall <- a %>% filter(ESTADO == "MUERTO") %>% mutate(edad = suppressWarnings(as.numeric(EDAD)))
cat("\nEdad de fallecidos (resumen):\n"); print(summary(fall$edad))
guardar_fig(ggplot(fall %>% filter(!is.na(edad), edad < 110, SEXO != "SIN INFORMACION"), aes(edad, fill = SEXO)) +
  geom_histogram(binwidth = 5, position = "dodge") + labs(x = "Edad", y = "Fallecidos", fill = NULL,
  title = "Edad y sexo de las víctimas fatales"), "08_edad_sexo_fallecidos.png")

# ---- 9. Candidatas de localidad para el caso de estudio ---------------------
cand <- per %>% transmute(localidad, n_1519 = n_p1519, fat_1519 = fat_p1519, n_2020 = n_p2020, fat_2020 = fat_p2020,
                          tasa_1519 = round(tasa_1519, 4), tasa_2020 = round(tasa_2020, 4),
                          dif_vs_bogota_2020 = round(tasa_2020 - sum(s$fatal[s$anio == 2020]) / sum(s$anio == 2020), 4))
guardar_tabla(cand, "09_candidatas.csv")
cat("\nProporción fatal Bogotá global:", round(p0, 5),
    "| 2015-2019:", round(mean(s$fatal[s$anio <= 2019]), 5), "| 2020:", round(mean(s$fatal[s$anio == 2020]), 5), "\n")
cat("\nListo. Tablas en outputs/tables, figuras en outputs/figures.\n")
