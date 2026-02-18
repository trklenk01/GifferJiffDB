CREATE OR REPLACE VIEW gif_with_tags AS
SELECT
  g.*,
  COALESCE(array_agg(t.name ORDER BY t.name)
    FILTER (WHERE t.name IS NOT NULL), '{}') AS tags
FROM gifs g
LEFT JOIN gif_tags gt ON gt.gif_id = g.id
LEFT JOIN tags t ON t.id = gt.tag_id
GROUP BY g.id;
