-- =========================================
-- V1__init.sql
-- Platform schema for venues, events, hosts,
-- assets, recurrence, and event grouping.
-- All times are DATETIME(3) with UTC defaults.
-- =========================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- =========================
-- VENUE & ROOM
-- =========================
CREATE TABLE venue (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name            VARCHAR(200)    NOT NULL,
  slug            VARCHAR(200)    NULL,  -- optional friendly id for apps/URLs
  address_line1   VARCHAR(200)    NOT NULL,
  address_line2   VARCHAR(200)    NULL,
  city            VARCHAR(100)    NOT NULL,
  state           CHAR(2)         NOT NULL,
  zip_code        VARCHAR(10)     NOT NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at      DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_venue_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE room (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  venue_id   BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(120)    NOT NULL,
  created_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_room_venue (venue_id),
  CONSTRAINT fk_room_venue FOREIGN KEY (venue_id) REFERENCES venue(id) ON DELETE CASCADE,
  UNIQUE KEY uq_room_venue_name (venue_id, name),
  -- For composite FK from event to ensure room belongs to venue
  UNIQUE KEY uq_room_id_venue (id, venue_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- MUSIC GENRE
-- =========================
CREATE TABLE music_genre (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code       VARCHAR(64)     NOT NULL,   -- e.g., POP
  label      VARCHAR(100)    NOT NULL,   -- e.g., Pop
  created_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
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
  created_at   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
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
  avatar_url   VARCHAR(500)    NULL,  -- optional legacy convenience (migrate to asset_link)
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
  avatar_url   VARCHAR(500)    NULL,  -- optional legacy convenience (migrate to asset_link)
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
  created_at  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (group_id, member_id),
  KEY idx_group_member_member (member_id),
  CONSTRAINT fk_gm_group  FOREIGN KEY (group_id)  REFERENCES party(id) ON DELETE CASCADE,
  CONSTRAINT fk_gm_member FOREIGN KEY (member_id) REFERENCES party(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT & RELATED
-- =========================
CREATE TABLE event (
  id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  parent_event_id  BIGINT UNSIGNED NULL,   -- for recurrence instances (optional)
  venue_id         BIGINT UNSIGNED NOT NULL,
  room_id          BIGINT UNSIGNED NULL,   -- must belong to venue (composite FK below)
  title            VARCHAR(200)    NOT NULL,
  description      TEXT            NULL,
  background_url   VARCHAR(500)    NULL,   -- legacy convenience (migrate to asset_link)
  start_time       DATETIME(3)     NOT NULL,   -- store UTC
  end_time         DATETIME(3)     NOT NULL,   -- store UTC
  created_at       DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at       DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_event_parent (parent_event_id),
  KEY idx_event_room (room_id),
  KEY idx_event_start (start_time),
  -- Common mobile query: upcoming by venue
  KEY idx_event_venue_start (venue_id, start_time),

  CONSTRAINT fk_event_parent FOREIGN KEY (parent_event_id) REFERENCES event(id) ON DELETE SET NULL,
  CONSTRAINT fk_event_venue  FOREIGN KEY (venue_id)        REFERENCES venue(id) ON DELETE RESTRICT,
  CONSTRAINT fk_event_room   FOREIGN KEY (room_id)         REFERENCES room(id)  ON DELETE SET NULL,

  -- Enforce: selected room must belong to the event's venue
  CONSTRAINT fk_event_room_matches_venue FOREIGN KEY (room_id, venue_id)
    REFERENCES room(id, venue_id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_prize (
  id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id   BIGINT UNSIGNED NOT NULL,
  name       VARCHAR(200)    NOT NULL,
  sort_order INT             NOT NULL DEFAULT 0,
  created_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (id),
  KEY idx_prize_event (event_id, sort_order),
  CONSTRAINT fk_prize_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_music_genre (
  event_id  BIGINT UNSIGNED NOT NULL,
  genre_id  BIGINT UNSIGNED NOT NULL,
  created_at DATETIME(3)    NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (event_id, genre_id),
  KEY idx_emg_genre (genre_id),
  CONSTRAINT fk_emg_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
  CONSTRAINT fk_emg_genre FOREIGN KEY (genre_id) REFERENCES music_genre(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Hosts (people or groups) per event
CREATE TABLE event_host (
  event_id   BIGINT UNSIGNED NOT NULL,
  party_id   BIGINT UNSIGNED NOT NULL,
  role       VARCHAR(120)    NULL,   -- Headliner, MC, Opening Act, etc.
  sort_order INT             NOT NULL DEFAULT 0,
  created_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (event_id, party_id),
  KEY idx_event_host_party (party_id, event_id),
  CONSTRAINT fk_eh_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
  CONSTRAINT fk_eh_party FOREIGN KEY (party_id) REFERENCES party(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT GROUPING / SERIES
-- e.g., "Santa Pub Crawl", "Summer Concert Series"
-- =========================
CREATE TABLE event_group (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  name        VARCHAR(200)    NOT NULL,
  slug        VARCHAR(200)    NULL,
  description TEXT            NULL,
  created_at  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_event_group_slug (slug),
  KEY idx_event_group_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_group_event (
  group_id   BIGINT UNSIGNED NOT NULL,
  event_id   BIGINT UNSIGNED NOT NULL,
  sort_order INT             NOT NULL DEFAULT 0,
  created_at DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (group_id, event_id),
  KEY idx_ege_event (event_id),
  CONSTRAINT fk_ege_group FOREIGN KEY (group_id) REFERENCES event_group(id) ON DELETE CASCADE,
  CONSTRAINT fk_ege_event FOREIGN KEY (event_id)  REFERENCES event(id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- EVENT RECURRENCE
-- Store iCalendar RRULE and exceptions.
-- parent_event_id in event can be used for materialized instances.
-- =========================
CREATE TABLE event_recurrence_rule (
  id          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  event_id    BIGINT UNSIGNED NOT NULL,     -- template/base event
  rrule       VARCHAR(500)    NOT NULL,     -- RFC5545 string, e.g., FREQ=WEEKLY;BYDAY=FR;COUNT=10
  dtstart     DATETIME(3)     NOT NULL,     -- anchor start (UTC)
  dtend       DATETIME(3)     NOT NULL,     -- anchor end   (UTC)
  timezone    VARCHAR(64)     NOT NULL DEFAULT 'UTC',  -- Olson TZ identifier if needed
  until_at    DATETIME(3)     NULL,         -- optional UNTIL
  count_occurrences INT       NULL,         -- optional COUNT
  created_at  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at  DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY idx_rrule_event (event_id),
  CONSTRAINT fk_rrule_event FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE event_recurrence_exception (
  rule_id    BIGINT UNSIGNED NOT NULL,
  exdate     DATETIME(3)     NOT NULL,  -- occurrence start to exclude (UTC)
  PRIMARY KEY (rule_id, exdate),
  KEY idx_exception_exdate (exdate),
  CONSTRAINT fk_exception_rule FOREIGN KEY (rule_id) REFERENCES event_recurrence_rule(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Optional materialized instances table (if you choose to pre-generate occurrences)
-- Each row represents a single occurrence derived from a rule, mapped to a concrete event id.
CREATE TABLE event_instance (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  rule_id         BIGINT UNSIGNED NOT NULL,
  occurrence_num  INT             NOT NULL,        -- nth instance generated
  event_id        BIGINT UNSIGNED NOT NULL,        -- concrete event row
  status          ENUM('SCHEDULED','CANCELLED','MOVED') NOT NULL DEFAULT 'SCHEDULED',
  created_at      DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (id),
  UNIQUE KEY uq_instance_rule_occurrence (rule_id, occurrence_num),
  KEY idx_instance_event (event_id),
  CONSTRAINT fk_instance_rule  FOREIGN KEY (rule_id)  REFERENCES event_recurrence_rule(id) ON DELETE CASCADE,
  CONSTRAINT fk_instance_event FOREIGN KEY (event_id) REFERENCES event(id)                 ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =========================
-- ASSET CATALOG (metadata only)
-- Files live in CDN/object storage; DB stores descriptors & links.
-- =========================
CREATE TABLE asset (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  content_sha256 CHAR(64)        NOT NULL,      -- dedupe + cache-busting
  mime_type      VARCHAR(100)    NOT NULL,      -- e.g., image/jpeg, image/webp
  byte_size      BIGINT UNSIGNED NOT NULL,
  width_px       INT             NULL,
  height_px      INT             NULL,
  duration_ms    INT             NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  updated_at     DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)) ON UPDATE UTC_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_hash (content_sha256),
  KEY idx_asset_mime (mime_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_location (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  provider     ENUM('CDN_SERVER','S3','GCS','LOCAL') NOT NULL,
  storage_key  VARCHAR(500)    NOT NULL,    -- path/key in bucket or on your cdn-server
  public_url   VARCHAR(1000)   NULL,        -- optional cached, or compute on read
  is_primary   TINYINT(1)      NOT NULL DEFAULT 1,
  created_at   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_primary (asset_id, is_primary),
  KEY idx_location_asset (asset_id),
  CONSTRAINT fk_location_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE asset_variant (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  variant_code VARCHAR(64)     NOT NULL,    -- e.g., hero_1920, thumb_320, webp_1080
  mime_type    VARCHAR(100)    NOT NULL,
  width_px     INT             NULL,
  height_px    INT             NULL,
  byte_size    BIGINT UNSIGNED NULL,
  storage_key  VARCHAR(500)    NOT NULL,
  public_url   VARCHAR(1000)   NULL,
  created_at   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
  PRIMARY KEY (id),
  UNIQUE KEY uq_asset_variant (asset_id, variant_code),
  KEY idx_variant_asset (asset_id),
  CONSTRAINT fk_variant_asset FOREIGN KEY (asset_id) REFERENCES asset(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Polymorphic attachments to domain entities
CREATE TABLE asset_link (
  id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  asset_id     BIGINT UNSIGNED NOT NULL,
  object_type  ENUM('EVENT','VENUE','PARTY','ROOM','PERSON_PROFILE','GROUP_PROFILE') NOT NULL,
  object_id    BIGINT UNSIGNED NOT NULL,
  relation     ENUM('HERO','GALLERY','AVATAR','BANNER','BACKGROUND','OTHER') NOT NULL DEFAULT 'GALLERY',
  sort_order   INT             NOT NULL DEFAULT 0,
  created_at   DATETIME(3)     NOT NULL DEFAULT (UTC_TIMESTAMP(3)),
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

-- =========================
-- RECOMMENDED VIEWS / QUERIES (optional; create later as views)
-- - Upcoming events by venue:
--   SELECT e.* FROM event e
--   WHERE e.venue_id=? AND e.start_time >= UTC_TIMESTAMP()
--   ORDER BY e.start_time LIMIT 50;
--
-- - Upcoming events by host (person or group):
--   SELECT e.* FROM event e
--   JOIN event_host eh ON eh.event_id = e.id
--   WHERE eh.party_id=? AND e.start_time >= UTC_TIMESTAMP()
--   ORDER BY e.start_time LIMIT 50;
--
-- - Events in a named group/series:
--   SELECT e.* FROM event_group eg
--   JOIN event_group_event ege ON ege.group_id = eg.id
--   JOIN event e ON e.id = ege.event_id
--   WHERE eg.slug=? OR eg.name=? ORDER BY ege.sort_order, e.start_time;
-- =========================