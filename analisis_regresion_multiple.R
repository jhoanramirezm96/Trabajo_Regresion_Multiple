# Rendimiento academico: regresion lineal multiple reproducible.
# Integrantes: Frank Arlom Rico; Emily Daniela Hernandez;
# Jhoan Sebastian Ramirez Monsalve.
# Fuente de la simulacion: Dataset_RegMultiple.R suministrado en la actividad.
# No se usa el Excel adjunto: contiene ID, Metodo y Puntaje (90 registros).
# Ejecucion: Rscript analisis_regresion_multiple.R
# Requiere R >= 3.6.0. No requiere paquetes adicionales.

options(digits = 15)
args <- commandArgs(trailingOnly = FALSE)
script_arg <- grep("^--file=", args, value = TRUE)
root <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[1]))) else getwd()
out <- file.path(root, "resultados")
dir.create(out, showWarnings = FALSE, recursive = TRUE)
save_table <- function(x, name, row.names = FALSE) {
  write.csv(x, file.path(out, paste0(name, ".csv")), row.names = row.names, fileEncoding = "UTF-8")
}

# 1. Reproducir el generador original. Se explicitan los algoritmos de R moderno.
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
set.seed(123)
n <- 2000
edad <- round(rnorm(n, mean = 21, sd = 3))
genero <- sample(c(0, 1), n, replace = TRUE)
estrato <- sample(1:6, n, replace = TRUE, prob = c(.25, .30, .20, .15, .07, .03))
ingreso_familiar <- round(rnorm(n, mean = 2000000 + estrato * 500000, sd = 500000))
horas_estudio <- round(rnorm(n, mean = 15, sd = 5))
asistencia <- round(runif(n, 70, 100), 1)
reprobadas <- rpois(n, lambda = 1)
motivacion <- round(runif(n, 1, 5), 1)
estres <- round(runif(n, 1, 5), 1)
apoyo_familiar <- round(runif(n, 1, 5), 1)
trabaja <- sample(c(0, 1), n, replace = TRUE, prob = c(.7, .3))
horas_trabajo <- ifelse(trabaja == 1, round(rnorm(n, 20, 10)), 0)
uso_redes <- round(rnorm(n, mean = 3, sd = 1.5), 1)
sueno <- round(rnorm(n, mean = 7, sd = 1.5), 1)
rendimiento <- 2.5 + .05 * horas_estudio + .03 * asistencia / 10 +
  .2 * motivacion - .15 * estres + .1 * apoyo_familiar - .2 * reprobadas -
  .1 * trabaja + .02 * sueno - .03 * uso_redes + rnorm(n, 0, .3)
rendimiento <- pmin(pmax(rendimiento, 0), 5)
datos <- data.frame(edad, genero, estrato, ingreso_familiar, horas_estudio,
                    asistencia, reprobadas, motivacion, estres, apoyo_familiar,
                    trabaja, horas_trabajo, uso_redes, sueno, rendimiento)
# El original llama write.xlsx(dataset, ...), pero el objeto se llama datos.
# Se exporta CSV para no depender de openxlsx ni alterar el Excel recibido.
write.csv(datos, file.path(root, "datos_simulados_R.csv"), row.names = FALSE)

# 2. Auditoria y exploracion. Se conserva la simulacion original para el ajuste.
descriptivos <- data.frame(variable = names(datos), n = sapply(datos, length),
  media = sapply(datos, mean), de = sapply(datos, sd), minimo = sapply(datos, min),
  q1 = sapply(datos, quantile, .25), mediana = sapply(datos, median),
  q3 = sapply(datos, quantile, .75), maximo = sapply(datos, max), row.names = NULL)
save_table(descriptivos, "descriptivos")
save_table(data.frame(variable = names(datos), faltantes = colSums(is.na(datos)),
  negativos = colSums(datos < 0)), "calidad_por_variable")
negativos <- datos$horas_estudio < 0 | datos$horas_trabajo < 0 | datos$uso_redes < 0 | datos$sueno < 0
save_table(data.frame(fila = which(negativos), datos[negativos, ]), "filas_con_horas_negativas")
save_table(data.frame(variable = names(datos), correlacion = cor(datos)[, "rendimiento"]), "correlaciones")

# 3. Modelo preespecificado: los diez predictores del ejemplo del profesor.
form <- rendimiento ~ horas_estudio + asistencia + motivacion + estres +
  apoyo_familiar + reprobadas + trabaja + sueno + uso_redes + estrato
modelo <- lm(form, data = datos)
s <- summary(modelo)
co <- coef(s)
ic <- confint(modelo)
coeficientes <- data.frame(termino = rownames(co), beta = co[, 1], ee = co[, 2],
  t = co[, 3], p = co[, 4], ic_inf = ic[, 1], ic_sup = ic[, 2], row.names = NULL)

# Covarianza HC3 como sensibilidad de la inferencia; contraste t aproximado.
X <- model.matrix(modelo)
e <- residuals(modelo)
h <- hatvalues(modelo)
XtX_inv <- chol2inv(chol(crossprod(X)))
Xw <- X * as.vector(e / (1 - h))
Vhc3 <- XtX_inv %*% crossprod(Xw) %*% XtX_inv
se_hc3 <- sqrt(diag(Vhc3))
coeficientes$ee_hc3 <- se_hc3
coeficientes$p_hc3 <- 2 * pt(abs(coef(modelo) / se_hc3), df.residual(modelo), lower.tail = FALSE)
coeficientes$ic_hc3_inf <- coef(modelo) - qt(.975, df.residual(modelo)) * se_hc3
coeficientes$ic_hc3_sup <- coef(modelo) + qt(.975, df.residual(modelo)) * se_hc3
save_table(coeficientes, "coeficientes")

predictores <- all.vars(form)[-1]
vif <- sapply(predictores, function(v) {
  aux <- reformulate(setdiff(predictores, v), response = v)
  1 / (1 - summary(lm(aux, data = datos))$r.squared)
})
save_table(data.frame(variable = names(vif), vif = as.numeric(vif)), "vif")

# 4. Diagnosticos: Shapiro-Wilk, Breusch-Pagan studentizado (Koenker), RESET.
sh <- shapiro.test(e)
aux_bp <- lm(I(e^2) ~ X[, -1])
bp <- nrow(datos) * summary(aux_bp)$r.squared
bp_p <- pchisq(bp, df = length(predictores), lower.tail = FALSE)
aj <- fitted(modelo)
mod_reset <- lm(datos$rendimiento ~ X[, -1] + I(aj^2) + I(aj^3))
q <- df.residual(modelo) - df.residual(mod_reset)
reset_f <- ((deviance(modelo) - deviance(mod_reset)) / q) / (deviance(mod_reset) / df.residual(mod_reset))
reset_p <- pf(reset_f, q, df.residual(mod_reset), lower.tail = FALSE)
dw <- sum(diff(e)^2) / sum(e^2)
cook <- cooks.distance(modelo)
rst <- rstudent(modelo)
save_table(data.frame(fila = seq_len(n), ajustado = aj, residuo = e,
  estandarizado = rstandard(modelo), studentizado = rst, leverage = h, cook = cook), "diagnosticos_filas")

# 5. Validacion fuera de muestra. Ninguna seleccion se hace con la prueba.
set.seed(2026)
train_id <- sort(sample.int(n, size = floor(.8 * n)))
test_id <- setdiff(seq_len(n), train_id)
train <- datos[train_id, ]
test <- datos[test_id, ]
modelo_train <- lm(form, data = train)
pr <- predict(modelo_train, newdata = test, interval = "prediction", level = .95)
metrics <- function(y, p) c(rmse = sqrt(mean((y - p)^2)), mae = mean(abs(y - p)),
                          r2 = 1 - sum((y - p)^2) / sum((y - mean(y))^2))
m_train <- metrics(train$rendimiento, predict(modelo_train))
m_test <- metrics(test$rendimiento, pr[, "fit"])
m_base <- metrics(test$rendimiento, rep(mean(train$rendimiento), nrow(test)))
save_table(data.frame(conjunto = c("entrenamiento", "prueba", "base_media_prueba"),
  n = c(nrow(train), nrow(test), nrow(test)), rbind(m_train, m_test, m_base), row.names = NULL), "validacion")
save_table(data.frame(fila = test_id, observado = test$rendimiento,
  predicho = pr[, "fit"], limite_inf = pr[, "lwr"], limite_sup = pr[, "upr"]), "predicciones_prueba")
save_table(data.frame(fila = seq_len(n), conjunto = ifelse(seq_len(n) %in% train_id, "entrenamiento", "prueba")), "particion")

# Validacion cruzada de cinco particiones solo dentro del entrenamiento.
set.seed(2027)
fold <- sample(rep(1:5, length.out = nrow(train)))
cv <- do.call(rbind, lapply(1:5, function(k) {
  mk <- lm(form, data = train[fold != k, ])
  met <- metrics(train$rendimiento[fold == k], predict(mk, newdata = train[fold == k, ]))
  data.frame(particion = k, t(met))
}))
save_table(cv, "validacion_cruzada")

# 6. Sensibilidad; no modifica el modelo ni su prueba principal.
mod_no_neg <- lm(form, data = datos[!negativos, ])
mod_no_cook <- lm(form, data = datos[cook <= 4 / n, ])
sens <- data.frame(termino = names(coef(modelo)), original = coef(modelo),
  sin_horas_negativas = coef(mod_no_neg), sin_cook_mayor_4_n = coef(mod_no_cook), row.names = NULL)
save_table(sens, "sensibilidad_coeficientes")
mod_factor <- lm(update(form, . ~ . - estrato + factor(estrato)), data = datos)
anova_factor <- anova(modelo, mod_factor)

# 7. Ejemplo ilustrativo usando el modelo reajustado con las 2000 filas.
nuevo <- data.frame(horas_estudio = 15, asistencia = 90, motivacion = 4,
  estres = 2, apoyo_familiar = 4, reprobadas = 0, trabaja = 0, sueno = 8,
  uso_redes = 2, estrato = 3)
save_table(data.frame(nuevo, predict(modelo, nuevo, interval = "confidence")), "ejemplo_ic_media")
save_table(data.frame(nuevo, predict(modelo, nuevo, interval = "prediction")), "ejemplo_ip_individual")

# 8. Resumen de resultados para tablas, informe y verificacion independiente.
fs <- s$fstatistic
resumen <- c(n = n, predictores = length(predictores), faltantes = sum(is.na(datos)),
  duplicados = sum(duplicated(datos)), horas_negativas_filas = sum(negativos),
  rendimiento_cero = sum(datos$rendimiento == 0), rendimiento_cinco = sum(datos$rendimiento == 5),
  r2 = s$r.squared, r2_ajustado = s$adj.r.squared, sigma = s$sigma,
  rmse_ajuste = sqrt(mean(e^2)), F = unname(fs[1]), gl1 = unname(fs[2]), gl2 = unname(fs[3]),
  p_F = unname(pf(fs[1], fs[2], fs[3], lower.tail = FALSE)),
  shapiro_W = unname(sh$statistic), shapiro_p = sh$p.value,
  bp_LM = bp, bp_gl = length(predictores), bp_p = bp_p,
  reset_F = reset_f, reset_gl1 = q, reset_gl2 = df.residual(mod_reset), reset_p = reset_p,
  durbin_watson = dw, vif_max = max(vif),
  cook_max = max(cook), cook_mayor_4_n = sum(cook > 4 / n), cook_mayor_uno = sum(cook > 1),
  leverage_max = max(h), leverage_mayor_2p_n = sum(h > 2 * ncol(X) / n),
  studentizados_mayor_tres = sum(abs(rst) > 3),
  cobertura_ip_prueba = mean(test$rendimiento >= pr[, "lwr"] & test$rendimiento <= pr[, "upr"]),
  predicciones_fuera_escala_prueba = sum(pr[, "fit"] < 0 | pr[, "fit"] > 5),
  cv_rmse_media = mean(cv$rmse), cv_rmse_de = sd(cv$rmse),
  mejora_rmse_vs_media = unname(1 - m_test["rmse"] / m_base["rmse"]),
  sensibilidad_no_neg_r2 = summary(mod_no_neg)$r.squared,
  sensibilidad_no_cook_r2 = summary(mod_no_cook)$r.squared,
  factor_estrato_F = anova_factor$F[2], factor_estrato_p = anova_factor$`Pr(>F)`[2])
save_table(data.frame(metrica = names(resumen), valor = as.numeric(resumen)), "resumen")
capture.output(summary(modelo), file = file.path(out, "summary_modelo.txt"))
capture.output(sessionInfo(), file = file.path(out, "sesion_R.txt"))
print(s)
print(data.frame(metrica = names(resumen), valor = as.numeric(resumen)), row.names = FALSE)
cat("\nResultados guardados en:", out, "\n")
