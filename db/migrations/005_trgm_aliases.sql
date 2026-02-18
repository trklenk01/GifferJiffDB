CREATE INDEX IF NOT EXISTS tag_aliases_alias_trgm_idx
ON tag_aliases USING gin (alias gin_trgm_ops);
