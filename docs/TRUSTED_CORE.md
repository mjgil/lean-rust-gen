# Trusted core and gates

## Trusted definitions

- `LeanRustCore.Extract.extractConst`
- `LeanRustCore.Extract.extractMonoConst`
- `LeanRustCore.Extract.registerAutoMonoSpec`
- `LeanRustCore.Extract.extractWithDiagnostics`
- `LeanRustCore.Extract.extractPendingAutoHelpers`
- `LeanRustCore.Examples.extractedSurfaceFunctions`
- `LeanRustCore.Extract.typeOfLeanM`
- `LeanRustCore.Surface.SurfaceExpr`
- `LeanRustCore.Surface.typeOf`
- `LeanRustCore.Surface.evalSurfaceExpr`
- `LeanRustCore.Surface.evalSurfaceFun`
- `LeanRustCore.RustHygiene.validateSurfaceModuleHygiene`
- `LeanRustCore.EmitRust.emitSurfaceRustModule`
- `LeanRustCore.TargetValidation.targetValidationSnapshot`
- `LeanRustCore.BoundaryExport.generatedBoundaryRust`
- `LeanRustCore.IR.RType`
- `LeanRustCore.IR.RExpr`
- `LeanRustCore.IR.eval`
- `LeanRustCore.ChimeraBoundary.lowerResultSignature`
- `rust/tests/parser_validation.rs`
- `rust/tests/semantic_validation.rs`
- `rust/tests/ffi_boundary.rs`
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
cd rust && cargo test --features ffi
```

The snapshot gate is important: it proves the checked-in Rust fallback is exactly
what the Lean extractor emits. The validation gate then checks the generated Rust snapshot and the Lean-generated differential test snapshot before Cargo tests run.

## Current supported extraction slice

The extractor supports ordinary `def`s tagged with `@[rust_export]` whose
arguments and return values are built from:

- `Nat` only when the exported declaration has `@[rust_nat_wrapping_u32]`,
- `Bool`, `Unit`, `UInt32`, `UInt64`, `Int32`, `Int64`, `Char`, `String`,
- `Option`,
- `Except`,
- `List` and `Array` as owned Rust `Vec<T>` values,
- erased `Subtype`, `Fin n`, and `Vector α n` runtime shapes,
- unary function-pointer arguments,
- index-free structures and inductive enums, including concrete monomorphized parameterized data.

The body subset includes variables, literals, `if`, `let`, scalar comparisons,
wrapping arithmetic, `Option`/`Except` constructors, struct literals, field
projection, enum payload constructors, payload enum pattern matching, and
first-order calls to other tagged exported Lean declarations or automatically extracted first-order helper definitions, and the initial structural-recursion slice for `List.map`/`List.foldl`. Explicit concrete
monomorphizations are registered with `rust_mono_export`, and generic calls inside concrete exported declarations are automatically monomorphized.

`LeanRustCore.Surface.evalSurfaceFun` now gives this extracted surface subset a
dynamic Lean semantics used by the differential suite. It covers the same
expression families as the emitter and bounds call evaluation with explicit fuel, which now also protects recursive or helper-expanded call graphs during tests.

The next milestones are broader structural recursion lowering beyond the current `List.map`/`List.foldl` slice, captured-closure conversion, generated typeclass dictionaries, exact `Nat`/`Int` backends, and semantic Rust→Lean translation validation beyond the current generated-subset `syn` parser gate. See `docs/LARGE_SUBSET_PLAN.md` for the staged large-subset plan.

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
subset. The SurfaceExpr differential expectations now consume
`LeanRustCore.Examples.extractedSurfaceFunctions`, emitted by the same extractor
command as the generated Rust snapshot. `rust/tests/parser_validation.rs` parses the generated Rust with `syn`
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
## Phase 0-2 large-subset gates

The current large-subset slice treats `LeanRustCore.RecursionPolicy` as an analyzer instead of the default rejection path. Generated Rust may contain first-order recursive calls, while validation and differential evaluation remain fuel-bounded. Parameterized data is accepted only after concrete monomorphization to Rust-facing type names. Proof-shaped binders are erased conservatively, and higher-order support is limited to unary Rust `fn` pointer arguments until closure conversion is added.

## Phase 3 target-validation trusted surface

Additional generated/trusted artifacts:

- `LeanRustCore.TargetValidation.targetValidationSnapshot`
- `TargetValidationMain.lean`
- `rust/target-validation.txt`
- `rust/tests/semantic_validation.rs`

The semantic validation test parses generated Rust with `syn`, reconstructs the
approved generated-subset target fingerprint, and compares it to the Lean-side
snapshot. This turns target validation from parse-only checking into an explicit
Rust AST → target-fingerprint reconstruction gate.

## Phase 4 boundary-export trusted surface

Additional generated/trusted artifacts:

- `LeanRustCore.BoundaryExport.generatedBoundaryRust`
- `BoundaryMain.lean`
- `rust/src/ffi_generated.rs`
- `rust/tests/ffi_boundary.rs`
- `rust/src/abi.rs` result-lowering helpers under the `ffi` feature

The direct lane still checks `rust/src/generated.rs` for absence of `unsafe` and
raw `extern "C"` items. Raw ABI wrappers live in `rust/src/ffi_generated.rs` and
are included only when the Rust `ffi` feature is enabled.
