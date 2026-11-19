-- =====================================================================
-- Back2You | 06_indexes.sql | Secondary + FULLTEXT indexes
-- (see 09_explain_demo.sql for before/after EXPLAIN evidence)
-- =====================================================================
USE back2you;
-- browse/filter: "open items in a category, newest first"
CREATE INDEX idx_items_status_cat_found ON items (status, category_id, found_at);
-- staff queue by location
CREATE INDEX idx_items_location_status  ON items (location_id, status);
-- custodian workload
CREATE INDEX idx_items_holder           ON items (current_holder_id, status);
-- semantic-ish keyword search on free text
ALTER TABLE items ADD FULLTEXT INDEX ft_items_text (title, description);
-- review queue / fraud heuristics (claims in last 24h by user)
CREATE INDEX idx_claims_status_created  ON claims (status, created_at);
CREATE INDEX idx_claims_claimant_time   ON claims (claimant_id, created_at);
CREATE INDEX idx_custody_item_start     ON custody_log (item_id, start_at);
CREATE INDEX idx_attempts_user_time     ON verification_attempts (claimant_id, is_correct, attempted_at);
CREATE INDEX idx_flags_status           ON fraud_flags (status, flag_type);
CREATE INDEX idx_audit_record           ON audit_log (table_name, record_id);
CREATE INDEX idx_audit_changed_at       ON audit_log (changed_at);
CREATE INDEX idx_lr_owner               ON lost_reports (owner_id, status);
