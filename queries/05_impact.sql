-- =============================================================
-- QUERY 05 · IMPACTO DEL CAMBIO DE ONBOARDING
-- =============================================================
-- ¿Qué cambió después de la mejora de onboarding en sept 2024?
--
-- Esta query divide el año en dos períodos y compara todas
-- las métricas clave: conversión, churn, CAC, LTV, MRR, runway.
--
-- Métricas que produce por período:
--   - period              → 'Before' (ene-ago) / 'After' (sep-dic)
--   - trials              → trials totales del período
--   - conversions         → conversiones a pago
--   - conversion_rate     → tasa de conversión
--   - cancellations       → cancelaciones del período
--   - churn_rate          → tasa de churn promedio
--   - mrr                 → Monthly Recurring Revenue promedio
--   - total_revenue       → ingresos totales del período
--   - marketing_spend     → gasto en marketing del período
--   - cac                 → CAC del período
--   - avg_ltv             → LTV promedio de los clientes
--   - ltv_cac_ratio       → ratio LTV/CAC del período
--   - runway_months       → runway proyectado con esos números
--
-- Por qué importa:
--   Es la query más poderosa del portfolio. Demuestra que sabés
--   medir el impacto real de una decisión de producto con datos.
--   Un analista que sabe hacer esto es contratado.
-- =============================================================

WITH

-- Definir períodos
periods AS (
    SELECT 'Before (Jan–Aug 2024)' AS period, '2024-01-01'::DATE AS p_start, '2024-08-31'::DATE AS p_end
    UNION ALL
    SELECT 'After (Sep–Dec 2024)',             '2024-09-01'::DATE,             '2024-12-31'::DATE
),

-- Métricas de trials por período
trial_metrics AS (
    SELECT
        p.period,
        COUNT(*)                                            AS total_trials,
        COUNT(*) FILTER (WHERE t.trial_status = 'converted')
                                                            AS total_conversions,
        ROUND(
            COUNT(*) FILTER (WHERE t.trial_status = 'converted')
            * 100.0 / COUNT(*), 2
        )                                                   AS conversion_rate_pct
    FROM periods p
    JOIN trials t ON t.start_date BETWEEN p.p_start AND p.p_end
    GROUP BY p.period
),

-- Métricas de churn por período
churn_metrics AS (
    SELECT
        p.period,
        COUNT(c.cancellation_id)                            AS total_cancellations,
        -- Suscripciones activas durante el período
        COUNT(DISTINCT s.subscription_id)                   AS active_subs,
        ROUND(
            COUNT(c.cancellation_id) * 100.0
            / NULLIF(COUNT(DISTINCT s.subscription_id), 0),
            2
        )                                                   AS churn_rate_pct
    FROM periods p
    JOIN subscriptions s
        ON s.start_date <= p.p_end
        AND (s.status = 'active' OR s.subscription_id IN (
            SELECT subscription_id FROM cancellations
            WHERE cancellation_date >= p.p_start
        ))
    LEFT JOIN cancellations c
        ON s.subscription_id = c.subscription_id
        AND c.cancellation_date BETWEEN p.p_start AND p.p_end
    GROUP BY p.period
),

-- MRR y revenue por período
revenue_metrics AS (
    SELECT
        p.period,
        -- MRR promedio: suma de suscripciones activas por período / meses
        ROUND(
            SUM(pay.amount) FILTER (WHERE pay.status = 'success')
            / CASE p.period
                WHEN 'Before (Jan–Aug 2024)' THEN 8.0
                ELSE 4.0
              END,
            2
        )                                                   AS avg_mrr,
        ROUND(
            SUM(pay.amount) FILTER (WHERE pay.status = 'success'), 2
        )                                                   AS total_revenue,
        COUNT(pay.payment_id) FILTER (WHERE pay.status = 'failed')
                                                            AS failed_payments
    FROM periods p
    JOIN payments pay ON pay.payment_date BETWEEN p.p_start AND p.p_end
    GROUP BY p.period
),

-- Gasto en marketing por período
spend_metrics AS (
    SELECT
        p.period,
        SUM(ms.amount)                                      AS total_spend,
        -- Meses del período
        CASE p.period
            WHEN 'Before (Jan–Aug 2024)' THEN 8
            ELSE 4
        END                                                 AS period_months
    FROM periods p
    JOIN marketing_spend ms ON ms.spend_month BETWEEN p.p_start AND p.p_end
    GROUP BY p.period
),

-- CAC por período
cac_metrics AS (
    SELECT
        tm.period,
        ROUND(
            sm.total_spend / NULLIF(tm.total_conversions, 0),
            2
        )                                                   AS cac
    FROM trial_metrics tm
    JOIN spend_metrics sm ON tm.period = sm.period
),

-- LTV promedio por período (clientes adquiridos en ese período)
ltv_metrics AS (
    SELECT
        p.period,
        ROUND(AVG(
            s.monthly_amount *
            CASE
                WHEN s.status = 'cancelled' THEN
                    EXTRACT(MONTH FROM AGE(c.cancellation_date, s.start_date)) + 1
                ELSE
                    EXTRACT(MONTH FROM AGE(CURRENT_DATE, s.start_date)) + 1
            END
        ), 2)                                               AS avg_ltv
    FROM periods p
    JOIN subscriptions s  ON s.start_date BETWEEN p.p_start AND p.p_end
    LEFT JOIN cancellations c ON s.subscription_id = c.subscription_id
    GROUP BY p.period
),

-- Costo operativo mensual fijo
-- $310.000/mes según parámetros del caso
opex AS (
    SELECT 310000.00 AS monthly_opex
)

-- =============================================================
-- RESULTADO FINAL: comparación completa before vs after
-- =============================================================
SELECT
    tm.period,

    -- FUNNEL
    tm.total_trials,
    tm.total_conversions,
    tm.conversion_rate_pct,

    -- CHURN
    cm.total_cancellations,
    cm.churn_rate_pct,

    -- REVENUE
    rm.avg_mrr,
    rm.total_revenue,
    rm.failed_payments,

    -- UNIT ECONOMICS
    sm.total_spend                                          AS marketing_spend,
    ca.cac,
    lv.avg_ltv,
    ROUND(lv.avg_ltv / NULLIF(ca.cac, 0), 2)              AS ltv_cac_ratio,

    -- SEMÁFORO LTV/CAC
    CASE
        WHEN lv.avg_ltv / NULLIF(ca.cac, 0) >= 3  THEN '🟢 Saludable'
        WHEN lv.avg_ltv / NULLIF(ca.cac, 0) >= 1  THEN '🟡 Zona de peligro'
        ELSE                                           '🔴 Destruye valor'
    END                                                     AS ltv_cac_status,

    -- RUNWAY PROYECTADO
    -- Con el MRR del período y el costo operativo mensual
    ROUND(
        rm.avg_mrr / NULLIF(o.monthly_opex - rm.avg_mrr, 0) * -1,
        1
    )                                                       AS runway_months_projected,

    -- Pérdida o ganancia mensual promedio del período
    ROUND(rm.avg_mrr - o.monthly_opex, 2)                  AS avg_monthly_result

FROM trial_metrics    tm
JOIN churn_metrics    cm  ON tm.period = cm.period
JOIN revenue_metrics  rm  ON tm.period = rm.period
JOIN spend_metrics    sm  ON tm.period = sm.period
JOIN cac_metrics      ca  ON tm.period = ca.period
JOIN ltv_metrics      lv  ON tm.period = lv.period
CROSS JOIN opex       o

ORDER BY
    CASE tm.period
        WHEN 'Before (Jan–Aug 2024)' THEN 1
        ELSE 2
    END;
