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

**Q2a (resolved as mechanical):** the paper says the imported users "could
not be associated with our own," predicting zero user ids with ratings on
both sides of the seam. The count is 506, but their endings are coordinated,
not organic: **475 of 506 (94%) have their last rating on 1998-05-22**, and
502 of 506 finish within May 22 to June 7, 1998. Humans do not quit in
unison; batch jobs do. The spanning is consistent with an undocumented
migration or import event ending 1998-05-22, not with people using both
platforms under one id. The paper's claim survives in spirit, and the
dataset gains a third timestamp scar (1995 second, 1997 seam, 1998 batch
termination).

**Q2b (supported by fingerprint):** era-split distributions over the same
five values disagree in a mechanically specific way:

| rating | EachMovie era | native whole-star era (1997-09 to 2003-02) |
|--:|--:|--:|
| 1 | 3.8% | 5.8% |
| 2 | 5.9% | 11.2% |
| 3 | **40.8%** | 26.5% |
| 4 | 29.6% | **34.7%** |
| 5 | 19.9% | 21.9% |

The imported era's mode is 3 with a 14-point single-bin spike. That is the
exact signature of the natural affine conversion from EachMovie's 0-1
six-value scale (0.2 steps; from memory, externally unverified) to stars:
`stars = 1 + 4*score` sends both 0.4 and 0.6 to 3 under rounding, collapsing
two source bins into the middle star. Population drift can lean a
distribution; it struggles to spike one interior value by 14 points while
the neighbors stay ordinary. External verification of the EachMovie scale
would seal this.

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
- **movie_id unique in `movies` and `links`**: 62,423 = 62,423 in both.
- **All ~98 title+year twins are distinct films.** A self-join on title,
  adjudicated via `links`: every pair carries different imdb ids, so the
  catalog holds no order-1028-style duplicate and per-movie metrics are safe
  from rating fragmentation. (Dracula (1931) resolves to imdb 0021814 and
  0021815: the English- and Spanish-language versions shot on the same sets.)
  Caveat: exact-string title matching; variant spellings would evade it.

**Phase 1 declared dry, 2026-08-18.** All sweeps and contract checks
complete; remaining threads are investigation, not audit.

## Business

### B1 (confirmed). "Top movie" is a function of metric AND parameter

Most-rated: Forrest Gump (81,491, nine ahead of Shawshank). Best-rated is
not one answer but a floor-sensitive family of answers:

| min ratings | winner | avg | n |
|--:|---|--:|--:|
| none | 820 movies tied at 5.0 | 5.0 | 1 each |
| 1,000 | Planet Earth II (television) | 4.48 | 1,124 |
| 10,000 | The Shawshank Redemption (1994) | 4.41 | 81,482 |

855 movies carry a perfect 5.0 average; 820 of them have exactly one rating.
The floor is a published parameter, not a hidden one: the winner changes at
every tier, so the report shows the sensitivity instead of picking a floor
silently. Two scope notes: MovieLens catalogs television (Planet Earth I/II,
Band of Brothers), so "best movie" needs a stated scope at low floors, and
cross-era average comparisons carry the instrument caveat (Q2b/Q3): movies
old enough to have lived through the EachMovie 3-spike collected ratings
under a regime that dragged averages toward 3.

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

- External verification of EachMovie's rating scale (seals Q2b).
- What happened on 1998-05-22 (Q2a's batch event; likely needs GroupLens
  history, not queries).
- The era tax: do pre-1997 movies' averages differ by era of rating? (One
  era-split query on a handful of old titles settles it.)
- The Oct-Dec 1999 wall (34k -> 310k -> 400k/month): an event, unexplained.
- The 2015-2017 resurgence: same question, 16 years later.
