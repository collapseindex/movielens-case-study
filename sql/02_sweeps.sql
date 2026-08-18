-- 02: phase-1 sweeps, with the outputs they actually produced (2026-08-18).
-- Tables are referenced as ml.* (the read-only attach start_ui.py creates);
-- drop the prefix if querying movielens.duckdb directly.

-- Sweep 1: what values can a rating take?
SELECT rating, count(*) FROM ml.ratings GROUP BY rating ORDER BY rating;
-- 0.5: 393,068 | 1: 776,815 | 1.5: 399,490 | 2: 1,640,868 | 2.5: 1,262,797
-- 3: 4,896,928 | 3.5: 3,177,318 | 4: 6,639,798 | 4.5: 2,200,539 | 5: 3,612,474
-- Ten values. The halves are not taste, they are a feature (see 04: the set
-- was five values until 2003-02-18).

-- Whole-star collapse (definition: a half falls to its floor, "not quite the
-- next star"). The 0 bucket is the scale's floor reading as "would go lower";
-- it holds exactly the 0.5s and is labeled, not silently merged.
SELECT floor(rating) AS stars, count(*) AS n
FROM ml.ratings GROUP BY stars ORDER BY stars;
-- 0: 393,068 | 1: 1,176,305 | 2: 2,903,665 | 3: 8,074,246 | 4: 8,840,337
-- 5: 3,612,474      (sums to 25,000,095: parts equal the whole)
-- 68% of all ratings sit in the 3-4 band; the mode is 4, not the midpoint.

-- Does the value set change over time? (It does: the instrument changed.)
SELECT date_trunc('year', rated_at) AS yr,
       count(*) AS n,
       count(DISTINCT user_id) AS raters,
       round(count(*) * 1.0 / count(DISTINCT user_id), 1) AS per_rater,
       count(DISTINCT rating) AS distinct_values
FROM ml.ratings GROUP BY yr ORDER BY yr;
-- 1995: n=3 (see below) | 1996-2002: 5 values | 2003 on: 10 values
-- Volume swings: 1996 1.43M -> 1998 272k -> 2000 1.74M -> 2014 479k -> 2016 1.76M
-- per_rater: 62.1 (1996), 62.5 (1997), rising to ~130 by 2000.

-- Monthly zoom on the early era: shape distinguishes stories.
SELECT date_trunc('month', rated_at) AS mo, count(*) AS n
FROM ml.ratings WHERE rated_at < '2000-01-01'
GROUP BY mo ORDER BY mo;
-- Jan 1996: 42 -> Jun 1996: 230,239   (a RAMP: organic launch of something)
-- August 1997: NO ROW AT ALL          (absence renders as nothing; see 04)
-- Sep 1997: 16,656                    (a tenth of pre-gap volume)
-- Oct 1999: 310,288 after Sep 34,526  (a WALL: an event, still unexplained)

-- The whole year 1995:
SELECT * FROM ml.ratings WHERE rated_at < '1996-01-01';
-- 3 rows: user 2262, three movies, all stamped 1995-01-09 03:46:49 to the
-- second. Predates MovieLens (summer 1997) and EachMovie (Jan 1996) alike.
-- The dataset's advertised start date rests on these three artifact rows.
