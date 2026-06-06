-- =============================================================================
-- DELIVERABLE 3: Drivers of incorrect routing decisions
-- (intent detection, entry points, conversation flows).
-- Reads vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
-- =============================================================================

-- 3a. Intent-detection quality: misroute rate by CONFIDENCE_LEVEL -----------
SELECT
  CONFIDENCE_LEVEL,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY CONFIDENCE_LEVEL
ORDER BY pct_misroute DESC;

-- 3b. FIRST_INTENT values that most often misroute technical topics ---------
-- These are the intent-detection entries that send technical issues astray.
SELECT
  FIRST_INTENT,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
GROUP BY FIRST_INTENT
HAVING technical_sessions >= 30
ORDER BY hard_misroutes DESC
LIMIT 50;

-- 3c. Entry point: misroute rate by channel ---------------------------------
SELECT
  CHANNEL,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
GROUP BY CHANNEL
ORDER BY pct_misroute DESC;

-- 3d. Conversation-flow drivers: the route (R_) / module (M_) steps that
--     precede a misroute. Explodes the flow trail and counts tokens that
--     appear in hard-misrouted technical sessions.
WITH exploded AS (
  SELECT
    SESSION_ID,
    is_hard_misroute,
    is_technical_topic,
    TRIM(tok) AS token
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`,
  UNNEST(SPLIT(flow_trail, ' > ')) AS tok
  WHERE is_technical_topic
    AND (STARTS_WITH(TRIM(tok),'R_') OR STARTS_WITH(TRIM(tok),'M_'))
)
SELECT
  token,
  COUNT(DISTINCT SESSION_ID)                               AS technical_sessions,
  COUNT(DISTINCT IF(is_hard_misroute, SESSION_ID, NULL))   AS misrouted_sessions,
  ROUND(COUNT(DISTINCT IF(is_hard_misroute, SESSION_ID, NULL))
        / COUNT(DISTINCT SESSION_ID) * 100, 2)             AS pct_misroute
FROM exploded
GROUP BY token
HAVING technical_sessions >= 30
ORDER BY misrouted_sessions DESC
LIMIT 60;

-- 3e. Low-confidence + misroute combined (the prime root-cause segment) -----
SELECT
  technical_topic_type,
  CONFIDENCE_LEVEL,
  COUNT(*)                                                 AS sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/COUNT(*)*100,2)          AS pct_misroute
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
GROUP BY technical_topic_type, CONFIDENCE_LEVEL
ORDER BY hard_misroutes DESC
LIMIT 50;
