-- =====================================================================
-- Back2You - 03_functions.sql   (stored functions)
-- NOTE: regenerated from the live database after the original file was
-- overwritten by mistake (2026-10-17). Same objects, header comments lost.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;
DROP FUNCTION IF EXISTS fn_distance_km;
DROP FUNCTION IF EXISTS fn_hash_answer;
DROP FUNCTION IF EXISTS fn_is_admin;
DROP FUNCTION IF EXISTS fn_is_staff;
DROP FUNCTION IF EXISTS fn_now;
DROP FUNCTION IF EXISTS fn_structured_score;

DELIMITER $$

CREATE FUNCTION `fn_distance_km`(p_lat1 DECIMAL(9,6), p_lon1 DECIMAL(9,6),
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
END$$

CREATE FUNCTION `fn_hash_answer`(p_text VARCHAR(255)) RETURNS char(64) CHARSET utf8mb4 COLLATE utf8mb4_unicode_ci
    NO SQL
    DETERMINISTIC
BEGIN
  IF p_text IS NULL OR CHAR_LENGTH(TRIM(p_text)) = 0 THEN
    RETURN NULL;
  END IF;
  RETURN SHA2(LOWER(TRIM(p_text)), 256);
END$$

CREATE FUNCTION `fn_is_admin`(p_user_id INT UNSIGNED) RETURNS tinyint(1)
    READS SQL DATA
BEGIN
  DECLARE v_n INT DEFAULT 0;
  SELECT COUNT(*) INTO v_n FROM users
   WHERE user_id = p_user_id AND is_active = 1 AND role = 'admin';
  RETURN v_n > 0;
END$$

CREATE FUNCTION `fn_is_staff`(p_user_id INT UNSIGNED) RETURNS tinyint(1)
    READS SQL DATA
BEGIN
  DECLARE v_n INT DEFAULT 0;
  SELECT COUNT(*) INTO v_n FROM users
   WHERE user_id = p_user_id AND is_active = 1 AND role IN ('staff', 'admin');
  RETURN v_n > 0;
END$$

CREATE FUNCTION `fn_now`() RETURNS datetime
    NO SQL
BEGIN
  RETURN CAST(COALESCE(@b2y_now, NOW()) AS DATETIME);
END$$

CREATE FUNCTION `fn_structured_score`(p_item_id     INT UNSIGNED,
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
END$$

DELIMITER ;
