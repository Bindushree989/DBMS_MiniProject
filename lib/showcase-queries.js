// Named, read-only queries shown on /admin/queries (JOIN, GROUP BY/HAVING, subqueries, windows, FULLTEXT, views).
// Executed by id only - the API never runs user-supplied SQL.
module.exports = [
  { id: 'join5', concept: 'JOIN (6 tables)', title: 'Latest handovers with full context',
    sql: `SELECT h.handover_id, i.title, c.name AS category, l.name AS location,
       g.full_name AS given_by, r.full_name AS received_by, h.proof_type, h.handed_at
  FROM handovers h
  JOIN items i ON i.item_id = h.item_id
  JOIN categories c ON c.category_id = i.category_id
  JOIN locations l ON l.location_id = i.location_id
  JOIN users g ON g.user_id = h.given_by
  JOIN users r ON r.user_id = h.received_by
 ORDER BY h.handed_at DESC LIMIT 10` },
  { id: 'hotspots', concept: 'GROUP BY + HAVING', title: 'Locations with low return rates (>= 8 items, < 45% returned)',
    sql: `SELECT l.name AS location, l.loc_type, COUNT(*) AS items_found,
       SUM(i.status = 'RETURNED') AS returned,
       ROUND(100 * SUM(i.status = 'RETURNED') / COUNT(*), 1) AS return_rate_pct
  FROM items i JOIN locations l ON l.location_id = i.location_id
 GROUP BY l.location_id, l.name, l.loc_type
HAVING COUNT(*) >= 8 AND SUM(i.status = 'RETURNED') / COUNT(*) < 0.45
 ORDER BY return_rate_pct ASC` },
  { id: 'subq_avg', concept: 'Subquery (scalar, in HAVING)', title: 'Items attracting more claims than the average item',
    sql: `SELECT i.item_id, i.title, COUNT(c.claim_id) AS claims
  FROM items i JOIN claims c ON c.item_id = i.item_id
 GROUP BY i.item_id, i.title
HAVING COUNT(c.claim_id) > (SELECT COUNT(*) / COUNT(DISTINCT item_id) FROM claims)
 ORDER BY claims DESC, i.item_id LIMIT 15` },
  { id: 'subq_exists', concept: 'Subquery (correlated EXISTS)', title: 'Good Samaritans: finders whose items were actually returned',
    sql: `SELECT u.full_name, COUNT(*) AS items_returned
  FROM users u JOIN items i ON i.finder_id = u.user_id
 WHERE EXISTS (SELECT 1 FROM handovers h WHERE h.item_id = i.item_id)
 GROUP BY u.user_id, u.full_name
 ORDER BY items_returned DESC, u.full_name LIMIT 10` },
  { id: 'window', concept: 'Window function', title: 'Cumulative returns per month',
    sql: `SELECT month, found, returned,
       SUM(returned) OVER (ORDER BY month) AS cumulative_returned
  FROM v_monthly_returns ORDER BY month` },
  { id: 'agg_cat', concept: 'Aggregates + JOIN', title: 'Average hours from found to returned, per category',
    sql: `SELECT c.name AS category, c.is_high_value, COUNT(*) AS returned_items,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, i.found_at, i.returned_at)), 1) AS avg_hours,
       MAX(TIMESTAMPDIFF(HOUR, i.found_at, i.returned_at)) AS max_hours
  FROM items i JOIN categories c ON c.category_id = i.category_id
 WHERE i.status = 'RETURNED'
 GROUP BY c.category_id, c.name, c.is_high_value
 ORDER BY avg_hours` },
  { id: 'fulltext', concept: 'FULLTEXT search', title: 'MATCH ... AGAINST: "black leather wallet"',
    sql: `SELECT item_id, title, status,
       ROUND(MATCH(title, description) AGAINST ('black leather wallet' IN NATURAL LANGUAGE MODE), 3) AS relevance
  FROM items
 WHERE MATCH(title, description) AGAINST ('black leather wallet' IN NATURAL LANGUAGE MODE)
 ORDER BY relevance DESC LIMIT 10` },
  { id: 'custody_len', concept: 'GROUP BY + HAVING on chain of custody', title: 'Items that changed hands 4+ times',
    sql: `SELECT i.item_id, i.title, i.status, COUNT(*) AS custody_steps
  FROM custody_log cl JOIN items i ON i.item_id = cl.item_id
 GROUP BY i.item_id, i.title, i.status
HAVING COUNT(*) >= 4
 ORDER BY custody_steps DESC, i.item_id LIMIT 10` },
  { id: 'audit_mix', concept: 'Audit trail analysis', title: 'Audit activity by table and action',
    sql: `SELECT table_name, action, COUNT(*) AS events, MIN(changed_at) AS first_event, MAX(changed_at) AS last_event
  FROM audit_log GROUP BY table_name, action ORDER BY table_name, action` },
  { id: 'view_unclaimed', concept: 'View', title: 'v_unclaimed_by_location (items waiting > 7 days)',
    sql: `SELECT * FROM v_unclaimed_by_location ORDER BY unclaimed_items DESC LIMIT 10` },
  { id: 'slow_claim', concept: 'Self-join / CASE', title: 'Fastest verified claims (claim -> review hours)',
    sql: `SELECT c.claim_id, i.title, u.full_name AS claimant, s.full_name AS verified_by,
       TIMESTAMPDIFF(MINUTE, c.created_at, c.reviewed_at) AS minutes_to_verify,
       CASE WHEN c.match_score IS NULL THEN 'n/a' WHEN c.match_score >= 0.8 THEN 'strong' ELSE 'weak' END AS match_quality
  FROM claims c JOIN items i ON i.item_id = c.item_id
  JOIN users u ON u.user_id = c.claimant_id JOIN users s ON s.user_id = c.reviewed_by
 WHERE c.status = 'VERIFIED' ORDER BY minutes_to_verify ASC LIMIT 10` },
];
