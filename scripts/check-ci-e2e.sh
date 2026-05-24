#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

lane="${1:-default}"

case "$lane" in
  default)
    ./scripts/check.sh
    ;;
  ffi)
    ./scripts/check.sh
    cargo test --workspace --features ffi
    ;;
  *)
    echo "usage: $0 [default|ffi]" >&2
    exit 1
    ;;
esac
