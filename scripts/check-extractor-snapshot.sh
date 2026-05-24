#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

format_generated_rust() {
  rustfmt --edition 2021 "$1"
}

./scripts/check-first-20-completion.py
./scripts/check-next-20-completion.py
./scripts/check-remaining-completion.py

tmp="$(mktemp)"
lake exe gen_rust "$tmp"
format_generated_rust "$tmp"
diff -u rust/src/generated.rs "$tmp"
rm -f "$tmp"

tmp_report="$(mktemp)"
lake exe gen_compatibility_report "$tmp_report"
diff -u rust/compatibility-report.json "$tmp_report"
rm -f "$tmp_report"

tmp_proof="$(mktemp)"
lake exe gen_proof_report "$tmp_proof"
diff -u rust/proof-report.json "$tmp_proof"
rm -f "$tmp_proof"

tmp_diff="$(mktemp)"
lake exe gen_differential_tests "$tmp_diff"
format_generated_rust "$tmp_diff"
diff -u rust/tests/differential_generated.rs "$tmp_diff"
rm -f "$tmp_diff"

tmp_validation="$(mktemp)"
lake exe gen_validation_report "$tmp_validation"
diff -u rust/validation-report.json "$tmp_validation"
rm -f "$tmp_validation"


tmp_metadata="$(mktemp)"
lake exe gen_build_metadata "$tmp_metadata"
diff -u rust/build-metadata.json "$tmp_metadata"
rm -f "$tmp_metadata"

tmp_target_validation="$(mktemp)"
lake exe gen_target_validation "$tmp_target_validation"
diff -u rust/target-validation.txt "$tmp_target_validation"
rm -f "$tmp_target_validation"

tmp_boundary="$(mktemp)"
lake exe gen_boundary_exports "$tmp_boundary"
format_generated_rust "$tmp_boundary"
diff -u rust/src/ffi_generated.rs "$tmp_boundary"
rm -f "$tmp_boundary"

tmp_coverage="$(mktemp)"
lake exe gen_coverage_dashboard "$tmp_coverage"
diff -u rust/coverage-dashboard.json "$tmp_coverage"
rm -f "$tmp_coverage"
