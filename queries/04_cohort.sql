-- =============================================================
-- QUERY 04 · ANÁLISIS DE COHORTES
-- =============================================================
-- ¿Qué porcentaje de clientes sigue activo después de N meses?
--
-- Una cohorte = grupo de clientes que convirtieron en el mismo mes.
-- Se mide cuántos de ellos siguen activos 1, 2, 3... meses después.
--
-- Métricas que produce:
--   - cohort_month        → mes en que el grupo se suscribió
--   - cohort_size         → clientes iniciales de la cohorte
--   - month_0 a month_11  → % de retención en cada mes subsiguiente
--
-- Por qué importa:
--   Es la métrica más honesta del negocio. No se puede manipular.
--   Si una cohorte retiene el 80% al mes 3, el producto funciona.
--   Si retiene el 40%, hay un problema estructural de valor.
--   También permite ver si el cambio de onboarding (mes 9)
--   mejoró la retención de las cohortes nuevas vs las anteriores.
-- =============================================================

WITH

-- Definir cohortes: mes de inicio de cada suscripción
cohorts AS (
    SELECT
        s.subscription_id,
        s.user_id,
        DATE_TRUNC('month', s.start_date)           AS cohort_month,
        s.start_date,
        s.status,
        c.cancellation_date
    FROM subscriptions s
    LEFT JOIN cancellations c ON s.subscription_id = c.subscription_id
),

-- Tamaño inicial de cada cohorte
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*)    AS cohort_size
    FROM cohorts
    GROUP BY cohort_month
),

-- Retención mes a mes para cada cohorte
-- Un cliente "sigue activo" en el mes N si no canceló
-- antes del inicio del mes N de su suscripción
cohort_retention AS (
    SELECT
        c.cohort_month,
        cs.cohort_size,

        -- Mes 0: todos los clientes (100% por definición)
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month
        )                                                   AS retained_m0,

        -- Mes 1
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '1 month'
        )                                                   AS retained_m1,

        -- Mes 2
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '2 months'
        )                                                   AS retained_m2,

        -- Mes 3
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '3 months'
        )                                                   AS retained_m3,

        -- Mes 4
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '4 months'
        )                                                   AS retained_m4,

        -- Mes 5
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '5 months'
        )                                                   AS retained_m5,

        -- Mes 6
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '6 months'
        )                                                   AS retained_m6,

        -- Mes 7
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '7 months'
        )                                                   AS retained_m7,

        -- Mes 8
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '8 months'
        )                                                   AS retained_m8,

        -- Mes 9
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '9 months'
        )                                                   AS retained_m9,

        -- Mes 10
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '10 months'
        )                                                   AS retained_m10,

        -- Mes 11
        COUNT(*) FILTER (
            WHERE c.cancellation_date IS NULL
               OR c.cancellation_date >= c.cohort_month + INTERVAL '11 months'
        )                                                   AS retained_m11

    FROM cohorts c
    JOIN cohort_sizes cs ON c.cohort_month = cs.cohort_month
    GROUP BY c.cohort_month, cs.cohort_size
)

-- Output final: porcentajes de retención
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM')            AS cohort_month,
    cohort_size,

    -- Retención expresada como porcentaje del tamaño inicial
    100                                          AS pct_m0,

    ROUND(retained_m1  * 100.0 / cohort_size, 1) AS pct_m1,
    ROUND(retained_m2  * 100.0 / cohort_size, 1) AS pct_m2,
    ROUND(retained_m3  * 100.0 / cohort_size, 1) AS pct_m3,
    ROUND(retained_m4  * 100.0 / cohort_size, 1) AS pct_m4,
    ROUND(retained_m5  * 100.0 / cohort_size, 1) AS pct_m5,
    ROUND(retained_m6  * 100.0 / cohort_size, 1) AS pct_m6,
    ROUND(retained_m7  * 100.0 / cohort_size, 1) AS pct_m7,
    ROUND(retained_m8  * 100.0 / cohort_size, 1) AS pct_m8,
    ROUND(retained_m9  * 100.0 / cohort_size, 1) AS pct_m9,
    ROUND(retained_m10 * 100.0 / cohort_size, 1) AS pct_m10,
    ROUND(retained_m11 * 100.0 / cohort_size, 1) AS pct_m11

FROM cohort_retention
ORDER BY cohort_month ASC;
