-- =============================================================================
-- SUPPORTING ANALYSIS D5: Conversation-flow transition (Sankey) data
-- Reveals WHERE in the flow technical issues leak toward non-technical queues.
-- Produces edge lists ready for a Sankey / network diagram (see notebook).
-- Depends on views models/01 + models/04.
-- =============================================================================

-- 5a. Step-to-step transitions within technical sessions --------------------
-- Edge list: (source token -> next token) over R_/M_/T_ steps.
WITH steps AS (
  SELECT
    l.SESSION_ID,
    l.ROW_ID,
    TRIM(l.LOG) AS token
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex` l
  JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master` m
    USING (SESSION_ID)
  WHERE m.is_technical_topic
    AND REGEXP_CONTAINS(TRIM(l.LOG), r'^(R_|M_|T_)')
),
seq AS (
  SELECT
    SESSION_ID,
    token AS source,
    LEAD(token) OVER (PARTITION BY SESSION_ID ORDER BY ROW_ID) AS target
  FROM steps
)
SELECT
  source,
  target,
  COUNT(*)                    AS n_transitions,
  COUNT(DISTINCT SESSION_ID)  AS n_sessions
FROM seq
WHERE target IS NOT NULL
GROUP BY source, target
ORDER BY n_sessions DESC
LIMIT 300;

-- 5b. Direct intent -> final destination edges (high-level Sankey) ----------
SELECT
  FIRST_INTENT                AS source_intent,
  technical_topic_type,
  final_transfer_target       AS target_queue,
  routed_queue_category,
  COUNT(*)                    AS n_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
  AND final_transfer_target IS NOT NULL
GROUP BY source_intent, technical_topic_type, target_queue, routed_queue_category
ORDER BY n_sessions DESC
LIMIT 200;

-- 5c. Topic -> destination "confusion matrix" (correct vs misrouted) --------
SELECT
  technical_topic_type,
  routed_queue_category,
  routed_queue_subtype,
  COUNT(*) AS n_sessions
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic AND was_transferred
GROUP BY technical_topic_type, routed_queue_category, routed_queue_subtype
ORDER BY technical_topic_type, n_sessions DESC;
