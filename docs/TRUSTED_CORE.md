# Trusted core and gates

## Trusted definitions

- `LeanRustCore.Extract.extractConst`
- `LeanRustCore.Extract.extractMonoConst`
- `LeanRustCore.Extract.registerAutoMonoSpec`
- `LeanRustCore.Extract.extractWithDiagnostics`
- `LeanRustCore.Extract.typeOfLeanM`
- `LeanRustCore.Surface.SurfaceExpr`
- `LeanRustCore.Surface.typeOf`
- `LeanRustCore.Surface.evalSurfaceExpr`
- `LeanRustCore.Surface.evalSurfaceFun`
- `LeanRustCore.RustHygiene.validateSurfaceModuleHygiene`
- `LeanRustCore.EmitRust.emitSurfaceRustModule`
- `LeanRustCore.IR.RType`
- `LeanRustCore.IR.RExpr`
- `LeanRustCore.IR.eval`
- `LeanRustCore.ChimeraBoundary.lowerResultSignature`
- `rust/tests/parser_validation.rs`
- `LeanRustCore.Toolchain.buildMetadataJson`
- `rust/build.rs` fallback policy

## CI gates

```bash
./scripts/check-no-placeholders.sh
./scripts/check-toolchain-pins.sh
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
projection, enum payload constructors, payload enum pattern matching, and
first-order calls to other tagged exported Lean declarations. Explicit concrete
monomorphizations are registered with `rust_mono_export`, and generic calls inside concrete exported declarations are automatically monomorphized.

`LeanRustCore.Surface.evalSurfaceFun` now gives this extracted surface subset a
dynamic Lean semantics used by the differential suite. It covers the same
expression families as the emitter and bounds call evaluation with explicit fuel
for the current non-recursive subset.

The next milestones are recursive functions, richer generic type arguments, and semantic Rust→Lean translation validation beyond the current generated-subset `syn` parser gate.

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
subset. `rust/tests/parser_validation.rs` parses the generated Rust with `syn`
and validates the approved AST shape. The expanded differential suite now computes extracted-declaration
expectations through `evalSurfaceFun` for structs, enums, `Result`, calls, and
monomorphized functions.


## Identifier hygiene and parser-backed validation

`LeanRustCore.RustHygiene` rejects generated modules whose Rust-facing names
collide after keyword escaping, invalid-character replacement, or type/variant
case conversion. The emitter calls this check before producing Rust source.

The Rust parser gate is intentionally target-side: it parses `generated.rs` with
`syn` during `cargo test` and checks the emitted AST rather than relying only on
textual grep.


## Toolchain and fallback gates

`scripts/check-toolchain-pins.sh` rejects moving Lean/Rust channels and checks
that `rust/build-metadata.json` records the exact pinned toolchains. `rust/build.rs`
forbids checked-in generated snapshot fallback in CI and release builds; fallback
requires `LEAN_RUST_CORE_ALLOW_FALLBACK=1` in a local non-release build.

## Automatic monomorphization

Generic calls found inside concrete exported declarations enqueue concrete
`MonoExportSpec`s. The extraction loop processes those specs to a fixpoint, emits
the generated instances, and records them as `auto-monomorphized-export` entries
in the compatibility report.
