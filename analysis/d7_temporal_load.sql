-- =============================================================================
-- SUPPORTING ANALYSIS D7: Temporal patterns of misrouting / channel load
-- Helps staffing & flow decisions: when do misroutes spike?
-- Depends on view models/04.
-- =============================================================================

-- 7a. Misroute by hour-of-day -----------------------------------------------
SELECT
  EXTRACT(HOUR FROM START_MOMENT)                               AS hour_of_day,
  COUNTIF(is_technical_topic)                                   AS technical_sessions,
  COUNTIF(is_hard_misroute)                                     AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute,
  SUM(n_transfers)                                             AS total_handovers
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 7b. Misroute by day-of-week (1=Sun ... 7=Sat in BigQuery) -----------------
SELECT
  EXTRACT(DAYOFWEEK FROM START_MOMENT)                          AS day_of_week,
  COUNTIF(is_technical_topic)                                   AS technical_sessions,
  COUNTIF(is_hard_misroute)                                     AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY day_of_week
ORDER BY day_of_week;

-- 7c. Heatmap source: day-of-week x hour (misroute count) -------------------
SELECT
  EXTRACT(DAYOFWEEK FROM START_MOMENT)                          AS day_of_week,
  EXTRACT(HOUR FROM START_MOMENT)                               AS hour_of_day,
  COUNTIF(is_hard_misroute)                                     AS hard_misroutes,
  COUNTIF(is_technical_topic)                                   AS technical_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY day_of_week, hour_of_day
ORDER BY day_of_week, hour_of_day;
