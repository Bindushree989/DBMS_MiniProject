-- =====================================================================
-- Back2You | 07_views.sql | Reporting views
-- =====================================================================
USE back2you;
DROP VIEW IF EXISTS v_item_public;
DROP VIEW IF EXISTS v_item_timeline;
DROP VIEW IF EXISTS v_admin_kpis;
DROP VIEW IF EXISTS v_unclaimed_by_location;
DROP VIEW IF EXISTS v_suspicious_users;
DROP VIEW IF EXISTS v_monthly_returns;
DROP VIEW IF EXISTS v_staff_workload;

-- Public projection: never exposes the verification answer hash
CREATE VIEW v_item_public AS
SELECT i.item_id, i.title, i.description, i.color, i.brand, i.status, i.found_at, i.created_at,
       i.verification_question, i.category_id, c.name AS category, c.is_high_value,
       i.location_id, l.name AS location, l.loc_type, l.city,
       i.finder_id, f.full_name AS finder_name,
       i.current_holder_id, h.full_name AS holder_name, i.returned_at
  FROM items i
  JOIN categories c ON c.category_id = i.category_id
  JOIN locations  l ON l.location_id = i.location_id
  JOIN users      f ON f.user_id = i.finder_id
  LEFT JOIN users h ON h.user_id = i.current_holder_id;

-- One chronological timeline per item built from four source tables
CREATE VIEW v_item_timeline AS
SELECT cl.item_id, cl.start_at AS event_time, cl.event AS event_type, u.full_name AS actor,
       CONCAT('Custody -> ', u.full_name, IFNULL(CONCAT(' (from ', f.full_name, ')'), ''),
              IFNULL(CONCAT(' | ', cl.note), '')) AS detail
  FROM custody_log cl
  JOIN users u ON u.user_id = cl.holder_id
  LEFT JOIN users f ON f.user_id = cl.received_from
UNION ALL
SELECT c.item_id, c.created_at, 'CLAIM_SUBMITTED', u.full_name,
       CONCAT('Claim #', c.claim_id, IF(c.answer_match = 1, ' (hidden-detail answer correct)', ' (answer not matched)'))
  FROM claims c JOIN users u ON u.user_id = c.claimant_id
UNION ALL
SELECT c.item_id, c.reviewed_at, CONCAT('CLAIM_', c.status), u.full_name,
       CONCAT('Claim #', c.claim_id, IFNULL(CONCAT(' | ', c.review_notes), ''))
  FROM claims c JOIN users u ON u.user_id = c.reviewed_by
 WHERE c.status IN ('VERIFIED','REJECTED')
UNION ALL
SELECT h.item_id, h.handed_at, 'HANDOVER', g.full_name,
       CONCAT(g.full_name, ' gave to ', r.full_name, ' | proof ', h.proof_type, ': ', h.proof_ref)
  FROM handovers h JOIN users g ON g.user_id = h.given_by JOIN users r ON r.user_id = h.received_by
UNION ALL
SELECT i.item_id, i.returned_at, 'RETURNED', NULL, 'Owner confirmed receipt'
  FROM items i WHERE i.returned_at IS NOT NULL;

-- Single-row KPI view for the admin dashboard
CREATE VIEW v_admin_kpis AS
SELECT COUNT(*)                                                         AS total_items,
       SUM(status = 'RETURNED')                                         AS returned_items,
       ROUND(100 * SUM(status = 'RETURNED') / COUNT(*), 1)              AS return_rate_pct,
       ROUND(AVG(CASE WHEN status = 'RETURNED'
                      THEN TIMESTAMPDIFF(HOUR, found_at, returned_at) END), 1) AS avg_hours_to_return,
       SUM(status IN ('REGISTERED','CLAIMED'))                          AS open_items,
       (SELECT COUNT(*) FROM claims WHERE status = 'PENDING')           AS pending_claims,
       (SELECT COUNT(*) FROM fraud_flags WHERE status = 'OPEN')         AS open_flags
  FROM items;

-- Items sitting at a location with no claim for > 7 days (business clock aware)
CREATE VIEW v_unclaimed_by_location AS
SELECT l.location_id, l.name AS location, l.loc_type, COUNT(*) AS unclaimed_items,
       MIN(i.found_at) AS oldest_found_at,
       ROUND(AVG(TIMESTAMPDIFF(DAY, i.found_at, fn_now())), 1) AS avg_age_days
  FROM items i JOIN locations l ON l.location_id = i.location_id
 WHERE i.status = 'REGISTERED' AND i.found_at < DATE_SUB(fn_now(), INTERVAL 7 DAY)
 GROUP BY l.location_id, l.name, l.loc_type
HAVING COUNT(*) >= 1;

-- Users worth an admin's attention
CREATE VIEW v_suspicious_users AS
SELECT u.user_id, u.full_name, u.email,
       COUNT(DISTINCT ff.flag_id)                       AS flags,
       SUM(ff.status = 'OPEN')                          AS open_flags,
       (SELECT COUNT(*) FROM claims c WHERE c.claimant_id = u.user_id) AS total_claims,
       (SELECT COUNT(*) FROM verification_attempts v
         WHERE v.claimant_id = u.user_id AND v.is_correct = 0)          AS wrong_answers
  FROM users u JOIN fraud_flags ff ON ff.user_id = u.user_id
 GROUP BY u.user_id, u.full_name, u.email
HAVING COUNT(DISTINCT ff.flag_id) >= 1;

CREATE VIEW v_monthly_returns AS
SELECT DATE_FORMAT(found_at, '%Y-%m') AS month,
       COUNT(*)                        AS found,
       SUM(status = 'RETURNED')        AS returned
  FROM items
 GROUP BY DATE_FORMAT(found_at, '%Y-%m');

CREATE VIEW v_staff_workload AS
SELECT u.user_id, u.full_name, u.role,
       SUM(i.status IN ('REGISTERED','CLAIMED','VERIFIED')) AS items_in_custody,
       SUM(i.status = 'VERIFIED')                          AS awaiting_handover
  FROM users u LEFT JOIN items i ON i.current_holder_id = u.user_id
 WHERE u.role IN ('staff','admin')
 GROUP BY u.user_id, u.full_name, u.role;
