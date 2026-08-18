# Findings

Data quality (Q), business (B), limitations (L), same taxonomy as the
[e-commerce case](https://github.com/collapseindex/ecommerce-case-study).
Findings are appended as they are earned, with the query that earned each and
its independent recomputation. Nothing here yet is not a defect of the file:
phase 1 is in progress.

## Data quality

*(pending phase 1 sweeps)*

## Business

### B1 (preliminary). Most-rated and best-rated are different questions

From the first 20 rows of the movie dimension table
([sql/01_worksheet.sql](sql/01_worksheet.sql), logged query): Forrest Gump
leads the catalog on rating count (81,491) by nine ratings over Shawshank
(81,482), while Shawshank leads the same list on average (4.41 vs 4.05).
Any "top movies" claim must therefore name its metric before it names a movie.

**Status: preliminary.** Recorded before phase 1 completed, top-20 only, no
floors applied; worksheet C2 upgrades or amends it.

## Limitations

*(stated as they bind)*
