-- =====================================================================
-- Back2You  |  01_schema.sql  |  DDL: CREATE TABLE (PK, FK, UNIQUE, CHECK)
-- Target: MySQL 8.0+ (also runs on MariaDB 10.5+)
-- =====================================================================
DROP DATABASE IF EXISTS back2you;
CREATE DATABASE back2you CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE back2you;

-- ---------- users -----------------------------------------------------
CREATE TABLE users (
  user_id        INT AUTO_INCREMENT PRIMARY KEY,
  full_name      VARCHAR(100) NOT NULL,
  email          VARCHAR(150) NOT NULL,
  phone          VARCHAR(20)  NULL,
  password_hash  VARCHAR(100) NOT NULL,
  role           ENUM('user','staff','admin') NOT NULL DEFAULT 'user',
  is_active      TINYINT(1)   NOT NULL DEFAULT 1,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT uq_users_email UNIQUE (email),
  CONSTRAINT ck_users_email CHECK (email LIKE '_%@_%._%'),
  CONSTRAINT ck_users_name  CHECK (CHAR_LENGTH(TRIM(full_name)) >= 2),
  CONSTRAINT ck_users_phone CHECK (phone IS NULL OR phone REGEXP '^[0-9+ -]{7,20}$')
) ENGINE=InnoDB;

-- ---------- categories ------------------------------------------------
CREATE TABLE categories (
  category_id  INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(60) NOT NULL,
  CONSTRAINT uq_categories_name UNIQUE (name)
) ENGINE=InnoDB;

-- ---------- locations -------------------------------------------------
CREATE TABLE locations (
  location_id  INT AUTO_INCREMENT PRIMARY KEY,
  name         VARCHAR(120) NOT NULL,
  loc_type     ENUM('cab','bus','college','hostel','office','metro','public') NOT NULL,
  city         VARCHAR(60)  NOT NULL,
  latitude     DECIMAL(9,6) NOT NULL,
  longitude    DECIMAL(9,6) NOT NULL,
  CONSTRAINT uq_locations_name_city UNIQUE (name, city),
  CONSTRAINT ck_locations_lat CHECK (latitude  BETWEEN -90  AND 90),
  CONSTRAINT ck_locations_lon CHECK (longitude BETWEEN -180 AND 180)
) ENGINE=InnoDB;

-- ---------- items (found items) --------------------------------------
-- status is the lifecycle: FOUND -> REGISTERED -> CLAIMED -> VERIFIED
--                          -> HANDED_OVER -> RETURNED   (enforced by triggers)
CREATE TABLE items (
  item_id                  INT AUTO_INCREMENT PRIMARY KEY,
  title                    VARCHAR(120) NOT NULL,
  description              TEXT         NOT NULL,
  category_id              INT          NOT NULL,
  color                    VARCHAR(30)  NULL,
  brand                    VARCHAR(60)  NULL,
  location_id              INT          NOT NULL,
  found_at                 DATETIME     NOT NULL,
  finder_id                INT          NOT NULL,
  current_holder_id        INT          NULL,
  -- the finder hides ONE identifying detail; only its hash is stored
  verification_question    VARCHAR(200) NOT NULL,
  verification_answer_hash CHAR(64)     NOT NULL,
  status                   ENUM('FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED')
                           NOT NULL DEFAULT 'FOUND',
  created_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at               DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  returned_at              DATETIME     NULL,
  CONSTRAINT fk_items_category FOREIGN KEY (category_id)       REFERENCES categories(category_id),
  CONSTRAINT fk_items_location FOREIGN KEY (location_id)       REFERENCES locations(location_id),
  CONSTRAINT fk_items_finder   FOREIGN KEY (finder_id)         REFERENCES users(user_id),
  CONSTRAINT fk_items_holder   FOREIGN KEY (current_holder_id) REFERENCES users(user_id),
  CONSTRAINT ck_items_title    CHECK (CHAR_LENGTH(TRIM(title)) >= 3),
  CONSTRAINT ck_items_desc     CHECK (CHAR_LENGTH(TRIM(description)) >= 10),
  CONSTRAINT ck_items_question CHECK (CHAR_LENGTH(TRIM(verification_question)) >= 5),
  CONSTRAINT ck_items_returned CHECK (returned_at IS NULL OR returned_at >= found_at),
  CONSTRAINT ck_items_ret_stat CHECK ((status = 'RETURNED') = (returned_at IS NOT NULL))
) ENGINE=InnoDB;

-- ---------- lost_reports (what owners are looking for) ---------------
CREATE TABLE lost_reports (
  report_id         INT AUTO_INCREMENT PRIMARY KEY,
  owner_id          INT          NOT NULL,
  title             VARCHAR(120) NOT NULL,
  description       TEXT         NOT NULL,
  category_id       INT          NOT NULL,
  color             VARCHAR(30)  NULL,
  brand             VARCHAR(60)  NULL,
  lost_location_id  INT          NOT NULL,
  lost_at           DATETIME     NOT NULL,
  status            ENUM('OPEN','MATCHED','CLOSED') NOT NULL DEFAULT 'OPEN',
  created_at        DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_lr_owner    FOREIGN KEY (owner_id)         REFERENCES users(user_id),
  CONSTRAINT fk_lr_category FOREIGN KEY (category_id)      REFERENCES categories(category_id),
  CONSTRAINT fk_lr_location FOREIGN KEY (lost_location_id) REFERENCES locations(location_id),
  CONSTRAINT ck_lr_title    CHECK (CHAR_LENGTH(TRIM(title)) >= 3),
  CONSTRAINT ck_lr_desc     CHECK (CHAR_LENGTH(TRIM(description)) >= 10)
) ENGINE=InnoDB;

-- ---------- claims ----------------------------------------------------
CREATE TABLE claims (
  claim_id        INT AUTO_INCREMENT PRIMARY KEY,
  item_id         INT NOT NULL,
  claimant_id     INT NOT NULL,
  report_id       INT NULL,
  description     TEXT NOT NULL,
  answer_match    TINYINT(1)   NOT NULL DEFAULT 0,
  match_score     DECIMAL(5,4) NULL,
  status          ENUM('PENDING','VERIFIED','REJECTED','WITHDRAWN') NOT NULL DEFAULT 'PENDING',
  reviewed_by     INT NULL,
  review_notes    VARCHAR(255) NULL,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  reviewed_at     DATETIME NULL,
  -- at most ONE verified claim per item (NULL is ignored by UNIQUE)
  verified_flag   TINYINT GENERATED ALWAYS AS (IF(status = 'VERIFIED', 1, NULL)) VIRTUAL,
  CONSTRAINT fk_claims_item     FOREIGN KEY (item_id)     REFERENCES items(item_id) ON DELETE CASCADE,
  CONSTRAINT fk_claims_claimant FOREIGN KEY (claimant_id) REFERENCES users(user_id),
  CONSTRAINT fk_claims_report   FOREIGN KEY (report_id)   REFERENCES lost_reports(report_id),
  CONSTRAINT fk_claims_reviewer FOREIGN KEY (reviewed_by) REFERENCES users(user_id),
  CONSTRAINT uq_claims_item_claimant UNIQUE (item_id, claimant_id),
  CONSTRAINT uq_claims_one_verified  UNIQUE (item_id, verified_flag),
  CONSTRAINT ck_claims_desc  CHECK (CHAR_LENGTH(TRIM(description)) >= 10),
  CONSTRAINT ck_claims_score CHECK (match_score IS NULL OR match_score BETWEEN 0 AND 1),
  CONSTRAINT ck_claims_review CHECK (status = 'PENDING' OR reviewed_at IS NOT NULL OR status = 'WITHDRAWN')
) ENGINE=InnoDB;

-- ---------- custody_log (chain of custody) ---------------------------
CREATE TABLE custody_log (
  custody_id     INT AUTO_INCREMENT PRIMARY KEY,
  item_id        INT NOT NULL,
  holder_id      INT NOT NULL,
  received_from  INT NULL,
  event          ENUM('FOUND_BY_FINDER','ACCEPTED_BY_STAFF','TRANSFERRED','HANDED_TO_OWNER') NOT NULL,
  start_at       DATETIME NOT NULL,
  end_at         DATETIME NULL,
  note           VARCHAR(255) NULL,
  -- exactly ONE open custody row per item (NULL end_at => active)
  active_flag    TINYINT GENERATED ALWAYS AS (IF(end_at IS NULL, 1, NULL)) VIRTUAL,
  CONSTRAINT fk_cust_item   FOREIGN KEY (item_id)       REFERENCES items(item_id) ON DELETE CASCADE,
  CONSTRAINT fk_cust_holder FOREIGN KEY (holder_id)     REFERENCES users(user_id),
  CONSTRAINT fk_cust_from   FOREIGN KEY (received_from) REFERENCES users(user_id),
  CONSTRAINT uq_cust_one_active UNIQUE (item_id, active_flag),
  CONSTRAINT ck_cust_dates CHECK (end_at IS NULL OR end_at >= start_at)
) ENGINE=InnoDB;

-- ---------- handovers (immutable proof of release) -------------------
CREATE TABLE handovers (
  handover_id  INT AUTO_INCREMENT PRIMARY KEY,
  item_id      INT NOT NULL,
  claim_id     INT NOT NULL,
  given_by     INT NOT NULL,
  received_by  INT NOT NULL,
  handed_at    DATETIME NOT NULL,
  proof_type   ENUM('ID_CARD','OTP','SIGNATURE','PHOTO') NOT NULL,
  proof_ref    VARCHAR(200) NOT NULL,
  notes        VARCHAR(255) NULL,
  CONSTRAINT fk_ho_item     FOREIGN KEY (item_id)     REFERENCES items(item_id),
  CONSTRAINT fk_ho_claim    FOREIGN KEY (claim_id)    REFERENCES claims(claim_id),
  CONSTRAINT fk_ho_giver    FOREIGN KEY (given_by)    REFERENCES users(user_id),
  CONSTRAINT fk_ho_receiver FOREIGN KEY (received_by) REFERENCES users(user_id),
  CONSTRAINT uq_ho_item  UNIQUE (item_id),
  CONSTRAINT uq_ho_claim UNIQUE (claim_id),
  CONSTRAINT ck_ho_parties CHECK (given_by <> received_by),
  CONSTRAINT ck_ho_proof   CHECK (CHAR_LENGTH(TRIM(proof_ref)) >= 3)
) ENGINE=InnoDB;

-- ---------- verification_attempts ------------------------------------
CREATE TABLE verification_attempts (
  attempt_id        INT AUTO_INCREMENT PRIMARY KEY,
  claim_id          INT NOT NULL,
  claimant_id       INT NOT NULL,
  submitted_answer  VARCHAR(200) NOT NULL,
  is_correct        TINYINT(1) NOT NULL,
  attempted_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_va_claim    FOREIGN KEY (claim_id)    REFERENCES claims(claim_id) ON DELETE CASCADE,
  CONSTRAINT fk_va_claimant FOREIGN KEY (claimant_id) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- ---------- fraud_flags ----------------------------------------------
CREATE TABLE fraud_flags (
  flag_id      INT AUTO_INCREMENT PRIMARY KEY,
  user_id      INT NOT NULL,
  item_id      INT NULL,
  flag_type    ENUM('MANY_CLAIMS','MULTIPLE_CLAIMANTS','REPEATED_WRONG_ANSWER') NOT NULL,
  details      VARCHAR(255) NULL,
  status       ENUM('OPEN','DISMISSED','CONFIRMED') NOT NULL DEFAULT 'OPEN',
  created_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  resolved_by  INT NULL,
  resolved_at  DATETIME NULL,
  CONSTRAINT fk_ff_user     FOREIGN KEY (user_id)     REFERENCES users(user_id),
  CONSTRAINT fk_ff_item     FOREIGN KEY (item_id)     REFERENCES items(item_id) ON DELETE CASCADE,
  CONSTRAINT fk_ff_resolver FOREIGN KEY (resolved_by) REFERENCES users(user_id)
) ENGINE=InnoDB;

-- ---------- audit_log (append-only, hash-chained) --------------------
CREATE TABLE audit_log (
  audit_id    BIGINT AUTO_INCREMENT PRIMARY KEY,
  table_name  VARCHAR(40) NOT NULL,
  record_id   BIGINT      NOT NULL,
  action      ENUM('INSERT','UPDATE','DELETE') NOT NULL,
  old_values  LONGTEXT    NULL,
  new_values  LONGTEXT    NULL,
  changed_by  INT         NULL,
  changed_at  DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  prev_hash   CHAR(64)    NOT NULL DEFAULT '',
  row_hash    CHAR(64)    NOT NULL DEFAULT '',
  CONSTRAINT ck_audit_old CHECK (old_values IS NULL OR JSON_VALID(old_values)),
  CONSTRAINT ck_audit_new CHECK (new_values IS NULL OR JSON_VALID(new_values))
) ENGINE=InnoDB;

-- single row holding the tail of the audit hash chain (serialises appends safely)
CREATE TABLE audit_chain_head (
  id         TINYINT PRIMARY KEY,
  last_hash  CHAR(64) NOT NULL,
  CONSTRAINT ck_ach_id CHECK (id = 1)
) ENGINE=InnoDB;
INSERT INTO audit_chain_head (id, last_hash) VALUES (1, REPEAT('0', 64));
