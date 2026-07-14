-- =============================================================
-- QUERY 01 · FUNNEL MENSUAL
-- =============================================================
-- ¿Cuántos trials se inician cada mes y cuántos convierten?
--
-- Métricas que produce:
--   - trials_started      → trials iniciados en el mes
--   - trials_converted    → trials que terminaron en suscripción paga
--   - trials_churned      → trials que terminaron sin conversión
--   - conversion_rate_pct → porcentaje de conversión del mes
--   - benchmark_diff      → diferencia vs benchmark del 8% (saludable)
--
-- Por qué importa:
--   Esta query es el primer diagnóstico del negocio.
--   Si la conversión está por debajo del 8%, el problema
--   no es volumen (más trials) sino funnel (algo rompe antes
--   de que el usuario decida pagar).
-- =============================================================

SELECT
    -- Truncar al primer día del mes para agrupar
    DATE_TRUNC('month', t.start_date)          AS month,

    -- Volumen de trials del mes
    COUNT(*)                                    AS trials_started,

    -- Cuántos convirtieron a pago
    COUNT(*) FILTER (WHERE t.trial_status = 'converted')
                                                AS trials_converted,

    -- Cuántos se fueron sin pagar
    COUNT(*) FILTER (WHERE t.trial_status = 'churned')
                                                AS trials_churned,

    -- Tasa de conversión del mes en porcentaje
    ROUND(
        COUNT(*) FILTER (WHERE t.trial_status = 'converted')
        * 100.0 / COUNT(*),
        2
    )                                           AS conversion_rate_pct,

    -- Diferencia vs benchmark saludable (8%)
    -- Negativo = por debajo del benchmark
    -- Positivo = por encima del benchmark
    ROUND(
        COUNT(*) FILTER (WHERE t.trial_status = 'converted')
        * 100.0 / COUNT(*) - 8.0,
        2
    )                                           AS benchmark_diff

FROM trials t

GROUP BY DATE_TRUNC('month', t.start_date)
ORDER BY month ASC;
