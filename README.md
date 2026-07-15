# FlowDesk Analytics

**Análisis de unit economics y comportamiento de usuarios para una startup SaaS ficticia**

SQL · Google Sheets · Looker Studio

---

## El problema

FlowDesk es una herramienta de gestión de proyectos B2B que compite contra Asana y Monday.com. Llevan 3 años en el mercado y acaban de cerrar una ronda de inversión de **$8M**.

El CEO quiere usar ese dinero para escalar el equipo de ventas de 6 a 20 personas y triplicar el gasto en marketing. Su lógica: *"Tenemos un producto que la gente ama. Solo necesitamos más volumen."*

El VP de Producto disiente: *"El problema no es volumen. Algo está roto en el funnel. Más volumen sobre un funnel roto solo quema la plata más rápido."*

**¿Quién tiene razón?**

---

## El diagnóstico

Antes de recomendar cualquier acción, construí el modelo de datos completo y analicé 12 meses de comportamiento de usuarios.

Los tres números que lo dicen todo:

| Métrica | Valor FlowDesk | Saludable |
|---|---|---|
| Conversión trial → pago | 4% | 8–12% |
| Churn mensual | 8.5% | < 3% |
| LTV / CAC ratio | 1.85x | > 3x |

**Los tres están en rojo.** Escalar con los tres en rojo no es ambición, es destrucción de capital.

En el mes 9 del período analizado, el equipo de producto lanzó una mejora en el onboarding. La conversión subió al 7% y el churn bajó al 6%. Este before/after es el corazón analítico del proyecto.

---

## Estructura del repositorio

```
flowdesk-analytics/
│
├── README.md
│
├── schema/
│   └── schema.sql              — Modelo de datos: 6 tablas, 13 índices
│
├── data/
│   ├── seed_data.sql           — 38.400 usuarios, 12 meses de datos sintéticos
│   └── generate_seed.py        — Script Python que generó los datos
│
├── queries/
│   ├── 01_funnel.sql           — Funnel mensual: trials vs conversiones
│   ├── 02_churn.sql            — Churn mensual con motivos y vida promedio
│   ├── 03_unit_economics.sql   — CAC, LTV y LTV/CAC por canal de adquisición
│   ├── 04_cohort.sql           — Retención por cohorte de adquisición
│   └── 05_impact.sql           — Before vs after del cambio de onboarding
│
├── sheets/
│   └── [link al modelo financiero en Google Sheets]
│
└── dashboard/
    └── [link al dashboard en Looker Studio]
```

---

## Modelo de datos

Seis tablas diseñadas para reflejar el comportamiento real de un negocio SaaS B2B.

```
users ──────────┐
                ├── trials
                │
                └── subscriptions ──── payments
                          │
                          └── cancellations

marketing_spend (tabla independiente para calcular CAC por canal)
```

### Decisiones de diseño

**`trials` separada de `users`** — el registro y el período de prueba son eventos distintos con fechas y estados propios. Mezclarlos en una tabla impide calcular el funnel correctamente.

**`payments` separada de `subscriptions`** — un cliente puede tener su suscripción activa pero un pago fallido. Si solo existiera `subscriptions`, ese estado sería invisible. Los pagos fallidos representan churn involuntario, una señal diferente al churn voluntario.

**`cancellations` con campo `reason`** — el churn no es un número único. Es una distribución de causas: precio, competencia, falta de features, desuso. Sin ese campo, la query de churn produce un número que no dice qué hay que arreglar.

**`user_country` y `company_country` separados** — en B2B, el ingreso viene de la empresa, no de la persona que se registró. Una empresa brasileña con un empleado argentino registrado genera revenue de Brasil. Tener ambos campos permite analizar tanto el comportamiento del usuario como la geografía del mercado.

---

## Las 5 queries

Ordenadas de menor a mayor complejidad para mostrar progresión técnica.

### 01 · Funnel mensual

Trials iniciados, conversiones y tasa de conversión por mes, con diferencia vs el benchmark saludable del 8%.

**Técnicas:** `GROUP BY`, `DATE_TRUNC`, `COUNT FILTER`, `ROUND`

```sql
SELECT
    DATE_TRUNC('month', t.start_date)   AS month,
    COUNT(*)                             AS trials_started,
    COUNT(*) FILTER (WHERE t.trial_status = 'converted')
                                         AS trials_converted,
    ROUND(
        COUNT(*) FILTER (WHERE t.trial_status = 'converted')
        * 100.0 / COUNT(*), 2
    )                                    AS conversion_rate_pct,
    ROUND(
        COUNT(*) FILTER (WHERE t.trial_status = 'converted')
        * 100.0 / COUNT(*) - 8.0, 2
    )                                    AS benchmark_diff
FROM trials t
GROUP BY DATE_TRUNC('month', t.start_date)
ORDER BY month ASC;
```

### 02 · Churn mensual

Clientes activos al inicio y cierre de cada mes, cancelaciones, tasa de churn y vida promedio implícita del cliente.

**Técnicas:** CTEs, `GENERATE_SERIES`, `MODE() WITHIN GROUP`, subqueries

### 03 · Unit economics por canal

CAC, LTV y ratio LTV/CAC por canal de adquisición, cruzando gasto en marketing con conversiones reales. Semáforo de salud por canal y payback period.

**Técnicas:** CTEs encadenados, múltiples JOINs, campos calculados, `NULLIF` para evitar división por cero

### 04 · Análisis de cohortes

Retención mensual de cada cohorte de adquisición: qué porcentaje de los clientes de enero sigue activo en febrero, marzo, etc. Es la métrica más honesta del negocio porque no se puede manipular.

**Técnicas:** lógica de cohortes con intervalos de fecha, `COUNT FILTER` con condiciones de rango temporal

### 05 · Impacto del cambio de onboarding

Comparación completa de todas las métricas clave entre el período previo (meses 1–8) y posterior (meses 9–12) al cambio de producto. Incluye conversión, churn, CAC, LTV, MRR, runway y resultado mensual promedio.

**Técnicas:** CTEs complejos con `UNION ALL`, `CROSS JOIN` para costos fijos, `CASE` para clasificación de períodos

---

## Modelo financiero — Google Sheets

Tres escenarios proyectados a 12 meses con todas las métricas clave.

| Escenario | Descripción | Net Result (12m) | Runway |
|---|---|---|---|
| **A — Status Quo** | Sin cambios. Baseline para medir. | ($3.4M) | 21 meses |
| **B — CEO Plan** | Marketing ×3 + 14 vendedores extra. | ($4.6M) | 17 meses |
| **C — VP Product** | Arreglar conversión primero, sin gasto extra. | Menor pérdida | 24+ meses |

**Conclusión del modelo:** el Escenario B quema $1.2M adicionales en 12 meses sin mejorar el LTV/CAC. El Escenario C extiende el runway y mejora el ratio desde el mes 1, dando más tiempo para llegar a la próxima ronda.

→ [Ver modelo financiero en Google Sheets](https://docs.google.com/spreadsheets/d/1D8TzKxiGSpBy5E_mrOgl1OEfAgplP25cnizez4DQB7c/edit?usp=sharing)

---

## Dashboard — Looker Studio

Tres páginas conectadas a la base de datos con filtros globales por canal, país y período.

### Página 1 — Funnel Health
Trials vs conversiones por mes, tasa de conversión con línea de benchmark en 8%, comparación before/after del mes 9.

### Página 2 — Unit Economics
LTV/CAC por canal con semáforo de colores, evolución del churn mensual, razones de cancelación, mapa de revenue por país.

### Página 3 — Financial Projection
MRR vs OpEx con punto de equilibrio, comparación de los 3 escenarios de inversión, revenue por plan type.

→ [Ver dashboard en Looker Studio](https://datastudio.google.com/reporting/75e5bae1-2346-4678-989e-6b95d4c15271)(#)

---

## Hallazgos principales

**1. El programa no tiene un problema de volumen, tiene un problema de conversión**

Con 3.200 trials mensuales y 4% de conversión, FlowDesk genera 128 clientes nuevos por mes. Triplicar el marketing a 9.600 trials con la misma conversión genera 384. El CAC pasa de $940 a $915: una mejora del 2.7% a un costo de $170.000 adicionales por mes.

Si en cambio la conversión sube al 8% con el mismo gasto:

```
Clientes nuevos: 256 (vs 128)
CAC nuevo: $332 (vs $940)
LTV/CAC: 5.25x (vs 1.85x)
```

Mismo presupuesto. El triple de eficiencia.

**2. El cambio de onboarding del mes 9 validó la hipótesis del VP de Producto**

| Métrica | Meses 1–8 | Meses 9–12 | Variación |
|---|---|---|---|
| Conversión | 4.0% | 7.0% | +75% |
| Churn mensual | 8.5% | 6.0% | -29% |
| Vida promedio cliente | 11.7 meses | 16.7 meses | +42% |

El producto no era el problema. El onboarding era el problema.

**3. El canal referral es el más rentable pero el menos invertido**

El canal referral genera la mayor tasa de conversión (clientes que llegan recomendados por otros clientes tienen más intención de compra) pero recibe solo $8.000/mes de los $85.000 del presupuesto de marketing. El canal paid_ads recibe $45.000 y tiene la menor tasa de conversión.

Reasignar presupuesto de paid_ads a referral es la segunda palanca más eficiente después de arreglar el onboarding.

---

## Cómo reproducir el análisis

### Requisitos

- PostgreSQL 14+ (o cualquier base SQL compatible con `GENERATE_SERIES` y `DATE_TRUNC`)
- Python 3.8+ (solo para regenerar los datos sintéticos)
- Google Sheets (para el modelo financiero)
- Looker Studio con cuenta de Google (para el dashboard)

### Setup

```bash
# 1. Clonar el repositorio
git clone https://github.com/[tu-usuario]/flowdesk-analytics
cd flowdesk-analytics

# 2. Crear la base de datos
psql -U postgres -c "CREATE DATABASE flowdesk;"

# 3. Crear el schema
psql -U postgres -d flowdesk -f schema/schema.sql

# 4. Cargar los datos
psql -U postgres -d flowdesk -f data/seed_data.sql

# 5. Ejecutar las queries
psql -U postgres -d flowdesk -f queries/01_funnel.sql
psql -U postgres -d flowdesk -f queries/02_churn.sql
psql -U postgres -d flowdesk -f queries/03_unit_economics.sql
psql -U postgres -d flowdesk -f queries/04_cohort.sql
psql -U postgres -d flowdesk -f queries/05_impact.sql
```

### Regenerar los datos sintéticos

```bash
# Instalar dependencias
pip install numpy faker

# Regenerar (seed fijo = resultados reproducibles)
python data/generate_seed.py
```

Los datos se generan con `random.seed(42)` para que cualquier persona que clone el repositorio obtenga exactamente los mismos números.

---

## Decisiones técnicas

**¿Por qué datos sintéticos y no datos reales?**

Los datos reales de empresas SaaS son confidenciales. Los datos sintéticos permiten controlar exactamente los parámetros del caso (3.200 trials, 4% conversión, 8.5% churn) para que el análisis cuente una historia coherente. El script de generación es parte del portfolio: demuestra que entiendo cómo se generan los datos reales, no solo cómo se analizan.

**¿Por qué PostgreSQL y no BigQuery o Snowflake?**

PostgreSQL es el estándar más accesible para reproducir el análisis localmente sin una cuenta cloud. Las queries usan sintaxis estándar (CTEs, window functions, `DATE_TRUNC`) que funciona en BigQuery y Snowflake con cambios mínimos.

**¿Por qué Google Sheets para el modelo financiero?**

Porque es donde viven los modelos financieros en el 90% de las empresas que no son fondos de inversión. Un analista que sabe construir un modelo de escenarios en Sheets es más útil en el día a día que uno que solo sabe hacerlo en Python.

---

## Conceptos analíticos aplicados

| Concepto | Dónde aparece en el proyecto |
|---|---|
| **Causalidad vs correlación** | Query 05: el crecimiento del 23% en ventas de miembros no prueba que el programa lo causó |
| **Sesgo de supervivencia** | El NPS alto solo mide a los clientes que se quedaron, no al 96% que se fue |
| **Sesgo de selección** | Los mejores clientes se inscriben primero, inflando las métricas del grupo convertido |
| **Unit economics** | Query 03: verificar que una unidad individual es rentable antes de escalar |
| **Costo de oportunidad** | La pregunta no es si el programa genera valor, sino si genera más que la alternativa |
| **Margen bruto vs rentabilidad neta** | Modelo financiero: el CMO opera en nivel 1, el CEO necesita el nivel 4 |

---

## Autor

Jonathan Manzolido
[Linkedin](https://www.linkedin.com/in/jonathan-manzolido/) · [Portfolio](https://jonaamf.github.io/Portfolio/)

*Proyecto construido como parte de un proceso de entrenamiento en mentalidad analítica de alto nivel.*
