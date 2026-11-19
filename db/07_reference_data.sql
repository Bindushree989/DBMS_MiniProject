-- =====================================================================
-- Back2You - 07_reference_data.sql
-- Lookup data: the state machine, categories and locations.
-- =====================================================================

SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Lifecycle state machine. Anything not listed here is rejected by trg_items_bu.
INSERT INTO status_transitions (from_status, to_status, description) VALUES
  ('FOUND',       'REGISTERED',  'Staff takes custody and catalogues the item'),
  ('REGISTERED',  'CLAIMED',     'First pending claim submitted'),
  ('CLAIMED',     'REGISTERED',  'All pending claims withdrawn or rejected'),
  ('CLAIMED',     'VERIFIED',    'Ownership of one claim verified by staff'),
  ('VERIFIED',    'REGISTERED',  'Verification revoked before handover'),
  ('VERIFIED',    'HANDED_OVER', 'Staff hands the item to the verified owner'),
  ('HANDED_OVER', 'RETURNED',    'Owner confirms receipt; case closed');

INSERT INTO categories (name) VALUES
  ('Phone'), ('Wallet'), ('Bag'), ('Keys'), ('Laptop'), ('Earphones'),
  ('ID / Cards'), ('Clothing'), ('Watch / Jewellery'), ('Water Bottle'),
  ('Umbrella'), ('Spectacles'), ('Documents'), ('Other');

INSERT INTO locations (name, location_type, city, latitude, longitude) VALUES
  ('Cab - Airport Route',             'cab',     'Bengaluru', 13.198900, 77.706300),
  ('Cab - City Rides',                'cab',     'Bengaluru', 12.971600, 77.594600),
  ('BMTC Bus - Route 500D',           'bus',     'Bengaluru', 12.935200, 77.614300),
  ('Kempegowda Bus Station (Majestic)','bus',    'Bengaluru', 12.977900, 77.572700),
  ('Namma Metro - MG Road',           'metro',   'Bengaluru', 12.975600, 77.606700),
  ('Namma Metro - Indiranagar',       'metro',   'Bengaluru', 12.978400, 77.640800),
  ('College Main Library',            'college', 'Bengaluru', 12.923500, 77.498300),
  ('College CSE Block',               'college', 'Bengaluru', 12.923900, 77.499100),
  ('College Canteen',                 'college', 'Bengaluru', 12.922800, 77.498000),
  ('Boys Hostel Block A',             'hostel',  'Bengaluru', 12.921700, 77.500200),
  ('Girls Hostel Block B',            'hostel',  'Bengaluru', 12.921200, 77.497200),
  ('Tech Park Cafeteria - Whitefield','office',  'Bengaluru', 12.969800, 77.749900),
  ('Office Reception - Koramangala',  'office',  'Bengaluru', 12.935200, 77.624500),
  ('Cubbon Park',                     'public',  'Bengaluru', 12.976400, 77.592900),
  ('Phoenix Mall - Food Court',       'public',  'Bengaluru', 13.011100, 77.554900);
