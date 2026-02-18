-- db/migrations/002_seed_minimal.sql

INSERT INTO tags(name) VALUES
  ('lol'), ('happy'), ('dance'), ('sad'), ('cat'), ('dog')
ON CONFLICT (name) DO NOTHING;

-- aliases
INSERT INTO tag_aliases(alias, tag_id)
SELECT 'lmao', id FROM tags WHERE name='lol'
ON CONFLICT (alias) DO NOTHING;

-- 3 sample gifs
INSERT INTO gifs(source_url, cdn_url, title, rating, width, height)
VALUES
  ('https://example.com/src1', 'https://cdn.example.com/g1.gif', 'Happy dance', 'g', 480, 270),
  ('https://example.com/src2', 'https://cdn.example.com/g2.gif', 'Sad cat', 'g', 320, 320),
  ('https://example.com/src3', 'https://cdn.example.com/g3.gif', 'LOL dog', 'pg', 400, 300);

-- tag the gifs
WITH g AS (
  SELECT id, title FROM gifs
),
t AS (
  SELECT id, name FROM tags
)
INSERT INTO gif_tags(gif_id, tag_id, source)
SELECT g.id, t.id, 'seed'
FROM g
JOIN t ON
  (g.title ILIKE '%dance%' AND t.name='dance') OR
  (g.title ILIKE '%happy%' AND t.name='happy') OR
  (g.title ILIKE '%sad%' AND t.name='sad') OR
  (g.title ILIKE '%cat%' AND t.name='cat') OR
  (g.title ILIKE '%dog%' AND t.name='dog') OR
  (g.title ILIKE '%lol%' AND t.name='lol')
ON CONFLICT DO NOTHING;
