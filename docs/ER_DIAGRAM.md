# ER Diagram & Data Dictionary

Generated from the live schema.

```mermaid
erDiagram
  audit_chain_head {
    tinyint_4_ id PK
    char_64_ last_hash
  }
  audit_log {
    bigint_20_ audit_id PK
    varchar_40_ table_name
    bigint_20_ record_id
    enum_'INSERT'_'UPDATE'_'DELETE'_ action
    longtext old_values
    longtext new_values
    int_11_ changed_by
    datetime_3_ changed_at
    char_64_ prev_hash
    char_64_ row_hash
  }
  categories {
    int_11_ category_id PK
    varchar_60_ name
    tinyint_1_ is_high_value
  }
  claims {
    int_11_ claim_id PK
    int_11_ item_id FK
    int_11_ claimant_id FK
    int_11_ report_id FK
    text description
    tinyint_1_ answer_match
    decimal_5_4_ match_score
    enum_'PENDING'_'VERIFIED'_'REJECTED'_'WITHDRAWN'_ status
    int_11_ reviewed_by FK
    varchar_255_ review_notes
    datetime created_at
    datetime reviewed_at
    tinyint_4_ verified_flag
  }
  custody_log {
    int_11_ custody_id PK
    int_11_ item_id FK
    int_11_ holder_id FK
    int_11_ received_from FK
    enum_'FOUND_BY_FINDER'_'ACCEPTED_BY_STAFF'_'TRANSFERRED'_'HANDED_TO_OWNER'_ event
    datetime start_at
    datetime end_at
    varchar_255_ note
    tinyint_4_ active_flag
  }
  fraud_flags {
    int_11_ flag_id PK
    int_11_ user_id FK
    int_11_ item_id FK
    enum_'MANY_CLAIMS'_'MULTIPLE_CLAIMANTS'_'REPEATED_WRONG_ANSWER'_ flag_type
    varchar_255_ details
    enum_'OPEN'_'DISMISSED'_'CONFIRMED'_ status
    datetime created_at
    int_11_ resolved_by FK
    datetime resolved_at
  }
  handovers {
    int_11_ handover_id PK
    int_11_ item_id FK
    int_11_ claim_id FK
    int_11_ given_by FK
    int_11_ received_by FK
    datetime handed_at
    enum_'ID_CARD'_'OTP'_'SIGNATURE'_'PHOTO'_ proof_type
    varchar_200_ proof_ref
    varchar_255_ notes
  }
  items {
    int_11_ item_id PK
    varchar_120_ title
    text description
    int_11_ category_id FK
    varchar_30_ color
    varchar_60_ brand
    int_11_ location_id FK
    datetime found_at
    int_11_ finder_id FK
    int_11_ current_holder_id FK
    varchar_200_ verification_question
    char_64_ verification_answer_hash
    enum_'FOUND'_'REGISTERED'_'CLAIMED'_'VERIFIED'_'HANDED_OVER'_'RETURNED'_ status
    datetime created_at
    datetime updated_at
    datetime returned_at
  }
  locations {
    int_11_ location_id PK
    varchar_120_ name
    enum_'cab'_'bus'_'college'_'hostel'_'office'_'metro'_'public'_ loc_type
    varchar_60_ city
    decimal_9_6_ latitude
    decimal_9_6_ longitude
    tinyint_1_ is_staffed
  }
  lost_reports {
    int_11_ report_id PK
    int_11_ owner_id FK
    varchar_120_ title
    text description
    int_11_ category_id FK
    varchar_30_ color
    varchar_60_ brand
    int_11_ lost_location_id FK
    datetime lost_at
    enum_'OPEN'_'MATCHED'_'CLOSED'_ status
    datetime created_at
  }
  users {
    int_11_ user_id PK
    varchar_100_ full_name
    varchar_150_ email
    varchar_20_ phone
    varchar_100_ password_hash
    enum_'user'_'staff'_'admin'_ role
    tinyint_1_ is_active
    datetime created_at
  }
  verification_attempts {
    int_11_ attempt_id PK
    int_11_ claim_id FK
    int_11_ claimant_id FK
    varchar_200_ submitted_answer
    tinyint_1_ is_correct
    datetime attempted_at
  }
  categories ||--o{ items : "category_id"
  users ||--o{ items : "finder_id"
  users ||--o{ items : "current_holder_id"
  locations ||--o{ items : "location_id"
  categories ||--o{ lost_reports : "category_id"
  locations ||--o{ lost_reports : "lost_location_id"
  users ||--o{ lost_reports : "owner_id"
  users ||--o{ claims : "claimant_id"
  items ||--o{ claims : "item_id"
  lost_reports ||--o{ claims : "report_id"
  users ||--o{ claims : "reviewed_by"
  claims ||--o{ verification_attempts : "claim_id"
  users ||--o{ verification_attempts : "claimant_id"
  items ||--o{ fraud_flags : "item_id"
  users ||--o{ fraud_flags : "resolved_by"
  users ||--o{ fraud_flags : "user_id"
  claims ||--o{ handovers : "claim_id"
  users ||--o{ handovers : "given_by"
  items ||--o{ handovers : "item_id"
  users ||--o{ handovers : "received_by"
  users ||--o{ custody_log : "received_from"
  users ||--o{ custody_log : "holder_id"
  items ||--o{ custody_log : "item_id"
```

## Data dictionary

### audit_chain_head
| Column | Type | Key | Nullable |
|---|---|---|---|
| id | tinyint(4) | PRI | NO |
| last_hash | char(64) |  | NO |

### audit_log
| Column | Type | Key | Nullable |
|---|---|---|---|
| audit_id | bigint(20) | PRI | NO |
| table_name | varchar(40) | MUL | NO |
| record_id | bigint(20) |  | NO |
| action | enum('INSERT','UPDATE','DELETE') |  | NO |
| old_values | longtext |  | YES |
| new_values | longtext |  | YES |
| changed_by | int(11) |  | YES |
| changed_at | datetime(3) | MUL | NO |
| prev_hash | char(64) |  | NO |
| row_hash | char(64) |  | NO |

### categories
| Column | Type | Key | Nullable |
|---|---|---|---|
| category_id | int(11) | PRI | NO |
| name | varchar(60) | UNI | NO |
| is_high_value | tinyint(1) |  | NO |

### claims
| Column | Type | Key | Nullable |
|---|---|---|---|
| claim_id | int(11) | PRI | NO |
| item_id | int(11) | MUL | NO |
| claimant_id | int(11) | MUL | NO |
| report_id | int(11) | MUL | YES |
| description | text |  | NO |
| answer_match | tinyint(1) |  | NO |
| match_score | decimal(5,4) |  | YES |
| status | enum('PENDING','VERIFIED','REJECTED','WITHDRAWN') | MUL | NO |
| reviewed_by | int(11) | MUL | YES |
| review_notes | varchar(255) |  | YES |
| created_at | datetime |  | NO |
| reviewed_at | datetime |  | YES |
| verified_flag | tinyint(4) |  | YES |

### custody_log
| Column | Type | Key | Nullable |
|---|---|---|---|
| custody_id | int(11) | PRI | NO |
| item_id | int(11) | MUL | NO |
| holder_id | int(11) | MUL | NO |
| received_from | int(11) | MUL | YES |
| event | enum('FOUND_BY_FINDER','ACCEPTED_BY_STAFF','TRANSFERRED','HANDED_TO_OWNER') |  | NO |
| start_at | datetime |  | NO |
| end_at | datetime |  | YES |
| note | varchar(255) |  | YES |
| active_flag | tinyint(4) |  | YES |

### fraud_flags
| Column | Type | Key | Nullable |
|---|---|---|---|
| flag_id | int(11) | PRI | NO |
| user_id | int(11) | MUL | NO |
| item_id | int(11) | MUL | YES |
| flag_type | enum('MANY_CLAIMS','MULTIPLE_CLAIMANTS','REPEATED_WRONG_ANSWER') |  | NO |
| details | varchar(255) |  | YES |
| status | enum('OPEN','DISMISSED','CONFIRMED') | MUL | NO |
| created_at | datetime |  | NO |
| resolved_by | int(11) | MUL | YES |
| resolved_at | datetime |  | YES |

### handovers
| Column | Type | Key | Nullable |
|---|---|---|---|
| handover_id | int(11) | PRI | NO |
| item_id | int(11) | UNI | NO |
| claim_id | int(11) | UNI | NO |
| given_by | int(11) | MUL | NO |
| received_by | int(11) | MUL | NO |
| handed_at | datetime |  | NO |
| proof_type | enum('ID_CARD','OTP','SIGNATURE','PHOTO') |  | NO |
| proof_ref | varchar(200) |  | NO |
| notes | varchar(255) |  | YES |

### items
| Column | Type | Key | Nullable |
|---|---|---|---|
| item_id | int(11) | PRI | NO |
| title | varchar(120) | MUL | NO |
| description | text |  | NO |
| category_id | int(11) | MUL | NO |
| color | varchar(30) |  | YES |
| brand | varchar(60) |  | YES |
| location_id | int(11) | MUL | NO |
| found_at | datetime |  | NO |
| finder_id | int(11) | MUL | NO |
| current_holder_id | int(11) | MUL | YES |
| verification_question | varchar(200) |  | NO |
| verification_answer_hash | char(64) |  | NO |
| status | enum('FOUND','REGISTERED','CLAIMED','VERIFIED','HANDED_OVER','RETURNED') | MUL | NO |
| created_at | datetime |  | NO |
| updated_at | datetime |  | NO |
| returned_at | datetime |  | YES |

### locations
| Column | Type | Key | Nullable |
|---|---|---|---|
| location_id | int(11) | PRI | NO |
| name | varchar(120) | MUL | NO |
| loc_type | enum('cab','bus','college','hostel','office','metro','public') |  | NO |
| city | varchar(60) |  | NO |
| latitude | decimal(9,6) |  | NO |
| longitude | decimal(9,6) |  | NO |
| is_staffed | tinyint(1) |  | NO |

### lost_reports
| Column | Type | Key | Nullable |
|---|---|---|---|
| report_id | int(11) | PRI | NO |
| owner_id | int(11) | MUL | NO |
| title | varchar(120) |  | NO |
| description | text |  | NO |
| category_id | int(11) | MUL | NO |
| color | varchar(30) |  | YES |
| brand | varchar(60) |  | YES |
| lost_location_id | int(11) | MUL | NO |
| lost_at | datetime |  | NO |
| status | enum('OPEN','MATCHED','CLOSED') |  | NO |
| created_at | datetime |  | NO |

### users
| Column | Type | Key | Nullable |
|---|---|---|---|
| user_id | int(11) | PRI | NO |
| full_name | varchar(100) |  | NO |
| email | varchar(150) | UNI | NO |
| phone | varchar(20) |  | YES |
| password_hash | varchar(100) |  | NO |
| role | enum('user','staff','admin') |  | NO |
| is_active | tinyint(1) |  | NO |
| created_at | datetime |  | NO |

### verification_attempts
| Column | Type | Key | Nullable |
|---|---|---|---|
| attempt_id | int(11) | PRI | NO |
| claim_id | int(11) | MUL | NO |
| claimant_id | int(11) | MUL | NO |
| submitted_answer | varchar(200) |  | NO |
| is_correct | tinyint(1) |  | NO |
| attempted_at | datetime |  | NO |
