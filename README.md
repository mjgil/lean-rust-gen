# LeanRustCore

LeanRustCore is a direct Lean-to-Rust extraction pipeline.

It reads elaborated Lean declarations, lowers them into a checked Rust-shaped
intermediate representation, emits safe Rust for the supported subset, and
keeps the generated lane under reproducible validation and release gates.

## Status

The current repository includes:

- a Lean extractor and checked surface IR under `LeanRustCore/`
- a generated Rust crate in `rust/`
- dedicated runtime, ABI, validation, and header crates under `crates/`
- checked generated artifacts and release-gate scripts under `rust/` and
  `scripts/`

The supported subset, design notes, and staged roadmap live in `docs/`.
Start with:

- `docs/ARCHITECTURE.md`
- `docs/RELEASE_CHECKLIST.md`
- `docs/PUBLISHING.md`
- `docs/LARGE_SUBSET_PLAN.md`

## Repository layout

```text
LeanRustCore/   Lean extractor, IRs, emitter, validators, and feature metadata
rust/           Generated Rust crate, generated artifacts, and integration tests
crates/         Runtime, ABI, validation, and header crates
docs/           Architecture, feature design, testing, and release documents
scripts/        Regeneration, validation, and release-check helpers
```

## Quick start

Toolchains are pinned in `lean-toolchain` and `rust-toolchain.toml`.

Regenerate the checked Rust artifacts:

```bash
./scripts/gen.sh
```

Run the default release gate locally:

```bash
./scripts/check.sh
```

Run the same CI entrypoints used by GitHub Actions:

```bash
./scripts/check-ci-e2e.sh default
./scripts/check-ci-e2e.sh ffi
```

## Validation and release policy

The release lane checks:

- exact Lean and Rust toolchain pins
- reproducible generated artifacts
- parser, semantic, differential, property, and FFI-lane tests
- formatting and clippy on the Rust workspace
- crate metadata, dependency-license audit, and `cargo publish --dry-run`
- open-source surface hygiene for tracked files and public docs

The generated crate keeps the default lane safe:

```rust
#![cfg_attr(not(feature = "ffi"), forbid(unsafe_code))]
```

The raw ABI wrappers live behind the `ffi` feature and are validated as a
separate release lane.

## Workspace crates

- `lean-rust-core-generated`: generated safe Rust API surface
- `lean-rust-core-runtime`: shared safe runtime helpers
- `lean-rust-core-abi`: feature-gated raw ABI layer
- `lean-rust-core-validate`: artifact and target-validation helpers
- `lean-rust-core-headers`: generated C header helpers

## License

This repository is dual-licensed under either:

- Apache License, Version 2.0
- MIT license

See `LICENSE-APACHE` and `LICENSE-MIT`.
