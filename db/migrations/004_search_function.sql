CREATE OR REPLACE FUNCTION search_gifs_by_terms(terms text[], lim int, off int)
RETURNS TABLE(gif_id uuid, title text, cdn_url text, matched_tags int) AS $$
WITH normalized_terms AS (
  SELECT DISTINCT lower(btrim(x)) AS term
  FROM unnest(terms) AS x
  WHERE x IS NOT NULL AND btrim(x) <> ''
),
resolved_tags AS (
  -- Exact tag matches
  SELECT t.id
  FROM tags t
  JOIN normalized_terms nt ON t.name = nt.term

  UNION

  -- Exact alias matches
  SELECT ta.tag_id
  FROM tag_aliases ta
  JOIN normalized_terms nt ON ta.alias = nt.term

  UNION

  -- Fuzzy tag matches (index-accelerated with %)
  SELECT ft.id
  FROM normalized_terms nt
  JOIN LATERAL (
    SELECT t.id
    FROM tags t
    WHERE t.name % nt.term
    ORDER BY similarity(t.name, nt.term) DESC
    LIMIT 5
  ) ft ON true

  UNION

  -- Fuzzy alias matches -> canonical tag_id (index-accelerated with %)
  SELECT fa.tag_id
  FROM normalized_terms nt
  JOIN LATERAL (
    SELECT ta.tag_id
    FROM tag_aliases ta
    WHERE ta.alias % nt.term
    ORDER BY similarity(ta.alias, nt.term) DESC
    LIMIT 5
  ) fa ON true
),
matches AS (
  SELECT gt.gif_id, COUNT(*)::int AS matched_tags
  FROM gif_tags gt
  JOIN resolved_tags rt ON rt.id = gt.tag_id
  GROUP BY gt.gif_id
)
SELECT g.id, g.title, g.cdn_url, m.matched_tags
FROM matches m
JOIN gifs g ON g.id = m.gif_id
WHERE g.is_deleted = false AND g.is_unlisted = false
ORDER BY m.matched_tags DESC, g.created_at DESC
LIMIT lim OFFSET off;
$$ LANGUAGE sql STABLE;
