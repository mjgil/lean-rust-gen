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

The publish gate for this crate is `scripts/check-publishing.sh`. It validates
crate metadata, runs `cargo doc --workspace --no-deps`, audits dependency
licenses through Cargo metadata, and executes `cargo publish --dry-run -p
lean-rust-core-generated` from a clean copied release tree before Task 73 can
stay complete.

Published/package verification uses the checked-in `src/generated.rs` snapshot
when the Lean workspace root is not present in the crate tarball. Repo-local
CI and release builds still regenerate via `lake`.

Reference docs: <https://docs.rs/lean-rust-core-generated>
