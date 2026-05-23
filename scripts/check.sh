#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/check-no-placeholders.sh
./scripts/check-toolchain-pins.sh
./scripts/check-first-20-completion.py
./scripts/check-next-20-completion.py
./scripts/check-final-16-completion.py
./scripts/check-remaining-completion.py
lake build
./scripts/check-extractor-snapshot.sh
./scripts/check-rust-validation.sh
cargo fmt --check --all
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo test -p lean-rust-core-generated --features ffi
