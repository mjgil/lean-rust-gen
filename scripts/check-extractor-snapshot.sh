#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

tmp="$(mktemp)"
lake exe gen_rust "$tmp"
diff -u rust/src/generated.rs "$tmp"
rm -f "$tmp"
