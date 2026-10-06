-- Finalised data model (Phase 0). Implemented in Phase 1 as Alembic migrations; this file is the reference.
-- Additions beyond spec §4 are marked  -- [added]  with the reason.

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ---------- enums ----------
CREATE TYPE department   AS ENUM ('deck','engine','electrical','catering','other');
CREATE TYPE crew_level   AS ENUM ('officer','rating','cadet');
CREATE TYPE doc_type     AS ENUM ('circular','order','notice','exam_schedule','result','advisory','rules','unknown');
CREATE TYPE doc_status   AS ENUM ('new','extracted','processed','needs_review','failed');
CREATE TYPE priority     AS ENUM ('critical','normal','low');
CREATE TYPE channel      AS ENUM ('in_app','push','whatsapp','sms','email');
CREATE TYPE cert_type    AS ENUM ('coc','cop','stcw_basic','stcw_advanced','medical','cdc','passport','bsid','visa','other');
CREATE TYPE tag_kind     AS ENUM ('rank','department','level','ship_type','mmd','topic','certificate_type','exam_grade');
CREATE TYPE lang         AS ENUM ('en','hi','mr','ta','ml','bn','te','gu');

-- ---------- users ----------
CREATE TABLE users (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone              text UNIQUE,                       -- E.164
  email              citext UNIQUE,
  name               text,
  preferred_language lang NOT NULL DEFAULT 'en',
  rank               text,                              -- code from ranks reference list, e.g. 'MASTER','2O','MEO_CL4','AB','OS','WIPER'
  department         department,
  level              crew_level,
  ship_types         text[] NOT NULL DEFAULT '{}',      -- e.g. {'tanker_oil','bulk','container','offshore','passenger','lng'}
  home_mmd           text,                              -- 'MUMBAI','KOLKATA','CHENNAI','KOCHI','KANDLA','NOIDA','GOA','TUTICORIN','VIZAG','PORTBLAIR','JAMNAGAR', ...
  exam_grades        text[] NOT NULL DEFAULT '{}',      -- [added] grades the user is preparing for (exam alerts, feature 7)
  alert_channels     channel[] NOT NULL DEFAULT '{in_app,push}',
  quiet_hours        int4range,                         -- minutes from IST midnight, e.g. [1320,420)
  plan               text NOT NULL DEFAULT 'free',      -- [added] 'free' | 'premium' (cached from subscriptions)
  created_at         timestamptz NOT NULL DEFAULT now(),
  deleted_at         timestamptz,                       -- [added] soft-delete window before the 24 h hard delete
  CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

CREATE TABLE user_topic_prefs (                        -- [added] follow / mute topics (feature 2)
  user_id  uuid REFERENCES users ON DELETE CASCADE,
  topic    text,
  mode     text CHECK (mode IN ('follow','mute')),
  PRIMARY KEY (user_id, topic)
);

CREATE TABLE consents (                                -- [added] DPDP: purpose-wise consent records
  id         bigserial PRIMARY KEY,
  user_id    uuid REFERENCES users ON DELETE CASCADE,
  purpose    text NOT NULL,                            -- 'core_service','whatsapp','analytics','cloud_backup'
  granted    boolean NOT NULL,
  policy_ver text NOT NULL,
  at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE devices (                                 -- [added] push tokens + sync cursors
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES users ON DELETE CASCADE,
  platform    text CHECK (platform IN ('windows','android','ios')),
  fcm_token   text,
  app_version text,
  last_seen   timestamptz
);

-- ---------- sources & documents ----------
CREATE TABLE sources (                                 -- [added] mirrors scraper/sources/*.yaml for health tracking
  id              text PRIMARY KEY,                    -- 'dgma_all_circulars'
  url             text NOT NULL,
  enabled         boolean NOT NULL DEFAULT true,
  poll_minutes    int NOT NULL DEFAULT 180,
  last_success_at timestamptz,
  last_item_count int,
  structure_hash  text                                 -- hash of the selector-matched DOM skeleton → drift detection
);

CREATE TABLE scrape_runs (                             -- [added] scraper self-monitoring
  id          bigserial PRIMARY KEY,
  source_id   text REFERENCES sources,
  started_at  timestamptz NOT NULL,
  finished_at timestamptz,
  http_status int,
  items_found int,
  new_items   int,
  changed_items int,
  error       text
);

CREATE TABLE documents (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_id           text REFERENCES sources,
  source_url          text NOT NULL,                   -- listing page the item came from
  pdf_url             text,
  pdf_hash            text,                            -- sha256 of the current PDF bytes
  title               text NOT NULL,
  circular_number     text,                            -- verbatim as published, e.g. '53 of 2026'; NULL if absent
  issuing_branch      text,
  published_date      date,
  doc_type            doc_type NOT NULL DEFAULT 'unknown',
  priority            priority NOT NULL DEFAULT 'normal',
  related_document_id uuid REFERENCES documents,       -- [added] addendum/corrigendum → original
  relation            text,                            -- [added] 'addendum'|'corrigendum'|'supersedes'|'amends'
  raw_text            text,
  extraction_method   text,                            -- [added] 'pdfplumber'|'ocr'
  classify_confidence real,                            -- [added] accuracy gate
  status              doc_status NOT NULL DEFAULT 'new',
  fts                 tsvector GENERATED ALWAYS AS (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(raw_text,''))) STORED,
  first_seen_at       timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pdf_url)
);
CREATE INDEX documents_fts_idx ON documents USING gin (fts);
CREATE INDEX documents_pub_idx ON documents (published_date DESC);

CREATE TABLE document_versions (                       -- [added] keep every PDF hash we have seen (changed-item detection)
  document_id uuid REFERENCES documents ON DELETE CASCADE,
  pdf_hash    text,
  seen_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (document_id, pdf_hash)
);

CREATE TABLE document_summaries (
  document_id       uuid REFERENCES documents ON DELETE CASCADE,
  language          lang,
  summary_short     text NOT NULL,                     -- ≤ 3 lines
  summary_detailed  text,
  action_required   boolean NOT NULL DEFAULT false,
  action_deadline   date,
  affected_groups   jsonb NOT NULL DEFAULT '{}',       -- {"departments":[...],"levels":[...],"ranks":[...],"ship_types":[...],"mmds":[...],"cert_types":[...]}
  key_points        text[] NOT NULL DEFAULT '{}',
  uncertain_fields  text[] NOT NULL DEFAULT '{}',      -- [added] what the model could not determine
  model_version     text NOT NULL,
  verified_by_human boolean NOT NULL DEFAULT false,
  verified_by       uuid,                              -- [added] admin id
  created_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (document_id, language)
);

CREATE TABLE document_tags (
  document_id uuid REFERENCES documents ON DELETE CASCADE,
  kind        tag_kind,
  value       text,
  PRIMARY KEY (document_id, kind, value)
);
CREATE INDEX document_tags_lookup ON document_tags (kind, value);

CREATE TABLE document_chunks (                         -- [added] Q&A retrieval with page-level citations
  id          bigserial PRIMARY KEY,
  document_id uuid REFERENCES documents ON DELETE CASCADE,
  page_from   int,
  page_to     int,
  text        text NOT NULL,
  embedding   vector(1024)                             -- dimension depends on the chosen model (decision D6)
);
CREATE INDEX document_chunks_vec ON document_chunks USING hnsw (embedding vector_cosine_ops);

CREATE TABLE exam_events (                             -- [added] countdown cards (feature 7)
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id uuid REFERENCES documents ON DELETE CASCADE,
  kind        text CHECK (kind IN ('seat_booking_open','seat_booking_close','exam_date','result','coc_dispatch')),
  grade       text,
  mmd         text,
  starts_at   timestamptz,
  ends_at     timestamptz
);

-- ---------- user data (offline-first: client-generated ids, versioned) ----------
CREATE TABLE certificates (
  id                uuid PRIMARY KEY,                  -- generated on device
  user_id           uuid REFERENCES users ON DELETE CASCADE,
  type              cert_type NOT NULL,
  subtype           text,                              -- [added] e.g. 'AFF','PSCRB','MEO_CL2','GMDSS_GOC'
  number            text,
  issuing_authority text,
  issue_date        date,
  expiry_date       date,                              -- NULL = no expiry
  file_path         text,                              -- device-local path to AES-256-GCM encrypted file; server never stores files by default (D5)
  ocr_raw           text,                              -- kept on device only; column exists for opt-in backup
  version           int NOT NULL DEFAULT 1,            -- [added] sync
  updated_at        timestamptz NOT NULL DEFAULT now(),-- [added] sync
  deleted_at        timestamptz,                       -- [added] sync tombstone
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE cert_document_links (
  certificate_id uuid REFERENCES certificates ON DELETE CASCADE,
  document_id    uuid REFERENCES documents ON DELETE CASCADE,
  reason         text NOT NULL,                        -- plain-language impact explanation
  notified_at    timestamptz,
  PRIMARY KEY (certificate_id, document_id)
);

CREATE TABLE alerts (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        uuid REFERENCES users ON DELETE CASCADE,
  document_id    uuid REFERENCES documents ON DELETE CASCADE,
  certificate_id uuid REFERENCES certificates ON DELETE CASCADE,
  kind           text NOT NULL,                        -- [added] 'new_document'|'cert_impact'|'cert_expiry'|'exam'|'broadcast'
  channel        channel NOT NULL,
  priority       priority NOT NULL,
  dedupe_key     text NOT NULL,                        -- [added] idempotency
  sent_at        timestamptz,
  read_at        timestamptz,
  CHECK (document_id IS NOT NULL OR certificate_id IS NOT NULL OR kind = 'broadcast'),
  UNIQUE (user_id, channel, dedupe_key)
);

CREATE TABLE sea_service (
  id          uuid PRIMARY KEY,
  user_id     uuid REFERENCES users ON DELETE CASCADE,
  vessel_name text NOT NULL,
  imo         text CHECK (imo ~ '^[0-9]{7}$'),
  rank        text,
  sign_on     date NOT NULL,
  sign_off    date,                                    -- NULL = currently on board
  ship_type   text,
  flag        text,                                    -- [added] Indian vs foreign flag matters for NRI rules
  version     int NOT NULL DEFAULT 1,
  updated_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz,
  CHECK (sign_off IS NULL OR sign_off >= sign_on)
);

-- ---------- reference lists ----------
CREATE TABLE reference_lists (
  id           bigserial PRIMARY KEY,
  list         text CHECK (list IN ('banned_vessel','restricted_vessel','rpsl_valid','rpsl_suspended')),
  name         text NOT NULL,
  imo          text,
  licence_no   text,
  extra        jsonb NOT NULL DEFAULT '{}',
  source_url   text NOT NULL,
  last_updated date NOT NULL
);
CREATE INDEX reference_lists_name_trgm ON reference_lists USING gin (name gin_trgm_ops);

-- ---------- monetisation ----------
CREATE TABLE subscriptions (                           -- [added] feature 14
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES users ON DELETE CASCADE,
  provider     text CHECK (provider IN ('razorpay','play','appstore','manual')),
  provider_ref text NOT NULL,
  plan         text NOT NULL,                          -- 'premium_monthly'|'premium_yearly'
  status       text NOT NULL,                          -- 'active'|'grace'|'cancelled'|'expired'
  current_period_end timestamptz,
  UNIQUE (provider, provider_ref)
);

CREATE TABLE feature_flags (                           -- [added] spec: feature-flag everything
  key      text PRIMARY KEY,
  enabled  boolean NOT NULL DEFAULT false,
  premium_only boolean NOT NULL DEFAULT false,
  rollout  int NOT NULL DEFAULT 100 CHECK (rollout BETWEEN 0 AND 100)
);

-- ---------- admin ----------
CREATE TABLE admins (                                  -- [added] separate from users; TOTP required
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email       citext UNIQUE NOT NULL,
  totp_secret text NOT NULL,                           -- encrypted with app key
  role        text NOT NULL CHECK (role IN ('editor','owner'))
);

CREATE TABLE admin_audit_log (
  id        bigserial PRIMARY KEY,
  admin_id  uuid REFERENCES admins,
  action    text NOT NULL,                             -- 'summary.edit','summary.verify','broadcast.send','user.delete', ...
  target    text,
  diff      jsonb,                                     -- no user PII
  at        timestamptz NOT NULL DEFAULT now()
);
