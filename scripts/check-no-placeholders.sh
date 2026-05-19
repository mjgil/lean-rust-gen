#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

! grep -R -n -E '\b(sorry|admit)\b|^\s*axiom\b' LeanRustCore Main.lean ProofReportMain.lean CompatibilityReportMain.lean DifferentialMain.lean ValidationReportMain.lean
