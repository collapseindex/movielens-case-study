-- 01 · The worksheet: GROUP BY, HAVING, JOIN, anti-join
--
-- 25,000,095 ratings, 62,423 movies, 1,093,360 tags, 1995-2019. This is the
-- case where eyeballing dies: at 25M rows the sweeps are not discipline,
-- they are the only eyes you have.
--
-- Setup: `python setup.py` once. Direct: `duckdb movielens.duckdb` and the
-- tables are plain names. Via sql-notes' start_ui.py the db is attached
-- read-only as `ml`, so prefix: SELECT * FROM ml.ratings LIMIT 10;
--
-- RULE FOR THIS DB: never run a bare SELECT * on ml.ratings in the UI.
-- 25M rows into a browser tab is a crash, not a query. LIMIT, always.
--
-- Worksheet, no answers included. Verify each result a second way before
-- moving on; questions.md applies at every step.


-- A. Sweeps first, same three as ever (ranges, distincts, id shape).
--    A1. How many ratings, distinct users, distinct movies? Does every
--        ratings.movie_id exist in movies?
--    A2. min/max of rating and rated_at. What VALUES can rating take, and is
--        that set what you assumed? (GROUP BY rating is the sweep here.)
--    A3. Does the set of possible rating values change over time? (Hint:
--        GROUP BY the year and look at min(rating) or count(DISTINCT rating).
--        There is a real product change hiding in this one.)

-- B. GROUP BY / HAVING, single table.
--    B1. Ratings per year. Any year with a hole or a cliff? (date_trunc)
--    B2. How many users have 1,000+ ratings? What share of ALL ratings do
--        they account for? (Two queries, or one with a CTE.)
--    B3. How many movies were rated exactly once?
--    B4. Per-user average rating: are heavy raters harsher? (Bucket users by
--        rating count, then average within buckets. Bands must cover the
--        whole range; parts must sum to 25,000,095.)

-- C. JOIN.
--    C1. Top 20 most-rated movies, with titles.
--    C2. "Best movie ever": top 20 by average rating. First without any
--        floor, then with HAVING count(*) >= 1000. Compare the two lists.
--        This is the small-n lesson from the e-commerce case at 25M scale.
--    C3. Anti-join: how many movies have ZERO ratings? Newest such movie?
--        (movies LEFT JOIN ratings ... WHERE IS NULL, or NOT EXISTS.)
--    C4. Genres are pipe-separated ('Comedy|Romance'): unnest(string_split())
--        them, then average rating per genre. DECIDE FIRST: a movie with
--        three genres contributes its ratings three times. Is that the right
--        grain for this question, or do you want per-movie averages averaged
--        per genre? Both are defensible; they answer different questions.
--        Write down which one you computed. What does '(no genres listed)'
--        mean, and what did you do with it?
--    C5. Do tagged movies rate higher than untagged ones? DANGER: joining
--        ratings to tags on movie_id multiplies 25M rows by tags-per-movie.
--        Aggregate BOTH sides to movie grain first, then join one row to one
--        row. (questions.md #6, at a scale where getting it wrong is not a
--        wrong number but a hung query.)

-- D. Patterns you just unlocked, for the sql-notes pattern list when they feel
--    automatic: filter-and-aggregate, join at the right grain then aggregate,
--    anti-join. Top-N per group (best movie PER genre) needs window
--    functions; that is the next syntax stop after this session.

-- Findings and answers get appended below, with the query that earned them.


-- ============================================================================
-- Logged 2026-08-18 · the movie dimension table: all tables mashed at movie
-- grain. Aggregate-first, every join one-to-one LEFT, 62,423 rows out.
-- (The naive row-grain six-way join computes to 12.3 TRILLION rows; the
-- worst single movie alone contributes 479 billion. Grain matching is not
-- style, it is the difference between 358ms and never.)
-- ============================================================================
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
LEFT JOIN g USING (movie_id)
ORDER BY n_ratings DESC
LIMIT 20;
-- Observation logged from the first 20 rows: Forrest Gump leads on COUNT
-- (81,491, nine ahead of Shawshank's 81,482) while Shawshank leads the top
-- list on AVERAGE (4.41 vs 4.05). Most-rated and best-rated are different
-- questions with different winners. Preliminary: recorded before the phase-1
-- audit; C2 makes it rigorous (floors, full list, not just the top 20).


-- ============================================================================
-- Logged 2026-08-18 · C2: best-rated is a function of the floor (finding B1)
-- ============================================================================
-- 855 movies average a perfect 5.0; 820 of them have exactly one rating.
SELECT count(*) AS perfect_movies,
       sum(CASE WHEN n_ratings = 1 THEN 1 ELSE 0 END) AS of_which_n1
FROM movie_dim WHERE avg_rating = 5.0;

-- Winner by floor: none -> 820-way tie at 5.0 | 1,000 -> Planet Earth II
-- (4.48, n=1,124, television) | 10,000 -> Shawshank (4.41, n=81,482).
SELECT title, avg_rating, n_ratings FROM movie_dim
WHERE n_ratings >= 10000 ORDER BY avg_rating DESC LIMIT 10;
