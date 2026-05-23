# lean-rust-core-generated

This crate is the generated safe Rust lane. It contains generated functions and
types, parser/semantic/differential/property tests, and optional `ffi` feature
integration.

Default builds forbid unsafe code. Raw ABI wrappers are feature-gated and the
long-term ABI implementation lives in `lean-rust-core-abi`.

## Publishing/versioning

The generated crate follows the semver policy in `docs/PUBLISHING.md`: new
generated functions/types are semver-minor, but changed signatures or layouts are
semver-major.
