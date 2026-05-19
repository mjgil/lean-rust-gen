#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

lake exe gen_rust rust/src/generated.rs
lake exe gen_proof_report rust/proof-report.json
lake exe gen_compatibility_report rust/compatibility-report.json
