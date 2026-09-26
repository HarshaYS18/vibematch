"""Chunk 48 ClickHouse/data-lake architecture guard."""
from __future__ import annotations
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
APP=ROOT/"apps/analytics-sink"

def require(path, markers):
    p=ROOT/path if isinstance(path,str) else path
    if not p.is_file(): raise SystemExit(f"missing analytics artifact: {p.relative_to(ROOT)}")
    text=p.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text: raise SystemExit(f"{p.relative_to(ROOT)} missing {marker}")
    return text

def main():
    require(APP/"consumer.py",("enable_auto_commit=False","await sink.write_batch(valid)","OffsetAndMetadata"))
    require(APP/"sink.py",("ReplacingMergeTree","pyarrow.parquet","put_object","compression=\"zstd\""))
    require(APP/"config.py",("production analytics requires KAFKA_SECURITY_PROTOCOL=SASL_SSL","object_store_mode"))
    combined="\n".join(p.read_text(encoding="utf-8") for p in APP.glob("*.py"))
    if re.search(r"\b(sqlalchemy|psycopg|SessionLocal)\b",combined):
        raise SystemExit("analytics sink must never gain business database authority")
    require("docs/architecture/analytics-platform.md",("ClickHouse","Parquet","projection"))
    require("docs/runbooks/analytics-platform.md",("replay","ClickHouse"))
    require("docs/platform/chunk48-analytics-clickhouse-lake.md",("Chunk 48",))
    print("Analytics/ClickHouse/data-lake guard: OK")
if __name__=="__main__": main()
