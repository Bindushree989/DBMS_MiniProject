-- =====================================================================
-- Back2You  |  03_triggers.sql
--  A. Lifecycle state machine + business rules  (BEFORE triggers)
--  B. Fraud heuristics                          (AFTER triggers)
--  C. Audit trail, append-only + hash chained   (AFTER triggers)
-- Error codes are embedded in messages as B2Y-Exxx so tests can assert them.
-- =====================================================================
USE back2you;
DELIMITER $$

-- =====================================================================
-- A. ITEMS: state machine
-- =====================================================================
CREATE TRIGGER trg_items_bi BEFORE INSERT ON items FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  IF NEW.status <> 'FOUND' THEN
    SET msg = 'B2Y-E001: a new item must start in status FOUND';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.found_at > DATE_ADD(fn_now(), INTERVAL 5 MINUTE) THEN
    SET msg = 'B2Y-E002: found_at cannot be in the future';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF fn_role(NEW.finder_id) IS NULL THEN
    SET msg = 'B2Y-E003: finder is not an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  SET NEW.created_at = fn_now();
  SET NEW.updated_at = fn_now();
END$$

CREATE TRIGGER trg_items_bu BEFORE UPDATE ON items FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  DECLARE legal TINYINT DEFAULT 0;

  IF OLD.status = 'RETURNED' THEN
    SET msg = 'B2Y-E010: item is RETURNED and locked against any change';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;

  IF NOT (NEW.finder_id <=> OLD.finder_id) OR NOT (NEW.found_at <=> OLD.found_at)
     OR NOT (NEW.verification_answer_hash <=> OLD.verification_answer_hash) THEN
    SET msg = 'B2Y-E011: finder, found_at and verification answer are immutable';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;

  IF NEW.status <> OLD.status THEN
    -- ---- allowed edges of the lifecycle graph ----
    IF (OLD.status = 'FOUND'        AND NEW.status = 'REGISTERED')
    OR (OLD.status = 'REGISTERED'   AND NEW.status = 'CLAIMED')
    OR (OLD.status = 'CLAIMED'      AND NEW.status = 'REGISTERED')   -- all claims rejected/withdrawn
    OR (OLD.status = 'CLAIMED'      AND NEW.status = 'VERIFIED')
    OR (OLD.status = 'VERIFIED'     AND NEW.status = 'HANDED_OVER')
    OR (OLD.status = 'HANDED_OVER'  AND NEW.status = 'RETURNED') THEN
      SET legal = 1;
    END IF;
    IF legal = 0 THEN
      SET msg = CONCAT('B2Y-E012: illegal status transition ', OLD.status, ' -> ', NEW.status);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;

    -- ---- per-edge preconditions ----
    IF NEW.status = 'REGISTERED' AND OLD.status = 'FOUND' THEN
      IF fn_role(NEW.current_holder_id) NOT IN ('staff','admin') OR fn_role(NEW.current_holder_id) IS NULL THEN
        SET msg = 'B2Y-E013: only staff/admin custody can REGISTER an item';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
    END IF;
    IF NEW.status = 'CLAIMED' THEN
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'PENDING') THEN
        SET msg = 'B2Y-E014: CLAIMED requires at least one pending claim';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
    END IF;
    IF NEW.status = 'REGISTERED' AND OLD.status = 'CLAIMED' THEN
      IF EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status IN ('PENDING','VERIFIED')) THEN
        SET msg = 'B2Y-E015: cannot reopen item while a pending/verified claim exists';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
    END IF;
    IF NEW.status = 'VERIFIED' THEN
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'VERIFIED') THEN
        SET msg = 'B2Y-E016: VERIFIED requires a verified claim (no handover without verification)';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
    END IF;
    IF NEW.status = 'HANDED_OVER' THEN
      IF NOT EXISTS (SELECT 1 FROM handovers WHERE item_id = OLD.item_id AND received_by = NEW.current_holder_id) THEN
        SET msg = 'B2Y-E017: HANDED_OVER requires a handover record naming the new holder';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
    END IF;
    IF NEW.status = 'RETURNED' AND NEW.returned_at IS NULL THEN
      SET msg = 'B2Y-E018: RETURNED requires returned_at';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
  END IF;

  SET NEW.updated_at = fn_now();
END$$

-- Only unprocessed (FOUND) items may be deleted (spam / duplicates)
CREATE TRIGGER trg_items_bd BEFORE DELETE ON items FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  IF OLD.status <> 'FOUND' THEN
    SET msg = CONCAT('B2Y-E019: only items in FOUND status can be deleted (this one is ', OLD.status, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END$$

-- =====================================================================
-- A. CLAIMS
-- =====================================================================
CREATE TRIGGER trg_claims_bi BEFORE INSERT ON claims FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  DECLARE st VARCHAR(12);
  DECLARE fid INT;
  DECLARE holder INT;
  SELECT status, finder_id, current_holder_id INTO st, fid, holder
    FROM items WHERE item_id = NEW.item_id;
  IF st IS NULL THEN
    SET msg = 'B2Y-E020: item does not exist';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF st NOT IN ('REGISTERED','CLAIMED') THEN
    SET msg = CONCAT('B2Y-E021: item cannot be claimed while in status ', st);
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.claimant_id = fid OR NEW.claimant_id = holder THEN
    SET msg = 'B2Y-E022: finder/custodian cannot claim the item they hold';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF fn_role(NEW.claimant_id) IS NULL THEN
    SET msg = 'B2Y-E023: claimant is not an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.status <> 'PENDING' THEN
    SET msg = 'B2Y-E024: a new claim must be PENDING';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  SET NEW.created_at = fn_now();
END$$

CREATE TRIGGER trg_claims_bu BEFORE UPDATE ON claims FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  IF NEW.item_id <> OLD.item_id OR NEW.claimant_id <> OLD.claimant_id THEN
    SET msg = 'B2Y-E030: claim item/claimant are immutable';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF OLD.status <> 'PENDING' THEN
    SET msg = CONCAT('B2Y-E031: claim is already ', OLD.status, ' and final');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF OLD.answer_match = 1 AND NEW.answer_match = 0 THEN
    SET msg = 'B2Y-E032: a matched answer cannot be un-matched';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.status IN ('VERIFIED','REJECTED') THEN
    IF fn_role(NEW.reviewed_by) IS NULL OR fn_role(NEW.reviewed_by) NOT IN ('staff','admin') THEN
      SET msg = 'B2Y-E033: only staff/admin may review a claim';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
  END IF;
  IF NEW.status = 'VERIFIED' AND NEW.answer_match = 0 THEN
    SET msg = 'B2Y-E034: cannot verify a claim whose hidden-detail answer did not match';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END$$

CREATE TRIGGER trg_claims_bd BEFORE DELETE ON claims FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E035: claims are permanent records and cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

-- =====================================================================
-- A. HANDOVERS (immutable proof)
-- =====================================================================
CREATE TRIGGER trg_handovers_bi BEFORE INSERT ON handovers FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  DECLARE ist VARCHAR(12); DECLARE holder INT;
  DECLARE cst VARCHAR(12); DECLARE citem INT; DECLARE cclaimant INT;
  SELECT status, current_holder_id INTO ist, holder FROM items WHERE item_id = NEW.item_id;
  SELECT status, item_id, claimant_id INTO cst, citem, cclaimant FROM claims WHERE claim_id = NEW.claim_id;
  IF ist IS NULL OR ist <> 'VERIFIED' THEN
    SET msg = 'B2Y-E040: handover requires item status VERIFIED';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF cst IS NULL OR cst <> 'VERIFIED' OR citem <> NEW.item_id THEN
    SET msg = 'B2Y-E041: handover requires a VERIFIED claim for this same item';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.given_by <> holder THEN
    SET msg = 'B2Y-E042: only the current custodian can hand the item over';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.received_by <> cclaimant THEN
    SET msg = 'B2Y-E043: item can only be handed to the verified claimant';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.handed_at > DATE_ADD(fn_now(), INTERVAL 5 MINUTE) THEN
    SET msg = 'B2Y-E044: handed_at cannot be in the future';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END$$

CREATE TRIGGER trg_handovers_bu BEFORE UPDATE ON handovers FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E045: handover records are immutable';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

CREATE TRIGGER trg_handovers_bd BEFORE DELETE ON handovers FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E045: handover records are immutable';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

-- =====================================================================
-- A. CUSTODY LOG (rows may only be CLOSED, never edited/removed)
-- =====================================================================
CREATE TRIGGER trg_custody_bi BEFORE INSERT ON custody_log FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  IF fn_role(NEW.holder_id) IS NULL THEN
    SET msg = 'B2Y-E050: custody holder must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF NEW.start_at > DATE_ADD(fn_now(), INTERVAL 5 MINUTE) THEN
    SET msg = 'B2Y-E051: custody start cannot be in the future';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END$$

CREATE TRIGGER trg_custody_bu BEFORE UPDATE ON custody_log FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  IF OLD.end_at IS NOT NULL OR NEW.end_at IS NULL
     OR NEW.item_id <> OLD.item_id OR NEW.holder_id <> OLD.holder_id
     OR NEW.start_at <> OLD.start_at OR NEW.event <> OLD.event THEN
    SET msg = 'B2Y-E052: custody rows can only be closed once (set end_at), never edited';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END$$

CREATE TRIGGER trg_custody_bd BEFORE DELETE ON custody_log FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E053: custody history cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

-- =====================================================================
-- A. USERS
-- =====================================================================
CREATE TRIGGER trg_users_bu BEFORE UPDATE ON users FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  DECLARE admins INT;
  IF OLD.role = 'admin' AND (NEW.role <> 'admin' OR NEW.is_active = 0) THEN
    SELECT COUNT(*) INTO admins FROM users WHERE role = 'admin' AND is_active = 1;
    IF admins <= 1 THEN
      SET msg = 'B2Y-E060: the last active admin cannot be demoted or deactivated';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_users_bd BEFORE DELETE ON users FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E061: users are never deleted - deactivate them (is_active = 0)';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

-- =====================================================================
-- B. FRAUD HEURISTICS
-- =====================================================================
CREATE TRIGGER trg_claims_ai AFTER INSERT ON claims FOR EACH ROW
BEGIN
  DECLARE n_recent INT;
  DECLARE n_pending INT;
  -- flag 1: same user filing many claims within 24h
  SELECT COUNT(*) INTO n_recent FROM claims
   WHERE claimant_id = NEW.claimant_id AND created_at >= DATE_SUB(fn_now(), INTERVAL 24 HOUR);
  IF n_recent >= 3 AND NOT EXISTS (SELECT 1 FROM fraud_flags WHERE user_id = NEW.claimant_id
        AND flag_type = 'MANY_CLAIMS' AND status = 'OPEN') THEN
    INSERT INTO fraud_flags (user_id, item_id, flag_type, details, created_at)
    VALUES (NEW.claimant_id, NEW.item_id, 'MANY_CLAIMS',
            CONCAT(n_recent, ' claims filed within 24 hours'), fn_now());
  END IF;
  -- flag 2: several people claiming the same item
  SELECT COUNT(*) INTO n_pending FROM claims WHERE item_id = NEW.item_id AND status = 'PENDING';
  IF n_pending >= 2 AND NOT EXISTS (SELECT 1 FROM fraud_flags WHERE item_id = NEW.item_id
        AND flag_type = 'MULTIPLE_CLAIMANTS' AND status = 'OPEN') THEN
    INSERT INTO fraud_flags (user_id, item_id, flag_type, details, created_at)
    VALUES (NEW.claimant_id, NEW.item_id, 'MULTIPLE_CLAIMANTS',
            CONCAT(n_pending, ' competing pending claims on one item'), fn_now());
  END IF;
  -- audit
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('claims', NEW.claim_id, 'INSERT', NULL,
          JSON_OBJECT('item_id', NEW.item_id, 'claimant_id', NEW.claimant_id,
                      'status', NEW.status, 'answer_match', NEW.answer_match), @app_user_id);
END$$

CREATE TRIGGER trg_attempts_ai AFTER INSERT ON verification_attempts FOR EACH ROW
BEGIN
  DECLARE n_wrong INT;
  DECLARE v_item INT;
  IF NEW.is_correct = 0 THEN
    SELECT COUNT(*) INTO n_wrong FROM verification_attempts
     WHERE claimant_id = NEW.claimant_id AND is_correct = 0
       AND attempted_at >= DATE_SUB(fn_now(), INTERVAL 24 HOUR);
    IF n_wrong >= 3 AND NOT EXISTS (SELECT 1 FROM fraud_flags WHERE user_id = NEW.claimant_id
          AND flag_type = 'REPEATED_WRONG_ANSWER' AND status = 'OPEN') THEN
      SELECT item_id INTO v_item FROM claims WHERE claim_id = NEW.claim_id;
      INSERT INTO fraud_flags (user_id, item_id, flag_type, details, created_at)
      VALUES (NEW.claimant_id, v_item, 'REPEATED_WRONG_ANSWER',
              CONCAT(n_wrong, ' wrong verification answers within 24 hours'), fn_now());
    END IF;
  END IF;
END$$

-- =====================================================================
-- C. AUDIT TRAIL
-- 1) append-only  2) every row stores SHA-256(prev_hash | content)
-- =====================================================================
CREATE TRIGGER trg_audit_bi BEFORE INSERT ON audit_log FOR EACH ROW
BEGIN
  DECLARE ph CHAR(64);
  -- row lock on the chain head serialises concurrent appends and is rolled back with the txn
  SELECT last_hash INTO ph FROM audit_chain_head WHERE id = 1 FOR UPDATE;
  SET NEW.changed_at = IF(@b2y_now IS NULL, NOW(3), CAST(@b2y_now AS DATETIME(3)));
  SET NEW.prev_hash  = ph;
  SET NEW.row_hash   = SHA2(CONCAT_WS('|', ph, NEW.table_name, NEW.record_id, NEW.action,
                            IFNULL(NEW.old_values, ''), IFNULL(NEW.new_values, ''),
                            IFNULL(NEW.changed_by, ''), NEW.changed_at), 256);
  UPDATE audit_chain_head SET last_hash = NEW.row_hash WHERE id = 1;
END$$

CREATE TRIGGER trg_audit_bu BEFORE UPDATE ON audit_log FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E070: audit_log is append-only (UPDATE rejected)';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

CREATE TRIGGER trg_audit_bd BEFORE DELETE ON audit_log FOR EACH ROW
BEGIN
  DECLARE msg VARCHAR(255);
  SET msg = 'B2Y-E070: audit_log is append-only (DELETE rejected)';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
END$$

-- ---- items ----
CREATE TRIGGER trg_items_ai AFTER INSERT ON items FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('items', NEW.item_id, 'INSERT', NULL,
          JSON_OBJECT('title', NEW.title, 'status', NEW.status, 'category_id', NEW.category_id,
                      'finder_id', NEW.finder_id, 'holder_id', NEW.current_holder_id), @app_user_id);
END$$

CREATE TRIGGER trg_items_au AFTER UPDATE ON items FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('items', NEW.item_id, 'UPDATE',
          JSON_OBJECT('status', OLD.status, 'holder_id', OLD.current_holder_id, 'title', OLD.title),
          JSON_OBJECT('status', NEW.status, 'holder_id', NEW.current_holder_id, 'title', NEW.title),
          @app_user_id);
END$$

CREATE TRIGGER trg_items_ad AFTER DELETE ON items FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('items', OLD.item_id, 'DELETE',
          JSON_OBJECT('title', OLD.title, 'status', OLD.status, 'finder_id', OLD.finder_id), NULL, @app_user_id);
END$$

-- ---- claims (insert audit is inside trg_claims_ai) ----
CREATE TRIGGER trg_claims_au AFTER UPDATE ON claims FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('claims', NEW.claim_id, 'UPDATE',
          JSON_OBJECT('status', OLD.status, 'answer_match', OLD.answer_match),
          JSON_OBJECT('status', NEW.status, 'answer_match', NEW.answer_match,
                      'reviewed_by', NEW.reviewed_by, 'notes', NEW.review_notes), @app_user_id);
END$$

-- ---- custody ----
CREATE TRIGGER trg_custody_ai AFTER INSERT ON custody_log FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('custody_log', NEW.custody_id, 'INSERT', NULL,
          JSON_OBJECT('item_id', NEW.item_id, 'holder_id', NEW.holder_id,
                      'received_from', NEW.received_from, 'event', NEW.event), @app_user_id);
END$$

CREATE TRIGGER trg_custody_au AFTER UPDATE ON custody_log FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('custody_log', NEW.custody_id, 'UPDATE',
          JSON_OBJECT('end_at', NULL), JSON_OBJECT('end_at', NEW.end_at), @app_user_id);
END$$

-- ---- handovers ----
CREATE TRIGGER trg_handovers_ai AFTER INSERT ON handovers FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('handovers', NEW.handover_id, 'INSERT', NULL,
          JSON_OBJECT('item_id', NEW.item_id, 'claim_id', NEW.claim_id, 'given_by', NEW.given_by,
                      'received_by', NEW.received_by, 'proof_type', NEW.proof_type), @app_user_id);
END$$

-- ---- users (password hash is NEVER written to the audit log) ----
CREATE TRIGGER trg_users_ai AFTER INSERT ON users FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('users', NEW.user_id, 'INSERT', NULL,
          JSON_OBJECT('email', NEW.email, 'role', NEW.role), @app_user_id);
END$$

CREATE TRIGGER trg_users_au AFTER UPDATE ON users FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('users', NEW.user_id, 'UPDATE',
          JSON_OBJECT('role', OLD.role, 'is_active', OLD.is_active),
          JSON_OBJECT('role', NEW.role, 'is_active', NEW.is_active), @app_user_id);
END$$

-- ---- fraud flags / lost reports ----
CREATE TRIGGER trg_flags_ai AFTER INSERT ON fraud_flags FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('fraud_flags', NEW.flag_id, 'INSERT', NULL,
          JSON_OBJECT('user_id', NEW.user_id, 'item_id', NEW.item_id, 'type', NEW.flag_type), @app_user_id);
END$$

CREATE TRIGGER trg_flags_au AFTER UPDATE ON fraud_flags FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('fraud_flags', NEW.flag_id, 'UPDATE',
          JSON_OBJECT('status', OLD.status), JSON_OBJECT('status', NEW.status, 'resolved_by', NEW.resolved_by),
          @app_user_id);
END$$

CREATE TRIGGER trg_lr_ai AFTER INSERT ON lost_reports FOR EACH ROW
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by)
  VALUES ('lost_reports', NEW.report_id, 'INSERT', NULL,
          JSON_OBJECT('owner_id', NEW.owner_id, 'title', NEW.title), @app_user_id);
END$$

DELIMITER ;
