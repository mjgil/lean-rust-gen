#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if git ls-files --error-unmatch .ai-history/store.db >/dev/null 2>&1; then
  echo "tracked local artifact: .ai-history/store.db" >&2
  exit 1
fi

if git ls-files --error-unmatch repomix-output.xml >/dev/null 2>&1; then
  echo "tracked local artifact: repomix-output.xml" >&2
  exit 1
fi

if rg -n \
  --glob '!scripts/check-open-source-surface.sh' \
  '/home/|/Users/|C:\\Users\\|file://' \
  README.md docs rust crates scripts .github
then
  echo "public docs contain an absolute local path" >&2
  exit 1
fi

test -f LICENSE
test -f LICENSE-APACHE
test -f LICENSE-MIT
