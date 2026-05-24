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
| cargo-metadata | `cargo metadata --no-deps --format-version 1` |
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

It verifies ExtractIR, runtime denotation coverage, exhaustive `SurfaceExpr`
constructor coverage, expanded diagnostics,
source-span metadata, corpus fixtures, generated report metadata, the mandatory
`rust/extract-ir.txt` snapshot, and the docs required for every feature in rows
1 through 20.

That gate now also checks the row-18 semantics split: `docs/SEMANTICS.md` and
`docs/RUNTIME_SEMANTICS.md` must explicitly separate proved semantics from
tested semantics, and `LeanRustCore.CompleteSemantics` must carry
representative compositional evaluator checks for struct, enum, recursive,
dependent, closure, dictionary, and effect values.

## Next-20 gate

The next-20 implementation gate must also pass before release:

```bash
scripts/check-next-20-completion.py
```

It verifies the rows 21 through 40 feature modules and docs, plus complete
diagnostic corpus coverage for `LRC001` through `LRC014`, per-template
`requiresSpan`/`nextFeature` metadata, the four explicit extractor fallback
branches, the parameterized-data corpus for multi-parameter, nested, and
rejected dependent generic shapes, and the Rust completion test that scans the
checked corpus fixtures.

## Remaining rows 41-63 gate

The release matrix now includes `scripts/check-remaining-completion.py`, which
checks generated dictionaries, first-class closures, pure do-notation,
controlled IO boundary metadata, complete target semantics, preservation
obligations, property generators, feature-complete coverage, CI matrix metadata,
and publishing/versioning metadata.

Publishing dry-runs are required before external crate release:

```text
cargo publish --dry-run -p lean-rust-core-generated
cargo publish --dry-run -p lean-rust-core-runtime
cargo publish --dry-run -p lean-rust-core-abi
cargo publish --dry-run -p lean-rust-core-validate
cargo publish --dry-run -p lean-rust-core-headers
```

## Exact final command set

The release evidence for task 1 is the exact command set below. A green release
run means each command exits `0`, `./scripts/check.sh` finishes without diffs or
test failures, and the Rust lane reaches `cargo fmt`, `cargo clippy`, workspace
tests, and the `ffi` feature tests on the pinned toolchains.

```text
lake build
./scripts/check.sh
cargo metadata --no-deps --format-version 1
cargo test --workspace
cargo test -p lean-rust-core-generated --features ffi
cargo fmt --check --all
cargo clippy --workspace --all-targets -- -D warnings
```

## Generated artifact policy

Checked-in generated files are reproducible release artifacts, not source of
truth. `scripts/gen.sh` must regenerate:

- `rust/src/generated.rs`
- `rust/src/ffi_generated.rs`
- `rust/tests/differential_generated.rs`
- `rust/compatibility-report.json`
- `rust/proof-report.json`
- `rust/validation-report.json`
- `rust/target-validation.txt`
- `rust/extract-ir.txt`
- `rust/build-metadata.json`
- `rust/coverage-dashboard.json`

The script formats generated Rust with `rustfmt --edition 2021`, and
`scripts/check-extractor-snapshot.sh` formats its temporary Rust outputs before
diffing them. A clean snapshot gate therefore proves both regeneration and
format normalization for the checked-in artifacts.

## Supported combinations

The release target matrix is:

- Linux default lane
- Linux `ffi` lane
- macOS default lane
- macOS `ffi` lane

GitHub Actions runs these combinations through the scripted lane helper:

```text
./scripts/check-ci-e2e.sh default
./scripts/check-ci-e2e.sh ffi
```

`.github/workflows/ci.yml` executes that helper across the Linux/macOS by
default/`ffi` matrix, so the checked workflow and the local scripted path use
the same commands.
