# Estimación bayesiana de la proporción de siniestros viales fatales por localidad en Bogotá D.C.

Proyecto Integrador 2 - Estadística Bayesiana (ECI Julio Garavito, 2026-2). Modelo Beta-Binomial.

## Datos
"Siniestros Viales Consolidados Bogotá D.C." (Secretaría Distrital de Movilidad, CC BY 4.0).
Cobertura real: **2015-01-01 a 2020-12-31** (196.152 siniestros; 422.416 actores viales).

1. Descargar el xlsx desde <https://datosabiertos.bogota.gov.co/dataset/siniestros-viales-consolidados-bogota-d-c>
   y guardarlo en `data/raw/siniestros_viales_consolidados_bogota_dc.xlsx` (no se versiona).
2. Ejecutar en R, en orden: `scripts/00_importar.R`, `scripts/01_eda.R`, `scripts/02_eda_completo.R`.

Paquetes: readxl, dplyr, tidyr, ggplot2.

## Salidas del EDA
`outputs/tables/*.csv` y `outputs/figures/*.png`.

## Hallazgos del EDA
- Proporción fatal global: 1,53 % (2015-2019: 1,51 %; 2020: 1,63 %). No es homogénea entre años (chi-cuadrado, p = 0,001).
- 2020 es atípico: caída de ~35 % en siniestros por la cuarentena.
- Localidades con proporción fatal bien por encima de Bogotá: Usme (3,2 %), Ciudad Bolívar (2,9 %); muy por debajo: Chapinero, Usaquén, Teusaquillo (~0,8-0,9 %).
- Sumapaz tiene solo 7 siniestros (3 fatales): útil para ilustrar el efecto del prior.
- Letalidad por actor: peatón 6,1 %, ciclista 3,1 %, motociclista 1,7 %. Los siniestros con motociclista son ~3 veces más letales (3,1 % vs 1,0 %).
- Atropello: 6,9 % fatal vs 0,8 % en choque.
