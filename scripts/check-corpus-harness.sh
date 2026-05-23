#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import pathlib

root = pathlib.Path(".")
proof = json.loads(pathlib.Path("rust/proof-report.json").read_text())
policy = proof.get("policy", {})
if policy.get("corpus_harness") is not True:
    raise SystemExit("proof-report corpus_harness policy is missing or false")

required_dirs = ["corpus/positive", "corpus/negative", "corpus/unsupported"]
for directory in required_dirs:
    path = root / directory
    if not path.is_dir():
        raise SystemExit(f"missing corpus directory {directory}")
    if not any(path.glob("*.expected.json")):
        raise SystemExit(f"{directory} must contain at least one expected diagnostic/status JSON fixture")

for fixture in root.glob("corpus/*/*.expected.json"):
    data = json.loads(fixture.read_text())
    if data.get("format") != "lean-rust-core.corpus-case.v1":
        raise SystemExit(f"{fixture} has wrong format")
    for key in ["kind", "source", "expected_status", "tests", "documentation"]:
        if key not in data:
            raise SystemExit(f"{fixture} missing {key}")
    if data["kind"] in {"negative", "unsupported"}:
        if not str(data.get("diagnostic_code", "")).startswith("LRC"):
            raise SystemExit(f"{fixture} missing stable LRC diagnostic code")
        if data.get("source_span_required") is not True:
            raise SystemExit(f"{fixture} must require source span metadata")
PY
