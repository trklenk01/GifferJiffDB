-- db/migrations/001_init.sql
-- Tenor-clone baseline schema (v1)

CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS gifs (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_url text NOT NULL,
  cdn_url text NOT NULL,
  title text,
  rating text NOT NULL DEFAULT 'g',          -- g, pg, pg13, r
  width int,
  height int,
  filesize_bytes bigint,
  duration_ms int,
  is_deleted boolean NOT NULL DEFAULT false,
  is_unlisted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tags (
  id bigserial PRIMARY KEY,
  name text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tag_aliases (
  alias text PRIMARY KEY,
  tag_id bigint NOT NULL REFERENCES tags(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS gif_tags (
  gif_id uuid NOT NULL REFERENCES gifs(id) ON DELETE CASCADE,
  tag_id bigint NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  confidence real,                           -- optional
  source text NOT NULL DEFAULT 'import',     -- import/manual/auto
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (gif_id, tag_id)
);

CREATE TABLE IF NOT EXISTS gif_metrics_daily (
  gif_id uuid NOT NULL REFERENCES gifs(id) ON DELETE CASCADE,
  date date NOT NULL,
  views int NOT NULL DEFAULT 0,
  clicks int NOT NULL DEFAULT 0,
  shares int NOT NULL DEFAULT 0,
  favorites int NOT NULL DEFAULT 0,
  PRIMARY KEY (gif_id, date)
);

-- Indexes
CREATE INDEX IF NOT EXISTS gif_tags_tag_id_idx ON gif_tags(tag_id);
CREATE INDEX IF NOT EXISTS gif_tags_gif_id_idx ON gif_tags(gif_id);

-- Fuzzy tag lookup (nice for search UX and aliasing)
CREATE INDEX IF NOT EXISTS tags_name_trgm_idx ON tags USING gin (name gin_trgm_ops);

-- Common filters
CREATE INDEX IF NOT EXISTS gifs_created_at_idx ON gifs(created_at);
CREATE INDEX IF NOT EXISTS gifs_visibility_idx ON gifs(is_deleted, is_unlisted);
