-- =====================================================================
-- Back2You - 05_procedures.sql   (stored procedures)
-- NOTE: regenerated from the live database after the original file was
-- overwritten by mistake (2026-10-17). Same objects, header comments lost.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP PROCEDURE IF EXISTS sp_cancel_claim;
DROP PROCEDURE IF EXISTS sp_confirm_return;
DROP PROCEDURE IF EXISTS sp_match_structured;
DROP PROCEDURE IF EXISTS sp_perform_handover;
DROP PROCEDURE IF EXISTS sp_register_item;
DROP PROCEDURE IF EXISTS sp_reject_claim;
DROP PROCEDURE IF EXISTS sp_report_found_item;
DROP PROCEDURE IF EXISTS sp_revoke_verification;
DROP PROCEDURE IF EXISTS sp_submit_claim;
DROP PROCEDURE IF EXISTS sp_transfer_custody;
DROP PROCEDURE IF EXISTS sp_verify_claim;
DROP PROCEDURE IF EXISTS sp_withdraw_found_item;
DROP PROCEDURE IF EXISTS sp_write_audit;

DELIMITER $$

CREATE PROCEDURE `sp_cancel_claim`(
  IN p_claim_id INT UNSIGNED,
  IN p_user_id  INT UNSIGNED
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_claimant INT UNSIGNED;
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SELECT item_id INTO v_item_id FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT claimant_id, status INTO v_claimant, v_cstatus FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF v_claimant <> p_user_id THEN
    SET v_msg = 'You can only cancel your own claim';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cstatus <> 'PENDING' THEN
    SET v_msg = 'Only pending claims can be cancelled';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE claims SET status = 'CANCELLED' WHERE claim_id = p_claim_id;
  IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = v_item_id AND status = 'PENDING') THEN
    UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item_id AND status = 'CLAIMED';
  END IF;

  COMMIT;
  SELECT p_claim_id AS claim_id, 'CANCELLED' AS status;
END$$

CREATE PROCEDURE `sp_confirm_return`(
  IN p_claim_id INT UNSIGNED,
  IN p_actor_id INT UNSIGNED
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_istatus VARCHAR(20);
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_claimant INT UNSIGNED;
  DECLARE v_hours DECIMAL(10,1);
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SELECT status INTO v_istatus FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT claimant_id, status INTO v_claimant, v_cstatus FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF v_claimant <> p_actor_id AND NOT fn_is_staff(p_actor_id) THEN
    SET v_msg = 'Only the owner or staff can confirm the return';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_istatus <> 'HANDED_OVER' OR v_cstatus <> 'VERIFIED' THEN
    SET v_msg = 'Return can only be confirmed after the handover';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE claims SET status = 'FULFILLED' WHERE claim_id = p_claim_id;
  UPDATE items SET status = 'RETURNED', returned_at = fn_now() WHERE item_id = v_item_id;
  UPDATE custody_log SET ended_at = fn_now() WHERE item_id = v_item_id AND active_flag = 1;

  SELECT TIMESTAMPDIFF(MINUTE, found_at, returned_at) / 60.0 INTO v_hours FROM items WHERE item_id = v_item_id;

  COMMIT;
  SELECT v_item_id AS item_id, 'RETURNED' AS status, v_hours AS hours_to_return;
END$$

CREATE PROCEDURE `sp_match_structured`(
  IN p_category_id   INT UNSIGNED,
  IN p_color         VARCHAR(30),
  IN p_brand         VARCHAR(60),
  IN p_location_id   INT UNSIGNED,
  IN p_lost_at       DATETIME,
  IN p_candidate_ids TEXT,
  IN p_limit         INT
)
BEGIN
  SELECT t.*
    FROM (
      SELECT i.item_id, i.title, i.description, i.status, i.color, i.brand, i.found_at,
             c.name AS category, l.name AS location_name,
             fn_structured_score(i.item_id, p_category_id, p_color, p_brand, p_location_id, p_lost_at)
               AS structured_score
        FROM items i
        JOIN categories c ON c.category_id = i.category_id
        JOIN locations  l ON l.location_id = i.found_location_id
       WHERE i.status IN ('REGISTERED', 'CLAIMED')
    ) t
   WHERE t.structured_score >= 0.35
      OR FIND_IN_SET(t.item_id, p_candidate_ids) > 0
   ORDER BY t.structured_score DESC, t.item_id
   LIMIT p_limit;
END$$

CREATE PROCEDURE `sp_perform_handover`(
  IN p_claim_id   INT UNSIGNED,
  IN p_staff_id   INT UNSIGNED,
  IN p_proof_type VARCHAR(20),
  IN p_proof_ref  VARCHAR(120),
  IN p_notes      VARCHAR(255)
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_istatus VARCHAR(20);
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_claimant INT UNSIGNED;
  DECLARE v_cust INT UNSIGNED;
  DECLARE v_holder INT UNSIGNED;
  DECLARE v_ho INT UNSIGNED;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SELECT status INTO v_istatus FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT claimant_id, status INTO v_claimant, v_cstatus FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF NOT fn_is_staff(p_staff_id) THEN
    SET v_msg = 'Only staff can perform a handover';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cstatus <> 'VERIFIED' THEN
    SET v_msg = 'No handover without a verified claim';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_istatus <> 'VERIFIED' THEN
    SET v_msg = CONCAT('Item is not ready for handover (status: ', v_istatus, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT custody_id, holder_id INTO v_cust, v_holder
    FROM custody_log WHERE item_id = v_item_id AND active_flag = 1 FOR UPDATE;
  IF v_holder <> p_staff_id THEN
    SET v_msg = 'Only the current custodian can hand the item over; transfer custody first';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO handovers (item_id, claim_id, handover_type, from_user_id, to_user_id,
                         proof_type, proof_reference, notes)
  VALUES (v_item_id, p_claim_id, 'STAFF_TO_OWNER', p_staff_id, v_claimant,
          p_proof_type, p_proof_ref, p_notes);
  SET v_ho = LAST_INSERT_ID();

  UPDATE custody_log SET ended_at = fn_now() WHERE custody_id = v_cust;
  INSERT INTO custody_log (item_id, holder_id, from_user_id, handover_id, started_at, notes)
  VALUES (v_item_id, v_claimant, p_staff_id, v_ho, fn_now(), 'Handed to verified owner');

  UPDATE items SET status = 'HANDED_OVER' WHERE item_id = v_item_id;

  COMMIT;
  SELECT v_item_id AS item_id, v_ho AS handover_id, 'HANDED_OVER' AS status;
END$$

CREATE PROCEDURE `sp_register_item`(
  IN p_item_id       INT UNSIGNED,
  IN p_staff_id      INT UNSIGNED,
  IN p_proof_type    VARCHAR(20),
  IN p_proof_ref     VARCHAR(120),
  IN p_storage_place VARCHAR(120)
)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_cust INT UNSIGNED;
  DECLARE v_holder INT UNSIGNED;
  DECLARE v_ho INT UNSIGNED;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT status INTO v_status FROM items WHERE item_id = p_item_id FOR UPDATE;
  IF v_status IS NULL THEN
    SET v_msg = 'Item not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF NOT fn_is_staff(p_staff_id) THEN
    SET v_msg = 'Only staff can register items';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_status <> 'FOUND' THEN
    SET v_msg = 'Only items in FOUND status can be registered';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT custody_id, holder_id INTO v_cust, v_holder
    FROM custody_log WHERE item_id = p_item_id AND active_flag = 1 FOR UPDATE;

  IF v_holder = p_staff_id THEN
    
    UPDATE custody_log SET storage_place = COALESCE(NULLIF(TRIM(p_storage_place), ''), storage_place)
     WHERE custody_id = v_cust;
  ELSE
    INSERT INTO handovers (item_id, claim_id, handover_type, from_user_id, to_user_id,
                           proof_type, proof_reference, notes)
    VALUES (p_item_id, NULL, 'FINDER_TO_STAFF', v_holder, p_staff_id,
            p_proof_type, p_proof_ref, 'Item registered into staff custody');
    SET v_ho = LAST_INSERT_ID();

    UPDATE custody_log SET ended_at = fn_now() WHERE custody_id = v_cust;
    INSERT INTO custody_log (item_id, holder_id, from_user_id, handover_id, started_at, storage_place, notes)
    VALUES (p_item_id, p_staff_id, v_holder, v_ho, fn_now(), NULLIF(TRIM(p_storage_place), ''),
            'Received from finder');
  END IF;

  UPDATE items SET status = 'REGISTERED' WHERE item_id = p_item_id;

  COMMIT;
  SELECT p_item_id AS item_id, 'REGISTERED' AS status;
END$$

CREATE PROCEDURE `sp_reject_claim`(
  IN p_claim_id INT UNSIGNED,
  IN p_staff_id INT UNSIGNED,
  IN p_reason   VARCHAR(255)
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SELECT item_id INTO v_item_id FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT status INTO v_cstatus FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF NOT fn_is_staff(p_staff_id) THEN
    SET v_msg = 'Only staff can reject claims';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cstatus <> 'PENDING' THEN
    SET v_msg = 'Only pending claims can be rejected';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_reason IS NULL OR CHAR_LENGTH(TRIM(p_reason)) < 3 THEN
    SET v_msg = 'A rejection reason is required';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE claims SET status = 'REJECTED', reject_reason = TRIM(p_reason) WHERE claim_id = p_claim_id;
  IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = v_item_id AND status = 'PENDING') THEN
    UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item_id AND status = 'CLAIMED';
  END IF;

  COMMIT;
  SELECT p_claim_id AS claim_id, 'REJECTED' AS status;
END$$

CREATE PROCEDURE `sp_report_found_item`(
  IN p_finder_id     INT UNSIGNED,
  IN p_title         VARCHAR(120),
  IN p_description   TEXT,
  IN p_category_id   INT UNSIGNED,
  IN p_color         VARCHAR(30),
  IN p_brand         VARCHAR(60),
  IN p_location_id   INT UNSIGNED,
  IN p_found_at      DATETIME,
  IN p_hint          VARCHAR(255),
  IN p_answer        VARCHAR(255),
  IN p_storage_place VARCHAR(120)
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_hint VARCHAR(255);
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_finder_id AND is_active = 1) THEN
    SET v_msg = 'Finder must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SET v_hint = NULLIF(TRIM(p_hint), '');
  IF (v_hint IS NULL) <> (fn_hash_answer(p_answer) IS NULL) THEN
    SET v_msg = 'Provide both the hidden-detail question and its answer, or neither';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO items (title, description, category_id, color, brand, found_location_id, found_at,
                     finder_id, status, verification_hint, verification_answer_hash)
  VALUES (p_title, p_description, p_category_id, p_color, p_brand, p_location_id, p_found_at,
          p_finder_id, 'FOUND', v_hint, fn_hash_answer(p_answer));
  SET v_item_id = LAST_INSERT_ID();

  INSERT INTO custody_log (item_id, holder_id, from_user_id, started_at, storage_place, notes)
  VALUES (v_item_id, p_finder_id, NULL, fn_now(), NULLIF(TRIM(p_storage_place), ''), 'Reported found by finder');

  COMMIT;
  SELECT v_item_id AS item_id, 'FOUND' AS status;
END$$

CREATE PROCEDURE `sp_revoke_verification`(
  IN p_claim_id INT UNSIGNED,
  IN p_staff_id INT UNSIGNED,
  IN p_reason   VARCHAR(255)
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_istatus VARCHAR(20);
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SELECT status INTO v_istatus FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT status INTO v_cstatus FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF NOT fn_is_staff(p_staff_id) THEN
    SET v_msg = 'Only staff can revoke a verification';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cstatus <> 'VERIFIED' OR v_istatus <> 'VERIFIED' THEN
    SET v_msg = 'Only a verified claim on a VERIFIED item (before handover) can be revoked';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_reason IS NULL OR CHAR_LENGTH(TRIM(p_reason)) < 3 THEN
    SET v_msg = 'A reason is required';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  UPDATE claims SET status = 'REJECTED', reject_reason = CONCAT('Verification revoked: ', TRIM(p_reason))
   WHERE claim_id = p_claim_id;
  UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item_id;

  COMMIT;
  SELECT p_claim_id AS claim_id, 'REGISTERED' AS item_status;
END$$

CREATE PROCEDURE `sp_submit_claim`(
  IN p_item_id     INT UNSIGNED,
  IN p_claimant_id INT UNSIGNED,
  IN p_description TEXT,
  IN p_answer      VARCHAR(255)
)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_claim_id INT UNSIGNED;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR 1062
  BEGIN
    ROLLBACK;
    SET v_msg = 'You already have an active claim on this item';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT status INTO v_status FROM items WHERE item_id = p_item_id FOR UPDATE;
  IF v_status IS NULL THEN
    SET v_msg = 'Item not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_status NOT IN ('REGISTERED', 'CLAIMED') THEN
    SET v_msg = CONCAT('Item is not open for claims (status: ', v_status, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO claims (item_id, claimant_id, description, answer_hash, status)
  VALUES (p_item_id, p_claimant_id, p_description, fn_hash_answer(p_answer), 'PENDING');
  SET v_claim_id = LAST_INSERT_ID();

  IF v_status = 'REGISTERED' THEN
    UPDATE items SET status = 'CLAIMED' WHERE item_id = p_item_id;
  END IF;

  COMMIT;
  SELECT v_claim_id AS claim_id, 'CLAIMED' AS item_status;
END$$

CREATE PROCEDURE `sp_transfer_custody`(
  IN p_item_id       INT UNSIGNED,
  IN p_actor_id      INT UNSIGNED,
  IN p_to_staff_id   INT UNSIGNED,
  IN p_proof_type    VARCHAR(20),
  IN p_proof_ref     VARCHAR(120),
  IN p_storage_place VARCHAR(120),
  IN p_notes         VARCHAR(255)
)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_cust INT UNSIGNED;
  DECLARE v_holder INT UNSIGNED;
  DECLARE v_ho INT UNSIGNED;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT status INTO v_status FROM items WHERE item_id = p_item_id FOR UPDATE;
  IF v_status IS NULL THEN
    SET v_msg = 'Item not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF NOT fn_is_staff(p_actor_id) THEN
    SET v_msg = 'Only staff can transfer custody';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  SELECT custody_id, holder_id INTO v_cust, v_holder
    FROM custody_log WHERE item_id = p_item_id AND active_flag = 1 FOR UPDATE;

  IF v_holder <> p_actor_id AND NOT fn_is_admin(p_actor_id) THEN
    SET v_msg = 'Only the current custodian (or an admin) can transfer this item';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_holder = p_to_staff_id THEN
    SET v_msg = 'The item is already held by that staff member';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  INSERT INTO handovers (item_id, claim_id, handover_type, from_user_id, to_user_id,
                         proof_type, proof_reference, notes)
  VALUES (p_item_id, NULL, 'STAFF_TO_STAFF', v_holder, p_to_staff_id,
          p_proof_type, p_proof_ref, p_notes);
  SET v_ho = LAST_INSERT_ID();

  UPDATE custody_log SET ended_at = fn_now() WHERE custody_id = v_cust;
  INSERT INTO custody_log (item_id, holder_id, from_user_id, handover_id, started_at, storage_place, notes)
  VALUES (p_item_id, p_to_staff_id, v_holder, v_ho, fn_now(), NULLIF(TRIM(p_storage_place), ''), p_notes);

  COMMIT;
  SELECT p_item_id AS item_id, v_ho AS handover_id;
END$$

CREATE PROCEDURE `sp_verify_claim`(
  IN p_claim_id  INT UNSIGNED,
  IN p_staff_id  INT UNSIGNED,
  IN p_method    VARCHAR(20),
  IN p_proof_ref VARCHAR(120),
  IN p_notes     VARCHAR(255)
)
BEGIN
  DECLARE v_item_id INT UNSIGNED;
  DECLARE v_claimant INT UNSIGNED;
  DECLARE v_cstatus VARCHAR(20);
  DECLARE v_istatus VARCHAR(20);
  DECLARE v_claim_hash CHAR(64);
  DECLARE v_item_hash CHAR(64);
  DECLARE v_failed TINYINT UNSIGNED DEFAULT 0;
  DECLARE v_pass TINYINT(1) DEFAULT 0;
  DECLARE v_outcome VARCHAR(10);
  DECLARE v_left INT DEFAULT NULL;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT item_id INTO v_item_id FROM claims WHERE claim_id = p_claim_id;
  IF v_item_id IS NULL THEN
    SET v_msg = 'Claim not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  
  SELECT status, verification_answer_hash INTO v_istatus, v_item_hash
    FROM items WHERE item_id = v_item_id FOR UPDATE;
  SELECT claimant_id, status, answer_hash, failed_attempts
    INTO v_claimant, v_cstatus, v_claim_hash, v_failed
    FROM claims WHERE claim_id = p_claim_id FOR UPDATE;

  IF NOT fn_is_staff(p_staff_id) THEN
    SET v_msg = 'Only staff can verify ownership';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_method NOT IN ('HINT_ANSWER', 'ID_PROOF', 'ADMIN_OVERRIDE') THEN
    SET v_msg = 'Unknown verification method';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_method = 'ADMIN_OVERRIDE' AND NOT fn_is_admin(p_staff_id) THEN
    SET v_msg = 'Only an admin can use ADMIN_OVERRIDE';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_cstatus <> 'PENDING' THEN
    SET v_msg = 'Only pending claims can be verified';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_istatus <> 'CLAIMED' THEN
    SET v_msg = CONCAT('Item is not awaiting verification (status: ', v_istatus, ')');
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_staff_id = v_claimant THEN
    SET v_msg = 'You cannot verify your own claim';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF p_method IN ('ID_PROOF', 'ADMIN_OVERRIDE') AND (p_proof_ref IS NULL OR CHAR_LENGTH(TRIM(p_proof_ref)) < 3) THEN
    SET v_msg = 'A proof reference (e.g. ID number, bill number) is required for this method';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  IF p_method = 'HINT_ANSWER' THEN
    IF v_item_hash IS NULL THEN
      SET v_msg = 'This item has no hidden-detail question; verify with ID_PROOF instead';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
    SET v_pass = (v_claim_hash IS NOT NULL AND v_claim_hash = v_item_hash);
  ELSE
    SET v_pass = 1;
  END IF;

  INSERT INTO verification_attempts (claim_id, staff_id, method, outcome, proof_ref, notes, attempted_at)
  VALUES (p_claim_id, p_staff_id, p_method, IF(v_pass = 1, 'PASS', 'FAIL'),
          NULLIF(TRIM(p_proof_ref), ''), p_notes, fn_now());

  IF v_pass = 1 THEN
    UPDATE claims SET status = 'VERIFIED' WHERE claim_id = p_claim_id;
    UPDATE items  SET status = 'VERIFIED' WHERE item_id = v_item_id;
    UPDATE claims SET status = 'REJECTED', reject_reason = 'Another claim on this item was verified'
     WHERE item_id = v_item_id AND status = 'PENDING' AND claim_id <> p_claim_id;
    SET v_outcome = 'PASS';
  ELSE
    SET v_failed = v_failed + 1;
    UPDATE claims SET failed_attempts = v_failed WHERE claim_id = p_claim_id;
    IF v_failed >= 3 THEN
      UPDATE claims SET status = 'REJECTED', reject_reason = 'Too many failed verification attempts'
       WHERE claim_id = p_claim_id;
      INSERT IGNORE INTO fraud_flags (user_id, item_id, claim_id, reason, severity, details, created_at)
      VALUES (v_claimant, v_item_id, p_claim_id, 'REPEATED_FAILED_VERIFICATION', 'HIGH',
              'Claimant failed the ownership check 3 times', fn_now());
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = v_item_id AND status = 'PENDING') THEN
        UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item_id AND status = 'CLAIMED';
      END IF;
    END IF;
    SET v_outcome = 'FAIL';
    SET v_left = GREATEST(0, 3 - v_failed);
  END IF;

  COMMIT;
  SELECT v_outcome AS outcome, v_left AS attempts_left, p_claim_id AS claim_id;
END$$

CREATE PROCEDURE `sp_withdraw_found_item`(
  IN p_item_id INT UNSIGNED,
  IN p_user_id INT UNSIGNED
)
BEGIN
  DECLARE v_status VARCHAR(20);
  DECLARE v_finder INT UNSIGNED;
  DECLARE v_msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  
  
  SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
  START TRANSACTION;

  SELECT status, finder_id INTO v_status, v_finder FROM items WHERE item_id = p_item_id FOR UPDATE;
  IF v_status IS NULL THEN
    SET v_msg = 'Item not found';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  IF v_finder <> p_user_id AND NOT fn_is_admin(p_user_id) THEN
    SET v_msg = 'Only the finder (or an admin) can withdraw a report';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;

  DELETE FROM items WHERE item_id = p_item_id;   

  COMMIT;
  SELECT p_item_id AS item_id, 'WITHDRAWN' AS status;
END$$

CREATE PROCEDURE `sp_write_audit`(
  IN p_table   VARCHAR(40),
  IN p_record  VARCHAR(40),
  IN p_action  VARCHAR(10),
  IN p_old     LONGTEXT,
  IN p_new     LONGTEXT
)
BEGIN
  INSERT INTO audit_log (table_name, record_id, action, old_values, new_values, changed_by, changed_at)
  VALUES (p_table, p_record, p_action, p_old, p_new,
          COALESCE(@b2y_actor, CONCAT('db:', CURRENT_USER())),
          fn_now());
END$$

DELIMITER ;
