"""Start a local PostgreSQL 16 + pgvector for development without Docker (uses the `pgserver` pip package).

Usage:  python infra/dev/localpg.py            -> prints the SA_DATABASE_URL to use
Data lives in ./data/pg (git-ignored). The server keeps running after this script exits.
"""
import sys
from pathlib import Path

import pgserver

data = Path(__file__).resolve().parents[2] / "data" / "pg"
data.mkdir(parents=True, exist_ok=True)
srv = pgserver.get_server(str(data), cleanup_mode=None)
db = sys.argv[1] if len(sys.argv) > 1 else "seafarer"
if "(0 rows)" in srv.psql(f"select 1 from pg_database where datname='{db}';"):
    srv.psql(f"create database {db};")
uri = srv.get_uri(db).replace("postgresql://", "postgresql+psycopg://")
print(uri)
