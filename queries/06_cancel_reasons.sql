-- =============================================================
-- QUERY 06 · RAZONES DE CANCELACIÓN (export para Looker)
-- =============================================================
-- Distribución completa de motivos de cancelación.
-- Alimenta el donut de la Página 2 del dashboard.
-- Exportar como: resultados_06_cancel_reasons.csv
-- =============================================================

SELECT
    reason,
    COUNT(*)                                        AS total_cancellations,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1)
                                                    AS pct_of_total
FROM cancellations
GROUP BY reason
ORDER BY total_cancellations DESC;
