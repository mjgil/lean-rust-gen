#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

python3 scripts/check-publishing.py

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

python3 - "$PWD" "$tmpdir/repo" <<'PY'
import pathlib
import shutil
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
shutil.copytree(
    src,
    dst,
    ignore=shutil.ignore_patterns(".git", "target", "__pycache__", "*.pyc"),
)
PY

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
