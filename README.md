# Regresión lineal múltiple del rendimiento académico

**Integrantes:** Frank Arlom Rico, Emily Daniela Hernandez y Jhoan Sebastian Ramirez Monsalve.

El informe analiza la base de 2.000 registros generada por el script R del material de clase. Incluye exploración, ajuste, interpretación de todos los coeficientes, diagnósticos, sensibilidad, evaluación predictiva y anexo de uso de IA.

## Fuente utilizada

El Excel adjunto en la actividad contiene 90 observaciones de `ID`, `Metodo` y `Puntaje`, y no corresponde al generador de rendimiento académico. Se reconstruyó la base con el generador original en R, semilla 123, y se corrigió la referencia al objeto de exportación. Esta decisión queda documentada en la primera página del informe. Los datos son simulados; no son registros de estudiantes reales.

## Archivos principales

| Archivo | Uso |
|---|---|
| `Informe_Regresion_Multiple.pdf` | Informe de 11 páginas compilado con LaTeX. |
| `analisis_regresion_multiple.R` | Generación de la base y análisis completo; solo requiere R. |
| `datos_simulados_R.csv` | Base exacta analizada, con 2.000 filas y 15 variables. |
| `Informe_Regresion_Multiple.html` | Informe con imágenes incorporadas y fórmulas MathML; se puede abrir sin conexión. |
| `index.html` | La misma versión HTML, con el nombre de entrada para GitHub Pages. |
| `Informe_Regresion_Multiple.tex` | Fuente LaTeX editable. |
| `Informe_Regresion_Multiple.md` | Fuente del contenido en Markdown. |
| `generar_informe.py` | Generación de figuras y compilación del informe. |
| `resultados/` | Tablas, particiones, predicciones, diagnósticos y sesión de R. |
| `figuras/` | Gráficos en PNG y PDF. |

## Reproducir los resultados

Descomprimir el proyecto y abrir una terminal en su carpeta. Con R 3.6 o posterior:

```bash
Rscript analisis_regresion_multiple.R
```

No se instalan paquetes adicionales. La ejecución de referencia se realizó con R 4.3.3. Se fijan explícitamente Mersenne-Twister, Inversion y Rejection. Las semillas son 123 para la base, 2026 para la partición de entrenamiento y prueba, y 2027 para la validación cruzada dentro del entrenamiento.

El modelo principal es:

```r
rendimiento ~ horas_estudio + asistencia + motivacion + estres +
  apoyo_familiar + reprobadas + trabaja + sueno + uso_redes + estrato
```

El código preserva las horas negativas del generador en el análisis principal y presenta su exclusión solo como sensibilidad. Mantiene también las predicciones fuera de 0 a 5 para hacer visible esa limitación. La prueba predictiva contiene 400 filas que no participaron en el ajuste del modelo entrenado.

Para volver a generar figuras y compilar el documento, usar Python 3.12 o posterior, las versiones del archivo `requirements.txt`, Pandoc y XeLaTeX:

```bash
python -m pip install -r requirements.txt
python generar_informe.py
```

Los gráficos y las tablas se leen de los resultados. La discusión escrita corresponde a las semillas y a la especificación entregadas; si se cambian, también debe revisarse el texto del informe. Los integrantes están incluidos en el PDF, el HTML, las fuentes y el encabezado del código R.
