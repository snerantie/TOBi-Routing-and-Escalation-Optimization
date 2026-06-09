-- =============================================================================
-- SUPPORTING ANALYSIS D8: Bot containment & self-service deflection opportunity
-- Beyond "wrong queue", how many technical contacts could the bot resolve
-- itself (first-contact, no human handover)? Sizes the FCR upside (Deliverable 5).
-- Depends on view models/04.
-- =============================================================================

-- 8a. Technical-session outcome funnel --------------------------------------
SELECT
  COUNTIF(is_technical_topic)                                   AS technical_sessions,
  COUNTIF(is_technical_topic AND is_fcr)                        AS contained_fcr,
  COUNTIF(is_technical_topic AND is_correct_technical_route)    AS correct_transfer,
  COUNTIF(is_technical_topic AND is_hard_misroute)              AS hard_misroute,
  COUNTIF(is_technical_topic AND is_soft_misroute)              AS soft_misroute,
  ROUND(COUNTIF(is_technical_topic AND is_fcr)
        /NULLIF(COUNTIF(is_technical_topic),0)*100,2)           AS pct_contained
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`;

-- 8b. Top technical topics NOT contained (self-service candidates) ----------
-- High-volume technical intents that end up transferred/misrouted are the best
-- candidates for an improved automated flow.
SELECT
  FIRST_INTENT,
  technical_topic_type,
  COUNT(*)                                                      AS technical_sessions,
  COUNTIF(is_fcr)                                               AS contained,
  COUNTIF(was_transferred)                                      AS transferred,
  COUNTIF(is_hard_misroute)                                     AS misrouted,
  ROUND(COUNTIF(is_fcr)/COUNT(*)*100,2)                         AS pct_contained
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
GROUP BY FIRST_INTENT, technical_topic_type
HAVING technical_sessions >= 30
ORDER BY transferred DESC
LIMIT 50;

-- 8c. Containment vs intent-detection confidence band -----------------------
-- Does low confidence correlate with poor containment?
SELECT
  confidence_band,
  COUNTIF(is_technical_topic)                                   AS technical_sessions,
  ROUND(COUNTIF(is_technical_topic AND is_fcr)
        /NULLIF(COUNTIF(is_technical_topic),0)*100,2)           AS pct_contained,
  ROUND(COUNTIF(is_technical_topic AND was_transferred)
        /NULLIF(COUNTIF(is_technical_topic),0)*100,2)           AS pct_transferred
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY confidence_band
ORDER BY technical_sessions DESC;
