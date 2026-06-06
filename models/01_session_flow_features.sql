-- =============================================================================
-- models/01_session_flow_features.sql
-- Reconstructs the per-session conversation trail from f_tobi_logs_vertex
-- (one token per row) and extracts typed token arrays + the routing decision.
--
-- Output view: vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow
--   CONFIG: replace `tobi_routing_analysis` with a dataset you can write to.
-- =============================================================================
CREATE OR REPLACE VIEW
  `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`
AS
WITH tokens AS (
  SELECT
    SESSION_ID,
    ROW_ID,
    MOMENT,
    TRIM(LOG) AS token
  FROM `vf-pt-copsvertex-live.vfpt_dh_lake_cops_pub_investigation.f_tobi_logs_vertex`
  WHERE LOG IS NOT NULL AND TRIM(LOG) != ''
),
agg AS (
  SELECT
    SESSION_ID,
    COUNT(*)                                              AS n_tokens,
    MIN(MOMENT)                                           AS first_token_moment,
    MAX(MOMENT)                                           AS last_token_moment,
    STRING_AGG(token, ' > ' ORDER BY ROW_ID)              AS flow_trail,
    -- typed token arrays (preserve order)
    ARRAY_AGG(token ORDER BY ROW_ID)                      AS all_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'T_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS transfer_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'R_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS route_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'M_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS module_tokens,
    ARRAY_AGG(IF(STARTS_WITH(token,'S_'), token, NULL) IGNORE NULLS ORDER BY ROW_ID) AS state_tokens
  FROM tokens
  GROUP BY SESSION_ID
)
SELECT
  SESSION_ID,
  n_tokens,
  first_token_moment,
  last_token_moment,
  flow_trail,
  all_tokens,
  transfer_tokens,
  route_tokens,
  module_tokens,
  state_tokens,
  -- routing decision -------------------------------------------------------
  ARRAY_LENGTH(transfer_tokens)                          AS n_transfers,
  transfer_tokens[SAFE_OFFSET(0)]                        AS first_transfer_target,
  transfer_tokens[SAFE_OFFSET(ARRAY_LENGTH(transfer_tokens)-1)] AS final_transfer_target,
  ARRAY_LENGTH(transfer_tokens) > 0                      AS was_transferred,
  -- searchable lower-cased blob of routes + modules + free text for topic match
  LOWER(CONCAT(
    ARRAY_TO_STRING(route_tokens,  ' '), ' ',
    ARRAY_TO_STRING(module_tokens, ' ')
  ))                                                     AS topic_text
FROM agg;
