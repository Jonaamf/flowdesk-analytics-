-- =============================================================
-- QUERY 07 · REVENUE POR PAÍS DE EMPRESA (export para Looker)
-- =============================================================
-- Ingresos reales (pagos exitosos) por país de la empresa cliente.
-- Alimenta el mapa de burbujas de la Página 2 del dashboard.
-- Exportar como: resultados_07_revenue_pais.csv
-- =============================================================

SELECT
    u.company_country,
    COUNT(DISTINCT s.subscription_id)               AS customers,
    ROUND(SUM(p.amount), 2)                         AS total_revenue
FROM payments p
JOIN subscriptions s ON p.subscription_id = s.subscription_id
JOIN users u         ON s.user_id = u.user_id
WHERE p.status = 'success'
GROUP BY u.company_country
ORDER BY total_revenue DESC;
