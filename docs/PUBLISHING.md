# Publishing and versioning policy

The workspace uses semver for every Rust crate.

- `lean-rust-core-generated`: additive generated functions/types are
  semver-minor; signature, layout, or emitted-behavior contract changes are
  semver-major.
- `lean-rust-core-runtime`: additive helper APIs are semver-minor; changed
  helper contracts are semver-major.
- `lean-rust-core-abi` and `lean-rust-core-headers`: C-visible signatures,
  ownership rules, and destructor behavior are semver-major.
- `lean-rust-core-validate`: additive report helpers are semver-minor; changed
  public schemas or target-semantics APIs are semver-major.

## Required metadata

Every publishable crate must declare:

- `version`, `edition`, `rust-version`, `license`, `description`
- `readme`, `documentation`, `repository`, `homepage`
- `keywords`, `categories`
- versioned intra-workspace dependencies for every `path` dependency

`scripts/check-publishing.py` validates those fields directly from the checked-in
Cargo manifests.

Required release commands before publishing a crate:

```text
python3 scripts/check-publishing.py
cargo publish --dry-run -p lean-rust-core-generated
cargo publish --dry-run -p lean-rust-core-runtime
cargo publish --dry-run -p lean-rust-core-abi
cargo publish --dry-run -p lean-rust-core-validate
cargo publish --dry-run -p lean-rust-core-headers
cargo doc --workspace --no-deps
cargo tree --workspace
```

The repository-level helper is:

```text
./scripts/check-publishing.sh
```

It runs the metadata/changelog audit in-place, then copies the repo to a clean
temporary release tree before running the workspace docs build, dependency tree,
and exact `cargo publish --dry-run -p <crate>` commands. The copy step avoids
false negatives from unrelated local worktree changes while still validating the
checked source. Local-only artifacts such as `.ai-history/` state files and
`repomix-output.xml` are excluded from that release tree and are guarded by
`scripts/check-open-source-surface.sh`.

For `lean-rust-core-generated`, package verification intentionally uses the
checked-in `src/generated.rs` when the packaged tarball does not contain the
Lean workspace root. Repo-local CI and release builds remain stricter: they
still regenerate through `lake` unless the explicit non-release fallback is
enabled.

## Dependency and license audit

Dependency audit is currently implemented through Cargo metadata and Cargo tree:

- `cargo metadata --format-version 1 --locked` is parsed to ensure every
  non-workspace dependency has a declared SPDX license or license file.
- `cargo tree --workspace` is recorded as the human-auditable dependency shape.

## Changelog discipline

`CHANGELOG.md` must contain an `Unreleased` section for current work and a
released section for the current crate version. Publishing changes are not
considered complete unless the changelog describes the release-gate or API
surface updates that motivated the versioned release.

Every crate must have a README, license, description, changelog entry,
documented features, release-matrix coverage, and a passing publishing gate
before publication.

Completion requires implementation, tests, and documentation for this feature.
