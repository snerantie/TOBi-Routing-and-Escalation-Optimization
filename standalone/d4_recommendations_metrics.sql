-- Build session_master as a TEMP table (no dataset / no views needed).
-- Run this whole file as ONE script in BigQuery.
CREATE TEMP TABLE session_master AS
WITH
-- ===== flow reconstruction from f_tobi_logs_vertex =========================
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
session_flow AS (
  SELECT
    SESSION_ID, n_tokens, flow_trail,
    transfer_tokens[SAFE_OFFSET(ARRAY_LENGTH(transfer_tokens)-1)] AS final_tag,
    ARRAY_LENGTH(transfer_tokens) AS n_tags,
    (SELECT COUNT(*) FROM UNNEST(transfer_tokens) t WHERE REGEXP_CONTAINS(t, r'^T_2')) AS n_transfers
  FROM flow_agg
),
-- ===== LAST S_ token per session (business rule per data-science lead) =====
-- "Extract Intent of the client - Take into account the last S_"
-- Earlier S_ tokens may reflect mid-conversation pivots; the LAST S_ is the
-- bot's final read of the customer intent and is the basis for classification.
last_s AS (
  SELECT SESSION_ID, token AS last_s_token
  FROM (
    SELECT SESSION_ID, token,
           ROW_NUMBER() OVER (PARTITION BY SESSION_ID ORDER BY ROW_ID DESC) AS rn
    FROM tokens
    WHERE STARTS_WITH(token, 'S_')
  )
  WHERE rn = 1
),
entities AS (
  SELECT
    SESSION_ID,
    last_s_token,
    SAFE_CAST(REGEXP_EXTRACT(last_s_token, r'_E([0-9]+)') AS INT64) AS entity_id,
    SAFE_CAST(REGEXP_EXTRACT(last_s_token, r'_I([0-9]+)') AS INT64) AS intent_id
  FROM last_s
),
tag_decode AS (
  SELECT
    sf.*,
    REGEXP_EXTRACT(final_tag, r'^T_([12])')                  AS tag_outcome_digit,
    REGEXP_EXTRACT(final_tag, r'^T_[12]([A-F])')             AS tag_letter,
    REGEXP_EXTRACT(final_tag, r'^T_[12][A-F]([IVX]+)_')      AS tag_roman,
    REGEXP_EXTRACT(final_tag, r'_([A-Z0-9#!]+)$')             AS routed_client_type
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
    (outcome_group = 'contained_bot' AND tag_roman IN ('I','II','III'))           AS is_bot_contained,
    (outcome_group IN ('transfer_livechat','transfer_acd'))                       AS is_transfer,
    (outcome_group IN ('transfer_livechat','transfer_acd','deflection_assisted')) AS is_human_routed,
    (routed_support_type = 'technical')                                           AS routed_to_technical,
    CASE
      WHEN routed_support_type = 'technical'              THEN 'technical'
      WHEN routed_support_type IN ('non_technical','commercial') THEN 'non_technical'
      ELSE 'unclassified'
    END AS routed_queue_category,
    routed_support_type AS routed_queue_subtype,
    final_tag AS final_transfer_target
  FROM tag_class tc
),
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
topic_flags AS (
  SELECT
    SESSION_ID, entity_id, intent_id, last_s_token,
    CASE
      WHEN entity_id IN (35,36,37)                  THEN 'tv_features'
      WHEN entity_id IN (38,39,40,41,43,45,46,50)   THEN 'connection_problem'
      WHEN entity_id IN (7,28,55)                   THEN 'device_equipment'
      WHEN entity_id = 32                           THEN 'general_fault'
      WHEN intent_id = 8                             THEN 'general_difficulty'
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
  f.is_human_routed AS was_transferred,
  t.last_s_token, t.entity_id, t.intent_id, t.technical_topic_type,
  (t.technical_topic_type != 'non_technical_or_unknown') AS is_technical_topic,
  (sess.NEXT_SESSION_ID IS NOT NULL AND sess.NEXT_SESSION_ID != '')   AS has_next_session,
  (sess.INTERNAL_SES_LIST IS NOT NULL AND sess.INTERNAL_SES_LIST != '') AS has_internal_handover,
  (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) AS repeat_contact_24h,
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND f.is_human_routed
    AND f.routed_support_type IN ('non_technical','commercial') )       AS is_hard_misroute,
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND f.outcome_group IN ('deflection_digital','abandoned','error')
    AND (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) ) AS is_soft_misroute,
  ( (t.technical_topic_type != 'non_technical_or_unknown')
    AND (f.is_bot_contained OR f.routed_to_technical) )                 AS is_correct_technical_route,
  ( f.is_bot_contained AND sess.is_functional_flag )                    AS is_fcr
FROM sess
LEFT JOIN flow_classified f USING (SESSION_ID)
LEFT JOIN topic_flags     t USING (SESSION_ID)
LEFT JOIN repeat_flag    rf USING (SESSION_ID);

-- =============================================================================
-- DELIVERABLE 4 & 5: Data-driven recommendations + implementation tracking.
-- This file produces the prioritised evidence that backs each recommendation
-- and the baseline KPIs to monitor after changes ship.
-- Reads session_master (TEMP table built above)
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
  FROM session_master
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
  FROM session_master
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
FROM session_master
GROUP BY day
ORDER BY day;

-- 4d. Unclassified destinations still needing a queue mapping ---------------
-- Anything here weakens the analysis -> classify in models/02.
SELECT
  final_transfer_target,
  COUNT(*) AS sessions,
  COUNTIF(is_technical_topic) AS technical_sessions
FROM session_master
WHERE routed_queue_category = 'unclassified'
  AND final_transfer_target IS NOT NULL
GROUP BY final_transfer_target
ORDER BY sessions DESC
LIMIT 50;
