-- =============================================================================
-- DELIVERABLE 2: Quantify the impact of misrouting on customer experience:
-- resolution time, channel load (handovers), and repeated contacts.
-- Reads vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
-- =============================================================================

-- 2a. Misrouted vs correctly-routed: side-by-side impact --------------------
WITH cohorts AS (
  SELECT
    CASE
      WHEN is_hard_misroute               THEN 'misrouted_hard'
      WHEN is_soft_misroute               THEN 'misrouted_soft'
      WHEN is_correct_technical_route     THEN 'correct_technical'
      WHEN is_technical_topic             THEN 'technical_other'
      ELSE 'non_technical'
    END AS cohort,
    duration_seconds,
    n_transfers,
    has_next_session,
    has_internal_handover,
    repeat_contact_24h,
    is_fcr
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
)
SELECT
  cohort,
  COUNT(*)                                              AS sessions,
  ROUND(AVG(duration_seconds), 1)                       AS avg_duration_s,
  APPROX_QUANTILES(duration_seconds, 100)[OFFSET(50)]   AS median_duration_s,
  ROUND(AVG(n_transfers), 2)                            AS avg_handovers,
  ROUND(AVG(CAST(has_next_session AS INT64))*100, 2)    AS pct_with_next_session,
  ROUND(AVG(CAST(repeat_contact_24h AS INT64))*100, 2)  AS pct_repeat_24h,
  ROUND(AVG(CAST(is_fcr AS INT64))*100, 2)              AS pct_fcr
FROM cohorts
GROUP BY cohort
ORDER BY sessions DESC;

-- 2b. Excess resolution time attributable to misrouting ---------------------
-- (misrouted technical vs correctly-routed technical baseline)
WITH t AS (
  SELECT
    is_hard_misroute,
    is_correct_technical_route,
    duration_seconds
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
  WHERE is_technical_topic
)
SELECT
  ROUND(AVG(IF(is_hard_misroute, duration_seconds, NULL)), 1)        AS avg_misrouted_s,
  ROUND(AVG(IF(is_correct_technical_route, duration_seconds, NULL)),1) AS avg_correct_s,
  ROUND(AVG(IF(is_hard_misroute, duration_seconds, NULL))
      - AVG(IF(is_correct_technical_route, duration_seconds, NULL)),1) AS excess_seconds_per_misroute,
  COUNTIF(is_hard_misroute)                                          AS n_misrouted,
  ROUND((AVG(IF(is_hard_misroute, duration_seconds, NULL))
       - AVG(IF(is_correct_technical_route, duration_seconds, NULL)))
       * COUNTIF(is_hard_misroute) / 3600.0, 1)                      AS total_excess_hours
FROM t;

-- 2c. Channel load: extra handovers + repeat contacts caused by misroutes ---
SELECT
  COUNTIF(is_hard_misroute OR is_soft_misroute)                       AS misrouted_sessions,
  SUM(IF(is_hard_misroute OR is_soft_misroute, n_transfers, 0))       AS total_handovers_on_misroutes,
  COUNTIF((is_hard_misroute OR is_soft_misroute) AND repeat_contact_24h) AS misrouted_with_repeat,
  COUNTIF((is_hard_misroute OR is_soft_misroute) AND has_next_session)   AS misrouted_with_continuation
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`;

-- 2d. Trend over time (daily misroute rate + impact) ------------------------
SELECT
  DATE(START_MOMENT)                                                 AS day,
  COUNTIF(is_technical_topic)                                        AS technical_sessions,
  COUNTIF(is_hard_misroute)                                          AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute,
  ROUND(AVG(IF(is_hard_misroute, duration_seconds, NULL)),1)         AS avg_misrouted_duration_s
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY day
ORDER BY day;
