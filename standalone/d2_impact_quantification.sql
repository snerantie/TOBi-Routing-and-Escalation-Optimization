-- Build session_master as a TEMP table (no dataset / no views needed).
-- Run this whole file as ONE script in BigQuery.
CREATE TEMP TABLE session_master AS
WITH
-- ===== models/01: flow reconstruction from f_tobi_logs_vertex =============
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
    ARRAY_AGG(IF(STARTS_WITH(token,'R_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS route_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'M_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS module_tokens
  FROM tokens
  GROUP BY SESSION_ID
),
session_flow AS (
  SELECT
    SESSION_ID, n_tokens, flow_trail,
    ARRAY_LENGTH(transfer_tokens) AS n_transfers,
    transfer_tokens[SAFE_OFFSET(0)] AS first_transfer_target,
    transfer_tokens[SAFE_OFFSET(ARRAY_LENGTH(transfer_tokens)-1)] AS final_transfer_target,
    ARRAY_LENGTH(transfer_tokens) > 0 AS was_transferred,
    LOWER(CONCAT(ARRAY_TO_STRING(route_tokens,' '),' ',ARRAY_TO_STRING(module_tokens,' '))) AS topic_text
  FROM flow_agg
),
-- ===== models/02: queue classification (override + keyword rules) =========
-- TODO(validate): add real T_ destinations to the override CASE below.
flow_classified AS (
  SELECT
    sf.*,
    CASE
      WHEN final_transfer_target IS NULL THEN NULL
      WHEN final_transfer_target = 'T_1All_CPOS' THEN 'non_technical'                 -- override
      WHEN REGEXP_CONTAINS(LOWER(final_transfer_target),
             r'(tecnic|tecn|avaria|repara|suporte|apoio.?tec|banda.?larga|tech|support|fault|fibra|internet|rede|network)')
        THEN 'technical'
      WHEN REGEXP_CONTAINS(LOWER(final_transfer_target),
             r'(cpos|vend|comerc|adesa|adesao|fideliz|retenc|retention|sales|billing|fatur|cobranc|loja|store|upgrade)')
        THEN 'non_technical'
      ELSE 'unclassified'
    END AS routed_queue_category,
    CASE
      WHEN final_transfer_target IS NULL THEN NULL
      WHEN final_transfer_target = 'T_1All_CPOS' THEN 'sales_commercial'
      ELSE 'keyword_rule'
    END AS routed_queue_subtype
  FROM session_flow sf
),
-- ===== sessions base ======================================================
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
-- ===== models/03: technical-topic classification ==========================
-- TODO(validate): refine the keyword stems against real R_/M_/FIRST_INTENT values.
topic_base AS (
  SELECT
    s.SESSION_ID,
    LOWER(CONCAT(COALESCE(f.topic_text,''),' ',COALESCE(s.FIRST_INTENT,''),' ',
                 COALESCE(s.INTENT_LIST,''))) AS signal_text
  FROM sess s
  LEFT JOIN flow_classified f USING (SESSION_ID)
),
topic AS (
  SELECT
    SESSION_ID,
    REGEXP_CONTAINS(signal_text,
      r'(internet|rede|sinal|sem.?servic|sem.?rede|lentid|avaria|router|wi.?fi|fibra|ligac|conex|cobertura|velocidade|no.?service|connection|outage)') AS is_connection_problem,
    REGEXP_CONTAINS(signal_text,
      r'(estragad|danificad|partid|ecra|ecr.|reparac|repara|avariad|nao.?liga|n.o.?liga|quebrad|broken|damage|repair|garantia)') AS is_device_damage,
    REGEXP_CONTAINS(signal_text,
      r'(\btv\b|televis|box|canais|gravac|telemovel|smartphone|configurac|definic|equipament|feature|funcionalidade)') AS is_feature_question
  FROM topic_base
),
topic_flags AS (
  SELECT
    SESSION_ID, is_connection_problem, is_device_damage, is_feature_question,
    (is_connection_problem OR is_device_damage OR is_feature_question) AS is_technical_topic,
    CASE
      WHEN is_connection_problem THEN 'connection_problem'
      WHEN is_device_damage      THEN 'device_damage_repair'
      WHEN is_feature_question    THEN 'feature_question'
      ELSE 'non_technical_or_unknown'
    END AS technical_topic_type
  FROM topic
),
-- repeat contact within 24h (same ANI) -------------------------------------
repeat_flag AS (
  SELECT
    SESSION_ID,
    TIMESTAMP_DIFF(
      LEAD(START_MOMENT) OVER (PARTITION BY ANI ORDER BY START_MOMENT),
      END_MOMENT, HOUR) AS hours_to_next_contact
  FROM sess
)
SELECT
  sess.SESSION_ID, sess.START_MOMENT, sess.END_MOMENT, sess.CHANNEL, sess.DNIS,
  sess.FIRST_INTENT, sess.CONFIDENCE_LEVEL, sess.INTENT_LIST, sess.NEXT_SESSION_ID,
  sess.INTERNAL_SES_LIST, sess.IS_FUNCTIONAL, sess.service_type, sess.HOTLINE_REASON_CODE,
  sess.CUSTOMER_TYPE, sess.SERVICE_STATUS, sess.ANI, sess.duration_seconds,
  sess.is_functional_flag,
  f.flow_trail, f.n_tokens, f.n_transfers, f.first_transfer_target,
  f.final_transfer_target, f.was_transferred,
  f.routed_queue_category, f.routed_queue_subtype,
  tf.is_technical_topic, tf.technical_topic_type,
  (sess.NEXT_SESSION_ID IS NOT NULL AND sess.NEXT_SESSION_ID != '')   AS has_next_session,
  (sess.INTERNAL_SES_LIST IS NOT NULL AND sess.INTERNAL_SES_LIST != '') AS has_internal_handover,
  (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) AS repeat_contact_24h,
  -- ===================== MISROUTING DEFINITIONS ==========================
  (tf.is_technical_topic AND f.was_transferred
     AND f.routed_queue_category = 'non_technical')                  AS is_hard_misroute,
  (tf.is_technical_topic
     AND COALESCE(f.routed_queue_category,'unclassified') != 'technical'
     AND NOT sess.is_functional_flag
     AND (sess.NEXT_SESSION_ID IS NOT NULL AND sess.NEXT_SESSION_ID != '')) AS is_soft_misroute,
  (tf.is_technical_topic AND f.was_transferred
     AND f.routed_queue_category = 'technical')                      AS is_correct_technical_route,
  (sess.is_functional_flag AND NOT f.was_transferred
     AND NOT (sess.NEXT_SESSION_ID IS NOT NULL AND sess.NEXT_SESSION_ID != '')) AS is_fcr
FROM sess
LEFT JOIN flow_classified f USING (SESSION_ID)
LEFT JOIN topic_flags     tf USING (SESSION_ID)
LEFT JOIN repeat_flag     rf USING (SESSION_ID);

-- =============================================================================
-- DELIVERABLE 2: Quantify the impact of misrouting on customer experience:
-- resolution time, channel load (handovers), and repeated contacts.
-- Reads session_master (TEMP table built above)
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
  FROM session_master
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
  FROM session_master
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
FROM session_master;

-- 2d. Trend over time (daily misroute rate + impact) ------------------------
SELECT
  DATE(START_MOMENT)                                                 AS day,
  COUNTIF(is_technical_topic)                                        AS technical_sessions,
  COUNTIF(is_hard_misroute)                                          AS hard_misroutes,
  ROUND(COUNTIF(is_hard_misroute)/NULLIF(COUNTIF(is_technical_topic),0)*100,2) AS pct_misroute,
  ROUND(AVG(IF(is_hard_misroute, duration_seconds, NULL)),1)         AS avg_misrouted_duration_s
FROM session_master
GROUP BY day
ORDER BY day;
