-- =========================================
-- V1__init.sql
-- Dual local/UTC datetime model for events.
-- - *_local : DATETIME(3)  (wall-clock, human meaning)
-- - *_utc   : TIMESTAMP(3) (canonical instant, UTC)
-- - timezone (IANA) + offset_minutes stored with rows
-- Audit columns use TIMESTAMP(3) in UTC.
-- =========================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- =========================
-- VENUE & ROOM
-- =========================
CREATE TABLE venue (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name            VARCHAR(200)    NOT NULL,
  slug            VARCHAR(200)    NULL,
  address_line1   VARCHAR(200)    NOT NULL,
  address_line2   VARCHAR(200)    NULL,
  city            VARCHAR(100)    NOT NULL,
  state           CHAR(2)         NOT NULL,
  zip_code        VARCHAR(10)     NOT NULL,
  created_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_venue_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE room (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  venue_id   BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(120)    NOT NULL,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_room_venue (venue_id),
  CONSTRAINT fk_room_venue FOREIGN KEY (venue_id) REFERENCES venue(id) ON DELETE CASCADE,
  UNIQUE KEY uq_room_venue_name (venue_id, name),
  UNIQUE KEY uq_room_id_venue (id, venue_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- MUSIC GENRE
-- =========================
CREATE TABLE music_genre (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code       VARCHAR(64)     NOT NULL,
  label      VARCHAR(100)    NOT NULL,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_genre_code (code),
  UNIQUE KEY uq_genre_label (label)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- PARTY / HOST MODEL
-- =========================
CREATE TABLE party (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  type         ENUM('PERSON','GROUP') NOT NULL,
  display_name VARCHAR(200)    NOT NULL,
  slug         VARCHAR(200)    NULL,
  created_at   TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at   TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_party_type (type),
  UNIQUE KEY uq_party_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE person_profile (
  party_id     BIGINT UNSIGNED NOT NULL,
  first_name   VARCHAR(120)    NULL,
  last_name    VARCHAR(120)    NULL,
  stage_name   VARCHAR(200)    NULL,
  bio          TEXT            NULL,
  avatar_url   VARCHAR(500)    NULL,
  instagram    VARCHAR(200)    NULL,
  tiktok       VARCHAR(200)    NULL,
  facebook     VARCHAR(200)    NULL,
  PRIMARY KEY (party_id),
  CONSTRAINT fk_person_party FOREIGN KEY (party_id) REFERENCES party(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE group_profile (
  party_id     BIGINT UNSIGNED NOT NULL,
  group_name   VARCHAR(200)    NOT NULL,
  bio          TEXT            NULL,
  avatar_url   VARCHAR(500)    NULL,
  instagram    VARCHAR(200)    NULL,
  tiktok       VARCHAR(200)    NULL,
  facebook     VARCHAR(200)    NULL,
  PRIMARY KEY (party_id),
  CONSTRAINT fk_group_party FOREIGN KEY (party_id) REFERENCES party(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE group_member (
  group_id    BIGINT UNSIGNED NOT NULL,  -- party.id where type=GROUP
  member_id   BIGINT UNSIGNED NOT NULL,  -- party.id where type=PERSON
  role        VARCHAR(120)    NULL,
  sort_order  INT             NOT NULL DEFAULT 0,
  created_at  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (group_id, member_id),
  KEY idx_group_member_member (member_id),
  CONSTRAINT fk_gm_group  FOREIGN KEY (group_id)  REFERENCES party(id) ON DELETE CASCADE,
  CONSTRAINT fk_gm_member FOREIGN KEY (member_id) REFERENCES party(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT & RELATED (dual local/UTC)
-- =========================
CREATE TABLE event (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_event_id  BIGINT UNSIGNED NULL,   -- for recurrence instances (optional)
  venue_id         BIGINT UNSIGNED NOT NULL,
  room_id          BIGINT UNSIGNED NULL,   -- must belong to venue (composite FK below)
  title            VARCHAR(200)    NOT NULL,
  description      TEXT            NULL,
  background_url   VARCHAR(500)    NULL,

  -- Local wall-clock times (what users see & enter)
  start_time_local DATETIME(3)     NOT NULL,
  end_time_local   DATETIME(3)     NOT NULL,
  timezone         VARCHAR(64)     NOT NULL,       -- IANA TZ, e.g., 'America/New_York'
  offset_minutes   SMALLINT        NOT NULL,       -- UTC offset at start (e.g., -240)

  -- Canonical UTC instants
  start_time_utc   TIMESTAMP(3)    NOT NULL,
  end_time_utc     TIMESTAMP(3)    NOT NULL,

  -- Audit
  created_at       TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at       TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),

  -- helpful indexes
  KEY idx_event_parent (parent_event_id),
  KEY idx_event_room (room_id),
  KEY idx_event_start_utc (start_time_utc),
  KEY idx_event_venue_start_utc (venue_id, start_time_utc),
  KEY idx_event_start_local (start_time_local),

  -- FKs
  CONSTRAINT fk_event_parent FOREIGN KEY (parent_event_id)
    REFERENCES event(id) ON DELETE SET NULL,

  CONSTRAINT fk_event_venue FOREIGN KEY (venue_id)
    REFERENCES venue(id) ON DELETE RESTRICT,

  -- if a room is deleted, just null out room_id on events
  CONSTRAINT fk_event_room FOREIGN KEY (room_id)
    REFERENCES room(id) ON DELETE SET NULL,

  -- ensure chosen room belongs to the same venue; do NOT set null here
  CONSTRAINT fk_event_room_matches_venue FOREIGN KEY (room_id, venue_id)
    REFERENCES room(id, venue_id)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_prize (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id   BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(200)    NOT NULL,
  sort_order INT             NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_prize_event (event_id, sort_order),
  CONSTRAINT fk_prize_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_music_genre (
  event_id   BIGINT UNSIGNED NOT NULL,
  genre_id   BIGINT UNSIGNED NOT NULL,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (event_id, genre_id),
  KEY idx_emg_genre (genre_id),
  CONSTRAINT fk_emg_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
  CONSTRAINT fk_emg_genre FOREIGN KEY (genre_id) REFERENCES music_genre(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_host (
  event_id   BIGINT UNSIGNED NOT NULL,
  party_id   BIGINT UNSIGNED NOT NULL,
  role       VARCHAR(120)    NULL,   -- Headliner, MC, Opening Act, etc.
  sort_order INT             NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (event_id, party_id),
  KEY idx_event_host_party (party_id, event_id),
  CONSTRAINT fk_eh_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
  CONSTRAINT fk_eh_party FOREIGN KEY (party_id) REFERENCES party(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT GROUPING / SERIES
-- =========================
CREATE TABLE event_group (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(200)    NOT NULL,
  slug        VARCHAR(200)    NULL,
  description TEXT            NULL,
  created_at  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at  TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_event_group_slug (slug),
  KEY idx_event_group_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_group_event (
  group_id   BIGINT UNSIGNED NOT NULL,
  event_id   BIGINT UNSIGNED NOT NULL,
  sort_order INT             NOT NULL DEFAULT 0,
  created_at TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (group_id, event_id),
  KEY idx_ege_event (event_id),
  CONSTRAINT fk_ege_group FOREIGN KEY (group_id) REFERENCES event_group(id) ON DELETE CASCADE,
  CONSTRAINT fk_ege_event FOREIGN KEY (event_id)  REFERENCES event(id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT RECURRENCE (dual local/UTC)
-- =========================
CREATE TABLE event_recurrence_rule (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id        BIGINT UNSIGNED NOT NULL,     -- template/base event
  rrule           VARCHAR(500)    NOT NULL,     -- RFC5545 string

  -- Local anchor (what humans expect)
  dtstart_local   DATETIME(3)     NOT NULL,
  dtend_local     DATETIME(3)     NOT NULL,
  timezone        VARCHAR(64)     NOT NULL DEFAULT 'UTC',
  offset_minutes  SMALLINT        NOT NULL,     -- offset at dtstart

  -- Canonical UTC anchors (first occurrence / convenience)
  dtstart_utc     TIMESTAMP(3)    NOT NULL,
  dtend_utc       TIMESTAMP(3)    NOT NULL,

  -- Optional UNTIL/COUNT in local, plus UTC mirror (nullable)
  until_at_local  DATETIME(3)     NULL,
  until_at_utc    TIMESTAMP(3)    NULL,
  count_occurrences INT           NULL,

  created_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_rrule_event (event_id),
  CONSTRAINT fk_rrule_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_recurrence_exception (
  rule_id       BIGINT UNSIGNED NOT NULL,
  exdate_local  DATETIME(3)     NOT NULL,
  exdate_utc    TIMESTAMP(3)    NOT NULL,
  PRIMARY KEY (rule_id, exdate_local),
  KEY idx_exception_exdate_local (exdate_local),
  KEY idx_exception_exdate_utc (exdate_utc),
  CONSTRAINT fk_exception_rule FOREIGN KEY (rule_id) REFERENCES event_recurrence_rule(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- MATERIALIZED OCCURRENCES (optional)
-- =========================
CREATE TABLE event_instance (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  rule_id         BIGINT UNSIGNED NOT NULL,
  occurrence_num  INT             NOT NULL,        -- nth instance generated
  event_id        BIGINT UNSIGNED NOT NULL,        -- concrete event row
  status          ENUM('SCHEDULED','CANCELLED','MOVED') NOT NULL DEFAULT 'SCHEDULED',
  created_at      TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_instance_rule_occurrence (rule_id, occurrence_num),
  KEY idx_instance_event (event_id),
  CONSTRAINT fk_instance_rule  FOREIGN KEY (rule_id)  REFERENCES event_recurrence_rule(id) ON DELETE CASCADE,
  CONSTRAINT fk_instance_event FOREIGN KEY (event_id) REFERENCES event(id)                 ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- ASSET CATALOG (metadata only)
-- =========================
CREATE TABLE asset (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  content_sha256 CHAR(64)        NOT NULL,
  mime_type      VARCHAR(100)    NOT NULL,
  byte_size      BIGINT UNSIGNED NOT NULL,
  width_px       INT             NULL,
  height_px      INT             NULL,
  duration_ms    INT             NULL,
  created_at     TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_hash (content_sha256),
  KEY idx_asset_mime (mime_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_location (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  provider     ENUM('CDN_SERVER','S3','GCS','LOCAL') NOT NULL,
  storage_key  VARCHAR(500)    NOT NULL,
  public_url   VARCHAR(1000)   NULL,
  is_primary   TINYINT(1)      NOT NULL DEFAULT 1,
  created_at   TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_primary (asset_id, is_primary),
  KEY idx_location_asset (asset_id),
  CONSTRAINT fk_location_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_variant (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  variant_code VARCHAR(64)     NOT NULL,
  mime_type    VARCHAR(100)    NOT NULL,
  width_px     INT             NULL,
  height_px    INT             NULL,
  byte_size    BIGINT UNSIGNED NULL,
  storage_key  VARCHAR(500)    NOT NULL,
  public_url   VARCHAR(1000)   NULL,
  created_at   TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_variant (asset_id, variant_code),
  KEY idx_variant_asset (asset_id),
  CONSTRAINT fk_variant_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_link (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  object_type  ENUM('EVENT','VENUE','PARTY','ROOM','PERSON_PROFILE','GROUP_PROFILE') NOT NULL,
  object_id    BIGINT UNSIGNED NOT NULL,
  relation     ENUM('HERO','GALLERY','AVATAR','BANNER','BACKGROUND','OTHER') NOT NULL DEFAULT 'GALLERY',
  sort_order   INT             NOT NULL DEFAULT 0,
  created_at   TIMESTAMP(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_link_lookup (object_type, object_id, relation, sort_order),
  KEY idx_link_asset (asset_id),
  CONSTRAINT fk_link_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_tag (
  asset_id BIGINT UNSIGNED NOT NULL,
  tag      VARCHAR(64)     NOT NULL,
  PRIMARY KEY (asset_id, tag),
  KEY idx_tag_tag (tag),
  CONSTRAINT fk_tag_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;