-- =====================================================================
-- Back2You - important queries (run them all with `npm run demo:queries`)
-- Each block starts with "-- @title" so the runner can label the output.
-- =====================================================================

-- @title Q1  JOIN (5 tables): items currently in staff custody, oldest first
SELECT i.item_id, i.title, c.name AS category, l.name AS found_at_location,
       u.full_name AS custodian, cl.storage_place, cl.started_at AS in_custody_since
  FROM items i
  JOIN categories  c  ON c.category_id  = i.category_id
  JOIN locations   l  ON l.location_id  = i.found_location_id
  JOIN custody_log cl ON cl.item_id = i.item_id AND cl.ended_at IS NULL
  JOIN users       u  ON u.user_id = cl.holder_id
 WHERE i.status IN ('REGISTERED', 'CLAIMED')
 ORDER BY cl.started_at
 LIMIT 10;

-- @title Q2  GROUP BY + aggregates + ORDER BY: return rate and speed per category (view v_category_stats)
SELECT category, total_items, returned_items, return_rate_pct, avg_hours_to_return
  FROM v_category_stats
 ORDER BY total_items DESC;

-- @title Q3  GROUP BY + HAVING: locations with at least 25 reports, ranked by return rate
SELECT l.name AS location, l.location_type, COUNT(*) AS items_found,
       SUM(i.status = 'RETURNED') AS returned,
       ROUND(100 * SUM(i.status = 'RETURNED') / COUNT(*), 1) AS return_rate_pct
  FROM items i
  JOIN locations l ON l.location_id = i.found_location_id
 GROUP BY l.location_id, l.name, l.location_type
HAVING COUNT(*) >= 25
 ORDER BY return_rate_pct DESC;

-- @title Q4  GROUP BY + HAVING: suspicious claimants (3+ claims, at least half of them rejected)
SELECT u.user_id, u.full_name, COUNT(*) AS claims,
       SUM(c.status = 'REJECTED') AS rejected, SUM(c.failed_attempts) AS failed_checks
  FROM claims c
  JOIN users u ON u.user_id = c.claimant_id
 GROUP BY u.user_id, u.full_name
HAVING COUNT(*) >= 3 AND SUM(c.status = 'REJECTED') / COUNT(*) >= 0.5
 ORDER BY rejected DESC, failed_checks DESC;

-- @title Q5  Subquery (scalar): REGISTERED items waiting longer than the average time-to-return
SELECT i.item_id, i.title, i.registered_at,
       ROUND(TIMESTAMPDIFF(HOUR, i.registered_at, NOW()) / 24, 1) AS days_waiting
  FROM items i
 WHERE i.status = 'REGISTERED'
   AND TIMESTAMPDIFF(HOUR, i.registered_at, NOW()) >
       (SELECT AVG(TIMESTAMPDIFF(HOUR, f.registered_at, f.returned_at)) FROM items f WHERE f.status = 'RETURNED')
 ORDER BY days_waiting DESC
 LIMIT 10;

-- @title Q6  Correlated subquery: items with competing claimants (more than one pending claim)
SELECT i.item_id, i.title, i.status,
       (SELECT COUNT(*) FROM claims c WHERE c.item_id = i.item_id AND c.status = 'PENDING') AS pending_claims
  FROM items i
 WHERE (SELECT COUNT(*) FROM claims c WHERE c.item_id = i.item_id AND c.status = 'PENDING') > 1
 ORDER BY pending_claims DESC, i.item_id
 LIMIT 10;

-- @title Q7  NOT EXISTS: registered items that have never received a claim (longest-waiting first)
SELECT i.item_id, i.title, i.registered_at, ROUND(TIMESTAMPDIFF(HOUR, i.registered_at, NOW()) / 24, 1) AS days_on_shelf
  FROM items i
 WHERE i.status = 'REGISTERED'
   AND NOT EXISTS (SELECT 1 FROM claims c WHERE c.item_id = i.item_id)
 ORDER BY i.registered_at
 LIMIT 10;

-- @title Q8  CTE + window function: monthly returns with a running total
WITH monthly AS (
  SELECT DATE_FORMAT(returned_at, '%Y-%m') AS month, COUNT(*) AS returned
    FROM items WHERE returned_at IS NOT NULL GROUP BY DATE_FORMAT(returned_at, '%Y-%m'))
SELECT month, returned, SUM(returned) OVER (ORDER BY month) AS running_total
  FROM monthly ORDER BY month;

-- @title Q9  View + subquery: the full custody chain of an item that changed hands 3+ times
SELECT event_time, event_type, actor, detail
  FROM v_item_timeline
 WHERE item_id = (SELECT item_id FROM handovers GROUP BY item_id HAVING COUNT(*) >= 3 ORDER BY item_id LIMIT 1)
 ORDER BY event_time, FIELD(event_type, 'REPORTED', 'CUSTODY', 'CLAIM_SUBMITTED', 'VERIFICATION', 'HANDOVER', 'RETURNED');

-- @title Q10 FULLTEXT search (relevance ranked)
SELECT item_id, title, status,
       ROUND(MATCH(title, description) AGAINST ('black wallet cards' IN NATURAL LANGUAGE MODE), 3) AS relevance
  FROM items
 WHERE MATCH(title, description) AGAINST ('black wallet cards' IN NATURAL LANGUAGE MODE)
 ORDER BY relevance DESC
 LIMIT 5;

-- @title Q11 Audit trail: every recorded change of one returned item
SELECT audit_id, table_name, action, old_values, new_values, changed_by, changed_at
  FROM audit_log
 WHERE table_name = 'items'
   AND record_id = (SELECT CAST(MIN(item_id) AS CHAR) FROM items WHERE status = 'RETURNED')
 ORDER BY audit_id;

-- @title Q12 Admin KPI view
SELECT * FROM v_admin_kpis;

-- @title Q13 Stored function: structured match score of every open item for a sample lost phone (attributes only)
SELECT i.item_id, i.title, fn_structured_score(i.item_id,
         (SELECT category_id FROM categories WHERE name = 'Phone'), 'black', NULL, i.found_location_id, NOW() - INTERVAL 1 DAY) AS structured_score
  FROM items i
 WHERE i.status IN ('REGISTERED', 'CLAIMED')
 ORDER BY structured_score DESC, i.item_id
 LIMIT 5;
