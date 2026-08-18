# Findings

Data quality (Q), business (B), limitations (L), same taxonomy as the
[e-commerce case](https://github.com/collapseindex/ecommerce-case-study).
Every number below was computed in the worksheet and independently recomputed
against `movielens.duckdb` before being written down.

## Data quality

### Q1. Three ratings at the dataset's origin, one user, one second

The entire year 1995 is three rows: user 2262, three movies, all stamped
`1995-01-09 03:46:49` to the second. The timestamp predates MovieLens (launched
summer 1997) and EachMovie (launched January 1996) alike, so it is almost
certainly not a moment anyone rated three movies. It is, however, the origin of
the README's claim that the data spans "January 09, 1995" onward: the
dataset's advertised start date rests on three artifact rows.

**Disposition:** negligible mass (3 of 25,000,095); flagged; excluded from
time-series claims.

### Q2. The 25-year time series is two platforms stitched at a 48-day seam

Ratings per month ramp organically from 42 (Jan 1996) to 230k (Jun 1996),
decline through mid-1997, then **stop entirely: the last pre-seam rating is
1997-07-23 00:55:30 and the next is 1997-09-09 09:35:25**, a 48-day hole
(August 1997 does not appear in a monthly GROUP BY at all; absence renders as
nothing, which is why it went unnoticed until counted). Volume resumes at
~17k/month, roughly a tenth of the pre-seam rate.

The founders' own workshop paper (Konstan, Riedl, Borchers & Herlocker,
"Recommender Systems: A GroupLens Perspective," AAAI Technical Report
WS-98-08, 1998, pp. 60-64;
[pdf](https://cdn.aaai.org/Workshops/1998/WS-98-08/WS98-08-016.pdf)) names
the mechanism: MovieLens **launched in the
summer of 1997**, seeded with **"over 2.8 million ratings from the earlier
EachMovie recommender system"** received as anonymous users: **"dead data."**
The pre-seam era in this extract is 1,966,631 ratings from 30,299 user ids,
whole stars only.

Consequences:
- Pre-seam "users" are not MovieLens users; user-behavior comparisons across
  the seam compare two products' populations.
- The ml-25m README describes one homogeneous collection ("created by 162541
  users between January 09, 1995 and November 21, 2019"); the founders' paper
  says otherwise. The receipt beats the summary.

**Open anomaly (Q2a):** the paper says the imported users "could not be
associated with our own." That predicts **zero** user ids with ratings on
both sides of the seam. The count is **506**. Either some accounts were
linkable after all, some pre-seam ratings are early-native MovieLens activity
mixed into the dead data, or the seam boundary is fuzzier than one cut date.
Unresolved; the 506 deserve their own look.

**Open hypothesis (Q2b):** EachMovie collected ratings on a 0-1 scale in 0.2
steps, six values (from memory, unverified against EachMovie documentation).
This extract's pre-seam era shows exactly five values (1-5). If the import
remapped six values onto five, pre-1997 ratings were born on a different
ruler and transcribed. Testable: era-split rating distributions should show
a remapping dent. Not yet run.

### Q3. The rating instrument changed mid-stream on 2003-02-18

Distinct rating values per year: 5 (whole stars) through 2002, 10 from 2003
on. The **first half-star in the dataset is stamped 2003-02-18 13:48:10**: a
feature launch, precise to the second, recovered from timestamps alone.

Consequences: any over-time average crosses an instrument change (finer
expressiveness, same opinions); the expressible floor moved from 1.0 to 0.5,
so "lowest possible rating" means different things by era (see L2); with Q2,
the file is **three instruments in sequence** (EachMovie remapped, MovieLens
whole-star, MovieLens half-star), sold by the README as one series.

### Q4. The README's genre vocabulary is stale in both directions

The README enumerates the complete legal genre list. Unnesting the actual
`genres` column yields 20 distinct values, and the diff runs both ways:
**`IMAX` exists in the data but not in the documented list**, and the doc's
**`Children's` appears in the data as `Children`** (no apostrophe-s), an
inheritance from an older generation of the dataset. Minor severity, real
lesson: this is the e-commerce `west` finding mirrored, with the
documentation stale and the data consistent. Contract checks adjudicate
disagreement; they do not presume which side drifted.

### Checks that held (logged because a pass has to mean something)

- **"Every movie has at least one rating or tag": exactly true.** All 3,376
  zero-rating movies carry tags; contract violations: 0.
- **"One rating of one movie by one user": exactly true.** No duplicate
  (user_id, movie_id) pair in 25,000,095 rows.

## Business

### B1 (preliminary). Most-rated and best-rated are different questions

From the first 20 rows of the movie dimension table: Forrest Gump leads on
count (81,491, nine ahead of Shawshank's 81,482); Shawshank leads the same
list on average (4.41 vs 4.05). Any "top movies" claim must name its metric.
**Status: preliminary** (top-20 only, no floors; C2 upgrades or kills it).

### B2 (observation). Ratings cluster generously

68% of all ratings (16.9M of 25M) sit in the 3-4 star band; the mode is 4.
The scale's midpoint is not the distribution's center. Mechanism note:
people rate movies they chose to watch, so this measures opinions about
self-selected movies (see L1, L2).

## Limitations

- **L1. The sample designs casual users out.** Per the README: random user
  sample, and every included user rated at least 20 movies. Light raters are
  invisible by construction, and yearly volumes are this sample's shadow of
  site history, not site history.
- **L2. Both scale boundaries are censored.** 0.5 (393,068 ratings) reads as
  "would go lower if allowed"; 5.0 (3.6M) as "would go higher." Averages near
  the boundaries average squeezed sentiment. Pre-2003 the floor was 1.0 (Q3),
  so boundary meaning also shifts by era.
- **L3. Timestamps are UTC; this analysis buckets in local time.** Irrelevant
  at year grain except at boundaries; declared once here.

## Open threads

- Phase-1 closers: movie_id uniqueness in `movies` and `links`; duplicate
  title+year pairs (the README itself warns "errors and inconsistencies may
  exist in these titles").
- Q2a: who are the 506 seam-spanning users?
- Q2b: the remap fingerprint (era-split rating distribution).
- The Oct-Dec 1999 wall (34k -> 310k -> 400k/month): an event, unexplained.
- The 2015-2017 resurgence: same question, 16 years later.
