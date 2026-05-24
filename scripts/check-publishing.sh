#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 scripts/check-publishing.py

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/repo"
rsync \
  -a \
  --exclude '.git' \
  --exclude '.lake' \
  --exclude 'target' \
  --exclude '__pycache__' \
  --exclude '*.pyc' \
  "$PWD"/ "$tmpdir/repo"/

mkdir -p "$tmpdir/repo/.cargo"
cat > "$tmpdir/repo/.cargo/config.toml" <<'EOF'
[patch.crates-io]
lean-rust-core-runtime = { path = "crates/runtime" }
lean-rust-core-abi = { path = "crates/abi" }
lean-rust-core-validate = { path = "crates/validate" }
lean-rust-core-headers = { path = "crates/headers" }
EOF

cd "$tmpdir/repo"

cargo doc --workspace --no-deps
cargo tree --workspace

for package in \
  lean-rust-core-generated \
  lean-rust-core-runtime \
  lean-rust-core-abi \
  lean-rust-core-validate \
  lean-rust-core-headers
do
  cargo publish --dry-run -p "$package"
done
