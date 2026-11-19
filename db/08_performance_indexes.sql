-- =====================================================================
-- Back2You - 08_performance_indexes.sql
-- Indexes added after profiling with EXPLAIN (see `npm run explain:demo`
-- and docs/EXPLAIN_RESULTS.md for the before/after plans).
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Admin audit viewer: "what did actor X change recently?" -> was a full scan of audit_log
CREATE INDEX idx_audit_actor_time ON audit_log (changed_by, changed_at);

-- Browse by date range without a status filter
CREATE INDEX idx_items_found_at ON items (found_at);
