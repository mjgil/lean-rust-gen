#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
import pathlib
import re

root = pathlib.Path(".")
template_re = re.compile(
    r'\{\s*code := "(LRC\d{3})", severity := \.(\w+), construct := "([^"]+)", '
    r'nextFeature := "([^"]+)", documentation := "([^"]+)", requiresSpan := (true|false) \}'
)
proof = json.loads(pathlib.Path("rust/proof-report.json").read_text())
policy = proof.get("policy", {})
if policy.get("corpus_harness") is not True:
    raise SystemExit("proof-report corpus_harness policy is missing or false")

templates = {}
for match in template_re.finditer(pathlib.Path("LeanRustCore/Diagnostics.lean").read_text()):
    code, severity, construct, next_feature, documentation, requires_span = match.groups()
    templates[code] = {
        "severity": severity,
        "construct": construct,
        "next_feature": next_feature,
        "documentation": documentation,
        "requires_span": requires_span == "true",
    }
if len(templates) != 14:
    raise SystemExit("LeanRustCore/Diagnostics.lean must define 14 stable LRC templates")

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
        code = str(data.get("diagnostic_code", ""))
        if code not in templates:
            raise SystemExit(f"{fixture} missing stable LRC diagnostic code")
        template = templates[code]
        if data.get("source_span_required") is not template["requires_span"]:
            raise SystemExit(f"{fixture} must match requiresSpan={template['requires_span']} for {code}")
        if data.get("next_feature") != template["next_feature"]:
            raise SystemExit(f"{fixture} must use next_feature {template['next_feature']}")
        expected_status = "error" if template["severity"] == "error" else "unsupported"
        if data.get("expected_status") != expected_status:
            raise SystemExit(f"{fixture} must use expected_status {expected_status}")
        if template["documentation"] not in data.get("documentation", []):
            raise SystemExit(f"{fixture} must reference {template['documentation']}")
PY
