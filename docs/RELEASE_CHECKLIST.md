# Release checklist

A release is accepted only when every feature has implementation, tests,
documentation, reproducible generated artifacts, and safe-lane/FFI separation.

## Required gates

| Gate | Command |
|---|---|
| lean-build | `lake build` |
| generated-snapshot | `scripts/check-extractor-snapshot.sh` |
| artifact-consistency | `scripts/check-artifact-consistency.py` |
| final-checklist | `scripts/check-final-16-completion.py` |
| cargo-workspace-test | `cargo test --workspace` |
| ffi-feature-test | `cargo test -p lean-rust-core-generated --features ffi` |
| cargo-fmt | `cargo fmt --check --all` |
| cargo-clippy | `cargo clippy --workspace --all-targets -- -D warnings` |
| negative-corpus | `scripts/check-corpus-harness.sh` |
| unsafe-default-lane | `scripts/check-rust-validation.sh` |
| toolchain-pins | `scripts/check-toolchain-pins.sh` |
| headers | `cargo test -p lean-rust-core-headers` |

## Documentation requirement

Every feature must point to a documentation page before it is marked complete.
Every diagnostic must have a code and an example. Every ABI function must have
an ownership or safety contract. Every crate must have a README.

## First-20 gate

The first-20 implementation gate must pass before release:

```bash
scripts/check-first-20-completion.py
```

It verifies ExtractIR, runtime denotation coverage, expanded diagnostics,
source-span metadata, corpus fixtures, generated report metadata, and the docs
required for every feature in rows 1 through 20.
