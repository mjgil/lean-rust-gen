#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import pathlib

proof = json.loads(pathlib.Path("rust/proof-report.json").read_text())
policy = proof.get("policy", {})
if policy.get("corpus_harness") is not True:
    raise SystemExit("proof-report corpus_harness policy is missing or false")
PY
