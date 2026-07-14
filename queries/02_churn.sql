-- =============================================================
-- QUERY 02 · CHURN MENSUAL
-- =============================================================
-- ¿Qué porcentaje de clientes cancela cada mes y por qué?
--
-- Métricas que produce:
--   - active_start        → clientes activos al inicio del mes
--   - new_subscriptions   → suscripciones nuevas en el mes
--   - cancellations       → cancelaciones en el mes
--   - active_end          → clientes activos al cierre del mes
--   - churn_rate_pct      → tasa de churn del mes
--   - top_cancel_reason   → motivo más frecuente de cancelación
--
-- Por qué importa:
--   El churn es el enemigo silencioso del crecimiento SaaS.
--   Aunque entren clientes nuevos, un churn alto los erosiona.
--   Con 8.5% de churn mensual, la vida promedio de un cliente
--   es de solo 11.7 meses. Bajarlo al 3% la extiende a 33 meses.
-- =============================================================

WITH

-- Suscripciones activas al inicio de cada mes
-- Una suscripción estaba activa si empezó antes del mes
-- y no fue cancelada antes del inicio del mes
active_at_start AS (
    SELECT
        DATE_TRUNC('month', gs.month_date)      AS month,
        COUNT(s.subscription_id)                AS active_count
    FROM
        -- Generar una fila por cada mes del período
        GENERATE_SERIES(
            '2024-01-01'::DATE,
            '2024-12-01'::DATE,
            INTERVAL '1 month'
        ) AS gs(month_date)
    LEFT JOIN subscriptions s
        ON  s.start_date < gs.month_date
        AND (
            -- Suscripción nunca cancelada
            s.status = 'active'
            OR
            -- Suscripción cancelada después del inicio del mes
            s.subscription_id IN (
                SELECT subscription_id FROM cancellations
                WHERE cancellation_date >= gs.month_date
            )
        )
    GROUP BY gs.month_date
),

-- Cancelaciones por mes con motivo más frecuente
cancellations_by_month AS (
    SELECT
        DATE_TRUNC('month', c.cancellation_date)    AS month,
        COUNT(*)                                     AS total_cancellations,

        -- Motivo más frecuente usando MODE()
        MODE() WITHIN GROUP (ORDER BY c.reason)     AS top_reason
    FROM cancellations c
    GROUP BY DATE_TRUNC('month', c.cancellation_date)
),

-- Nuevas suscripciones por mes
new_subs_by_month AS (
    SELECT
        DATE_TRUNC('month', s.start_date)           AS month,
        COUNT(*)                                     AS new_subscriptions
    FROM subscriptions s
    GROUP BY DATE_TRUNC('month', s.start_date)
)

-- Query principal
SELECT
    a.month,
    a.active_count                                  AS active_start,
    COALESCE(n.new_subscriptions, 0)                AS new_subscriptions,
    COALESCE(c.total_cancellations, 0)              AS cancellations,

    -- Clientes activos al cierre: inicio + nuevos - cancelados
    a.active_count
        + COALESCE(n.new_subscriptions, 0)
        - COALESCE(c.total_cancellations, 0)        AS active_end,

    -- Tasa de churn: cancelaciones / activos al inicio
    ROUND(
        COALESCE(c.total_cancellations, 0)
        * 100.0 / NULLIF(a.active_count, 0),
        2
    )                                               AS churn_rate_pct,

    -- Vida promedio implícita en meses (1 / churn)
    ROUND(
        100.0 / NULLIF(
            COALESCE(c.total_cancellations, 0)
            * 100.0 / NULLIF(a.active_count, 0),
            0
        ),
        1
    )                                               AS avg_customer_life_months,

    COALESCE(c.top_reason, 'no_cancellations')      AS top_cancel_reason

FROM active_at_start a
LEFT JOIN cancellations_by_month c  ON a.month = c.month
LEFT JOIN new_subs_by_month n       ON a.month = n.month

ORDER BY a.month ASC;
