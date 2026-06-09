-- =============================================================================
-- models/04_session_master.sql
-- The enriched, one-row-per-session table that every deliverable query reads.
-- Combines: raw session fields + flow features (01) + queue class (02) +
-- technical topic (03), and derives the misrouting / FCR / repeat-contact flags.
--
-- Output view: vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master
--
-- Depends on views 01, 02, 03 (run those first).
-- =============================================================================
CREATE OR REPLACE VIEW
  `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
AS
WITH s AS (
  SELECT
    SESSION_ID,
    START_MOMENT,
    END_MOMENT,
    CHANNEL,
    DNIS,
    FIRST_INTENT,
    CONFIDENCE_LEVEL,
    INTENT_LIST,
    NEXT_SESSION_ID,
    INTERNAL_SES_LIST,
    IS_FUNCTIONAL,
    service_type,
    HOTLINE_REASON_CODE,
    CUSTOMER_TYPE,
    SERVICE_STATUS,
    ANI,
    TIMESTAMP_DIFF(END_MOMENT, START_MOMENT, SECOND) AS duration_seconds
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
),
-- repeat contact from same ANI within 24h (independent of NEXT_SESSION_ID) ----
repeat_flag AS (
  SELECT
    SESSION_ID,
    LEAD(START_MOMENT) OVER (PARTITION BY ANI ORDER BY START_MOMENT) AS next_ani_contact,
    TIMESTAMP_DIFF(
      LEAD(START_MOMENT) OVER (PARTITION BY ANI ORDER BY START_MOMENT),
      END_MOMENT, HOUR) AS hours_to_next_contact
  FROM s
)
SELECT
  s.*,
  -- CONFIDENCE_LEVEL is a numeric score (0..1) stored as string -> bucket it.
  SAFE_CAST(s.CONFIDENCE_LEVEL AS FLOAT64) AS confidence_value,
  CASE
    WHEN s.CONFIDENCE_LEVEL IS NULL OR TRIM(s.CONFIDENCE_LEVEL) = '' THEN 'unknown'
    WHEN SAFE_CAST(s.CONFIDENCE_LEVEL AS FLOAT64) IS NULL            THEN 'unknown'
    WHEN SAFE_CAST(s.CONFIDENCE_LEVEL AS FLOAT64) = 0                THEN 'none'
    WHEN SAFE_CAST(s.CONFIDENCE_LEVEL AS FLOAT64) < 0.5              THEN 'low'
    WHEN SAFE_CAST(s.CONFIDENCE_LEVEL AS FLOAT64) < 0.8              THEN 'medium'
    ELSE 'high'
  END AS confidence_band,
  f.flow_trail,
  f.n_tokens,
  f.n_transfers,
  f.first_transfer_target,
  f.final_transfer_target,
  f.was_transferred,
  qc.queue_category               AS routed_queue_category,
  qc.queue_subtype                AS routed_queue_subtype,
  t.is_technical_topic,
  t.technical_topic_type,
  -- continuation / repeat-contact signals ----------------------------------
  (s.NEXT_SESSION_ID IS NOT NULL AND s.NEXT_SESSION_ID != '') AS has_next_session,
  (s.INTERNAL_SES_LIST IS NOT NULL AND s.INTERNAL_SES_LIST != '') AS has_internal_handover,
  (rf.hours_to_next_contact IS NOT NULL AND rf.hours_to_next_contact <= 24) AS repeat_contact_24h,
  -- outcome -----------------------------------------------------------------
  -- CONFIRMED via profiling p2e: IS_FUNCTIONAL = 'Yes' / 'No' / '' / null.
  -- UPPER('Yes')='YES' is treated as functional; 'No'/blank/null are not.
  UPPER(COALESCE(s.IS_FUNCTIONAL,'')) IN ('1','Y','YES','TRUE','T') AS is_functional_flag,

  -- ===================== MISROUTING DEFINITIONS ==========================
  -- Hard misroute: technical topic routed to a non-technical queue
  ( t.is_technical_topic
    AND f.was_transferred
    AND qc.queue_category = 'non_technical' ) AS is_hard_misroute,

  -- Soft misroute / containment failure: technical topic, NOT routed to a
  -- technical queue, not functionally resolved, and a follow-on session exists
  ( t.is_technical_topic
    AND COALESCE(qc.queue_category,'unclassified') != 'technical'
    AND NOT (UPPER(COALESCE(s.IS_FUNCTIONAL,'')) IN ('1','Y','YES','TRUE','T'))
    AND (s.NEXT_SESSION_ID IS NOT NULL AND s.NEXT_SESSION_ID != '')
  ) AS is_soft_misroute,

  -- Correctly routed technical: technical topic -> technical queue
  ( t.is_technical_topic
    AND f.was_transferred
    AND qc.queue_category = 'technical' ) AS is_correct_technical_route,

  -- First-contact resolution proxy: functional, no transfer, no follow-on ---
  ( UPPER(COALESCE(s.IS_FUNCTIONAL,'')) IN ('1','Y','YES','TRUE','T')
    AND NOT f.was_transferred
    AND NOT (s.NEXT_SESSION_ID IS NOT NULL AND s.NEXT_SESSION_ID != '')
  ) AS is_fcr
FROM s
LEFT JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`  f  USING (SESSION_ID)
LEFT JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_topic` t  USING (SESSION_ID)
LEFT JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_ref_queue_class` qc
  ON f.final_transfer_target = qc.routing_target
LEFT JOIN repeat_flag rf USING (SESSION_ID);
