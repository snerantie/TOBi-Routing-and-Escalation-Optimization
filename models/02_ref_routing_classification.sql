-- =============================================================================
-- models/02_ref_routing_classification.sql
-- Classifies every T_ routing destination as technical / non_technical /
-- unclassified. Two layers:
--   1) explicit_overrides  -> hand-curated, authoritative (EDIT THIS from p3a)
--   2) keyword rules        -> fallback for anything not in overrides
--
-- Output view: vf-pt-copsvertex-live.tobi_routing_analysis.v_ref_queue_class
--
-- TODO(validate): run profiling/p3a (T_ list) and move each real destination
-- into explicit_overrides with the correct category.
-- =============================================================================
CREATE OR REPLACE VIEW
  `vf-pt-copsvertex-live.tobi_routing_analysis.v_ref_queue_class`
AS
WITH
-- 1) Authoritative, hand-curated mapping. Seeded with the one known example. --
explicit_overrides AS (
  SELECT * FROM UNNEST([
    STRUCT('T_1All_CPOS' AS routing_target,
           'non_technical' AS queue_category,
           'sales_commercial' AS queue_subtype)
    -- , STRUCT('T_xxxxx', 'technical',     'tech_support')
    -- , STRUCT('T_xxxxx', 'non_technical', 'billing')
    -- , STRUCT('T_xxxxx', 'non_technical', 'retention')
  ])
),
-- 2) Keyword fallback rules (Portuguese + English stems). PROVISIONAL. --------
--    technical stems: suporte/apoio tecnico, avaria, tecnico, reparacao, banda larga
--    non-technical:   cpos, vendas, comercial, adesao, fidelizacao, retencao, faturacao
distinct_targets AS (
  SELECT DISTINCT final_transfer_target AS routing_target
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`
  WHERE final_transfer_target IS NOT NULL
  UNION DISTINCT
  SELECT DISTINCT first_transfer_target
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_flow`
  WHERE first_transfer_target IS NOT NULL
),
keyword_rules AS (
  SELECT
    routing_target,
    CASE
      WHEN REGEXP_CONTAINS(LOWER(routing_target),
             r'(tecnic|tecn|avaria|repara|suporte|apoio.?tec|banda.?larga|tech|support|fault|fibra|internet|rede|network)')
        THEN 'technical'
      WHEN REGEXP_CONTAINS(LOWER(routing_target),
             r'(cpos|vend|comerc|adesa|adesao|fideliz|retenc|retention|sales|billing|fatur|cobranc|loja|store|upgrade)')
        THEN 'non_technical'
      ELSE 'unclassified'
    END AS queue_category,
    'keyword_rule' AS queue_subtype
  FROM distinct_targets
)
SELECT
  d.routing_target,
  COALESCE(o.queue_category, k.queue_category, 'unclassified') AS queue_category,
  COALESCE(o.queue_subtype,  k.queue_subtype,  'keyword_rule') AS queue_subtype,
  o.routing_target IS NOT NULL                                 AS is_override
FROM distinct_targets d
LEFT JOIN explicit_overrides o USING (routing_target)
LEFT JOIN keyword_rules     k USING (routing_target);
