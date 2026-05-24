#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

format_generated_rust() {
  rustfmt --edition 2021 "$1"
}

lake exe gen_rust rust/src/generated.rs
format_generated_rust rust/src/generated.rs
lake exe gen_proof_report rust/proof-report.json
lake exe gen_compatibility_report rust/compatibility-report.json
lake exe gen_differential_tests rust/tests/differential_generated.rs
format_generated_rust rust/tests/differential_generated.rs
lake exe gen_validation_report rust/validation-report.json
lake exe gen_target_validation rust/target-validation.txt
lake exe gen_extract_ir rust/extract-ir.txt
lake exe gen_boundary_exports rust/src/ffi_generated.rs
format_generated_rust rust/src/ffi_generated.rs
lake exe gen_build_metadata rust/build-metadata.json
lake exe gen_coverage_dashboard rust/coverage-dashboard.json
