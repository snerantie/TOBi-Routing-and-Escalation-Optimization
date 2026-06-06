-- =============================================================================
-- p1_volume_and_join_integrity.sql
-- Phase 0 profiling: volume, date range, continuation links, and whether the
-- log events join cleanly to sessions.
-- Source: vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation
-- =============================================================================

-- 1a. Session table profile -------------------------------------------------
SELECT
  COUNT(*)                                                       AS total_rows,
  COUNT(DISTINCT SESSION_ID)                                     AS distinct_sessions,
  MIN(START_MOMENT)                                             AS earliest_session,
  MAX(END_MOMENT)                                               AS latest_session,
  COUNTIF(NEXT_SESSION_ID IS NOT NULL AND NEXT_SESSION_ID != '')      AS sessions_with_next,
  COUNTIF(INTERNAL_SES_LIST IS NOT NULL AND INTERNAL_SES_LIST != '')  AS sessions_with_internal,
  ROUND(COUNTIF(NEXT_SESSION_ID IS NOT NULL AND NEXT_SESSION_ID != '')
        / COUNT(*) * 100, 2)                                    AS pct_with_next
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`;

-- 1b. Log table profile -----------------------------------------------------
SELECT
  COUNT(*)                    AS total_log_rows,
  COUNT(DISTINCT SESSION_ID)  AS distinct_log_sessions,
  MIN(MOMENT)                 AS earliest_log,
  MAX(MOMENT)                 AS latest_log,
  ROUND(COUNT(*) / COUNT(DISTINCT SESSION_ID), 1) AS avg_tokens_per_session
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`;

-- 1c. Join integrity: do log sessions exist in the session table? -----------
SELECT
  COUNTIF(s.SESSION_ID IS NOT NULL)              AS log_sessions_matched,
  COUNTIF(s.SESSION_ID IS NULL)                  AS log_sessions_unmatched,
  COUNT(*)                                       AS distinct_log_sessions
FROM (
  SELECT DISTINCT SESSION_ID
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
) l
LEFT JOIN (
  SELECT DISTINCT SESSION_ID
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
) s USING (SESSION_ID);

-- 1d. Reverse: sessions that have no log events -----------------------------
SELECT
  COUNTIF(l.SESSION_ID IS NULL) AS sessions_without_logs,
  COUNT(*)                      AS distinct_sessions
FROM (
  SELECT DISTINCT SESSION_ID
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
) s
LEFT JOIN (
  SELECT DISTINCT SESSION_ID
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
) l USING (SESSION_ID);
