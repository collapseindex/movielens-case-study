# MovieLens Case Study

*A case study by [Alex Kwon](https://github.com/collapseindex).*

**Status: complete.** Phases 1 and 2 dry, report delivered. Second analyst case study, transferring the
methodology proven on the [e-commerce case](https://github.com/collapseindex/ecommerce-case-study)
to data at real scale: **25,000,095 ratings** across 62,423 movies from
MovieLens 25M, the canonical public recommender corpus (F. Maxwell Harper and
Joseph A. Konstan, ACM TiiS 2015).

The scale is the point. The e-commerce case had 35 rows and three of five
defects fell to reading them; at 25M rows eyeballing is dead, and the sweeps,
grain decisions, and join discipline are the only eyes there are.

## The engagement

You are the analyst at a streaming service. Product asks: what does our
catalog's rating behavior actually look like, where is the dead weight, and
what changed over the platform's 25-year history? Deliverable: findings with
receipts and a stakeholder report, same two registers as last time.

## Structure

| file | what it is |
|---|---|
| [FINDINGS.md](FINDINGS.md) | Findings with row ids and recomputations, appended as earned |
| [sql/01_worksheet.sql](sql/01_worksheet.sql) | The working document: the questions, plus queries logged as earned |
| [sql/02_sweeps.sql](sql/02_sweeps.sql) | Phase-1 sweeps with their actual outputs |
| [sql/03_contract_checks.sql](sql/03_contract_checks.sql) | The README's claims, checked; two held, one stale |
| [sql/04_seams_and_eras.sql](sql/04_seams_and_eras.sql) | The 1997 seam, the 1998 batch scar, the remap fingerprint, the 2003 switch |
| [sql/05_analysis.sql](sql/05_analysis.sql) | Phase 2: rater buckets, both genre grains, the flattery staircase |
| [setup.py](setup.py) | One command: download the corpus, import to DuckDB |
| [REPORT.md](REPORT.md) | The audit report, written for humans: five sentences up top, receipts below |
| [report.html](report.html) | The same report as a presentable page: annotated 25-year timeline, the flattery staircase, dark mode |

## Reproduce

```bash
pip install duckdb
python setup.py     # fetches ml-25m.zip (~262MB), builds movielens.duckdb
```

Tables: `ratings` (user_id, movie_id, rating, rated_at), `movies` (movie_id,
title, genres), `tags`, `links`, `genome_tags`, `genome_scores`. The data
itself is not committed (262MB, and GroupLens asks that the canonical download
be the source); `setup.py` re-derives everything.

One operating rule inherited from day one: **never bare `SELECT *` on
ratings** in a UI. 25M rows into a browser tab is a crash, not a query.

## References

- F. Maxwell Harper and Joseph A. Konstan. 2015. *The MovieLens Datasets:
  History and Context.* ACM TiiS 5(4).
  <https://doi.org/10.1145/2827872> (the dataset's citation of record)
- Joseph A. Konstan, John Riedl, Al Borchers, and Jonathan L. Herlocker.
  1998. *Recommender Systems: A GroupLens Perspective.* AAAI Technical
  Report WS-98-08, pp. 60-64.
  <https://cdn.aaai.org/Workshops/1998/WS-98-08/WS98-08-016.pdf>
  (primary source for the summer-1997 launch and the 2.8M-rating EachMovie
  "dead data" seeding; the receipt behind finding Q2)
- GroupLens dataset releases: <https://grouplens.org/datasets/movielens/>

## License

Code (SQL, scripts, the notebook) is **Apache-2.0** ([LICENSE](LICENSE)).
The written reports and figures (REPORT.md, report.html, FINDINGS.md, this
README) are **[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)**,
the same license as my papers: reuse with attribution ("Three Rulers, One Dataset",
Alex Kwon, github.com/collapseindex/movielens-case-study).

