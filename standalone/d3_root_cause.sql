-- Build session_master as a TEMP table (no dataset / no views needed).
-- Run this whole file as ONE script in BigQuery.
CREATE TEMP TABLE session_master AS
WITH
-- ===== flow reconstruction from f_tobi_logs_vertex (one token per row) =====
tokens AS (
  SELECT SESSION_ID, ROW_ID, TRIM(LOG) AS token
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
  WHERE LOG IS NOT NULL AND TRIM(LOG) != ''
),
flow_agg AS (
  SELECT
    SESSION_ID,
    COUNT(*) AS n_tokens,
    STRING_AGG(token, ' > ' ORDER BY ROW_ID) AS flow_trail,
    ARRAY_AGG(IF(STARTS_WITH(token,'T_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS transfer_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'S_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS state_tokens
  FROM tokens GROUP BY SESSION_ID
),
-- entity (E#) and intent (I#) ids parsed from S_ tokens ---------------------
entities AS (
  SELECT
    SESSION_ID,
    ARRAY_AGG(DISTINCT ent IGNORE NULLS) AS entity_ids,
    ARRAY_AGG(DISTINCT intnt IGNORE NULLS) AS intent_ids
  FROM (
    SELECT SESSION_ID,
      SAFE_CAST(REGEXP_EXTRACT(token, r'_E([0-9]+)') AS INT64) AS ent,
      SAFE_CAST(REGEXP_EXTRACT(token, r'_I([0-9]+)') AS INT64) AS intnt
    FROM tokens WHERE STARTS_WITH(token,'S_')
  )
  GROUP BY SESSION_ID
),
session_flow AS (
  SELECT
    SESSION_ID, n_tokens, flow_trail,
    transfer_tokens[SAFE_OFFSET(ARRAY_LENGTH(transfer_tokens)-1)] AS final_tag,
    ARRAY_LENGTH(transfer_tokens) AS n_tags,
    (SELECT COUNT(*) FROM UNNEST(transfer_tokens) t WHERE REGEXP_CONTAINS(t, r'^T_2')) AS n_transfers
  FROM flow_agg
),
-- ===== decode the final T_ tag (authoritative mapping) =====================
tag_decode AS (
  SELECT
    sf.*,
    REGEXP_EXTRACT(final_tag, r'^T_([12])')        AS tag_outcome_digit,
    REGEXP_EXTRACT(final_tag, r'^T_[12]([A-F])')   AS tag_letter,
    REGEXP_EXTRACT(final_tag, r'^T_[12][A-F]([IVX]+)_') AS tag_roman,
    REGEXP_EXTRACT(final_tag, r'_([A-Z0-9#!]+)$')  AS routed_client_type
  FROM session_flow sf
),
tag_class AS (
  SELECT
    td.*,
    CASE CONCAT(COALESCE(tag_outcome_digit,''), COALESCE(tag_letter,''))
      WHEN '1A' THEN 'contained_bot'
      WHEN '1B' THEN 'deflection_digital'
      WHEN '1C' THEN 'deflection_assisted'
      WHEN '1D' THEN 'abandoned'
      WHEN '1E' THEN 'error'
      WHEN '1F' THEN 'service_change'
      WHEN '2A' THEN 'transfer_livechat'
      WHEN '2B' THEN 'transfer_acd'
      ELSE IF(final_tag IS NULL, NULL, 'other')
    END AS outcome_group,
    -- support type is only defined for assisted-deflection + transfers
    CASE
      WHEN CONCAT(COALESCE(tag_outcome_digit,''),COALESCE(tag_letter,'')) IN ('1C','2A','2B') THEN
        CASE tag_roman WHEN 'I' THEN 'non_technical' WHEN 'II' THEN 'technical'
                       WHEN 'III' THEN 'commercial' ELSE 'other' END
      ELSE 'na'
    END AS routed_support_type
  FROM tag_decode td
),
flow_classified AS (
  SELECT
    tc.*,
    (outcome_group = 'contained_bot' AND tag_roman IN ('I','II','III')) AS is_bot_contained,
    (outcome_group IN ('transfer_livechat','transfer_acd'))             AS is_transfer,
    (outcome_group IN ('transfer_livechat','transfer_acd','deflection_assisted')) AS is_human_routed,
    (routed_support_type = 'technical')                                 AS routed_to_technical,
    -- legacy column names kept so deliverable queries keep working:
    CASE
      WHEN routed_support_type = 'technical'              THEN 'technical'
      WHEN routed_support_type IN ('non_technical','commercial') THEN 'non_technical'
      ELSE 'unclassified'
    END AS routed_queue_category,
    routed_support_type AS routed_queue_subtype,
    final_tag AS final_transfer_target
  FROM tag_class tc
),
-- ===== sessions base =======================================================
sess AS (
  SELECT
    SESSION_ID, START_MOMENT, END_MOMENT, CHANNEL, DNIS, FIRST_INTENT,
    CONFIDENCE_LEVEL, INTENT_LIST, NEXT_SESSION_ID, INTERNAL_SES_LIST,
    IS_FUNCTIONAL, service_type, HOTLINE_REASON_CODE, CUSTOMER_TYPE,
    SERVICE_STATUS, ANI,
    TIMESTAMP_DIFF(END_MOMENT, START_MOMENT, SECOND) AS duration_seconds,
    UPPER(COALESCE(IS_FUNCTIONAL,'')) IN ('1','Y','YES','TRUE','T') AS is_functional_flag
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
),
-- ===== technical-topic detection from entity (E#) + intent (I8) ============
topic_flags AS (
  SELECT
    SESSION_ID, entity_ids, intent_ids,
    CASE
      WHEN EXISTS(SELECT 1 FROM UNNEST(entity_ids) e WHERE e IN (35,36,37))                 THEN 'tv_features'
      WHEN EXISTS(SELECT 1 FROM UNNEST(entity_ids) e WHERE e IN (38,39,40,41,43,45,46,50))  THEN 'connection_problem'
      WHEN EXISTS(SELECT 1 FROM UNNEST(entity_ids) e WHERE e IN (7,28,55))                  THEN 'device_equipment'
      WHEN EXISTS(SELECT 1 FROM UNNEST(entity_ids) e WHERE e = 32)                          THEN 'general_fault'
      WHEN 8 IN UNNEST(intent_ids)                                                          THEN 'general_difficulty'
      ELSE 'non_technical_or_unknown'
    END AS technical_topic_type
  FROM entities
),
repeat_flag AS (
  SELECT SESSION_ID,
    TIMESTAMP_DIFF(LEAD(START_MOMENT) OVER (PARTITION BY ANI ORDER BY START_MOMENT),
                   END_MOMENT, HOUR) AS hours_to_next_contact
  FROM sess
)
SELECT
  sess.SESSION_ID, sess.START_MOMENT, sess.END_MOMENT, sess.CHANNEL, sess.DNIS,
  sess.FIRST_INTENT, sess.CONFIDENCE_LEVEL, sess.INTENT_LIST, sess.NEXT_SESSION_ID,
  sess.INTERNAL_SES_LIST, sess.IS_FUNCTIONAL, sess.service_type, sess.HOTLINE_REASON_CODE,
  sess.CUSTOMER_TYPE, sess.SERVICE_STATUS, sess.ANI, sess.duration_seconds, sess.is_functional_flag,
  SAFE_CAST(sess.CONFIDENCE_LEVEL AS FLOAT64) AS confidence_value,
  CASE
    WHEN sess.CONFIDENCE_LEVEL IS NULL OR TRIM(sess.CONFIDENCE_LEVEL) = '' THEN 'unknown'
    WHEN SAFE_CAST(sess.CONFIDENCE_LEVEL AS FLOAT64) IS NULL               THEN 'unknown'
    WHEN SAFE_CAST(sess.CONFIDENCE_LEVEL AS FLOAT64) = 0                   THEN 'none'
    WHEN SAFE_CAST(sess.CONFIDENCE_LEVEL AS FLOAT64) < 0.5                 THEN 'low'
    WHEN SAFE_CAST(sess.CONFIDENCE_LEVEL AS FLOAT64) < 0.8                 THEN 'medium'
    ELSE 'high'
  END AS confidence_band,
  f.flow_trail, f.n_tokens, f.n_tags, f.n_transfers, f.final_tag, f.final_transfer_target,
  f.tag_outcome_digit, f.tag_letter, f.tag_roman, f.routed_client_type,
  f.outcome_group, f.routed_support_type, f.routed_queue_category, f.routed_queue_subtype,
  f.is_bot_contained, f.is_transfer, f.is_human_routed, f.routed_to_technical,
  f.is_human_routed AS was_transferred,         -- legacy alias
  t.entity_ids, t.intent_ids, t.technical_topic_type,
  (t.technical_topic_type != 'non_technical_or_unknown') AS is_technical_topic,
  (sess.NEXT_SESSION_ID IS NOT NULL AND sess.NEXT_SESSION_ID != '')   AS has_next_session,
  (sess.INTERNAL_SES_LIST IS NOT NULL AND sess.INTERNAL_SES_LIST != '') AS has_internal_handover,
  (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) AS repeat_contact_24h,
  -- ===================== CORRECTED MISROUTING DEFINITIONS =================
  -- Hard misroute: technical topic routed to a human but to a NON-technical/
  -- commercial skill (wrong skill).
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND f.is_human_routed
    AND f.routed_support_type IN ('non_technical','commercial') )       AS is_hard_misroute,
  -- Soft misroute: technical topic deflected to digital / abandoned / error,
  -- and the customer comes back within 24h.
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND f.outcome_group IN ('deflection_digital','abandoned','error')
    AND (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) ) AS is_soft_misroute,
  -- Correct: technical topic bot-contained OR routed to a technical skill.
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND (f.is_bot_contained OR f.routed_to_technical) )                 AS is_correct_technical_route,
  -- FCR proxy: bot-contained (solved) + functional.
  ( f.is_bot_contained AND sess.is_functional_flag )                    AS is_fcr
FROM sess
LEFT JOIN flow_classified f USING (SESSION_ID)
LEFT JOIN topic_flags     t USING (SESSION_ID)
LEFT JOIN repeat_flag    rf USING (SESSION_ID);

-- =============================================================================
-- DELIVERABLE 3: Drivers of incorrect routing decisions
-- (intent detection, entry points, conversation flows).
-- Reads session_master (TEMP table built above)
-- =============================================================================

-- 3a. Intent-detection quality: misroute rate by confidence band -----------
-- CONFIDENCE_LEVEL is a numeric score (0..1); bucketed into none/low/medium/high.
SELECT
  confidence_band,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM session_master
GROUP BY confidence_band
ORDER BY pct_misroute DESC;

-- 3b. FIRST_INTENT values that most often misroute technical topics ---------
-- These are the intent-detection entries that send technical issues astray.
SELECT
  FIRST_INTENT,
  COUNTIF(is_technical_topic)                              AS technical_sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute
FROM session_master
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
FROM session_master
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
  FROM session_master,
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
  confidence_band,
  COUNT(*)                                                 AS sessions,
  COUNTIF(is_hard_misroute)                                AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/COUNT(*)*100,2)          AS pct_misroute
FROM session_master
WHERE is_technical_topic
GROUP BY technical_topic_type, confidence_band
ORDER BY hard_misroutes DESC
LIMIT 50;
