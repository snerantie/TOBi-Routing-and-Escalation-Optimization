-- =============================================================================
-- models/02_ref_routing_classification.sql
-- Classifies every T_ routing destination using the TOBi tag grammar:
--
--   T_<n><Channel><RomanNumeral>_<ClientType>      e.g. T_1AII_CPOS
--     Channel       A = Livechat,  B = Call/ACD,  F = Service-change
--     RomanNumeral  I = Non-Technical, II = Technical, III = Commercial
--     ClientType    CPOS=Postpaid, CPRE=Prepaid, CFIXO=Fixed, CCOL=Collaborator,
--                   B=Business, C=Client, N=Non-client
--
-- The SUPPORT TYPE (Roman numeral) is what decides technical vs non-technical.
-- (The client-type suffix is NOT a queue type.)
--
-- Output view: vf-pt-copsvertex-live.tobi_routing_analysis.v_ref_queue_class
-- =============================================================================
CREATE OR REPLACE VIEW
  `vf-pt-copsvertex-live.tobi_routing_analysis.v_ref_queue_class`
AS
WITH distinct_targets AS (
  SELECT DISTINCT final_transfer_target AS routing_target
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`
  WHERE final_transfer_target IS NOT NULL
  UNION DISTINCT
  SELECT DISTINCT first_transfer_target
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`
  WHERE first_transfer_target IS NOT NULL
),
parsed AS (
  SELECT
    routing_target,
    REGEXP_EXTRACT(routing_target, r'_([A-Z]+)$')                       AS client_type,
    REGEXP_EXTRACT(REGEXP_EXTRACT(routing_target, r'^T_(.+)_[A-Z]+$'),
                   r'^[0-9]*([A-Z])')                                   AS channel_letter,
    REGEXP_EXTRACT(REGEXP_EXTRACT(routing_target, r'^T_(.+)_[A-Z]+$'),
                   r'([IVX]+)$')                                        AS roman
  FROM distinct_targets
)
SELECT
  routing_target,
  client_type,
  CASE channel_letter
    WHEN 'A' THEN 'livechat'
    WHEN 'B' THEN 'call_acd'
    WHEN 'F' THEN 'service_change'
    ELSE 'other'
  END AS channel_type,
  CASE roman
    WHEN 'II'  THEN 'technical'
    WHEN 'I'   THEN 'non_technical'
    WHEN 'III' THEN 'commercial'
    ELSE 'other_review'          -- e.g. 'VI' tags -> confirm meaning with business
  END AS support_type,
  -- queue_category drives the misrouting flags: technical issues should reach
  -- a technical (II) destination; I (non-technical) and III (commercial) are not.
  CASE
    WHEN roman = 'II'           THEN 'technical'
    WHEN roman IN ('I','III')   THEN 'non_technical'
    ELSE 'unclassified'
  END AS queue_category,
  CASE roman
    WHEN 'II'  THEN 'technical'
    WHEN 'I'   THEN 'non_technical'
    WHEN 'III' THEN 'commercial'
    ELSE 'other_review'
  END AS queue_subtype
FROM parsed;
