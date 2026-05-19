#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

lake exe gen_rust rust/src/generated.rs
lake exe gen_proof_report rust/proof-report.json
lake exe gen_compatibility_report rust/compatibility-report.json
lake exe gen_differential_tests rust/tests/differential_generated.rs
lake exe gen_validation_report rust/validation-report.json
