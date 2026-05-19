# Trusted core and gates

## Trusted definitions

- `LeanRustCore.Extract.extractConst`
- `LeanRustCore.Extract.extractMonoConst`
- `LeanRustCore.Extract.extractWithDiagnostics`
- `LeanRustCore.Extract.typeOfLeanM`
- `LeanRustCore.Surface.SurfaceExpr`
- `LeanRustCore.Surface.typeOf`
- `LeanRustCore.EmitRust.emitSurfaceRustModule`
- `LeanRustCore.IR.RType`
- `LeanRustCore.IR.RExpr`
- `LeanRustCore.IR.eval`
- `LeanRustCore.ChimeraBoundary.lowerResultSignature`

## CI gates

```bash
./scripts/check-no-placeholders.sh
lake build
./scripts/check-extractor-snapshot.sh
./scripts/check-rust-validation.sh
cd rust && cargo fmt --check
cd rust && cargo clippy -- -D warnings
cd rust && cargo test
```

The snapshot gate is important: it proves the checked-in Rust fallback is exactly
what the Lean extractor emits. The validation gate then checks the generated Rust snapshot and the Lean-generated differential test snapshot before Cargo tests run.

## Current supported extraction slice

The extractor supports ordinary `def`s tagged with `@[rust_export]` whose
arguments and return values are built from:

- `Nat`, `Bool`, `Unit`,
- `UInt32`, `UInt64`, `Int32`, `Int64`,
- `Option`,
- `Except`,
- closed parameter-free structures and inductive enums.

The body subset includes variables, literals, `if`, `let`, scalar comparisons,
wrapping arithmetic, `Option`/`Except` constructors, struct literals, field
projection, enum payload constructors, and `match` over `Bool`, `Option`, and
simple no-field enums. Explicit concrete monomorphizations are registered with
`rust_mono_export`.

The next milestones are payload enum pattern matching, recursive functions,
automatically discovered monomorphizations, and richer generic type arguments.

## Differential and validation additions

Additional trusted/generated surfaces for steps 7 and 8:

- `LeanRustCore.Differential.generatedDifferentialRustTests`
- `LeanRustCore.RustValidation.validationReportJson`
- `DifferentialMain.lean`
- `ValidationReportMain.lean`
- `scripts/check-rust-validation.sh`

The validation gate is intentionally split: Lean generates the expected
differential Rust tests and the validation manifest, while shell/Rust tests check
that the generated Rust snapshot stays inside the current safe direct-emission
subset.
