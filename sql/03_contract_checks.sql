-- 03: the README as a contract, its claims as queries (2026-08-18).
-- The dataset documentation asserts checkable invariants; an audit checks
-- them rather than assuming either side. Results: two held exactly, one
-- stale in both directions, two structural checks clean.

-- The movie dimension view (all tables mashed at movie grain, aggregate-first;
-- the naive row-grain six-way join computes to 12.3 trillion rows).
CREATE OR REPLACE VIEW movie_dim AS
WITH r AS (SELECT movie_id, count(*) AS n_ratings, round(avg(rating), 2) AS avg_rating
           FROM ml.ratings GROUP BY movie_id),
     t AS (SELECT movie_id, count(*) AS n_tags FROM ml.tags GROUP BY movie_id),
     g AS (SELECT movie_id, count(*) AS n_genome FROM ml.genome_scores GROUP BY movie_id)
SELECT m.movie_id, m.title, m.genres, l.imdb_id,
       coalesce(r.n_ratings, 0) AS n_ratings, r.avg_rating,
       coalesce(t.n_tags, 0)    AS n_tags,
       coalesce(g.n_genome, 0)  AS n_genome
FROM ml.movies m
LEFT JOIN ml.links l USING (movie_id)
LEFT JOIN r USING (movie_id)
LEFT JOIN t USING (movie_id)
LEFT JOIN g USING (movie_id);

-- Claim: "Only movies with at least one rating or tag are included."
-- 3,376 movies have zero ratings, so all of them must carry tags.
SELECT count(*) AS contract_violations
FROM movie_dim WHERE n_ratings = 0 AND n_tags = 0;
-- 0. HELD, exactly.

-- Claim: the genre vocabulary is the README's enumerated list.
SELECT DISTINCT unnest(string_split(genres, '|')) AS genre
FROM ml.movies ORDER BY genre;
-- 20 values. Diff vs the doc, BOTH directions:
--   in data, not in doc:  IMAX
--   in doc, not in data:  Children's (the data says Children)
-- STALE DOCUMENTATION (finding Q4): the mirror of the e-commerce 'west'
-- finding, with the doc drifted and the data consistent.

-- Claim: "each line represents one rating of one movie by one user."
SELECT user_id, movie_id, count(*)
FROM ml.ratings GROUP BY user_id, movie_id HAVING count(*) > 1;
-- Empty. HELD across 25,000,095 rows.

-- Structural: movie_id unique where one-row-per-movie is claimed.
SELECT count(*), count(DISTINCT movie_id) FROM ml.movies;   -- 62,423 = 62,423
SELECT count(*), count(DISTINCT movie_id) FROM ml.links;    -- 62,423 = 62,423

-- The README warns "errors and inconsistencies may exist in these titles":
-- taken as an invitation. Self-join on title (a.movie_id < b.movie_id keeps
-- each pair once and no self-pairs), adjudicated via links.
SELECT a.movie_id AS id_a, b.movie_id AS id_b, a.title,
       la.imdb_id AS imdb_a, lb.imdb_id AS imdb_b,
       (la.imdb_id = lb.imdb_id) AS same_film
FROM ml.movies a
JOIN ml.movies b ON a.title = b.title AND a.movie_id < b.movie_id
LEFT JOIN ml.links la ON la.movie_id = a.movie_id
LEFT JOIN ml.links lb ON lb.movie_id = b.movie_id
ORDER BY same_film DESC, a.title;
-- ~98 title+year twin pairs, same_film FALSE on every one: all are genuinely
-- distinct films (Dracula (1931) resolves to consecutive imdb ids 0021814 /
-- 0021815: the English- and Spanish-language versions). No order-1028-style
-- catalog duplicate; per-movie metrics safe from rating fragmentation.
-- Caveat: exact-string titles only; variant spellings would evade this.
