#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp)"
lake exe gen_rust "$tmp"
diff -u rust/src/generated.rs "$tmp"
rm -f "$tmp"

tmp_report="$(mktemp)"
lake exe gen_compatibility_report "$tmp_report"
diff -u rust/compatibility-report.json "$tmp_report"
rm -f "$tmp_report"
