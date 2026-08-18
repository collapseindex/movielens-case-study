-- 04: the seams. Findings Q2/Q2a/Q2b/Q3 in runnable form (2026-08-18).
-- Receipt for the mechanism: Konstan, Riedl, Borchers & Herlocker 1998,
-- AAAI WS-98-08 (launched summer 1997; seeded with 2.8M anonymous EachMovie
-- ratings, "dead data"). See FINDINGS.md and README references.

-- The 1997 seam, edges exact:
SELECT max(rated_at) AS last_before FROM ml.ratings WHERE rated_at < '1997-09-01';
-- 1997-07-23 00:55:30
SELECT min(rated_at) AS first_after FROM ml.ratings WHERE rated_at >= '1997-08-01';
-- 1997-09-09 09:35:25       (a 48-day hole; August 1997 has zero ratings)

-- The pre-seam (EachMovie) era in this extract:
SELECT count(*) AS n, count(DISTINCT user_id) AS users,
       string_agg(DISTINCT rating::VARCHAR ORDER BY rating::VARCHAR) AS values
FROM ml.ratings WHERE rated_at < '1997-08-01';
-- 1,966,631 ratings | 30,299 users | values exactly 1,2,3,4,5

-- Q2a: users spanning the seam. The paper predicts zero linkable users.
SELECT count(*) AS spanning_users FROM (
  SELECT user_id FROM ml.ratings GROUP BY user_id
  HAVING min(rated_at) < '1997-08-01' AND max(rated_at) >= '1997-09-01');
-- 506. But their endings are coordinated, not organic:
WITH span AS (
  SELECT user_id FROM ml.ratings GROUP BY user_id
  HAVING min(rated_at) < '1997-08-01' AND max(rated_at) >= '1997-09-01')
SELECT date_trunc('day', max_r) AS last_day, count(*) AS users
FROM (SELECT user_id, max(rated_at) AS max_r FROM ml.ratings
      WHERE user_id IN (SELECT user_id FROM span) GROUP BY user_id)
GROUP BY last_day ORDER BY users DESC LIMIT 10;
-- 1998-05-22: 475 of 506 (94%) | 1998-06-07: 16 | 1998-06-02: 11 | 4 stragglers
-- Humans do not quit in unison; batch jobs do. An undocumented migration
-- event ending 1998-05-22, and the dataset's third timestamp scar.

-- Q2b: the remap fingerprint. Same five values, era-split shares:
SELECT rating, count(*) AS n,
       round(100.0 * count(*) / (SELECT count(*) FROM ml.ratings
             WHERE rated_at < '1997-08-01'), 1) AS pct
FROM ml.ratings WHERE rated_at < '1997-08-01'
GROUP BY rating ORDER BY rating;
-- EachMovie era:  1: 3.8% | 2: 5.9% | 3: 40.8% | 4: 29.6% | 5: 19.9%
SELECT rating, count(*) AS n,
       round(100.0 * count(*) / (SELECT count(*) FROM ml.ratings
             WHERE rated_at BETWEEN '1997-09-01' AND '2003-02-18'), 1) AS pct
FROM ml.ratings WHERE rated_at BETWEEN '1997-09-01' AND '2003-02-18'
GROUP BY rating ORDER BY rating;
-- Native era:     1: 5.8% | 2: 11.2% | 3: 26.5% | 4: 34.7% | 5: 21.9%
-- A 14-point single-bin spike on 3 in the imported era: the signature of
-- stars = 1 + 4*score sending EachMovie's 0.4 and 0.6 both to 3 under
-- rounding. Population drift leans a distribution; it does not spike one
-- interior value while the neighbors stay ordinary.

-- Q3: the half-star instrument change, precise to the second:
SELECT min(rated_at) AS first_half_star
FROM ml.ratings WHERE rating != floor(rating);
-- 2003-02-18 13:48:10
