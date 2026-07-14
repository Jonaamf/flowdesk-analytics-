-- =============================================================
-- QUERY 08 · MRR MENSUAL POR PLAN (export para Looker)
-- =============================================================
-- Ingresos mensuales reales desagregados por tipo de plan.
-- Alimenta el gráfico de área (MRR vs OpEx) y las barras
-- apiladas por plan de la Página 3 del dashboard.
-- Incluye el OpEx fijo como columna para graficar el cruce.
-- Exportar como: resultados_08_mrr_mensual.csv
-- =============================================================

SELECT
    DATE_TRUNC('month', p.payment_date)             AS month,
    s.plan_type,
    ROUND(SUM(p.amount), 2)                         AS revenue,
    COUNT(DISTINCT p.subscription_id)               AS paying_customers,
    310000.00                                       AS monthly_opex,
    85000.00                                        AS monthly_marketing
FROM payments p
JOIN subscriptions s ON p.subscription_id = s.subscription_id
WHERE p.status = 'success'
GROUP BY DATE_TRUNC('month', p.payment_date), s.plan_type
ORDER BY month ASC, s.plan_type;
