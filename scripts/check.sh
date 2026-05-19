#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/check-no-placeholders.sh
lake build
./scripts/check-extractor-snapshot.sh
(cd rust && cargo fmt --check && cargo clippy -- -D warnings && cargo test)
