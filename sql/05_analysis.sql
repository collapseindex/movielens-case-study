-- 05: phase-2 analysis, findings B1 and B3-B6 in runnable form (2026-08-18).
-- Outputs in comments are what actually came back. movie_dim is created in 03.

-- B1/C2: best-rated is a function of the floor.
SELECT count(*) AS perfect_movies,
       sum(CASE WHEN n_ratings = 1 THEN 1 ELSE 0 END) AS of_which_n1
FROM movie_dim WHERE avg_rating = 5.0;
-- 855 perfect-score movies, 820 of them rated exactly once.
SELECT title, avg_rating, n_ratings FROM movie_dim
WHERE n_ratings >= 1000 ORDER BY avg_rating DESC LIMIT 20;
-- floor 1,000: Planet Earth II wins (4.48, n=1,124, television).
SELECT title, avg_rating, n_ratings FROM movie_dim
WHERE n_ratings >= 10000 ORDER BY avg_rating DESC LIMIT 10;
-- floor 10,000: Shawshank (4.41, n=81,482). The winner moves with the floor.

-- B3: heavy raters are harsher and cast most of the votes.
WITH per_user AS (
  SELECT user_id, count(*) AS n, avg(rating) AS user_avg
  FROM ml.ratings GROUP BY user_id
)
SELECT CASE WHEN n < 50 THEN 'a: 20-49' WHEN n < 200 THEN 'b: 50-199'
            WHEN n < 1000 THEN 'c: 200-999' ELSE 'd: 1000+' END AS bucket,
       count(*) AS users, round(avg(user_avg), 3) AS avg_of_user_avgs,
       sum(n) AS ratings
FROM per_user GROUP BY bucket ORDER BY bucket;
-- 3.713 / 3.725 / 3.545 / 3.259; top two buckets = 20% of users, 64% of
-- ratings. Users sum to 162,541 and ratings to 25,000,095: parts check.

-- B4 grain A: genre averages, ratings-weighted (fan-out intentional: each
-- rating votes once per genre of its movie).
SELECT g.genre, count(*) AS ratings, round(avg(r.rating), 3) AS avg_rating
FROM ml.ratings r
JOIN (SELECT movie_id, unnest(string_split(genres, '|')) AS genre
      FROM ml.movies) g USING (movie_id)
GROUP BY g.genre ORDER BY avg_rating DESC;
-- Film-Noir 3.926 tops, Horror 3.294 bottoms. Every genre rates HIGHER than
-- in grain B (the popularity-quality correlation); Crime jumps 11th -> 4th.

-- B4 grain B: each movie one vote, floored.
SELECT g.genre, count(*) AS movies, round(avg(d.avg_rating), 3) AS avg_of_movie_avgs
FROM movie_dim d
JOIN (SELECT movie_id, unnest(string_split(genres, '|')) AS genre
      FROM ml.movies) g USING (movie_id)
WHERE d.n_ratings >= 100
GROUP BY g.genre ORDER BY avg_of_movie_avgs DESC;
-- Film-Noir 3.743 tops, Horror 2.967 bottoms (only genre under 3).
-- Documentary's grain gap is 0.046, smallest on the board.

-- B5: tagged vs untagged, movie grain, floored. Confound pre-committed:
-- popularity attracts both tags and ratings; description, not cause.
SELECT (n_tags > 0) AS has_tags, count(*) AS movies,
       round(avg(avg_rating), 3) AS avg_of_movie_avgs, sum(n_ratings) AS total_ratings
FROM movie_dim WHERE n_ratings >= 100 GROUP BY has_tags;
-- tagged 3.306 (n=10,263) vs untagged 2.981 (n=63).

-- B6 setup: heavyweight era-splits (conditional aggregation: CASE inside avg).
SELECT title,
  round(avg(CASE WHEN rated_at < '1997-08-01' THEN rating END), 2) AS eachmovie_avg,
  round(avg(CASE WHEN rated_at BETWEEN '1997-09-01' AND '2003-02-18' THEN rating END), 2) AS native_avg,
  round(avg(CASE WHEN rated_at > '2003-02-18' THEN rating END), 2) AS halfstar_avg
FROM ml.ratings JOIN ml.movies USING (movie_id)
WHERE movie_id IN (318, 356, 296, 593)
GROUP BY title;
-- No uniform era tax at the top: Gump's EachMovie era is its HIGHEST (4.12),
-- Pulp Fiction's its LOWEST (4.03). Per-movie reception drift, not a tax.

-- B6 test: the flattery staircase. Movies with 200+ ratings in each
-- whole-star era, banded by native-era average.
WITH per_movie AS (
  SELECT movie_id,
    avg(CASE WHEN rated_at < '1997-08-01' THEN rating END)   AS em_avg,
    count(CASE WHEN rated_at < '1997-08-01' THEN 1 END)      AS em_n,
    avg(CASE WHEN rated_at BETWEEN '1997-09-01' AND '2003-02-18'
             THEN rating END)                                AS native_avg,
    count(CASE WHEN rated_at BETWEEN '1997-09-01' AND '2003-02-18'
               THEN 1 END)                                   AS native_n
  FROM ml.ratings GROUP BY movie_id
)
SELECT round(native_avg * 2) / 2 AS native_band, count(*) AS movies,
       round(avg(em_avg), 2) AS em_mean, round(avg(native_avg), 2) AS native_mean,
       round(avg(abs(em_avg - 3)), 3) AS em_dist_from_3,
       round(avg(abs(native_avg - 3)), 3) AS native_dist_from_3
FROM per_movie
WHERE em_n >= 200 AND native_n >= 200
GROUP BY native_band ORDER BY native_band;
-- 822 movies, 7 bands, a monotonic gradient: +0.81 stars at the 1.5 band
-- fading to -0.14 at 4.5. The imported instrument flattered the despised
-- and spared the beloved. Extreme bands are small (n=3, n=29); the gradient
-- across all seven bands carries the finding.
