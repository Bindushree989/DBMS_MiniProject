-- =====================================================================
-- Back2You  |  04_procedures.sql  |  Transactional stored procedures
-- Every state-changing business operation is ONE atomic procedure:
-- all writes commit together or everything is rolled back.
-- Lock order is always:  item row  ->  claims/custody/handover rows -> audit head
-- (consistent order => no deadlock cycles between the main flows).
-- =====================================================================
USE back2you;
DROP PROCEDURE IF EXISTS sp_report_found_item;
DROP PROCEDURE IF EXISTS sp_register_item;
DROP PROCEDURE IF EXISTS sp_transfer_custody;
DROP PROCEDURE IF EXISTS sp_submit_lost_report;
DROP PROCEDURE IF EXISTS sp_submit_claim;
DROP PROCEDURE IF EXISTS sp_retry_answer;
DROP PROCEDURE IF EXISTS sp_withdraw_claim;
DROP PROCEDURE IF EXISTS sp_review_claim;
DROP PROCEDURE IF EXISTS sp_perform_handover;
DROP PROCEDURE IF EXISTS sp_confirm_return;
DROP PROCEDURE IF EXISTS sp_candidates;
DROP PROCEDURE IF EXISTS sp_resolve_flag;
DROP PROCEDURE IF EXISTS sp_set_user_role;
DROP PROCEDURE IF EXISTS sp_delete_spam_item;
DROP PROCEDURE IF EXISTS sp_verify_audit_chain;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 1. Finder reports a found item  (status FOUND, finder holds it)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_report_found_item(
  IN p_finder INT, IN p_title VARCHAR(120), IN p_desc TEXT, IN p_category INT,
  IN p_color VARCHAR(30), IN p_brand VARCHAR(60), IN p_location INT, IN p_found_at DATETIME,
  IN p_question VARCHAR(200), IN p_answer VARCHAR(200))
BEGIN
  DECLARE v_item INT;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_finder;
  START TRANSACTION;
    INSERT INTO items (title, description, category_id, color, brand, location_id, found_at,
                       finder_id, current_holder_id, verification_question, verification_answer_hash)
    VALUES (TRIM(p_title), p_desc, p_category, NULLIF(TRIM(p_color), ''), NULLIF(TRIM(p_brand), ''),
            p_location, p_found_at, p_finder, p_finder, p_question, fn_answer_hash(p_answer));
    SET v_item = LAST_INSERT_ID();
    INSERT INTO custody_log (item_id, holder_id, received_from, event, start_at, note)
    VALUES (v_item, p_finder, NULL, 'FOUND_BY_FINDER', fn_now(), 'Reported by finder');
  COMMIT;
  SELECT v_item AS item_id;
END$$

-- ---------------------------------------------------------------------
-- 2. Staff accepts the item into custody (FOUND -> REGISTERED)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_register_item(IN p_item INT, IN p_staff INT, IN p_note VARCHAR(255))
BEGIN
  DECLARE v_status VARCHAR(12); DECLARE v_holder INT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_staff;
  START TRANSACTION;
    SELECT status, current_holder_id INTO v_status, v_holder FROM items WHERE item_id = p_item FOR UPDATE;
    IF v_status IS NULL THEN SET msg = 'B2Y-E101: item not found'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; END IF;
    IF fn_role(p_staff) IS NULL OR fn_role(p_staff) = 'user' THEN
      SET msg = 'B2Y-E102: staff or admin role required'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF v_status <> 'FOUND' THEN
      SET msg = CONCAT('B2Y-E103: only FOUND items can be registered (item is ', v_status, ')');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    UPDATE custody_log SET end_at = fn_now() WHERE item_id = p_item AND end_at IS NULL;
    INSERT INTO custody_log (item_id, holder_id, received_from, event, start_at, note)
    VALUES (p_item, p_staff, v_holder, 'ACCEPTED_BY_STAFF', fn_now(), p_note);
    UPDATE items SET status = 'REGISTERED', current_holder_id = p_staff WHERE item_id = p_item;
  COMMIT;
  SELECT p_item AS item_id, 'REGISTERED' AS status;
END$$

-- ---------------------------------------------------------------------
-- 3. Custody moves between staff members (desk A -> desk B, evidence room ...)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_transfer_custody(IN p_item INT, IN p_from INT, IN p_to INT, IN p_note VARCHAR(255))
BEGIN
  DECLARE v_status VARCHAR(12); DECLARE v_holder INT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_from;
  START TRANSACTION;
    SELECT status, current_holder_id INTO v_status, v_holder FROM items WHERE item_id = p_item FOR UPDATE;
    IF v_status IS NULL OR v_status NOT IN ('REGISTERED','CLAIMED','VERIFIED') THEN
      SET msg = 'B2Y-E111: custody can only be transferred while the item is REGISTERED/CLAIMED/VERIFIED';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF v_holder <> p_from THEN
      SET msg = 'B2Y-E112: transfer must be initiated by the current custodian';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF p_from = p_to THEN
      SET msg = 'B2Y-E113: cannot transfer custody to yourself';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF fn_role(p_to) IS NULL OR fn_role(p_to) = 'user' THEN
      SET msg = 'B2Y-E114: recipient must be staff or admin';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    UPDATE custody_log SET end_at = fn_now() WHERE item_id = p_item AND end_at IS NULL;
    INSERT INTO custody_log (item_id, holder_id, received_from, event, start_at, note)
    VALUES (p_item, p_to, p_from, 'TRANSFERRED', fn_now(), p_note);
    UPDATE items SET current_holder_id = p_to WHERE item_id = p_item;
  COMMIT;
  SELECT p_item AS item_id, p_to AS holder_id;
END$$

-- ---------------------------------------------------------------------
-- 4. Owner files a lost report (used for matching)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_submit_lost_report(
  IN p_owner INT, IN p_title VARCHAR(120), IN p_desc TEXT, IN p_category INT,
  IN p_color VARCHAR(30), IN p_brand VARCHAR(60), IN p_location INT, IN p_lost_at DATETIME)
BEGIN
  DECLARE v_id INT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_owner;
  IF p_lost_at > DATE_ADD(fn_now(), INTERVAL 5 MINUTE) THEN
    SET msg = 'B2Y-E121: lost_at cannot be in the future'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  START TRANSACTION;
    INSERT INTO lost_reports (owner_id, title, description, category_id, color, brand, lost_location_id, lost_at, created_at)
    VALUES (p_owner, TRIM(p_title), p_desc, p_category, NULLIF(TRIM(p_color), ''), NULLIF(TRIM(p_brand), ''),
            p_location, p_lost_at, fn_now());
    SET v_id = LAST_INSERT_ID();
  COMMIT;
  SELECT v_id AS report_id;
END$$

-- ---------------------------------------------------------------------
-- 5. Owner submits a claim with the answer to the finder's hidden detail
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_submit_claim(
  IN p_item INT, IN p_claimant INT, IN p_report INT, IN p_desc TEXT, IN p_answer VARCHAR(200))
BEGIN
  DECLARE v_status VARCHAR(12); DECLARE v_hash CHAR(64); DECLARE v_match TINYINT;
  DECLARE v_claim INT; DECLARE v_score DECIMAL(5,4) DEFAULT NULL; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_claimant;
  START TRANSACTION;
    -- the item row lock serialises concurrent claimants on the same item
    SELECT status, verification_answer_hash INTO v_status, v_hash FROM items WHERE item_id = p_item FOR UPDATE;
    IF v_status IS NULL THEN SET msg = 'B2Y-E131: item not found'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg; END IF;
    SET v_match = (fn_answer_hash(p_answer) = v_hash);
    IF p_report IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM lost_reports WHERE report_id = p_report AND owner_id = p_claimant) THEN
        SET msg = 'B2Y-E132: lost report does not belong to the claimant';
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
      END IF;
      SET v_score = fn_match_score(p_item, p_report);
    END IF;
    INSERT INTO claims (item_id, claimant_id, report_id, description, answer_match, match_score)
    VALUES (p_item, p_claimant, p_report, p_desc, v_match, v_score);
    SET v_claim = LAST_INSERT_ID();
    INSERT INTO verification_attempts (claim_id, claimant_id, submitted_answer, is_correct, attempted_at)
    VALUES (v_claim, p_claimant, LEFT(p_answer, 200), v_match, fn_now());
    IF v_status = 'REGISTERED' THEN
      UPDATE items SET status = 'CLAIMED' WHERE item_id = p_item;
    END IF;
  COMMIT;
  SELECT v_claim AS claim_id, v_match AS answer_match, v_score AS match_score;
END$$

-- ---------------------------------------------------------------------
-- 6. Retry the hidden-detail answer (max 3 attempts per claim)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_retry_answer(IN p_claim INT, IN p_claimant INT, IN p_answer VARCHAR(200))
BEGIN
  DECLARE v_item INT; DECLARE v_status VARCHAR(12); DECLARE v_owner INT; DECLARE v_matched TINYINT;
  DECLARE v_hash CHAR(64); DECLARE v_tries INT; DECLARE v_match TINYINT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_claimant;
  SELECT item_id INTO v_item FROM claims WHERE claim_id = p_claim;
  START TRANSACTION;
    SELECT verification_answer_hash INTO v_hash FROM items WHERE item_id = v_item FOR UPDATE;
    SELECT status, claimant_id, answer_match INTO v_status, v_owner, v_matched
      FROM claims WHERE claim_id = p_claim FOR UPDATE;
    IF v_owner IS NULL OR v_owner <> p_claimant THEN
      SET msg = 'B2Y-E141: not your claim'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF v_status <> 'PENDING' OR v_matched = 1 THEN
      SET msg = 'B2Y-E142: claim is not awaiting an answer'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    SELECT COUNT(*) INTO v_tries FROM verification_attempts WHERE claim_id = p_claim;
    IF v_tries >= 3 THEN
      SET msg = 'B2Y-E143: maximum of 3 verification attempts reached'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    SET v_match = (fn_answer_hash(p_answer) = v_hash);
    INSERT INTO verification_attempts (claim_id, claimant_id, submitted_answer, is_correct, attempted_at)
    VALUES (p_claim, p_claimant, LEFT(p_answer, 200), v_match, fn_now());
    IF v_match = 1 THEN UPDATE claims SET answer_match = 1 WHERE claim_id = p_claim; END IF;
  COMMIT;
  SELECT v_match AS answer_match, (v_tries + 1) AS attempts_used;
END$$

-- ---------------------------------------------------------------------
-- 7. Claimant withdraws a pending claim
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_withdraw_claim(IN p_claim INT, IN p_user INT)
BEGIN
  DECLARE v_item INT; DECLARE v_owner INT; DECLARE v_status VARCHAR(12); DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_user;
  SELECT item_id INTO v_item FROM claims WHERE claim_id = p_claim;
  START TRANSACTION;
    SELECT status INTO v_status FROM items WHERE item_id = v_item FOR UPDATE;
    SELECT claimant_id, status INTO v_owner, v_status FROM claims WHERE claim_id = p_claim FOR UPDATE;
    IF v_owner IS NULL OR v_owner <> p_user THEN
      SET msg = 'B2Y-E151: not your claim'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    UPDATE claims SET status = 'WITHDRAWN', reviewed_at = fn_now() WHERE claim_id = p_claim;
    IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = v_item AND status IN ('PENDING','VERIFIED'))
       AND (SELECT status FROM items WHERE item_id = v_item) = 'CLAIMED' THEN
      UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item;
    END IF;
  COMMIT;
  SELECT p_claim AS claim_id, 'WITHDRAWN' AS status;
END$$

-- ---------------------------------------------------------------------
-- 8. Staff verifies / rejects a claim (CLAIMED -> VERIFIED or back to REGISTERED)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_review_claim(IN p_claim INT, IN p_staff INT, IN p_approve TINYINT, IN p_notes VARCHAR(255))
BEGIN
  DECLARE v_item INT; DECLARE v_cstatus VARCHAR(12); DECLARE v_istatus VARCHAR(12);
  DECLARE v_holder INT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_staff;
  SELECT item_id INTO v_item FROM claims WHERE claim_id = p_claim;
  START TRANSACTION;
    SELECT status, current_holder_id INTO v_istatus, v_holder FROM items WHERE item_id = v_item FOR UPDATE;
    SELECT status INTO v_cstatus FROM claims WHERE claim_id = p_claim FOR UPDATE;
    IF fn_role(p_staff) IS NULL OR fn_role(p_staff) = 'user' THEN
      SET msg = 'B2Y-E161: staff or admin role required'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF v_cstatus IS NULL OR v_cstatus <> 'PENDING' THEN
      SET msg = 'B2Y-E162: only PENDING claims can be reviewed'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF p_approve = 1 THEN
      UPDATE claims SET status = 'VERIFIED', reviewed_by = p_staff, review_notes = p_notes, reviewed_at = fn_now()
       WHERE claim_id = p_claim;
      UPDATE items SET status = 'VERIFIED' WHERE item_id = v_item;
      -- competing claims are closed automatically
      UPDATE claims SET status = 'REJECTED', reviewed_by = p_staff, reviewed_at = fn_now(),
             review_notes = 'Auto-rejected: another claim was verified'
       WHERE item_id = v_item AND status = 'PENDING' AND claim_id <> p_claim;
    ELSE
      UPDATE claims SET status = 'REJECTED', reviewed_by = p_staff, review_notes = p_notes, reviewed_at = fn_now()
       WHERE claim_id = p_claim;
      IF NOT EXISTS (SELECT 1 FROM claims WHERE item_id = v_item AND status = 'PENDING') AND v_istatus = 'CLAIMED' THEN
        UPDATE items SET status = 'REGISTERED' WHERE item_id = v_item;
      END IF;
    END IF;
  COMMIT;
  SELECT p_claim AS claim_id, IF(p_approve = 1, 'VERIFIED', 'REJECTED') AS status;
END$$

-- ---------------------------------------------------------------------
-- 9. ATOMIC handover: custody + handover record + item status together
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_perform_handover(
  IN p_item INT, IN p_staff INT, IN p_proof_type VARCHAR(12), IN p_proof_ref VARCHAR(200), IN p_notes VARCHAR(255))
BEGIN
  DECLARE v_status VARCHAR(12); DECLARE v_holder INT; DECLARE v_claim INT; DECLARE v_claimant INT;
  DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_staff;
  START TRANSACTION;
    SELECT status, current_holder_id INTO v_status, v_holder FROM items WHERE item_id = p_item FOR UPDATE;
    IF v_status IS NULL OR v_status <> 'VERIFIED' THEN
      SET msg = CONCAT('B2Y-E171: item must be VERIFIED for handover (is ', IFNULL(v_status, 'missing'), ')');
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF v_holder <> p_staff THEN
      SET msg = 'B2Y-E172: only the current custodian can perform the handover';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    SELECT claim_id, claimant_id INTO v_claim, v_claimant FROM claims
     WHERE item_id = p_item AND status = 'VERIFIED' FOR UPDATE;
    IF v_claim IS NULL THEN
      SET msg = 'B2Y-E173: no verified claim for this item'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    INSERT INTO handovers (item_id, claim_id, given_by, received_by, handed_at, proof_type, proof_ref, notes)
    VALUES (p_item, v_claim, p_staff, v_claimant, fn_now(), p_proof_type, p_proof_ref, p_notes);
    UPDATE custody_log SET end_at = fn_now() WHERE item_id = p_item AND end_at IS NULL;
    INSERT INTO custody_log (item_id, holder_id, received_from, event, start_at, note)
    VALUES (p_item, v_claimant, p_staff, 'HANDED_TO_OWNER', fn_now(), CONCAT('Proof: ', p_proof_type));
    UPDATE items SET status = 'HANDED_OVER', current_holder_id = v_claimant WHERE item_id = p_item;
  COMMIT;
  SELECT p_item AS item_id, v_claim AS claim_id, 'HANDED_OVER' AS status;
END$$

-- ---------------------------------------------------------------------
-- 10. Owner (or staff) confirms the item is back (HANDED_OVER -> RETURNED)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_confirm_return(IN p_item INT, IN p_user INT)
BEGIN
  DECLARE v_status VARCHAR(12); DECLARE v_holder INT; DECLARE msg VARCHAR(255);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
  SET @app_user_id = p_user;
  START TRANSACTION;
    SELECT status, current_holder_id INTO v_status, v_holder FROM items WHERE item_id = p_item FOR UPDATE;
    IF v_status IS NULL OR v_status <> 'HANDED_OVER' THEN
      SET msg = 'B2Y-E181: only HANDED_OVER items can be confirmed as returned';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    IF p_user <> v_holder AND (fn_role(p_user) IS NULL OR fn_role(p_user) = 'user') THEN
      SET msg = 'B2Y-E182: only the receiving owner or staff can confirm the return';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
    END IF;
    UPDATE custody_log SET end_at = fn_now() WHERE item_id = p_item AND end_at IS NULL;
    UPDATE items SET status = 'RETURNED', returned_at = fn_now() WHERE item_id = p_item;
  COMMIT;
  SELECT p_item AS item_id, 'RETURNED' AS status;
END$$

-- ---------------------------------------------------------------------
-- 11. Structured + full-text candidate search for a lost report
--     (also the fallback when the vector service is unavailable)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_candidates(IN p_report INT, IN p_limit INT)
BEGIN
  DECLARE v_text VARCHAR(500);
  SELECT CONCAT(title, ' ', description) INTO v_text FROM lost_reports WHERE report_id = p_report;
  SELECT i.item_id, i.title, i.color, i.brand, i.status, i.found_at, c.name AS category, l.name AS location,
         fn_match_score(i.item_id, p_report) AS structured_score,
         MATCH(i.title, i.description) AGAINST (v_text IN NATURAL LANGUAGE MODE) AS text_score
    FROM items i
    JOIN categories c ON c.category_id = i.category_id
    JOIN locations  l ON l.location_id = i.location_id
   WHERE i.status IN ('REGISTERED','CLAIMED')
   ORDER BY structured_score DESC, text_score DESC
   LIMIT p_limit;
END$$

-- ---------------------------------------------------------------------
-- 12-14. Admin operations
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_resolve_flag(IN p_flag INT, IN p_admin INT, IN p_status VARCHAR(10))
BEGIN
  DECLARE msg VARCHAR(255);
  SET @app_user_id = p_admin;
  IF fn_role(p_admin) <> 'admin' OR fn_role(p_admin) IS NULL THEN
    SET msg = 'B2Y-E191: admin role required'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  IF p_status NOT IN ('DISMISSED','CONFIRMED') THEN
    SET msg = 'B2Y-E192: status must be DISMISSED or CONFIRMED'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  UPDATE fraud_flags SET status = p_status, resolved_by = p_admin, resolved_at = fn_now()
   WHERE flag_id = p_flag AND status = 'OPEN';
  SELECT ROW_COUNT() AS updated;
END$$

CREATE PROCEDURE sp_set_user_role(IN p_admin INT, IN p_user INT, IN p_role VARCHAR(10))
BEGIN
  DECLARE msg VARCHAR(255);
  SET @app_user_id = p_admin;
  IF fn_role(p_admin) IS NULL OR fn_role(p_admin) <> 'admin' THEN
    SET msg = 'B2Y-E193: admin role required'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  UPDATE users SET role = p_role WHERE user_id = p_user;
  SELECT ROW_COUNT() AS updated;
END$$

CREATE PROCEDURE sp_delete_spam_item(IN p_admin INT, IN p_item INT)
BEGIN
  DECLARE msg VARCHAR(255);
  SET @app_user_id = p_admin;
  IF fn_role(p_admin) IS NULL OR fn_role(p_admin) <> 'admin' THEN
    SET msg = 'B2Y-E194: admin role required'; SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
  DELETE FROM items WHERE item_id = p_item;   -- trigger rejects anything beyond FOUND
  SELECT ROW_COUNT() AS deleted;
END$$

-- ---------------------------------------------------------------------
-- 15. Recompute the audit hash chain; returns every broken link (0 rows = intact)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_verify_audit_chain()
BEGIN
  SELECT audit_id, 'prev_hash does not link to previous row' AS problem
    FROM (SELECT audit_id, prev_hash,
                 COALESCE(LAG(row_hash) OVER (ORDER BY audit_id), REPEAT('0', 64)) AS expected_prev
            FROM audit_log) a
   WHERE prev_hash <> expected_prev
  UNION ALL
  SELECT audit_id, 'row content does not match its hash'
    FROM audit_log
   WHERE row_hash <> SHA2(CONCAT_WS('|', prev_hash, table_name, record_id, action,
                           IFNULL(old_values, ''), IFNULL(new_values, ''), IFNULL(changed_by, ''), changed_at), 256)
  UNION ALL
  SELECT 0, 'chain head does not match the last audit row (tail truncated?)'
    FROM audit_chain_head h
   WHERE h.last_hash <> COALESCE((SELECT row_hash FROM audit_log ORDER BY audit_id DESC LIMIT 1), REPEAT('0', 64));
END$$

DELIMITER ;
