-- =============================================================================
-- SUPPORTING ANALYSIS D6: Repeat-contact & session-chain analysis
-- Measures the downstream cost of misrouting: do customers come back, and is
-- the follow-on contact eventually resolved?
-- Depends on view models/04.
-- =============================================================================

-- 6a. One-hop continuation outcome via NEXT_SESSION_ID ----------------------
-- For each (technical) session that has a continuation, look at what the
-- continuation looked like.
SELECT
  a.technical_topic_type,
  a.is_hard_misroute,
  COUNT(*)                                             AS sessions_with_continuation,
  COUNTIF(b.is_functional_flag)                        AS continuation_resolved,
  ROUND(COUNTIF(b.is_functional_flag)/COUNT(*)*100, 2) AS pct_continuation_resolved,
  ROUND(AVG(b.duration_seconds), 1)                    AS avg_continuation_duration_s,
  COUNTIF(b.was_transferred)                           AS continuation_also_transferred
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master` a
JOIN `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master` b
  ON a.NEXT_SESSION_ID = b.SESSION_ID
WHERE a.is_technical_topic
GROUP BY a.technical_topic_type, a.is_hard_misroute
ORDER BY sessions_with_continuation DESC;

-- 6b. Contacts per customer (ANI) per day -----------------------------------
-- High repeat counts on technical topics = unresolved routing.
WITH per_ani_day AS (
  SELECT
    ANI,
    DATE(START_MOMENT)                       AS day,
    COUNT(*)                                 AS contacts,
    COUNTIF(is_technical_topic)              AS technical_contacts,
    COUNTIF(is_hard_misroute)                AS misrouted_contacts
  FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
  WHERE ANI IS NOT NULL AND ANI != ''
  GROUP BY ANI, day
)
SELECT
  contacts                                   AS contacts_per_customer_day,
  COUNT(*)                                   AS n_customer_days,
  SUM(technical_contacts)                    AS technical_contacts,
  SUM(misrouted_contacts)                    AS misrouted_contacts
FROM per_ani_day
GROUP BY contacts
ORDER BY contacts;

-- 6c. Repeat rate: misrouted vs correctly-routed technical ------------------
SELECT
  CASE WHEN is_hard_misroute THEN 'misrouted'
       WHEN is_correct_technical_route THEN 'correct'
       ELSE 'other_technical' END            AS cohort,
  COUNT(*)                                   AS sessions,
  COUNTIF(repeat_contact_24h)                AS repeat_24h,
  ROUND(COUNTIF(repeat_contact_24h)/COUNT(*)*100, 2) AS pct_repeat_24h,
  COUNTIF(has_next_session)                  AS with_next_session,
  ROUND(COUNTIF(has_next_session)/COUNT(*)*100, 2)   AS pct_with_next_session
FROM `vf-pt-copsvertex-live.tobi_routing_analysis.v_session_master`
WHERE is_technical_topic
GROUP BY cohort
ORDER BY sessions DESC;
