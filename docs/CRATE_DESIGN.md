# Rust crate design

The final Rust workspace separates generated safe code, runtime helpers, raw ABI
code, validation tooling, and header generation.

| Crate | Path | Unsafe policy | Purpose | Tests required |
|---|---|---:|---|---|
| `lean-rust-core-generated` | `rust` | no unsafe in default lane | generated functions/types and minimal reexports | parser, semantic, differential, property, FFI feature |
| `lean-rust-core-runtime` | `crates/runtime` | forbidden | numeric, container, dictionary, closure, and pure-effect helpers | unit and property seeds |
| `lean-rust-core-abi` | `crates/abi` | allowed only at raw boundary | status codes, result lowering, opaque handles, destructors | handle lifecycle, null out-params, double-drop |
| `lean-rust-core-validate` | `crates/validate` | forbidden | JSON, `syn`, target-validation helpers | valid and malformed artifacts |
| `lean-rust-core-headers` | `crates/headers` | forbidden | C header generation with ownership annotations | signature and ownership-comment checks |

A crate row is complete only when the crate is a Cargo workspace member, has its
own tests, has crate-level documentation, and is included in the release matrix.
The current workspace proof is `cargo metadata --no-deps --format-version 1`,
which lists all five crates as workspace members, and `./scripts/check.sh`,
which drives `cargo test --workspace` across the same set.

## Publishing metadata

Every crate participates in the publishing/versioning policy in
`docs/PUBLISHING.md`. A crate is release-ready only when its README, changelog
entry, semver policy, docs build, dependency audit, and cargo publish dry-run are
recorded in `LeanRustCore.Publishing`, validated by `scripts/check-publishing.py`,
and executed end to end by `scripts/check-publishing.sh`.
