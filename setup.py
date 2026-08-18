"""One-command setup: fetch MovieLens 25M and import it into movielens.duckdb.

Idempotent: skips the download if data/ml-25m.zip exists and the import if
movielens.duckdb already has the tables. The extraction directory is removed
afterwards; the zip is kept so everything re-derives offline.
"""
import pathlib, shutil, sys, urllib.request, zipfile

import duckdb

HERE = pathlib.Path(__file__).parent
ZIP = HERE / "data" / "ml-25m.zip"
DB = HERE / "movielens.duckdb"
URL = "https://files.grouplens.org/datasets/movielens/ml-25m.zip"

if not ZIP.exists():
    ZIP.parent.mkdir(exist_ok=True)
    print(f"downloading {URL} (~262MB)...")
    urllib.request.urlretrieve(URL, ZIP)
print(f"zip: {ZIP.stat().st_size/1e6:.0f} MB")

con = duckdb.connect(DB)
have = {r[0] for r in con.sql("SHOW TABLES").fetchall()}
if {"ratings", "movies", "tags", "links", "genome_tags", "genome_scores"} <= have:
    print("tables already imported; nothing to do")
    sys.exit(0)

print("extracting...")
with zipfile.ZipFile(ZIP) as z:
    z.extractall(ZIP.parent)
src = ZIP.parent / "ml-25m"
print("importing...")
con.sql(f"""CREATE OR REPLACE TABLE ratings AS
  SELECT userId AS user_id, movieId AS movie_id, rating,
         to_timestamp(timestamp) AS rated_at
  FROM read_csv('{(src / "ratings.csv").as_posix()}')""")
con.sql(f"""CREATE OR REPLACE TABLE movies AS
  SELECT movieId AS movie_id, title, genres
  FROM read_csv('{(src / "movies.csv").as_posix()}')""")
con.sql(f"""CREATE OR REPLACE TABLE tags AS
  SELECT userId AS user_id, movieId AS movie_id, tag,
         to_timestamp(timestamp) AS tagged_at
  FROM read_csv('{(src / "tags.csv").as_posix()}')""")
con.sql(f"""CREATE OR REPLACE TABLE links AS
  SELECT movieId AS movie_id, imdbId AS imdb_id, tmdbId AS tmdb_id
  FROM read_csv('{(src / "links.csv").as_posix()}')""")
con.sql(f"""CREATE OR REPLACE TABLE genome_tags AS
  SELECT tagId AS tag_id, tag FROM read_csv('{(src / "genome-tags.csv").as_posix()}')""")
con.sql(f"""CREATE OR REPLACE TABLE genome_scores AS
  SELECT movieId AS movie_id, tagId AS tag_id, relevance
  FROM read_csv('{(src / "genome-scores.csv").as_posix()}')""")
for tbl in ("ratings", "movies", "tags", "links", "genome_tags", "genome_scores"):
    print(f"  {tbl}: {con.sql(f'SELECT count(*) FROM {tbl}').fetchone()[0]:,} rows")
con.close()
shutil.rmtree(src)
print(f"done: movielens.duckdb ({DB.stat().st_size/1e6:.0f} MB); extraction removed, zip kept")
