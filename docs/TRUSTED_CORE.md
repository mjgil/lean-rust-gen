# Trusted core and gates

## Trusted definitions

- `LeanRustCore.Extract.extractConst`
- `LeanRustCore.Extract.extractMonoConst`
- `LeanRustCore.Extract.registerAutoMonoSpec`
- `LeanRustCore.Extract.extractWithDiagnostics`
- `LeanRustCore.Extract.extractPendingAutoHelpers`
- `LeanRustCore.TypeclassPolicy.isSupportedErasedDictionaryType`
- `LeanRustCore.Examples.extractedSurfaceFunctions`
- `LeanRustCore.Extract.typeOfLeanM`
- `LeanRustCore.Surface.SurfaceExpr`
- `LeanRustCore.Surface.typeOf`
- `LeanRustCore.Surface.evalSurfaceExpr`
- `LeanRustCore.Surface.evalSurfaceFun`
- `LeanRustCore.RustHygiene.validateSurfaceModuleHygiene`
- `LeanRustCore.EmitRust.emitSurfaceRustModule`
- `LeanRustCore.TargetValidation.targetValidationSnapshot`
- `LeanRustCore.ValidationV2.coverageDashboardJson`
- `LeanRustCore.RecursiveData.recursiveDataSummary`
- `LeanRustCore.BoundaryExport.generatedBoundaryRust`
- `LeanRustCore.IR.RType`
- `LeanRustCore.IR.RExpr`
- `LeanRustCore.IR.eval`
- `LeanRustCore.ChimeraBoundary.lowerResultSignature`
- `rust/tests/parser_validation.rs`
- `rust/tests/semantic_validation.rs`
- `rust/tests/target_interpreter.rs`
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

- `Nat` as wrapping `u32` only when the exported declaration has `@[rust_nat_wrapping_u32]`,
- exact `Nat`/`Int` when the exported declaration has `@[rust_nat_exact]`/`@[rust_int_exact]`,
- `Bool`, `Unit`, `UInt32`, `UInt64`, `Int32`, `Int64`, `Char`, `String`,
- `Option`,
- `Except`,
- `List` and `Array` as owned Rust `Vec<T>` values,
- erased `Subtype`, checked-carrier `Fin n`, and checked-carrier `Vector α n` runtime shapes,
- unary function-pointer arguments,
- index-free structures and inductive enums, including concrete monomorphized parameterized data.

The body subset includes variables, literals, `if`, `let`, scalar comparisons,
wrapping arithmetic, `Option`/`Except` constructors, proof-field-erased struct
literals, field projection, enum payload constructors, payload enum pattern
matching, exact integer arithmetic in opt-in exact modes, captured-lambda loop
bodies for recognized structural combinators, and
first-order calls to other tagged exported Lean declarations or automatically extracted first-order helper definitions, and the initial structural-recursion slice for `List.map`/`List.foldl`. Explicit concrete
monomorphizations are registered with `rust_mono_export`, generic calls inside concrete exported declarations are automatically monomorphized, and supported resolved typeclass dictionaries are erased when monomorphic lowering selects the target operation.

`LeanRustCore.Surface.evalSurfaceFun` now gives this extracted surface subset a
dynamic Lean semantics used by the differential suite. It covers the same
expression families as the emitter and bounds call evaluation with explicit fuel, which now also protects recursive or helper-expanded call graphs during tests.

The next milestones are broader structural recursion lowering beyond the current `List.map`/`List.foldl` slice, general first-class closure conversion, generated typeclass dictionaries for non-erasable class-heavy code, and semantic Rust→Lean translation validation beyond the current generated-subset parser/fingerprint/interpreter gates. See `docs/LARGE_SUBSET_PLAN.md` for the staged large-subset plan.

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

## Report schema validation

`lean-rust-core-validate` owns the typed schema for the checked-in JSON reports:

- `rust/validation-report.json`
- `rust/compatibility-report.json`
- `rust/proof-report.json`
- `rust/build-metadata.json`
- `rust/coverage-dashboard.json`

These structs use `#[serde(deny_unknown_fields)]` so report validation fails on
unexpected fields instead of relying only on string presence or ad hoc JSON
lookups. `rust/tests/validation_report.rs` parses each report through the typed
schema, then cross-checks counts, status enums, and feature flags against
`generated.rs`, `target-validation.txt`, and the workspace metadata.


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

The current large-subset slice treats `LeanRustCore.RecursionPolicy` as an analyzer instead of the default rejection path. Generated Rust may contain first-order recursive calls, while validation and differential evaluation remain fuel-bounded. Parameterized data is accepted only after concrete monomorphization to Rust-facing type names. Proof-shaped binders and proof-only runtime fields are erased conservatively, exact integer modes are explicit opt-ins, supported dependent carriers stay limited to `Subtype`/`Fin`/`Vector`, and higher-order support covers unary Rust `fn` pointer arguments plus captured lambdas inside recognized structural combinators.

## Phase 3 target-validation trusted surface

Additional generated/trusted artifacts:

- `LeanRustCore.TargetValidation.targetValidationSnapshot`
- `LeanRustCore.ValidationV2.coverageDashboardJson`
- `LeanRustCore.RecursiveData.recursiveDataSummary`
- `TargetValidationMain.lean`
- `rust/target-validation.txt`
- `rust/tests/semantic_validation.rs`
- `rust/tests/target_interpreter.rs`

The semantic validation test parses generated Rust with `syn`, reconstructs the
approved generated-subset target fingerprint, and compares it to the Lean-side
snapshot. `rust/tests/target_interpreter.rs` then iterates every emitted
target-validation function, generates sample inputs from the snapshot types,
executes the reconstructed fingerprint interpreter, and compares that result
with the compiled Rust call. This turns target validation from parse-only
checking into explicit Rust AST → target-fingerprint reconstruction plus
executable target-semantics coverage for the whole emitted function set.

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

## Sprint 13-14 trusted-core addition

The new trusted surface is the policy layer that classifies accepted closure conversion and defunctionalization shapes. Runtime code remains ordinary safe Rust: environment structs, enum cases, matches, and first-order apply functions.

## Sprint 3-6 trusted surface

Additional trusted/generated surfaces:

- `LeanRustCore.Pattern.patternCompilerSummary`
- `LeanRustCore.RecursionLowering.recursionLoweringSummary`
- `SurfacePattern` and `SurfaceExpr.matchPattern` checking in `LeanRustCore.Surface`
- `SurfaceExpr.listLength` and `SurfaceExpr.tailRecNat` checking/evaluation
- target-validation fingerprints for general patterns and tail-recursion loops

These are still subset checks rather than a full Lean pattern/compiler-correctness
proof. They strengthen the direct safe-Rust lane by making pattern and recursion
lowering explicit, typed, and covered by generated reports/tests.

## Phase 5/6 recursive data and validation-v2 trusted surface

Additional generated/trusted artifacts:

- `LeanRustCore.RecursiveData.recursiveDataSummary`
- `LeanRustCore.ValidationV2.coverageDashboardJson`
- `CoverageDashboardMain.lean`
- `rust/coverage-dashboard.json`
- `rust/tests/property_validation.rs`

Recursive user data currently uses a conservative owned `Box<T>` layout for known index-free recursive fixtures. The validation-v2 dashboard records this feature family and the target-validation format used by downstream checks.

## Final rows 41-56 trusted metadata

The final completion layer adds the following metadata surfaces:

- `LeanRustCore.PropertyCorpus.seedFamilies` records deterministic property/fuzz families.
- `LeanRustCore.CoverageDashboard.metrics` records quantitative dashboard denominators.
- `LeanRustCore.Diagnostics.templates` records stable LRC diagnostic codes.
- `LeanRustCore.CrateDesign.workspaceCrates` records the concrete Rust workspace split.
- `LeanRustCore.ReleaseMatrix.gates` records release acceptance commands.

A feature in this layer cannot be marked complete unless tests and documentation
are present. The non-toolchain gate is `scripts/check-final-16-completion.py`;
the full release gate is `docs/RELEASE_CHECKLIST.md`.

## First-20 completion checkpoint

The first twenty design rows are complete only when implementation, tests, and
documentation are all present. The checkpoint is enforced by
`scripts/check-first-20-completion.py` and covers:

- `LeanRustCore.ExtractIR` as an explicit pre-`SurfaceExpr` metadata stage;
- `RuntimeValue` and `runtimeValueHasType` as the non-placeholder denotation for
  generated structs, enums, and recursive names;
- `SourceSpan` and concrete diagnostic instances for source-aware failures;
- expanded diagnostic codes `LRC001` through `LRC014`;
- positive, negative, and unsupported corpus fixtures; and
- proof/validation-report metadata proving these items are wired into generated
  artifacts.

The unknown-span fallback is intentional: it records that Lean metadata did not
provide a range without dropping the source declaration or diagnostic code.

## Rows 21-40 completion trust surface

The second checklist block adds policy modules whose outputs are consumed by the
proof report, validation report, coverage dashboard, runtime tests, and
`scripts/check-next-20-completion.py`. A row in this block is marked complete
only when the implementation metadata, Rust/runtime tests, and feature-specific
documentation are all present.

New trusted metadata surfaces:

- `LeanRustCore.GenericEmission.monomorphizeDataShape` and `LeanRustCore.ParameterizedData.substituteTypeVars`
- `LeanRustCore.NumericSemantics.rules`
- `LeanRustCore.DependentErasureChecker.checkDependentErasure`
- `LeanRustCore.RecursiveDiscovery.layoutDecisions`
- `LeanRustCore.OwnershipPolicy.rules`
- `LeanRustCore.PatternMatrix.completedPatternFeatures`
- `LeanRustCore.RecursionAnalysis.decisions`
- `LeanRustCore.StdImplementation.lowerings`
- `LeanRustCore.TypeclassSpecialization.classes`

The semantic claim is still bounded: these modules complete the design-doc
requirements for the 21-40 checklist rows, but full compiler correctness still
requires the broader generated-subset semantic validator and preservation proof
tracks.

## Remaining completion trust surface

Rows 41-63 add metadata and test gates for generated dictionaries, first-class
closure objects, pure do-notation, controlled IO, complete generated-subset
semantics, preservation obligations, property generators, feature-complete
coverage, CI release matrix, and crate publishing/versioning. These gates are
aggregated by `LeanRustCore.RemainingCompletion` and checked by
`scripts/check-remaining-completion.py`.

The preservation portion is now split deliberately into two classes of evidence:

- proved Lean theorems in `LeanRustCore.Preservation`:
  `extraction_metadata_preserved`,
  `dependent_erasure_runtime_carriers_preserved`,
  `checked_surface_typing_preserved`,
  `checked_surface_evaluation_preserved`,
  `target_lowering_snapshot_preserved`,
  `safe_subset_emission_preserved`, and
  `emitted_subset_target_semantics_preserved`.
- regression-tested facts outside the Lean proof boundary:
  parser validation over generated Rust,
  target-interpreter execution against compiled Rust,
  coverage-dashboard evidence derivation, and
  property/fuzz-style randomized validation.

This means the trusted-core docs now separate what is proved in Lean from what
is only tested. The release gates require both classes to stay present.
