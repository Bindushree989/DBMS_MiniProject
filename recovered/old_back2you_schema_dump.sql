/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19  Distrib 10.11.14-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: back2you
-- ------------------------------------------------------
-- Server version	10.11.14-MariaDB-0ubuntu0.24.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `audit_log`
--

DROP TABLE IF EXISTS `audit_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_log` (
  `audit_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `table_name` varchar(40) NOT NULL,
  `record_id` varchar(40) NOT NULL,
  `action` enum('INSERT','UPDATE','DELETE') NOT NULL,
  `old_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`old_values`)),
  `new_values` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`new_values`)),
  `changed_by` varchar(120) NOT NULL,
  `changed_at` datetime(3) NOT NULL DEFAULT current_timestamp(3),
  PRIMARY KEY (`audit_id`),
  KEY `idx_audit_record` (`table_name`,`record_id`),
  KEY `idx_audit_time` (`changed_at`),
  KEY `idx_audit_actor_time` (`changed_by`,`changed_at`)
) ENGINE=InnoDB AUTO_INCREMENT=7132 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_audit_bu BEFORE UPDATE ON audit_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'audit_log is append-only: UPDATE is not allowed';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_audit_bd BEFORE DELETE ON audit_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'audit_log is append-only: DELETE is not allowed';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `categories`
--

DROP TABLE IF EXISTS `categories`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `categories` (
  `category_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  PRIMARY KEY (`category_id`),
  UNIQUE KEY `uq_categories_name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `claims`
--

DROP TABLE IF EXISTS `claims`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `claims` (
  `claim_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int(10) unsigned NOT NULL,
  `claimant_id` int(10) unsigned NOT NULL,
  `description` text NOT NULL,
  `answer_hash` char(64) DEFAULT NULL,
  `status` enum('PENDING','VERIFIED','REJECTED','CANCELLED','FULFILLED') NOT NULL DEFAULT 'PENDING',
  `failed_attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `reject_reason` varchar(255) DEFAULT NULL,
  `submitted_at` datetime NOT NULL DEFAULT current_timestamp(),
  `resolved_at` datetime DEFAULT NULL,
  `live_flag` tinyint(4) GENERATED ALWAYS AS (if(`status` in ('PENDING','VERIFIED','FULFILLED'),1,NULL)) STORED,
  `verified_flag` tinyint(4) GENERATED ALWAYS AS (if(`status` in ('VERIFIED','FULFILLED'),1,NULL)) STORED,
  PRIMARY KEY (`claim_id`),
  UNIQUE KEY `uq_claims_one_live` (`item_id`,`claimant_id`,`live_flag`),
  UNIQUE KEY `uq_claims_one_verified` (`item_id`,`verified_flag`),
  KEY `idx_claims_item_status` (`item_id`,`status`),
  KEY `idx_claims_claimant` (`claimant_id`,`submitted_at`),
  KEY `idx_claims_status_submitted` (`status`,`submitted_at`),
  CONSTRAINT `fk_claims_claimant` FOREIGN KEY (`claimant_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_claims_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`),
  CONSTRAINT `chk_claims_desc` CHECK (char_length(trim(`description`)) >= 10),
  CONSTRAINT `chk_claims_failed` CHECK (`failed_attempts` between 0 and 3),
  CONSTRAINT `chk_claims_reject` CHECK (`status` <> 'REJECTED' or `reject_reason` is not null)
) ENGINE=InnoDB AUTO_INCREMENT=486 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_claims_bi BEFORE INSERT ON claims FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_claims_ai AFTER INSERT ON claims FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_claims_bu BEFORE UPDATE ON claims FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_claims_au AFTER UPDATE ON claims FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status AND OLD.failed_attempts <=> NEW.failed_attempts) THEN
    CALL sp_write_audit('claims', NEW.claim_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status, 'failed_attempts', OLD.failed_attempts),
      JSON_OBJECT('status', NEW.status, 'failed_attempts', NEW.failed_attempts,
                  'reject_reason', NEW.reject_reason));
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_claims_bd BEFORE DELETE ON claims FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Claims are permanent records; cancel the claim instead of deleting it';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `custody_log`
--

DROP TABLE IF EXISTS `custody_log`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `custody_log` (
  `custody_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int(10) unsigned NOT NULL,
  `holder_id` int(10) unsigned NOT NULL,
  `from_user_id` int(10) unsigned DEFAULT NULL,
  `handover_id` int(10) unsigned DEFAULT NULL,
  `started_at` datetime NOT NULL DEFAULT current_timestamp(),
  `ended_at` datetime DEFAULT NULL,
  `storage_place` varchar(120) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `active_flag` tinyint(4) GENERATED ALWAYS AS (if(`ended_at` is null,1,NULL)) STORED,
  PRIMARY KEY (`custody_id`),
  UNIQUE KEY `uq_custody_one_active` (`item_id`,`active_flag`),
  KEY `fk_cl_from` (`from_user_id`),
  KEY `fk_cl_handover` (`handover_id`),
  KEY `idx_cl_holder` (`holder_id`,`ended_at`),
  CONSTRAINT `fk_cl_from` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_cl_handover` FOREIGN KEY (`handover_id`) REFERENCES `handovers` (`handover_id`),
  CONSTRAINT `fk_cl_holder` FOREIGN KEY (`holder_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_cl_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`) ON DELETE CASCADE,
  CONSTRAINT `chk_cl_period` CHECK (`ended_at` is null or `ended_at` >= `started_at`)
) ENGINE=InnoDB AUTO_INCREMENT=1882 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_custody_bi BEFORE INSERT ON custody_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = NEW.holder_id AND is_active = 1) THEN
    SET v_msg = 'Custody holder must be an active user';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
  SET NEW.started_at = fn_now();
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_custody_ai AFTER INSERT ON custody_log FOR EACH ROW
BEGIN
  CALL sp_write_audit('custody_log', NEW.custody_id, 'INSERT', NULL,
    JSON_OBJECT('item_id', NEW.item_id, 'holder_id', NEW.holder_id, 'from_user_id', NEW.from_user_id,
                'storage_place', NEW.storage_place));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_custody_bu BEFORE UPDATE ON custody_log FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_custody_bd BEFORE DELETE ON custody_log FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Custody history cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `embedding_outbox`
--

DROP TABLE IF EXISTS `embedding_outbox`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `embedding_outbox` (
  `outbox_id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int(10) unsigned NOT NULL,
  `op` enum('UPSERT','STATUS','DELETE') NOT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `processed_at` datetime DEFAULT NULL,
  `attempts` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `last_error` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`outbox_id`),
  KEY `idx_outbox_pending` (`processed_at`,`outbox_id`),
  KEY `idx_outbox_item` (`item_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2857 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `fraud_flags`
--

DROP TABLE IF EXISTS `fraud_flags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `fraud_flags` (
  `flag_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` int(10) unsigned NOT NULL,
  `item_id` int(10) unsigned DEFAULT NULL,
  `claim_id` int(10) unsigned DEFAULT NULL,
  `reason` enum('RAPID_CLAIMS','MULTIPLE_CLAIMANTS','REPEATED_FAILED_VERIFICATION') NOT NULL,
  `severity` enum('LOW','MEDIUM','HIGH') NOT NULL,
  `status` enum('OPEN','REVIEWED','DISMISSED') NOT NULL DEFAULT 'OPEN',
  `details` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `reviewed_by` int(10) unsigned DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`flag_id`),
  UNIQUE KEY `uq_ff_claim_reason` (`claim_id`,`reason`),
  KEY `fk_ff_user` (`user_id`),
  KEY `fk_ff_item` (`item_id`),
  KEY `fk_ff_review` (`reviewed_by`),
  KEY `idx_ff_status` (`status`,`severity`),
  CONSTRAINT `fk_ff_claim` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_ff_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`) ON DELETE SET NULL,
  CONSTRAINT `fk_ff_review` FOREIGN KEY (`reviewed_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_ff_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=116 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_fraud_ai AFTER INSERT ON fraud_flags FOR EACH ROW
BEGIN
  CALL sp_write_audit('fraud_flags', NEW.flag_id, 'INSERT', NULL,
    JSON_OBJECT('user_id', NEW.user_id, 'reason', NEW.reason, 'severity', NEW.severity));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_fraud_au AFTER UPDATE ON fraud_flags FOR EACH ROW
BEGIN
  IF NOT (OLD.status <=> NEW.status) THEN
    CALL sp_write_audit('fraud_flags', NEW.flag_id, 'UPDATE',
      JSON_OBJECT('status', OLD.status), JSON_OBJECT('status', NEW.status, 'reviewed_by', NEW.reviewed_by));
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `handovers`
--

DROP TABLE IF EXISTS `handovers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `handovers` (
  `handover_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `item_id` int(10) unsigned NOT NULL,
  `claim_id` int(10) unsigned DEFAULT NULL,
  `handover_type` enum('FINDER_TO_STAFF','STAFF_TO_STAFF','STAFF_TO_OWNER') NOT NULL,
  `from_user_id` int(10) unsigned NOT NULL,
  `to_user_id` int(10) unsigned NOT NULL,
  `handed_at` datetime NOT NULL DEFAULT current_timestamp(),
  `proof_type` enum('ID_CARD','PHOTO','SIGNATURE','OTP','OTHER') NOT NULL,
  `proof_reference` varchar(120) NOT NULL,
  `notes` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`handover_id`),
  KEY `fk_ho_claim` (`claim_id`),
  KEY `idx_ho_item` (`item_id`,`handed_at`),
  KEY `idx_ho_from` (`from_user_id`),
  KEY `idx_ho_to` (`to_user_id`),
  CONSTRAINT `fk_ho_claim` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`),
  CONSTRAINT `fk_ho_from` FOREIGN KEY (`from_user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_ho_item` FOREIGN KEY (`item_id`) REFERENCES `items` (`item_id`),
  CONSTRAINT `fk_ho_to` FOREIGN KEY (`to_user_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `chk_ho_parties` CHECK (`from_user_id` <> `to_user_id`),
  CONSTRAINT `chk_ho_proof` CHECK (char_length(trim(`proof_reference`)) >= 3),
  CONSTRAINT `chk_ho_claim` CHECK (`handover_type` = 'STAFF_TO_OWNER' = (`claim_id` is not null))
) ENGINE=InnoDB AUTO_INCREMENT=1012 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_handovers_bi BEFORE INSERT ON handovers FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_handovers_ai AFTER INSERT ON handovers FOR EACH ROW
BEGIN
  CALL sp_write_audit('handovers', NEW.handover_id, 'INSERT', NULL,
    JSON_OBJECT('item_id', NEW.item_id, 'type', NEW.handover_type, 'from', NEW.from_user_id,
                'to', NEW.to_user_id, 'proof_type', NEW.proof_type, 'proof_reference', NEW.proof_reference));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_handovers_bu BEFORE UPDATE ON handovers FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Handover records are immutable';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_handovers_bd BEFORE DELETE ON handovers FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET v_msg = 'Handover records cannot be deleted';
  SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `items`
--

DROP TABLE IF EXISTS `items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `items` (
  `item_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `title` varchar(120) NOT NULL,
  `description` text NOT NULL,
  `category_id` int(10) unsigned NOT NULL,
  `color` varchar(30) DEFAULT NULL,
  `brand` varchar(60) DEFAULT NULL,
  `found_location_id` int(10) unsigned NOT NULL,
  `found_at` datetime NOT NULL,
  `finder_id` int(10) unsigned NOT NULL,
  `status` enum('FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED') NOT NULL DEFAULT 'FOUND',
  `verification_hint` varchar(255) DEFAULT NULL,
  `verification_answer_hash` char(64) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `registered_at` datetime DEFAULT NULL,
  `returned_at` datetime DEFAULT NULL,
  `updated_at` datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`item_id`),
  KEY `idx_items_status_found` (`status`,`found_at`),
  KEY `idx_items_category` (`category_id`),
  KEY `idx_items_location` (`found_location_id`),
  KEY `idx_items_finder` (`finder_id`),
  KEY `idx_items_found_at` (`found_at`),
  FULLTEXT KEY `ft_items_text` (`title`,`description`),
  CONSTRAINT `fk_items_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`category_id`),
  CONSTRAINT `fk_items_finder` FOREIGN KEY (`finder_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `fk_items_location` FOREIGN KEY (`found_location_id`) REFERENCES `locations` (`location_id`),
  CONSTRAINT `chk_items_title` CHECK (char_length(trim(`title`)) >= 3),
  CONSTRAINT `chk_items_desc` CHECK (char_length(trim(`description`)) >= 10),
  CONSTRAINT `chk_items_hint_pair` CHECK (`verification_hint` is null and `verification_answer_hash` is null or `verification_hint` is not null and `verification_answer_hash` is not null),
  CONSTRAINT `chk_items_registered` CHECK (`registered_at` is null or `registered_at` >= `found_at`),
  CONSTRAINT `chk_items_returned` CHECK (`returned_at` is null or `status` = 'RETURNED' and `returned_at` >= `found_at`)
) ENGINE=InnoDB AUTO_INCREMENT=901 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_bi BEFORE INSERT ON items FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_ai AFTER INSERT ON items FOR EACH ROW
BEGIN
  CALL sp_write_audit('items', NEW.item_id, 'INSERT', NULL,
    JSON_OBJECT('title', NEW.title, 'status', NEW.status, 'category_id', NEW.category_id,
                'location_id', NEW.found_location_id, 'finder_id', NEW.finder_id));
  INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (NEW.item_id, 'UPSERT', fn_now());
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_bu BEFORE UPDATE ON items FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_au AFTER UPDATE ON items FOR EACH ROW
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
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_bd BEFORE DELETE ON items FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  IF OLD.status <> 'FOUND' THEN
    SET v_msg = 'Only items still in FOUND status can be deleted; later stages are permanent records';
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_items_ad AFTER DELETE ON items FOR EACH ROW
BEGIN
  CALL sp_write_audit('items', OLD.item_id, 'DELETE',
    JSON_OBJECT('title', OLD.title, 'status', OLD.status, 'finder_id', OLD.finder_id), NULL);
  INSERT INTO embedding_outbox (item_id, op, created_at) VALUES (OLD.item_id, 'DELETE', fn_now());
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Table structure for table `locations`
--

DROP TABLE IF EXISTS `locations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `locations` (
  `location_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(100) NOT NULL,
  `location_type` enum('cab','bus','metro','college','hostel','office','public','other') NOT NULL,
  `city` varchar(60) NOT NULL,
  `latitude` decimal(9,6) DEFAULT NULL,
  `longitude` decimal(9,6) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (`location_id`),
  UNIQUE KEY `uq_locations_name_city` (`name`,`city`),
  CONSTRAINT `chk_locations_lat` CHECK (`latitude` is null or `latitude` between -90 and 90),
  CONSTRAINT `chk_locations_lon` CHECK (`longitude` is null or `longitude` between -180 and 180),
  CONSTRAINT `chk_locations_pair` CHECK (`latitude` is null = (`longitude` is null)),
  CONSTRAINT `chk_locations_active` CHECK (`is_active` in (0,1))
) ENGINE=InnoDB AUTO_INCREMENT=16 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `status_transitions`
--

DROP TABLE IF EXISTS `status_transitions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `status_transitions` (
  `from_status` enum('FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED') NOT NULL,
  `to_status` enum('FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED') NOT NULL,
  `description` varchar(150) NOT NULL,
  PRIMARY KEY (`from_status`,`to_status`),
  CONSTRAINT `chk_transition_differs` CHECK (`from_status` <> `to_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `full_name` varchar(100) NOT NULL,
  `email` varchar(150) NOT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `password_hash` varchar(100) NOT NULL,
  `role` enum('user','staff','admin') NOT NULL DEFAULT 'user',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_login_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uq_users_email` (`email`),
  KEY `idx_users_role` (`role`,`is_active`),
  CONSTRAINT `chk_users_name` CHECK (char_length(trim(`full_name`)) >= 2),
  CONSTRAINT `chk_users_email` CHECK (`email` regexp '^[^@ ]+@[^@ ]+[.][^@ ]+$'),
  CONSTRAINT `chk_users_phone` CHECK (`phone` is null or `phone` regexp '^[0-9+() -]{7,20}$'),
  CONSTRAINT `chk_users_active` CHECK (`is_active` in (0,1))
) ENGINE=InnoDB AUTO_INCREMENT=87 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_users_bi BEFORE INSERT ON users FOR EACH ROW
BEGIN
  SET NEW.email     = LOWER(TRIM(NEW.email));
  SET NEW.full_name = TRIM(NEW.full_name);
  SET NEW.phone     = NULLIF(TRIM(NEW.phone), '');
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_users_ai AFTER INSERT ON users FOR EACH ROW
BEGIN
  CALL sp_write_audit('users', NEW.user_id, 'INSERT', NULL,
    JSON_OBJECT('email', NEW.email, 'role', NEW.role, 'is_active', NEW.is_active));
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_users_bu BEFORE UPDATE ON users FOR EACH ROW
BEGIN
  DECLARE v_msg VARCHAR(255);
  SET NEW.email = LOWER(TRIM(NEW.email));
  
  IF OLD.role = 'admin' AND OLD.is_active = 1 AND (NEW.role <> 'admin' OR NEW.is_active = 0) THEN
    IF (SELECT COUNT(*) FROM users WHERE role = 'admin' AND is_active = 1 AND user_id <> OLD.user_id) = 0 THEN
      SET v_msg = 'Cannot demote or deactivate the last active admin';
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_msg;
    END IF;
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
DELIMITER ;;
/*!50003 CREATE*/ /*!50017 DEFINER=`b2y`@`localhost`*/ /*!50003 TRIGGER trg_users_au AFTER UPDATE ON users FOR EACH ROW
BEGIN
  IF NOT (OLD.role <=> NEW.role AND OLD.is_active <=> NEW.is_active AND OLD.email <=> NEW.email) THEN
    CALL sp_write_audit('users', NEW.user_id, 'UPDATE',
      JSON_OBJECT('email', OLD.email, 'role', OLD.role, 'is_active', OLD.is_active),
      JSON_OBJECT('email', NEW.email, 'role', NEW.role, 'is_active', NEW.is_active));
  END IF;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Temporary table structure for view `v_admin_kpis`
--

DROP TABLE IF EXISTS `v_admin_kpis`;
/*!50001 DROP VIEW IF EXISTS `v_admin_kpis`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_admin_kpis` AS SELECT
 1 AS `total_items`,
  1 AS `returned_items`,
  1 AS `open_items`,
  1 AS `return_rate_pct`,
  1 AS `avg_hours_to_return`,
  1 AS `unclaimed_over_14d`,
  1 AS `pending_claims`,
  1 AS `open_fraud_flags`,
  1 AS `total_users` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_category_stats`
--

DROP TABLE IF EXISTS `v_category_stats`;
/*!50001 DROP VIEW IF EXISTS `v_category_stats`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_category_stats` AS SELECT
 1 AS `category_id`,
  1 AS `category`,
  1 AS `total_items`,
  1 AS `returned_items`,
  1 AS `return_rate_pct`,
  1 AS `avg_hours_to_return` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_item_current_custody`
--

DROP TABLE IF EXISTS `v_item_current_custody`;
/*!50001 DROP VIEW IF EXISTS `v_item_current_custody`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_item_current_custody` AS SELECT
 1 AS `item_id`,
  1 AS `holder_id`,
  1 AS `holder_name`,
  1 AS `holder_role`,
  1 AS `held_since`,
  1 AS `storage_place` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_item_overview`
--

DROP TABLE IF EXISTS `v_item_overview`;
/*!50001 DROP VIEW IF EXISTS `v_item_overview`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_item_overview` AS SELECT
 1 AS `item_id`,
  1 AS `title`,
  1 AS `description`,
  1 AS `color`,
  1 AS `brand`,
  1 AS `status`,
  1 AS `found_at`,
  1 AS `registered_at`,
  1 AS `returned_at`,
  1 AS `verification_hint`,
  1 AS `has_hidden_detail`,
  1 AS `category_id`,
  1 AS `category`,
  1 AS `location_id`,
  1 AS `location_name`,
  1 AS `location_type`,
  1 AS `city`,
  1 AS `finder_id`,
  1 AS `finder_name`,
  1 AS `holder_id`,
  1 AS `holder_name`,
  1 AS `storage_place`,
  1 AS `active_claims`,
  1 AS `days_since_found` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_item_timeline`
--

DROP TABLE IF EXISTS `v_item_timeline`;
/*!50001 DROP VIEW IF EXISTS `v_item_timeline`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_item_timeline` AS SELECT
 1 AS `item_id`,
  1 AS `event_time`,
  1 AS `event_type`,
  1 AS `actor`,
  1 AS `detail` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_open_fraud_flags`
--

DROP TABLE IF EXISTS `v_open_fraud_flags`;
/*!50001 DROP VIEW IF EXISTS `v_open_fraud_flags`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_open_fraud_flags` AS SELECT
 1 AS `flag_id`,
  1 AS `reason`,
  1 AS `severity`,
  1 AS `status`,
  1 AS `details`,
  1 AS `created_at`,
  1 AS `user_id`,
  1 AS `user_name`,
  1 AS `user_email`,
  1 AS `item_id`,
  1 AS `item_title`,
  1 AS `claim_id` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_staff_workload`
--

DROP TABLE IF EXISTS `v_staff_workload`;
/*!50001 DROP VIEW IF EXISTS `v_staff_workload`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_staff_workload` AS SELECT
 1 AS `user_id`,
  1 AS `full_name`,
  1 AS `role`,
  1 AS `items_in_custody`,
  1 AS `handovers_completed`,
  1 AS `verifications_done` */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `v_unclaimed_by_location`
--

DROP TABLE IF EXISTS `v_unclaimed_by_location`;
/*!50001 DROP VIEW IF EXISTS `v_unclaimed_by_location`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8mb4;
/*!50001 CREATE VIEW `v_unclaimed_by_location` AS SELECT
 1 AS `location_id`,
  1 AS `location_name`,
  1 AS `location_type`,
  1 AS `city`,
  1 AS `unclaimed_items`,
  1 AS `oldest_found_at`,
  1 AS `avg_age_days` */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `verification_attempts`
--

DROP TABLE IF EXISTS `verification_attempts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `verification_attempts` (
  `attempt_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `claim_id` int(10) unsigned NOT NULL,
  `staff_id` int(10) unsigned NOT NULL,
  `method` enum('HINT_ANSWER','ID_PROOF','ADMIN_OVERRIDE') NOT NULL,
  `outcome` enum('PASS','FAIL') NOT NULL,
  `proof_ref` varchar(120) DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `attempted_at` datetime NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`attempt_id`),
  KEY `fk_va_staff` (`staff_id`),
  KEY `idx_va_claim_outcome` (`claim_id`,`outcome`,`attempted_at`),
  CONSTRAINT `fk_va_claim` FOREIGN KEY (`claim_id`) REFERENCES `claims` (`claim_id`),
  CONSTRAINT `fk_va_staff` FOREIGN KEY (`staff_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=405 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping events for database 'back2you'
--

--
-- Dumping routines for database 'back2you'
--
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_distance_km` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_distance_km`(p_lat1 DECIMAL(9,6), p_lon1 DECIMAL(9,6),
                               p_lat2 DECIMAL(9,6), p_lon2 DECIMAL(9,6)) RETURNS double
    NO SQL
    DETERMINISTIC
BEGIN
  DECLARE a DOUBLE;
  IF p_lat1 IS NULL OR p_lon1 IS NULL OR p_lat2 IS NULL OR p_lon2 IS NULL THEN
    RETURN NULL;
  END IF;
  SET a = POW(SIN(RADIANS(p_lat2 - p_lat1) / 2), 2)
        + COS(RADIANS(p_lat1)) * COS(RADIANS(p_lat2)) * POW(SIN(RADIANS(p_lon2 - p_lon1) / 2), 2);
  RETURN 6371 * 2 * ASIN(LEAST(1, SQRT(a)));
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_hash_answer` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_hash_answer`(p_text VARCHAR(255)) RETURNS char(64) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci
    NO SQL
    DETERMINISTIC
BEGIN
  IF p_text IS NULL OR CHAR_LENGTH(TRIM(p_text)) = 0 THEN
    RETURN NULL;
  END IF;
  RETURN SHA2(LOWER(TRIM(p_text)), 256);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_is_admin` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_is_admin`(p_user_id INT UNSIGNED) RETURNS tinyint(1)
    READS SQL DATA
BEGIN
  DECLARE v_n INT DEFAULT 0;
  SELECT COUNT(*) INTO v_n FROM users
   WHERE user_id = p_user_id AND is_active = 1 AND role = 'admin';
  RETURN v_n > 0;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_is_staff` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_is_staff`(p_user_id INT UNSIGNED) RETURNS tinyint(1)
    READS SQL DATA
BEGIN
  DECLARE v_n INT DEFAULT 0;
  SELECT COUNT(*) INTO v_n FROM users
   WHERE user_id = p_user_id AND is_active = 1 AND role IN ('staff', 'admin');
  RETURN v_n > 0;
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_now` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_now`() RETURNS datetime
    NO SQL
BEGIN
  RETURN CAST(COALESCE(@b2y_now, NOW()) AS DATETIME);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP FUNCTION IF EXISTS `fn_structured_score` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` FUNCTION `fn_structured_score`(p_item_id     INT UNSIGNED,
  p_category_id INT UNSIGNED,
  p_color       VARCHAR(30),
  p_brand       VARCHAR(60),
  p_location_id INT UNSIGNED,
  p_lost_at     DATETIME
) RETURNS decimal(5,4)
    READS SQL DATA
BEGIN
  DECLARE v_cat INT UNSIGNED;
  DECLARE v_color VARCHAR(30);
  DECLARE v_brand VARCHAR(60);
  DECLARE v_loc INT UNSIGNED;
  DECLARE v_found DATETIME;
  DECLARE v_lat DECIMAL(9,6);
  DECLARE v_lon DECIMAL(9,6);
  DECLARE q_lat DECIMAL(9,6);
  DECLARE q_lon DECIMAL(9,6);
  DECLARE v_num DOUBLE DEFAULT 0;
  DECLARE v_den DOUBLE DEFAULT 0;
  DECLARE v_dist DOUBLE;
  DECLARE v_days DOUBLE;
  DECLARE v_part DOUBLE;

  SELECT category_id, color, brand, found_location_id, found_at
    INTO v_cat, v_color, v_brand, v_loc, v_found
    FROM items WHERE item_id = p_item_id;
  IF v_cat IS NULL THEN
    RETURN 0;
  END IF;

  IF p_category_id IS NOT NULL THEN
    SET v_den = v_den + 0.30;
    IF v_cat = p_category_id THEN SET v_num = v_num + 0.30; END IF;
  END IF;

  IF p_color IS NOT NULL AND CHAR_LENGTH(TRIM(p_color)) > 0 THEN
    SET v_den = v_den + 0.15;
    IF v_color IS NOT NULL AND LOWER(TRIM(v_color)) = LOWER(TRIM(p_color)) THEN SET v_num = v_num + 0.15; END IF;
  END IF;

  IF p_brand IS NOT NULL AND CHAR_LENGTH(TRIM(p_brand)) > 0 THEN
    SET v_den = v_den + 0.15;
    IF v_brand IS NOT NULL AND LOWER(TRIM(v_brand)) = LOWER(TRIM(p_brand)) THEN SET v_num = v_num + 0.15; END IF;
  END IF;

  IF p_location_id IS NOT NULL THEN
    SET v_den = v_den + 0.20;
    IF v_loc = p_location_id THEN
      SET v_num = v_num + 0.20;
    ELSE
      SELECT latitude, longitude INTO v_lat, v_lon FROM locations WHERE location_id = v_loc;
      SELECT latitude, longitude INTO q_lat, q_lon FROM locations WHERE location_id = p_location_id;
      SET v_dist = fn_distance_km(v_lat, v_lon, q_lat, q_lon);
      IF v_dist IS NOT NULL THEN
        SET v_num = v_num + 0.20 * GREATEST(0, 1 - v_dist / 20.0);
      END IF;
    END IF;
  END IF;

  IF p_lost_at IS NOT NULL THEN
    SET v_den = v_den + 0.20;
    SET v_days = TIMESTAMPDIFF(HOUR, p_lost_at, v_found) / 24.0;
    IF v_days < -0.25 THEN
      SET v_part = 0;
    ELSEIF v_days <= 3 THEN
      SET v_part = 1;
    ELSEIF v_days <= 30 THEN
      SET v_part = 1 - (v_days - 3) / 27.0;
    ELSE
      SET v_part = 0;
    END IF;
    SET v_num = v_num + 0.20 * v_part;
  END IF;

  IF v_den = 0 THEN
    RETURN 0;
  END IF;
  RETURN ROUND(v_num / v_den, 4);
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_cancel_claim` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_cancel_claim`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_confirm_return` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_confirm_return`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_match_structured` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_match_structured`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_perform_handover` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_perform_handover`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_register_item` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_register_item`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_reject_claim` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_reject_claim`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_report_found_item` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_report_found_item`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_revoke_verification` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_revoke_verification`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_submit_claim` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_submit_claim`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_transfer_custody` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_transfer_custody`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_verify_claim` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_verify_claim`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_withdraw_found_item` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_withdraw_found_item`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = 'IGNORE_SPACE,STRICT_TRANS_TABLES,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' */ ;
/*!50003 DROP PROCEDURE IF EXISTS `sp_write_audit` */;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8mb4 */ ;
/*!50003 SET character_set_results = utf8mb4 */ ;
/*!50003 SET collation_connection  = utf8mb4_unicode_ci */ ;
DELIMITER ;;
CREATE DEFINER=`b2y`@`localhost` PROCEDURE `sp_write_audit`(
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
END ;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;

--
-- Final view structure for view `v_admin_kpis`
--

/*!50001 DROP VIEW IF EXISTS `v_admin_kpis`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_admin_kpis` AS select (select count(0) from `items`) AS `total_items`,(select count(0) from `items` where `items`.`status` = 'RETURNED') AS `returned_items`,(select count(0) from `items` where `items`.`status` in ('REGISTERED','CLAIMED')) AS `open_items`,round(100.0 * (select count(0) from `items` where `items`.`status` = 'RETURNED') / nullif((select count(0) from `items`),0),1) AS `return_rate_pct`,(select round(avg(timestampdiff(MINUTE,`items`.`found_at`,`items`.`returned_at`)) / 60.0,1) from `items` where `items`.`status` = 'RETURNED') AS `avg_hours_to_return`,(select count(0) from `items` where `items`.`status` = 'REGISTERED' and `items`.`registered_at` < current_timestamp() - interval 14 day) AS `unclaimed_over_14d`,(select count(0) from `claims` where `claims`.`status` = 'PENDING') AS `pending_claims`,(select count(0) from `fraud_flags` where `fraud_flags`.`status` = 'OPEN') AS `open_fraud_flags`,(select count(0) from `users`) AS `total_users` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_category_stats`
--

/*!50001 DROP VIEW IF EXISTS `v_category_stats`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_category_stats` AS select `c`.`category_id` AS `category_id`,`c`.`name` AS `category`,count(`i`.`item_id`) AS `total_items`,sum(`i`.`status` = 'RETURNED') AS `returned_items`,round(100.0 * sum(`i`.`status` = 'RETURNED') / nullif(count(`i`.`item_id`),0),1) AS `return_rate_pct`,round(avg(case when `i`.`status` = 'RETURNED' then timestampdiff(MINUTE,`i`.`found_at`,`i`.`returned_at`) / 60.0 end),1) AS `avg_hours_to_return` from (`categories` `c` left join `items` `i` on(`i`.`category_id` = `c`.`category_id`)) group by `c`.`category_id`,`c`.`name` */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_item_current_custody`
--

/*!50001 DROP VIEW IF EXISTS `v_item_current_custody`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_item_current_custody` AS select `c`.`item_id` AS `item_id`,`c`.`holder_id` AS `holder_id`,`u`.`full_name` AS `holder_name`,`u`.`role` AS `holder_role`,`c`.`started_at` AS `held_since`,`c`.`storage_place` AS `storage_place` from (`custody_log` `c` join `users` `u` on(`u`.`user_id` = `c`.`holder_id`)) where `c`.`ended_at` is null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_item_overview`
--

/*!50001 DROP VIEW IF EXISTS `v_item_overview`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_item_overview` AS select `i`.`item_id` AS `item_id`,`i`.`title` AS `title`,`i`.`description` AS `description`,`i`.`color` AS `color`,`i`.`brand` AS `brand`,`i`.`status` AS `status`,`i`.`found_at` AS `found_at`,`i`.`registered_at` AS `registered_at`,`i`.`returned_at` AS `returned_at`,`i`.`verification_hint` AS `verification_hint`,`i`.`verification_hint` is not null AS `has_hidden_detail`,`cat`.`category_id` AS `category_id`,`cat`.`name` AS `category`,`loc`.`location_id` AS `location_id`,`loc`.`name` AS `location_name`,`loc`.`location_type` AS `location_type`,`loc`.`city` AS `city`,`i`.`finder_id` AS `finder_id`,`f`.`full_name` AS `finder_name`,`cu`.`holder_id` AS `holder_id`,`cu`.`holder_name` AS `holder_name`,`cu`.`storage_place` AS `storage_place`,(select count(0) from `claims` `cl` where `cl`.`item_id` = `i`.`item_id` and `cl`.`status` in ('PENDING','VERIFIED','FULFILLED')) AS `active_claims`,to_days(current_timestamp()) - to_days(`i`.`found_at`) AS `days_since_found` from ((((`items` `i` join `categories` `cat` on(`cat`.`category_id` = `i`.`category_id`)) join `locations` `loc` on(`loc`.`location_id` = `i`.`found_location_id`)) join `users` `f` on(`f`.`user_id` = `i`.`finder_id`)) left join `v_item_current_custody` `cu` on(`cu`.`item_id` = `i`.`item_id`)) */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_item_timeline`
--

/*!50001 DROP VIEW IF EXISTS `v_item_timeline`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_item_timeline` AS select `i`.`item_id` AS `item_id`,`i`.`created_at` AS `event_time`,'REPORTED' AS `event_type`,`u`.`full_name` AS `actor`,concat('Reported found: ',`i`.`title`) AS `detail` from (`items` `i` join `users` `u` on(`u`.`user_id` = `i`.`finder_id`)) union all select `c`.`item_id` AS `item_id`,`c`.`started_at` AS `started_at`,'CUSTODY' AS `CUSTODY`,`h`.`full_name` AS `full_name`,concat('Took custody',if(`c`.`from_user_id` is null,'',concat(' from ',`fu`.`full_name`)),if(`c`.`storage_place` is null,'',concat(' - stored at ',`c`.`storage_place`))) AS `Name_exp_5` from ((`custody_log` `c` join `users` `h` on(`h`.`user_id` = `c`.`holder_id`)) left join `users` `fu` on(`fu`.`user_id` = `c`.`from_user_id`)) union all select `cl`.`item_id` AS `item_id`,`cl`.`submitted_at` AS `submitted_at`,'CLAIM_SUBMITTED' AS `CLAIM_SUBMITTED`,`u`.`full_name` AS `full_name`,concat('Claim #',`cl`.`claim_id`,' submitted') AS `CONCAT('Claim #', cl.claim_id, ' submitted')` from (`claims` `cl` join `users` `u` on(`u`.`user_id` = `cl`.`claimant_id`)) union all select `cl`.`item_id` AS `item_id`,`va`.`attempted_at` AS `attempted_at`,'VERIFICATION' AS `VERIFICATION`,`s`.`full_name` AS `full_name`,concat('Claim #',`cl`.`claim_id`,' ',`va`.`method`,' check: ',`va`.`outcome`) AS `Name_exp_5` from ((`verification_attempts` `va` join `claims` `cl` on(`cl`.`claim_id` = `va`.`claim_id`)) join `users` `s` on(`s`.`user_id` = `va`.`staff_id`)) union all select `ho`.`item_id` AS `item_id`,`ho`.`handed_at` AS `handed_at`,'HANDOVER' AS `HANDOVER`,`g`.`full_name` AS `full_name`,concat(`ho`.`handover_type`,': ',`g`.`full_name`,' -> ',`r`.`full_name`,' (proof: ',`ho`.`proof_type`,' ',`ho`.`proof_reference`,')') AS `Name_exp_5` from ((`handovers` `ho` join `users` `g` on(`g`.`user_id` = `ho`.`from_user_id`)) join `users` `r` on(`r`.`user_id` = `ho`.`to_user_id`)) union all select `i`.`item_id` AS `item_id`,`i`.`returned_at` AS `returned_at`,'RETURNED' AS `RETURNED`,`o`.`full_name` AS `full_name`,'Owner confirmed receipt - case closed' AS `Owner confirmed receipt - case closed` from ((`items` `i` join `claims` `cl` on(`cl`.`item_id` = `i`.`item_id` and `cl`.`status` = 'FULFILLED')) join `users` `o` on(`o`.`user_id` = `cl`.`claimant_id`)) where `i`.`returned_at` is not null */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_open_fraud_flags`
--

/*!50001 DROP VIEW IF EXISTS `v_open_fraud_flags`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_open_fraud_flags` AS select `ff`.`flag_id` AS `flag_id`,`ff`.`reason` AS `reason`,`ff`.`severity` AS `severity`,`ff`.`status` AS `status`,`ff`.`details` AS `details`,`ff`.`created_at` AS `created_at`,`ff`.`user_id` AS `user_id`,`u`.`full_name` AS `user_name`,`u`.`email` AS `user_email`,`ff`.`item_id` AS `item_id`,`i`.`title` AS `item_title`,`ff`.`claim_id` AS `claim_id` from ((`fraud_flags` `ff` join `users` `u` on(`u`.`user_id` = `ff`.`user_id`)) left join `items` `i` on(`i`.`item_id` = `ff`.`item_id`)) where `ff`.`status` = 'OPEN' */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_staff_workload`
--

/*!50001 DROP VIEW IF EXISTS `v_staff_workload`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_staff_workload` AS select `u`.`user_id` AS `user_id`,`u`.`full_name` AS `full_name`,`u`.`role` AS `role`,(select count(0) from (`custody_log` `c` join `items` `i` on(`i`.`item_id` = `c`.`item_id`)) where `c`.`holder_id` = `u`.`user_id` and `c`.`ended_at` is null and `i`.`status` in ('REGISTERED','CLAIMED','VERIFIED')) AS `items_in_custody`,(select count(0) from `handovers` `h` where `h`.`from_user_id` = `u`.`user_id` and `h`.`handover_type` = 'STAFF_TO_OWNER') AS `handovers_completed`,(select count(0) from `verification_attempts` `va` where `va`.`staff_id` = `u`.`user_id`) AS `verifications_done` from `users` `u` where `u`.`role` in ('staff','admin') and `u`.`is_active` = 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;

--
-- Final view structure for view `v_unclaimed_by_location`
--

/*!50001 DROP VIEW IF EXISTS `v_unclaimed_by_location`*/;
/*!50001 SET @saved_cs_client          = @@character_set_client */;
/*!50001 SET @saved_cs_results         = @@character_set_results */;
/*!50001 SET @saved_col_connection     = @@collation_connection */;
/*!50001 SET character_set_client      = utf8mb4 */;
/*!50001 SET character_set_results     = utf8mb4 */;
/*!50001 SET collation_connection      = utf8mb4_unicode_ci */;
/*!50001 CREATE ALGORITHM=UNDEFINED */
/*!50013 DEFINER=`b2y`@`localhost` SQL SECURITY DEFINER */
/*!50001 VIEW `v_unclaimed_by_location` AS select `l`.`location_id` AS `location_id`,`l`.`name` AS `location_name`,`l`.`location_type` AS `location_type`,`l`.`city` AS `city`,count(0) AS `unclaimed_items`,min(`i`.`found_at`) AS `oldest_found_at`,round(avg(to_days(current_timestamp()) - to_days(`i`.`found_at`)),1) AS `avg_age_days` from (`items` `i` join `locations` `l` on(`l`.`location_id` = `i`.`found_location_id`)) where `i`.`status` = 'REGISTERED' group by `l`.`location_id`,`l`.`name`,`l`.`location_type`,`l`.`city` having count(0) >= 1 */;
/*!50001 SET character_set_client      = @saved_cs_client */;
/*!50001 SET character_set_results     = @saved_cs_results */;
/*!50001 SET collation_connection      = @saved_col_connection */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-10-17 12:30:26
