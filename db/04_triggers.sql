-- =====================================================================
-- Back2You - 04_triggers.sql   (triggers)
-- NOTE: regenerated from the live database after the original file was
-- overwritten by mistake (2026-10-17). Same objects, header comments lost.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP TRIGGER IF EXISTS trg_audit_bu;
DROP TRIGGER IF EXISTS trg_audit_bd;
DROP TRIGGER IF EXISTS trg_claims_bi;
DROP TRIGGER IF EXISTS trg_claims_bu;
DROP TRIGGER IF EXISTS trg_claims_bd;
DROP TRIGGER IF EXISTS trg_claims_ai;
DROP TRIGGER IF EXISTS trg_claims_au;
DROP TRIGGER IF EXISTS trg_custody_bi;
DROP TRIGGER IF EXISTS trg_custody_bu;
DROP TRIGGER IF EXISTS trg_custody_bd;
DROP TRIGGER IF EXISTS trg_custody_ai;
DROP TRIGGER IF EXISTS trg_fraud_ai;
DROP TRIGGER IF EXISTS trg_fraud_au;
DROP TRIGGER IF EXISTS trg_handovers_bi;
DROP TRIGGER IF EXISTS trg_handovers_bu;
DROP TRIGGER IF EXISTS trg_handovers_bd;
DROP TRIGGER IF EXISTS trg_handovers_ai;
DROP TRIGGER IF EXISTS trg_items_bi;
DROP TRIGGER IF EXISTS trg_items_bu;
DROP TRIGGER IF EXISTS trg_items_bd;
DROP TRIGGER IF EXISTS trg_items_ai;
DROP TRIGGER IF EXISTS trg_items_au;
DROP TRIGGER IF EXISTS trg_items_ad;
DROP TRIGGER IF EXISTS trg_users_bi;
DROP TRIGGER IF EXISTS trg_users_bu;
DROP TRIGGER IF EXISTS trg_users_ai;
DROP TRIGGER IF EXISTS trg_users_au;

DELIMITER $$

CREATE TRIGGER trg_audit_bu BEFORE UPDATE ON audit_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'audit_log is append-only: UPDATE is not allowed';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_audit_bd BEFORE DELETE ON audit_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'audit_log is append-only: DELETE is not allowed';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_claims_bi BEFORE INSERT ON claims FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  DECLARE v_status VARCHAR(20);
  DECLARE v_finder INT UNSIGNED;
  DECLARE v_holder INT UNSIGNED;

  IF NEW.status <> 'PENDING' THEN
    SET v_msg = 'New claims must start as PENDING';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT status, finder_id INTO v_status, v_finder FROM items WHERE item_id = NEW.item_id;
  IF v_status IS NULL OR v_status NOT IN ('REGISTERED', 'CLAIMED') THEN
    SET v_msg = 'Item is not open for claims';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF v_finder = NEW.claimant_id THEN
    SET v_msg = 'The finder cannot claim an item they reported';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT holder_id INTO v_holder FROM custody_log WHERE item_id = NEW.item_id AND ended_at IS NULL;
  IF v_holder = NEW.claimant_id THEN
    SET v_msg = 'The current custodian cannot claim an item they hold';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = NEW.claimant_id AND is_active = 1) THEN
    SET v_msg = 'Claimant must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  
  IF EXISTS (SELECT 1 FROM claims WHERE item_id = NEW.item_id AND claimant_id = NEW.claimant_id
                AND status = 'REJECTED' AND failed_attempts >= 3) THEN
    SET v_msg = 'Your earlier claim on this item was rejected after failed verification';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SET NEW.submitted_at = fn_now();
END$$

CREATE TRIGGER trg_claims_bu BEFORE UPDATE ON claims FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);

  IF NEW.item_id <> OLD.item_id OR NEW.claimant_id <> OLD.claimant_id THEN
    SET v_msg = 'item_id and claimant_id of a claim are immutable';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.status <> OLD.status THEN
    IF NOT (
         (OLD.status = 'PENDING'  AND NEW.status IN ('VERIFIED', 'REJECTED', 'CANCELLED'))
      OR (OLD.status = 'VERIFIED' AND NEW.status IN ('FULFILLED', 'REJECTED'))) THEN
      SET v_msg = CONCAT('Illegal claim status transition: ', OLD.status, ' -> ', NEW.status);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    IF NEW.status = 'VERIFIED' THEN
      IF NOT EXISTS (SELECT 1 FROM verification_attempts WHERE claim_id = OLD.claim_id AND outcome = 'PASS') THEN
        SET v_msg = 'A claim cannot be VERIFIED without a passing verification attempt';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'FULFILLED' THEN
      IF NOT EXISTS (SELECT 1 FROM handovers WHERE claim_id = OLD.claim_id AND handover_type = 'STAFF_TO_OWNER') THEN
        SET v_msg = 'A claim cannot be FULFILLED without an owner handover';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status IN ('REJECTED', 'CANCELLED', 'FULFILLED') THEN
      SET NEW.resolved_at = COALESCE(NEW.resolved_at, fn_now());
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_claims_bd BEFORE DELETE ON claims FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Claims are permanent records; cancel the claim instead of deleting it';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_claims_ai AFTER INSERT ON claims FOR EACH ROW
BEGIN
  DECLARE v_recent INT DEFAULT 0;
  DECLARE v_pending INT DEFAULT 0;
  DECLARE v_details VARCHAR(255);

  CALL sp_write_audit('claims', NEW.claim_id, 'INSERT', NULL,
    JSON_OBJECT('item_id', NEW.item_id, 'claimant_id', NEW.claimant_id, 'status', NEW.status));

  
  SELECT COUNT(*) INTO v_recent FROM claims
   WHERE claimant_id = NEW.claimant_id
     AND submitted_at >= DATE_SUB(NEW.submitted_at, INTERVAL 24 HOUR)
     AND submitted_at <= NEW.submitted_at;
  IF v_recent >= 4 THEN
    SET v_details = CONCAT(v_recent, ' claims submitted by this user within 24 hours');
    INSERT IGNORE INTO fraud_flags (user_id, item_id, claim_id, reason, severity, details, created_at)
    VALUES (NEW.claimant_id, NEW.item_id, NEW.claim_id, 'RAPID_CLAIMS',
            IF(v_recent >= 6, 'HIGH', 'MEDIUM'), v_details, NEW.submitted_at);
  END IF;

  
  SELECT COUNT(*) INTO v_pending FROM claims WHERE item_id = NEW.item_id AND status = 'PENDING';
  IF v_pending >= 2 THEN
    SET v_details = CONCAT(v_pending, ' competing pending claims on this item');
    INSERT IGNORE INTO fraud_flags (user_id, item_id, claim_id, reason, severity, details, created_at)
    VALUES (NEW.claimant_id, NEW.item_id, NEW.claim_id, 'MULTIPLE_CLAIMANTS',
            IF(v_pending >= 3, 'HIGH', 'MEDIUM'), v_details, NEW.submitted_at);
  END IF;
END$$

CREATE TRIGGER trg_claims_au AFTER UPDATE ON claims FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status AND OLD.failed_attempts <=> NEW.failed_attempts) THEN
    CALL sp_write_audit('claims', NEW.claim_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status, 'failed_attempts', OLD.failed_attempts),
      JSON_OBJECT('status', NEW.status, 'failed_attempts', NEW.failed_attempts,
                  'reject_reason', NEW.reject_reason));
  END IF;
END$$

CREATE TRIGGER trg_custody_bi BEFORE INSERT ON custody_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = NEW.holder_id AND is_active = 1) THEN
    SET v_msg = 'Custody holder must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SET NEW.started_at = fn_now();
END$$

CREATE TRIGGER trg_custody_bu BEFORE UPDATE ON custody_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF NEW.item_id <> OLD.item_id OR NEW.holder_id <> OLD.holder_id OR NEW.started_at <> OLD.started_at
     OR NOT (NEW.from_user_id <=> OLD.from_user_id) OR NOT (NEW.handover_id <=> OLD.handover_id) THEN
    SET v_msg = 'Custody history is immutable; only the end time and storage place of the open entry may change';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF OLD.ended_at IS NOT NULL THEN
    SET v_msg = 'Closed custody entries cannot be modified';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

CREATE TRIGGER trg_custody_bd BEFORE DELETE ON custody_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Custody history cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_custody_ai AFTER INSERT ON custody_log FOR EACH ROW
BEGIN
  CALL sp_write_audit('custody_log', NEW.custody_id, 'INSERT', NULL,
    JSON_OBJECT('item_id', NEW.item_id, 'holder_id', NEW.holder_id, 'from_user_id', NEW.from_user_id,
                'storage_place', NEW.storage_place));
END$$

CREATE TRIGGER trg_fraud_ai AFTER INSERT ON fraud_flags FOR EACH ROW
BEGIN
  CALL sp_write_audit('fraud_flags', NEW.flag_id, 'INSERT', NULL,
    JSON_OBJECT('user_id', NEW.user_id, 'reason', NEW.reason, 'severity', NEW.severity));
END$$

CREATE TRIGGER trg_fraud_au AFTER UPDATE ON fraud_flags FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status) THEN
    CALL sp_write_audit('fraud_flags', NEW.flag_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status), JSON_OBJECT('status', NEW.status, 'reviewed_by', NEW.reviewed_by));
  END IF;
END$$

CREATE TRIGGER trg_handovers_bi BEFORE INSERT ON handovers FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  DECLARE v_item_status VARCHAR(20);
  DECLARE v_claim_status VARCHAR(20);
  DECLARE v_claim_item INT UNSIGNED;
  DECLARE v_claimant INT UNSIGNED;

  SELECT status INTO v_item_status FROM items WHERE item_id = NEW.item_id;

  
  IF NOT EXISTS (SELECT 1 FROM custody_log WHERE item_id = NEW.item_id AND ended_at IS NULL
                    AND holder_id = NEW.from_user_id) THEN
    SET v_msg = 'The giver is not the current custodian of this item';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.handover_type = 'FINDER_TO_STAFF' THEN
    IF v_item_status <> 'FOUND' THEN
      SET v_msg = 'Finder-to-staff handover is only valid while the item is FOUND';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF NOT fn_is_staff(NEW.to_user_id) THEN
      SET v_msg = 'Receiver of a finder handover must be staff';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

  ELSEIF NEW.handover_type = 'STAFF_TO_STAFF' THEN
    IF v_item_status NOT IN ('REGISTERED', 'CLAIMED', 'VERIFIED') THEN
      SET v_msg = 'Custody can only be transferred while the item is REGISTERED, CLAIMED or VERIFIED';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF NOT (fn_is_staff(NEW.from_user_id) AND fn_is_staff(NEW.to_user_id)) THEN
      SET v_msg = 'Both parties of a custody transfer must be staff';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

  ELSE 
    SELECT status, item_id, claimant_id INTO v_claim_status, v_claim_item, v_claimant
      FROM claims WHERE claim_id = NEW.claim_id;
    IF v_claim_status IS NULL OR v_claim_status <> 'VERIFIED' THEN
      SET v_msg = 'No handover without a VERIFIED claim';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_claim_item <> NEW.item_id THEN
      SET v_msg = 'Claim does not belong to this item';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF v_item_status <> 'VERIFIED' THEN
      SET v_msg = 'Item must be in VERIFIED status to be handed to the owner';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF NEW.to_user_id <> v_claimant THEN
      SET v_msg = 'Receiver must be the verified claimant';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    IF NOT fn_is_staff(NEW.from_user_id) THEN
      SET v_msg = 'Only staff may hand an item to its owner';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  END IF;

  SET NEW.handed_at = fn_now();
END$$

CREATE TRIGGER trg_handovers_bu BEFORE UPDATE ON handovers FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Handover records are immutable';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_handovers_bd BEFORE DELETE ON handovers FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Handover records cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END$$

CREATE TRIGGER trg_handovers_ai AFTER INSERT ON handovers FOR EACH ROW
BEGIN
  CALL sp_write_audit('handovers', NEW.handover_id, 'INSERT', NULL,
    JSON_OBJECT('item_id', NEW.item_id, 'type', NEW.handover_type, 'from', NEW.from_user_id,
                'to', NEW.to_user_id, 'proof_type', NEW.proof_type, 'proof_reference', NEW.proof_reference));
END$$

CREATE TRIGGER trg_items_bi BEFORE INSERT ON items FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF NEW.status <> 'FOUND' THEN
    SET v_msg = 'New items must start in FOUND status';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF NEW.found_at > DATE_ADD(fn_now(), INTERVAL 10 MINUTE) THEN
    SET v_msg = 'found_at cannot be in the future';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = NEW.finder_id AND is_active = 1) THEN
    SET v_msg = 'Finder must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SET NEW.title      = TRIM(NEW.title);
  SET NEW.color      = NULLIF(LOWER(TRIM(NEW.color)), '');
  SET NEW.brand      = NULLIF(TRIM(NEW.brand), '');
  SET NEW.created_at = fn_now();
END$$

CREATE TRIGGER trg_items_bu BEFORE UPDATE ON items FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);

  IF OLD.status = 'RETURNED' THEN
    SET v_msg = 'Returned items are closed and cannot be modified';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.finder_id <> OLD.finder_id OR NEW.found_at <> OLD.found_at THEN
    SET v_msg = 'finder_id and found_at are immutable';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF NEW.status <> OLD.status THEN
    
    IF NOT EXISTS (SELECT 1 FROM status_transitions
                    WHERE from_status = OLD.status AND to_status = NEW.status) THEN
      SET v_msg = CONCAT('Illegal status transition: ', OLD.status, ' -> ', NEW.status);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;

    
    IF NEW.status = 'REGISTERED' AND OLD.status = 'FOUND' THEN
      IF NOT EXISTS (SELECT 1 FROM custody_log c JOIN users u ON u.user_id = c.holder_id
                      WHERE c.item_id = OLD.item_id AND c.ended_at IS NULL AND u.role IN ('staff','admin')) THEN
        SET v_msg = 'Item must be in staff custody before it can be REGISTERED';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
      SET NEW.registered_at = COALESCE(NEW.registered_at, fn_now());
    END IF;

    IF NEW.status = 'CLAIMED' THEN
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'PENDING') THEN
        SET v_msg = 'Item cannot be CLAIMED without a pending claim';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'REGISTERED' AND OLD.status = 'CLAIMED' THEN
      IF EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'PENDING') THEN
        SET v_msg = 'Item still has pending claims; it cannot go back to REGISTERED';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'VERIFIED' THEN
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'VERIFIED') THEN
        SET v_msg = 'Item cannot be VERIFIED without a verified claim';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'REGISTERED' AND OLD.status = 'VERIFIED' THEN
      IF EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'VERIFIED') THEN
        SET v_msg = 'Revoke the verified claim before releasing the item';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'HANDED_OVER' THEN
      IF NOT EXISTS (SELECT 1 FROM handovers WHERE item_id = OLD.item_id AND handover_type = 'STAFF_TO_OWNER') THEN
        SET v_msg = 'Item cannot be HANDED_OVER without a recorded owner handover';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
    END IF;

    IF NEW.status = 'RETURNED' THEN
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = OLD.item_id AND status = 'FULFILLED') THEN
        SET v_msg = 'Item cannot be RETURNED before the owner confirms receipt';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
      END IF;
      SET NEW.returned_at = COALESCE(NEW.returned_at, fn_now());
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_items_bd BEFORE DELETE ON items FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF OLD.status <> 'FOUND' THEN
    SET v_msg = 'Only items still in FOUND status can be deleted; later stages are permanent records';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END$$

CREATE TRIGGER trg_items_ai AFTER INSERT ON items FOR EACH ROW
BEGIN
  CALL sp_write_audit('items', NEW.item_id, 'INSERT', NULL,
    JSON_OBJECT('title', NEW.title, 'status', NEW.status, 'category_id', NEW.category_id,
                'location_id', NEW.found_location_id, 'finder_id', NEW.finder_id));
  INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (NEW.item_id, 'UPSERT', fn_now());
END$$

CREATE TRIGGER trg_items_au AFTER UPDATE ON items FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status AND OLD.title <=> NEW.title AND OLD.description <=> NEW.description
          AND OLD.color <=> NEW.color AND OLD.brand <=> NEW.brand AND OLD.category_id <=> NEW.category_id
          AND OLD.found_location_id <=> NEW.found_location_id) THEN
    CALL sp_write_audit('items', NEW.item_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status, 'title', OLD.title, 'color', OLD.color, 'brand', OLD.brand),
      JSON_OBJECT('status', NEW.status, 'title', NEW.title, 'color', NEW.color, 'brand', NEW.brand));
  END IF;

  
  IF NOT (OLD.title <=> NEW.title AND OLD.description <=> NEW.description AND OLD.color <=> NEW.color
          AND OLD.brand <=> NEW.brand AND OLD.category_id <=> NEW.category_id
          AND OLD.found_location_id <=> NEW.found_location_id) THEN
    INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (NEW.item_id, 'UPSERT', fn_now());
  ELSEIF NOT (OLD.status <=> NEW.status) THEN
    INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (NEW.item_id, 'STATUS', fn_now());
  END IF;
END$$

CREATE TRIGGER trg_items_ad AFTER DELETE ON items FOR EACH ROW
BEGIN
  CALL sp_write_audit('items', OLD.item_id, 'DELETE',
    JSON_OBJECT('title', OLD.title, 'status', OLD.status, 'finder_id', OLD.finder_id), NULL);
  INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (OLD.item_id, 'DELETE', fn_now());
END$$

CREATE TRIGGER trg_users_bi BEFORE INSERT ON users FOR EACH ROW
BEGIN
  SET NEW.email     = LOWER(TRIM(NEW.email));
  SET NEW.full_name = TRIM(NEW.full_name);
  SET NEW.phone     = NULLIF(TRIM(NEW.phone), '');
END$$

CREATE TRIGGER trg_users_bu BEFORE UPDATE ON users FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET NEW.email = LOWER(TRIM(NEW.email));
  
  IF OLD.role = 'admin' AND OLD.is_active = 1 AND (NEW.role <> 'admin' OR NEW.is_active = 0) THEN
    IF (SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1 AND user_id <> OLD.user_id) = 0 THEN
      SET v_msg = 'Cannot demote or deactivate the last active admin';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END$$

CREATE TRIGGER trg_users_ai AFTER INSERT ON users FOR EACH ROW
BEGIN
  CALL sp_write_audit('users', NEW.user_id, 'INSERT', NULL,
    JSON_OBJECT('email', NEW.email, 'role', NEW.role, 'is_active', NEW.is_active));
END$$

CREATE TRIGGER trg_users_au AFTER UPDATE ON users FOR EACH ROW
BEGIN
  IF NOT (OLD.role <=> NEW.role AND OLD.is_active <=> NEW.is_active AND OLD.email <=> NEW.email) THEN
    CALL sp_write_audit('users', NEW.user_id, 'UPDATE',
      JSON_OBJECT('email', OLD.email, 'role', OLD.role, 'is_active', OLD.is_active),
      JSON_OBJECT('email', NEW.email, 'role', NEW.role, 'is_active', NEW.is_active));
  END IF;
END$$

DELIMITER ;
