#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

generated="rust/src/generated.rs"
validation_report="rust/validation-report.json"
differential_tests="rust/tests/differential_generated.rs"

required_files=("$generated" "$validation_report" "$differential_tests")
for path in "${required_files[@]}"; do
  test -f "$path"
done

# The direct Lean-emits-Rust lane should emit ordinary safe Rust only. Raw FFI
# wrappers stay out of this path until an explicit boundary exporter is added.
! grep -n -E '(^|[^A-Za-z0-9_])unsafe([^A-Za-z0-9_]|$)|extern "C"|panic!|todo!|unimplemented!|/\* malformed|unsupported wrapping op' "$generated"

grep -q '"format": "lean-rust-core.rust-validation.v1"' "$validation_report"
grep -q '"architecture": "direct-lean-emits-rust"' "$validation_report"
grep -q '"name": "lean-evaluator-differential-tests"' "$validation_report"
grep -q '"name": "safe-rust-subset-gate"' "$validation_report"
! grep -q '"status": "failed"' "$validation_report"

grep -q 'LeanRustCore.Differential' "$differential_tests"
grep -q 'lean_evaluator_matches_generated_rust' "$differential_tests"
grep -q 'add_u32(u32::MAX, 1)' "$differential_tests"
