-- =============================================================
-- QUERY 03 · UNIT ECONOMICS POR CANAL
-- =============================================================
-- ¿Cuánto cuesta conseguir un cliente por canal y cuánto vale?
--
-- Métricas que produce:
--   - channel             → canal de adquisición
--   - total_spend         → gasto total en el canal (12 meses)
--   - trials_generated    → trials que trajo ese canal
--   - customers_acquired  → clientes pagos que convirtieron
--   - cac                 → costo de adquisición por cliente
--   - avg_ltv             → valor promedio de vida del cliente
--   - ltv_cac_ratio       → ratio LTV/CAC (saludable > 3x)
--   - payback_months      → meses para recuperar el CAC
--   - avg_monthly_revenue → ingreso mensual promedio por cliente
--
-- Por qué importa:
--   El CAC global esconde diferencias enormes entre canales.
--   Un canal puede traer muchos trials y pocos clientes (ineficiente),
--   mientras otro trae pocos trials y casi todos convierten (eficiente).
--   Esta query es la que le muestra al CEO dónde reasignar el presupuesto.
-- =============================================================

WITH

-- Gasto total por canal en los 12 meses
spend_by_channel AS (
    SELECT
        channel,
        SUM(amount)     AS total_spend
    FROM marketing_spend
    GROUP BY channel
),

-- Trials e ingresos por canal de adquisición del usuario
channel_performance AS (
    SELECT
        u.acquisition_channel                               AS channel,
        COUNT(DISTINCT u.user_id)                           AS trials_generated,

        -- Clientes que convirtieron a pago
        COUNT(DISTINCT s.subscription_id)                   AS customers_acquired,

        -- Ingreso mensual promedio por cliente del canal
        AVG(s.monthly_amount)                               AS avg_monthly_revenue,

        -- Vida promedio del cliente en meses usando churn implícito
        -- Se calcula como promedio de meses activos por suscripción
        AVG(
            CASE
                WHEN s.status = 'cancelled' THEN
                    -- Meses entre inicio y cancelación
                    EXTRACT(MONTH FROM AGE(
                        c.cancellation_date,
                        s.start_date
                    )) + 1
                ELSE
                    -- Suscripción aún activa: meses desde inicio hasta hoy
                    EXTRACT(MONTH FROM AGE(
                        CURRENT_DATE,
                        s.start_date
                    )) + 1
            END
        )                                                   AS avg_life_months

    FROM users u
    -- Solo usuarios que convirtieron
    INNER JOIN subscriptions s  ON u.user_id = s.user_id
    LEFT JOIN  cancellations c  ON s.subscription_id = c.subscription_id
    GROUP BY u.acquisition_channel
),

-- Unir gasto con performance
economics AS (
    SELECT
        cp.channel,
        COALESCE(sp.total_spend, 0)                         AS total_spend,
        cp.trials_generated,
        cp.customers_acquired,
        cp.avg_monthly_revenue,
        cp.avg_life_months,

        -- CAC: gasto del canal / clientes pagos que trajo
        ROUND(
            COALESCE(sp.total_spend, 0)
            / NULLIF(cp.customers_acquired, 0),
            2
        )                                                   AS cac,

        -- LTV: ingreso mensual promedio × vida promedio en meses
        ROUND(cp.avg_monthly_revenue * cp.avg_life_months, 2)
                                                            AS avg_ltv

    FROM channel_performance cp
    LEFT JOIN spend_by_channel sp ON cp.channel = sp.channel
)

SELECT
    channel,
    ROUND(total_spend, 2)                                   AS total_spend,
    trials_generated,
    customers_acquired,

    -- Tasa de conversión por canal
    ROUND(
        customers_acquired * 100.0
        / NULLIF(trials_generated, 0),
        2
    )                                                       AS conversion_rate_pct,

    cac,
    ROUND(avg_monthly_revenue, 2)                           AS avg_monthly_revenue,
    ROUND(avg_life_months, 1)                               AS avg_life_months,
    avg_ltv,

    -- LTV/CAC: el ratio que decide si el canal es escalable
    -- < 1x → destruye valor
    -- 1-3x → zona de peligro
    -- > 3x → saludable y escalable
    ROUND(avg_ltv / NULLIF(cac, 0), 2)                     AS ltv_cac_ratio,

    -- Semáforo de salud del canal
    CASE
        WHEN avg_ltv / NULLIF(cac, 0) >= 3  THEN '🟢 Saludable'
        WHEN avg_ltv / NULLIF(cac, 0) >= 1  THEN '🟡 Zona de peligro'
        ELSE                                     '🔴 Destruye valor'
    END                                                     AS health_status,

    -- Payback period: meses para recuperar el CAC
    ROUND(cac / NULLIF(avg_monthly_revenue, 0), 1)          AS payback_months

FROM economics
ORDER BY ltv_cac_ratio DESC NULLS LAST;
