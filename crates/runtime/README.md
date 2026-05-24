# lean-rust-core-runtime

This crate contains safe runtime helpers shared by generated Lean→Rust output.
It is intentionally separate from `lean-rust-core-generated` so numeric modes,
container helpers, typeclass dictionaries, pure-effect helpers, and closure
objects can be tested and documented independently.

A helper is not considered complete until it has unit/property tests in this
crate and documentation in `docs/CRATE_DESIGN.md` or the feature-specific docs.

## Remaining completion helpers

This crate also owns the runtime test surface for generated dictionary structs,
first-class closure objects, pure do-notation helpers, controlled IO transcript
helpers, and deterministic property generator values. A helper is complete only
when it has unit tests and feature documentation.

## Publishing/versioning

Runtime releases are semver-minor for additive helpers and semver-major for
changed helper signatures or runtime behavior contracts. `scripts/check-publishing.sh`
must pass before publication, including docs builds, dependency/license audit,
and `cargo publish --dry-run -p lean-rust-core-runtime`.

Reference docs: <https://docs.rs/lean-rust-core-runtime>
