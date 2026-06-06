-- =============================================================================
-- p2_categorical_distributions.sql
-- Phase 0 profiling: distributions of the categorical fields that define the
-- routing taxonomy, intent-detection quality, and outcomes.
-- Run each block independently.
-- =============================================================================
DECLARE src STRING DEFAULT
  'vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions';

-- NOTE: BigQuery does not template table names in plain SELECT. The blocks below
-- use the literal path. The DECLARE above is documentation of the source.

-- 2a. Channels / entry points ----------------------------------------------
SELECT CHANNEL, COUNT(*) AS n,
       ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2) AS pct
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY CHANNEL ORDER BY n DESC;

-- 2b. DNIS (dialled entry point) -------------------------------------------
SELECT DNIS, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY DNIS ORDER BY n DESC LIMIT 50;

-- 2c. service_type ----------------------------------------------------------
SELECT service_type, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY service_type ORDER BY n DESC;

-- 2d. HOTLINE_REASON_CODE ---------------------------------------------------
SELECT HOTLINE_REASON_CODE, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY HOTLINE_REASON_CODE ORDER BY n DESC LIMIT 50;

-- 2e. IS_FUNCTIONAL (outcome signal) ---------------------------------------
SELECT IS_FUNCTIONAL, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY IS_FUNCTIONAL ORDER BY n DESC;

-- 2f. CONFIDENCE_LEVEL domain (intent detection quality) -------------------
SELECT CONFIDENCE_LEVEL, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY CONFIDENCE_LEVEL ORDER BY n DESC;

-- 2g. FIRST_INTENT (entry-point intent) ------------------------------------
SELECT FIRST_INTENT, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY FIRST_INTENT ORDER BY n DESC LIMIT 100;

-- 2h. CUSTOMER_TYPE / SERVICE_STATUS context -------------------------------
SELECT CUSTOMER_TYPE, SERVICE_STATUS, COUNT(*) AS n
FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_kafka_tobi_sessions`
GROUP BY CUSTOMER_TYPE, SERVICE_STATUS ORDER BY n DESC LIMIT 50;
