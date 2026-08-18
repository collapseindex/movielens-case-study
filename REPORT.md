# MovieLens 25M: Audit Report

**Analyst:** [Alex Kwon](https://github.com/collapseindex)
**What this is:** an end-to-end analyst audit of MovieLens 25M, one of the
most-used public datasets in the world (25,000,095 movie ratings, 1995-2019).
**Full evidence:** [FINDINGS.md](FINDINGS.md) · runnable queries in [sql/](sql/)
· every number independently recomputed before publication.

## The whole report in five sentences

1. Structurally, this dataset is **immaculate**: every promise its
   documentation makes about uniqueness and completeness checks out exactly,
   across all 25 million rows.
2. But the 25-year "time series" is really **three different measuring
   instruments stitched together**, and the seams are not mentioned in the
   dataset's own README.
3. The oldest instrument (imported from a different company's website)
   **made bad movies look almost a full star better** than later eras rate
   the same films.
4. The "average rating" mostly reflects a small, harsh minority: **20% of
   users cast 64% of all ratings**, and they rate about half a star lower
   than casual users.
5. Questions like "what is the best movie?" have no single answer here,
   only answers-with-settings, and this report shows how the settings
   change the winner.

**One-line verdict: the data is immaculate; the ruler moved.**

## Part 1: What checked out (and why you can trust the rest)

An audit that only reports problems is a complaint. These claims from the
dataset's documentation were tested and **held exactly**:

| documented promise | result |
|---|---|
| every movie has at least one rating or tag | true for all 62,423 movies |
| one rating per (user, movie) pair | true across 25,000,095 rows |
| movie ids unique | true in both tables that claim it |
| no duplicate movies in the catalog | true: all 98 same-title pairs are genuinely different films |

That last one matters: 98 pairs of movies share a title and year, which looks
alarming until you check their IMDb links and find every pair is two real,
different films. (Fun example: *Dracula (1931)* is two movies, an English and
a Spanish version, filmed on the same sets.)

One thing did not check out: the README's list of legal genres is stale in
both directions. The data contains `IMAX` (not in the list) and `Children`
(the list says `Children's`). Small, but real: documentation drifts even at
the University of Minnesota.

## Part 2: The three rulers

Group the ratings by year and count the distinct values raters used, and the
dataset confesses its own history:

| era | period | what a rating could be | where it came from |
|---|---|---|---|
| 1 | Jan 1996 - Jul 1997 | 1, 2, 3, 4, 5 | **a different website.** MovieLens launched in fall 1997 seeded with 2.8M ratings from EachMovie, a shuttered DEC research site, imported with original timestamps ("dead data," per the founders' own 1998 paper) |
| 2 | Sep 1997 - Feb 2003 | 1, 2, 3, 4, 5 | MovieLens, whole stars |
| 3 | Feb 18, 2003 onward | 0.5 to 5.0 in halves | MovieLens v3: half-stars were the most-requested feature, and the first one in the data is stamped 2003-02-18 13:48:10 |

Between eras 1 and 2 there is a **48-day hole**: the last imported rating is
July 23, 1997, the first native one September 9, 1997. August 1997 simply
does not exist in this dataset. There are also three timestamp scars, all
found by grouping and counting: three ratings from one user stamped on a
single second in January 1995 (before either website existed), the 48-day
seam, and 506 accounts whose activity all terminates in unison on the
morning of May 22, 1998, the signature of an undocumented batch migration.

**Why care?** Because the old ruler measured differently. We took every
movie with 200+ ratings in both whole-star eras (822 movies) and compared
how each era scored the *same films*:

| how era 2 rates the movie | era 1 scored it | difference |
|---|--:|--:|
| terrible (1.5 average) | 2.42 | **+0.81 stars kinder** |
| bad (2.0) | 2.73 | +0.66 |
| below average (2.5) | 3.01 | +0.46 |
| average (3.0) | 3.27 | +0.26 |
| good (3.5) | 3.58 | +0.08 |
| great (4.0) | 3.92 | -0.07 |
| beloved (4.5) | 4.22 | -0.14 |

A clean staircase: **the imported era flattered bad movies by nearly a full
star and barely touched the great ones.** Any analysis that averages across
1997 without splitting eras inherits this distortion. Twenty years of
research papers have used this file as one continuous series.

## Part 3: Who is actually doing the rating

Bucket the 162,541 users by how much they rate (populations sum exactly;
so do their ratings):

| user type | users | share of all ratings | their average rating |
|---|--:|--:|--:|
| casual (20-49 ratings) | 60,049 | 7.6% | 3.71 |
| regular (50-199) | 69,415 | 28.0% | 3.73 |
| heavy (200-999) | 30,402 | 47.7% | 3.55 |
| extreme (1000+) | 2,675 | 16.8% | 3.26 |

Two facts fall out. First, **heavy raters are harsher**: nearly half a star
between casual and extreme. Second, **they dominate**: the top two buckets
are 20% of users and 64% of all ratings. The dataset's "average rating" is
mostly the opinion of its most prolific, most critical minority. (Also
remember who is missing entirely: the sample only includes users with 20+
ratings, so casual visitors do not exist here at all.)

## Part 4: "Best movie" is a settings menu, not a fact

Ask for the highest-rated movie and the answer depends entirely on a knob
called the minimum-ratings floor:

| floor | winner | average | ratings |
|--:|---|--:|--:|
| none | an 820-way tie of perfect 5.0s | 5.0 | 1 each |
| 1,000 | Planet Earth II (a TV series) | 4.48 | 1,124 |
| 10,000 | The Shawshank Redemption | 4.41 | 81,482 |

855 movies hold a perfect score; 820 of them earned it from exactly one
person. Honest rankings publish the floor next to the winner. (Most-rated
is a different question with a different answer: Forrest Gump, 81,491,
nine ratings ahead of Shawshank.)

Genre rankings have the same property. Weight by ratings and every genre
looks better than its catalog does, because hits dominate; Crime jumps
from 11th to 4th depending on the weighting. Only Documentary rates almost
identically both ways: its obscure titles are as loved as its famous ones,
because nobody watches documentaries by accident.

## Part 5: If you use this dataset

Practical rules this audit earned:

1. **For any over-time analysis, split at the seams** (Sept 1997 and Feb
   2003) or use post-2003 data only. The instrument changed twice.
2. **Publish your floor** with any per-movie ranking, and check the winner
   at two floors.
3. **Decide your grain** for genre or group averages (per-rating or
   per-movie) and say which; they rank differently.
4. **Expect volume swings to be history, not behavior**: the Oct 1999 10x
   spike is a Malcolm Gladwell article, ABC Nightline, and Roger Ebert;
   the 2015 surge is the v4 relaunch.
5. **Remember the sample design**: no user under 20 ratings exists here,
   both scale endpoints are squeezed (0.5 often means "would give 0"), and
   pooled averages over-represent the harsh extreme-rater minority.

## Limitations

Right-boundary effects apply throughout (a rating scale cannot express
sentiment past its edges); mechanisms behind era differences are tied
between instrument remapping and audience selection, and this data cannot
split them; the three-ratings 1995 artifact and the May 1998 batch event
remain unexplained by any public document we found.

## Method, in one paragraph

Definitions were pinned before querying; three mechanical sweeps ran to
completion before any analysis (distinct values, ranges, id sequences);
every documented claim was treated as a testable contract; every rate ships
with its n; parts were checked against wholes; predictions were written
down before queries ran, and the ones that died are reported dead. Every number here re-derives from
[sql/](sql/) against the database `setup.py` builds.

## References

Konstan, Riedl, Borchers & Herlocker 1998 (AAAI WS-98-08): the seed and
launch receipts. Harper & Konstan 2015 (ACM TiiS): the version history that
resolved both volume walls. Full citations in the [README](README.md).
