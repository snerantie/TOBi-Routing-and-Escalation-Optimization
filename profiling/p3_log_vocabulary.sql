-- =============================================================================
-- p3_log_vocabulary.sql
-- Phase 0 profiling: extract the LOG token vocabulary by prefix type.
-- Each LOG row holds ONE token. These lists drive the classifications in
-- models/02 (queues) and models/03 (technical topics).
--
-- ACTION: review the T_ list and classify each destination technical / non-technical.
-- =============================================================================

-- 3a. T_ routing destinations (THE routing decision) -----------------------
SELECT
  TRIM(LOG)                   AS routing_target,
  COUNT(*)                    AS n_events,
  COUNT(DISTINCT SESSION_ID)  AS n_sessions
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
WHERE STARTS_WITH(TRIM(LOG), 'T_')
GROUP BY routing_target
ORDER BY n_sessions DESC;

-- 3b. R_ routes / recognized intents ---------------------------------------
SELECT
  TRIM(LOG)                   AS route_token,
  COUNT(*)                    AS n_events,
  COUNT(DISTINCT SESSION_ID)  AS n_sessions
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
WHERE STARTS_WITH(TRIM(LOG), 'R_')
GROUP BY route_token
ORDER BY n_sessions DESC
LIMIT 200;

-- 3c. M_ menu / module selections ------------------------------------------
SELECT
  TRIM(LOG)                   AS module_token,
  COUNT(*)                    AS n_events,
  COUNT(DISTINCT SESSION_ID)  AS n_sessions
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
WHERE STARTS_WITH(TRIM(LOG), 'M_')
GROUP BY module_token
ORDER BY n_sessions DESC
LIMIT 200;

-- 3d. Token-type breakdown (sanity check of the grammar) -------------------
SELECT
  CASE
    WHEN STARTS_WITH(TRIM(LOG), 'S_') THEN 'S_state'
    WHEN STARTS_WITH(TRIM(LOG), 'R_') THEN 'R_route'
    WHEN STARTS_WITH(TRIM(LOG), 'M_') THEN 'M_module'
    WHEN STARTS_WITH(TRIM(LOG), 'T_') THEN 'T_transfer'
    ELSE CONCAT('other:', SUBSTR(TRIM(LOG), 1, 2))
  END AS token_type,
  COUNT(*) AS n_events
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
GROUP BY token_type
ORDER BY n_events DESC;

-- 3e. Sample full reconstructed trails (eyeball the flows) -----------------
SELECT
  SESSION_ID,
  STRING_AGG(TRIM(LOG), ' > ' ORDER BY ROW_ID) AS flow_trail,
  COUNT(*) AS n_tokens
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
GROUP BY SESSION_ID
LIMIT 30;
