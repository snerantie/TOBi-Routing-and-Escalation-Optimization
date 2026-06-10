-- =============================================================================
-- DELIVERABLE 4 & 5: Data-driven recommendations + implementation tracking.
-- This file produces the prioritised evidence that backs each recommendation
-- and the baseline KPIs to monitor after changes ship.
-- Reads vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
-- =============================================================================

-- 4a. Prioritised fix list: rank misroute "leaks" by volume x impact --------
-- Each row = an (intent -> wrong destination) leak. Sort by sessions to find
-- the highest-ROI routing-rule changes.
WITH leaks AS (
  SELECT
    FIRST_INTENT,
    technical_topic_type,
    final_transfer_target,
    routed_queue_subtype,
    COUNT(*)                                  AS misrouted_sessions,
    ROUND(AVG(duration_seconds),1)            AS avg_duration_s,
    COUNTIF(repeat_contact_24h)               AS repeat_contacts,
    SUM(n_transfers)                          AS total_handovers
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
  WHERE is_hard_misroute
  GROUP BY FIRST_INTENT, technical_topic_type, final_transfer_target, routed_queue_subtype
)
SELECT
  *,
  -- simple impact score = volume weighted by repeat contacts & handovers
  misrouted_sessions
    + 2 * repeat_contacts
    + total_handovers                          AS impact_score
FROM leaks
ORDER BY impact_score DESC
LIMIT 50;

-- 4b. Opportunity sizing.
-- NOTE: misrouted technical sessions are NOT longer than correctly-routed ones,
-- so duration-based "hours saved" is misleading (can go negative). The real cost
-- of misrouting is EXTRA HANDOVERS and REPEAT CONTACTS - size those instead.
WITH base AS (
  SELECT
    COUNTIF(is_hard_misroute)                                   AS n_hard_misroute,
    COUNTIF(is_soft_misroute)                                   AS n_soft_misroute,
    SUM(IF(is_hard_misroute OR is_soft_misroute, n_transfers, 0)) AS handovers_on_misroutes,
    AVG(IF(is_correct_technical_route, n_transfers, NULL))      AS avg_handovers_correct,
    AVG(IF(is_hard_misroute, n_transfers, NULL))               AS avg_handovers_misroute,
    COUNTIF((is_hard_misroute OR is_soft_misroute) AND repeat_contact_24h) AS repeat_contacts
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
  WHERE is_technical_topic
)
SELECT
  n_hard_misroute,
  n_soft_misroute,
  handovers_on_misroutes,
  ROUND(avg_handovers_misroute, 2)                              AS avg_handovers_misroute,
  ROUND(avg_handovers_correct, 2)                               AS avg_handovers_correct,
  -- excess handovers vs the correctly-routed baseline = avoidable rework
  ROUND((avg_handovers_misroute - avg_handovers_correct) * n_hard_misroute, 0)
                                                                AS excess_handovers_avoidable,
  repeat_contacts                                               AS repeat_contacts_avoidable
FROM base;

-- 4c. Baseline KPI scorecard (re-run post-implementation to track uplift) ---
SELECT
  DATE(START_MOMENT)                                            AS day,
  COUNT(*)                                                      AS all_sessions,
  COUNTIF(is_technical_topic)                                   AS technical_sessions,
  ROUND(COUNTIF(is_fcr)/COUNT(*)*100,2)                         AS fcr_pct_all,
  ROUND(COUNTIF(is_fcr AND is_technical_topic)
        /NULLIF(COUNTIF(is_technical_topic),0)*100,2)           AS fcr_pct_technical,
  ROUND(COUNTIF(is_hard_misroute)
        /NULLIF(COUNTIF(is_technical_topic),0)*100,2)           AS hard_misroute_pct,
  ROUND(COUNTIF(repeat_contact_24h)/COUNT(*)*100,2)             AS repeat_contact_pct,
  ROUND(AVG(n_transfers),2)                                     AS avg_handovers
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY day
ORDER BY day;

-- 4d. Unclassified destinations still needing a queue mapping ---------------
-- Anything here weakens the analysis -> classify in models/02.
SELECT
  final_transfer_target,
  COUNT(*) AS sessions,
  COUNTIF(is_technical_topic) AS technical_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE routed_queue_category = 'unclassified'
  AND final_transfer_target IS NOT NULL
GROUP BY final_transfer_target
ORDER BY sessions DESC
LIMIT 50;
