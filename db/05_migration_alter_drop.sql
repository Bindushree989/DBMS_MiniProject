-- =====================================================================
-- Back2You | 05_migration_alter_drop.sql | ALTER / DROP demonstrations
-- A real schema migration (adds business columns) plus a scratch-table
-- exercise of ALTER ... ADD/MODIFY/DROP COLUMN and DROP TABLE.
-- =====================================================================
USE back2you;

-- Real migration: high-value categories need staff-secured custody
ALTER TABLE categories
  ADD COLUMN is_high_value TINYINT(1) NOT NULL DEFAULT 0 AFTER name;

-- Real migration: which drop-off points have a staffed desk
ALTER TABLE locations
  ADD COLUMN is_staffed TINYINT(1) NOT NULL DEFAULT 0;

-- Scratch table: shows CREATE / ALTER (ADD, MODIFY, DROP COLUMN, ADD CONSTRAINT) / DROP
DROP TABLE IF EXISTS tmp_scratch;
CREATE TABLE tmp_scratch (id INT PRIMARY KEY, note VARCHAR(20));
ALTER TABLE tmp_scratch ADD COLUMN priority TINYINT NOT NULL DEFAULT 1;
ALTER TABLE tmp_scratch MODIFY COLUMN note VARCHAR(100) NOT NULL;
ALTER TABLE tmp_scratch ADD CONSTRAINT ck_tmp_priority CHECK (priority BETWEEN 1 AND 5);
ALTER TABLE tmp_scratch DROP COLUMN priority;
DROP TABLE tmp_scratch;
