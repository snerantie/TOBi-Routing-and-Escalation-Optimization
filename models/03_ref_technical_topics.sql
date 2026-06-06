-- =============================================================================
-- models/03_ref_technical_topics.sql
-- Classifies whether a session is about a TECHNICAL topic, per the business
-- definition: TV/phone (device) features, connection problems, phone damage/repair.
--
-- Signals combined: R_/M_ tokens (topic_text), FIRST_INTENT, INTENT_LIST.
-- Output view: vf-pt-copsvertex-live.tobi_routing_analysis.v_session_topic
--
-- TODO(validate): refine the keyword stems below against profiling/p3b (R_) and
-- p3c (M_) and p2g (FIRST_INTENT). Portuguese (vfpt) stems used.
-- =============================================================================
CREATE OR REPLACE VIEW
  `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_topic`
AS
WITH base AS (
  SELECT
    s.SESSION_ID,
    LOWER(CONCAT(
      COALESCE(f.topic_text, ''), ' ',
      COALESCE(s.FIRST_INTENT, ''), ' ',
      COALESCE(s.INTENT_LIST, '')
    )) AS signal_text
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions` s
  LEFT JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow` f
    USING (SESSION_ID)
),
classified AS (
  SELECT
    SESSION_ID,
    signal_text,
    -- connection problems -------------------------------------------------
    REGEXP_CONTAINS(signal_text,
      r'(internet|rede|sinal|sem.?servic|sem.?rede|lentid|avaria|router|wi.?fi|fibra|ligac|conex|cobertura|velocidade|no.?service|connection|outage)')
      AS is_connection_problem,
    -- phone / device damage or repair -------------------------------------
    REGEXP_CONTAINS(signal_text,
      r'(estragad|danificad|partid|ecra|ecr.|reparac|repara|avariad|nao.?liga|n.o.?liga|quebrad|broken|damage|repair|garantia)')
      AS is_device_damage,
    -- TV / phone feature questions ----------------------------------------
    REGEXP_CONTAINS(signal_text,
      r'(\btv\b|televis|box|canais|gravac|telemovel|smartphone|configurac|definic|equipament|feature|funcionalidade)')
      AS is_feature_question
  FROM base
)
SELECT
  SESSION_ID,
  is_connection_problem,
  is_device_damage,
  is_feature_question,
  (is_connection_problem OR is_device_damage OR is_feature_question) AS is_technical_topic,
  CASE
    WHEN is_connection_problem THEN 'connection_problem'
    WHEN is_device_damage      THEN 'device_damage_repair'
    WHEN is_feature_question    THEN 'feature_question'
    ELSE 'non_technical_or_unknown'
  END AS technical_topic_type
FROM classified;
