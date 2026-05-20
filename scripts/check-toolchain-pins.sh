#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

expected_lean='leanprover/lean4:v4.22.0'
expected_rust='1.85.0'

actual_lean="$(tr -d '\r\n' < lean-toolchain)"
if [[ "$actual_lean" != "$expected_lean" ]]; then
  echo "lean-toolchain must be pinned to $expected_lean, found $actual_lean" >&2
  exit 1
fi

if ! grep -q "channel = \"$expected_rust\"" rust-toolchain.toml; then
  echo "rust-toolchain.toml must pin channel = \"$expected_rust\"" >&2
  exit 1
fi

if grep -qE 'lean4:(stable|nightly)|lean4:master' lean-toolchain; then
  echo "lean-toolchain must not use a moving Lean channel" >&2
  exit 1
fi

if grep -qE 'channel = "(stable|beta|nightly)"' rust-toolchain.toml; then
  echo "rust-toolchain.toml must not use a moving Rust channel" >&2
  exit 1
fi

grep -q "\"lean_toolchain\": \"$expected_lean\"" rust/build-metadata.json
grep -q "\"rust_toolchain\": \"$expected_rust\"" rust/build-metadata.json
grep -q 'LEAN_RUST_CORE_ALLOW_FALLBACK' rust/build-metadata.json
