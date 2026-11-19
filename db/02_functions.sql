-- =====================================================================
-- Back2You  |  02_functions.sql  |  Stored functions
-- =====================================================================
USE back2you;
DROP FUNCTION IF EXISTS fn_now;
DROP FUNCTION IF EXISTS fn_answer_hash;
DROP FUNCTION IF EXISTS fn_role;
DROP FUNCTION IF EXISTS fn_distance_km;
DROP FUNCTION IF EXISTS fn_match_score;

DELIMITER $$

-- Business clock. Normal operation: NOW(). The seeder sets @b2y_now to
-- replay realistic history without touching the server clock.
CREATE FUNCTION fn_now() RETURNS DATETIME
  NO SQL
BEGIN
  RETURN COALESCE(CAST(@b2y_now AS DATETIME), NOW());
END$$

-- Normalised hash of the hidden verification detail (case/space-insensitive)
CREATE FUNCTION fn_answer_hash(p_answer VARCHAR(200)) RETURNS CHAR(64)
  DETERMINISTIC NO SQL
BEGIN
  RETURN SHA2(LOWER(TRIM(p_answer)), 256);
END$$

CREATE FUNCTION fn_role(p_user INT) RETURNS VARCHAR(10)
  READS SQL DATA
BEGIN
  DECLARE r VARCHAR(10);
  SELECT role INTO r FROM users WHERE user_id = p_user AND is_active = 1;
  RETURN r;
END$$

-- Haversine great-circle distance in km
CREATE FUNCTION fn_distance_km(lat1 DECIMAL(9,6), lon1 DECIMAL(9,6),
                               lat2 DECIMAL(9,6), lon2 DECIMAL(9,6)) RETURNS DOUBLE
  DETERMINISTIC NO SQL
BEGIN
  RETURN 6371 * 2 * ASIN(SQRT(
      POWER(SIN(RADIANS(lat2 - lat1) / 2), 2) +
      COS(RADIANS(lat1)) * COS(RADIANS(lat2)) *
      POWER(SIN(RADIANS(lon2 - lon1) / 2), 2)));
END$$

-- Structured half of the hybrid matcher (0..1).
--   category 0.30 | colour 0.15 | brand 0.15 | location 0.20 | time 0.20
CREATE FUNCTION fn_match_score(p_item INT, p_report INT) RETURNS DECIMAL(5,4)
  READS SQL DATA
BEGIN
  DECLARE s DOUBLE DEFAULT 0;
  DECLARE i_cat INT; DECLARE i_col VARCHAR(30); DECLARE i_brand VARCHAR(60);
  DECLARE i_found DATETIME; DECLARE i_lat DECIMAL(9,6); DECLARE i_lon DECIMAL(9,6);
  DECLARE r_cat INT; DECLARE r_col VARCHAR(30); DECLARE r_brand VARCHAR(60);
  DECLARE r_lost DATETIME; DECLARE r_lat DECIMAL(9,6); DECLARE r_lon DECIMAL(9,6);
  DECLARE km DOUBLE; DECLARE days_gap DOUBLE;

  SELECT i.category_id, i.color, i.brand, i.found_at, l.latitude, l.longitude
    INTO i_cat, i_col, i_brand, i_found, i_lat, i_lon
    FROM items i JOIN locations l ON l.location_id = i.location_id
   WHERE i.item_id = p_item;

  SELECT r.category_id, r.color, r.brand, r.lost_at, l.latitude, l.longitude
    INTO r_cat, r_col, r_brand, r_lost, r_lat, r_lon
    FROM lost_reports r JOIN locations l ON l.location_id = r.lost_location_id
   WHERE r.report_id = p_report;

  IF i_cat IS NULL OR r_cat IS NULL THEN RETURN 0; END IF;

  IF i_cat = r_cat THEN SET s = s + 0.30; END IF;
  IF i_col   IS NOT NULL AND r_col   IS NOT NULL AND LOWER(i_col)   = LOWER(r_col)   THEN SET s = s + 0.15; END IF;
  IF i_brand IS NOT NULL AND r_brand IS NOT NULL AND LOWER(i_brand) = LOWER(r_brand) THEN SET s = s + 0.15; END IF;

  SET km = fn_distance_km(i_lat, i_lon, r_lat, r_lon);
  IF km <= 2 THEN SET s = s + 0.20;
  ELSEIF km <= 10 THEN SET s = s + 0.12;
  ELSEIF km <= 50 THEN SET s = s + 0.05;
  END IF;

  -- an item can only be found AFTER it was lost
  SET days_gap = TIMESTAMPDIFF(HOUR, r_lost, i_found) / 24.0;
  IF days_gap >= -0.25 THEN
    IF days_gap <= 3 THEN SET s = s + 0.20;
    ELSEIF days_gap <= 14 THEN SET s = s + 0.12;
    ELSEIF days_gap <= 60 THEN SET s = s + 0.05;
    END IF;
  END IF;

  RETURN ROUND(s, 4);
END$$

DELIMITER ;
