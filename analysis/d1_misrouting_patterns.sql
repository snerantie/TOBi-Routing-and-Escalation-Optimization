-- =============================================================================
-- DELIVERABLE 1: Identify patterns of incorrect routing/escalation of technical
-- issues.
-- Reads vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
-- =============================================================================

-- 1a. Headline: how much technical traffic is misrouted? --------------------
SELECT
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  COUNTIF(is_soft_misroute)                                AS soft_misroutes,
  COUNTIF(is_correct_technical_route)                      AS correct_technical_routes,
  ROUND(COUNTIF(is_hard_misroute) / NULLIF(COUNTIF(is_technical_topic),0) * 100, 2) AS pct_hard_misroute,
  ROUND(COUNTIF(is_hard_misroute OR is_soft_misroute)
        / NULLIF(COUNTIF(is_technical_topic),0) * 100, 2)  AS pct_any_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`;

-- 1b. Misrouting by technical topic type ------------------------------------
SELECT
  technical_topic_type,
  COUNT(*)                                                 AS sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/COUNT(*)*100, 2)         AS pct_hard_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
GROUP BY technical_topic_type
ORDER BY hard_misroutes DESC;

-- 1c. Where do misrouted technical sessions actually land? ------------------
SELECT
  final_transfer_target,
  routed_queue_category,
  routed_queue_subtype,
  COUNT(*) AS misrouted_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_hard_misroute
GROUP BY final_transfer_target, routed_queue_category, routed_queue_subtype
ORDER BY misrouted_sessions DESC
LIMIT 50;

-- 1d. Misrouting rate by entry point (channel + DNIS) -----------------------
SELECT
  CHANNEL,
  DNIS,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100, 2) AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY CHANNEL, DNIS
HAVING technical_sessions >= 50          -- volume threshold for stability
ORDER BY hard_misroutes DESC
LIMIT 50;

-- 1e. Most common misrouted flow trails (the actual patterns) ---------------
SELECT
  flow_trail,
  technical_topic_type,
  final_transfer_target,
  COUNT(*) AS n_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_hard_misroute
GROUP BY flow_trail, technical_topic_type, final_transfer_target
ORDER BY n_sessions DESC
LIMIT 50;
