-- =====================================================================
-- Back2You - 02_alter_migrations.sql
-- Schema evolution applied on top of 01_schema.sql. Demonstrates ALTER
-- TABLE (ADD COLUMN / ADD CONSTRAINT / ADD KEY), CREATE INDEX and
-- DROP INDEX as a real migration step.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- 1) Track last login for the admin user list
ALTER TABLE users ADD COLUMN last_login_at DATETIME NULL AFTER created_at;

-- 2) Locations can be retired without deleting history
ALTER TABLE locations ADD COLUMN is_active TINYINT(1) NOT NULL DEFAULT 1;
ALTER TABLE locations ADD CONSTRAINT chk_locations_active CHECK (is_active IN (0, 1));

-- 3) Staff/admin lookups by role are frequent (fn_is_staff, custody picker)
ALTER TABLE users ADD KEY idx_users_role (role, is_active);

-- 4) Replace the narrow verification index by a covering one, then drop the old one
CREATE INDEX idx_va_claim_outcome ON verification_attempts (claim_id, outcome, attempted_at);
DROP INDEX idx_va_claim ON verification_attempts;

-- 5) Pending-claim scans by age (fraud rules, admin queue)
CREATE INDEX idx_claims_status_submitted ON claims (status, submitted_at);
