# Architecture

This repo is intentionally direct:

```text
ordinary Lean declarations
        │
        ▼
LeanRustCore.Extract.extractConst
        │  reads elaborated constant bodies from the Lean environment
        ▼
LeanRustCore.Surface.SurfaceFun
        │  first-order checked Rust-shaped IR
        ▼
LeanRustCore.EmitRust.emitSurfaceRustModule
        │
        ▼
LeanRustCore.RustHygiene.validateSurfaceModuleHygiene
        │  sanitizes Rust identifiers and rejects collisions
        ▼
rust/src/generated.rs
        │
        ▼
Cargo build/test/clippy with `unsafe_code` forbidden
```

There is no core/app split in this scaffold. The app is **Lean emits Rust**.

## Completed step 1: broader type extraction

`LeanRustCore.Extract.typeOfLeanM` now recognizes:

- `Nat` as an explicit opt-in `u32` wrapping boundary via
  `@[rust_nat_wrapping_u32]`,
- `UInt32` / `UInt64`,
- `Int32` / `Int64`,
- `Unit` and `Bool`,
- `Option T`,
- `Except E T`, emitted as Rust `Result<T, E>`,
- closed structures and inductive enums, including enum payload constructors.

The surface checker in `LeanRustCore.Surface` verifies every extracted function
body against the declared Rust-facing return type before emission.

## Completed step 2: match lowering

`LeanRustCore.Extract` now recognizes elaborated recursor/casesOn shapes for:

- `Bool`, emitted as Rust `match flag { true => ..., false => ... }`,
- `Option`, emitted as Rust `match option { None => ..., Some(value) => ... }`,
- closed inductive enums, including payload variants, emitted as Rust enum
  declarations plus Rust `match` expressions with variant-field binders.

Payload enum constructors and payload enum pattern matching are both supported in
this slice.

## Completed step 3: declarations, struct construction, field projection

`LeanRustCore.Surface` now includes `SurfaceStruct`, `SurfaceEnum`, struct
literals, field projections, and enum variant constructors. The emitter produces
Rust `struct`/`enum` items before the generated functions and collects nested
declarations from argument, return, and body types.

## Completed step 4: expected-type propagation

`Surface.typeOfExpected` checks expressions with an optional expected type. The
extractor passes that type into nested `Option.none`, `Option.some`, `Except.ok`,
and `Except.error`, so examples such as `some none`, `Except.ok none`, and
`Except.error (some e)` lower without ambiguous constructor defaults.

## Boundary model

`ChimeraBoundary` is retained only as a small vendored ABI/result-lowering model
for future raw FFI exports. It is not the main compiler architecture.


## Completed step 5: explicit concrete monomorphization

`rust_mono_export` records explicit concrete type instantiations of generic Lean
definitions. The extractor reuses the elaborated generic body, maps the leading
`Type` binders to concrete `RType`s, and emits one ordinary Rust function per
requested instance.

The extractor also now discovers generic calls that occur inside concrete
`@[rust_export]` declarations. Those calls enqueue automatic monomorphization
requests, including struct and enum concrete type arguments, and the emitter
orders the generated instances before their callers.

Examples:

```lean
rust_mono_export generic_choose as choose_generic_u32 [UInt32]

@[rust_export]
def auto_choose_point (flag : Bool) (left right : Point) : Point :=
  generic_choose Point flag left right
```

## Completed step 6: structured compatibility reporting

`rust_emit_exports_with_report` emits Rust for every supported export and also
defines a JSON compatibility report. `rust_emit_exports_with_report_and_surface`
adds a checked `List SurfaceFun` artifact for differential validation. Unsupported tagged declarations are not
silently accepted and no longer abort the whole generation pass; they appear as
`unsupported-declaration` diagnostics in `rust/compatibility-report.json`.

```lean
rust_emit_exports_with_report_and_surface generatedRust generatedCompatibilityReport extractedSurfaceFunctions
```

## Completed step 7: Lean-evaluator differential tests

`LeanRustCore.Differential` generates `rust/tests/differential_generated.rs`.
The right-hand side of each proof-carrying assertion is computed in Lean from
`LeanRustCore.IR.eval`, and the expanded extracted-declaration assertions are
computed from `LeanRustCore.Surface.evalSurfaceFun`. The left-hand side calls
the generated Rust function, giving the workflow a cross-language regression
gate over both semantic models and the emitted Rust snapshot.

```bash
lake exe gen_differential_tests rust/tests/differential_generated.rs
```

The suite currently covers the proof-carrying scalar/option examples plus
SurfaceExpr-backed extracted-declaration examples for `u64`, `Bool` matches,
`Option`, `Result`, structs, field projections, no-payload and payload enums,
first-order calls, nested constructors, explicit monomorphizations, and automatically discovered monomorphizations.

## Completed step 8: emitted-subset validation gate

`LeanRustCore.RustValidation` generates `rust/validation-report.json`, and
`scripts/check-rust-validation.sh` enforces the current direct Lean→Rust emitted
subset:

- generated Rust must not contain `unsafe`, raw `extern "C"` boundaries,
  `panic!`, `todo!`, `unimplemented!`, or malformed emitter markers,
- validation and compatibility reports must remain snapshot-reproducible,
- Lean-generated differential tests must be checked into the Rust test suite,
- the Rust crate continues to use `#![forbid(unsafe_code)]`.

This is a validation gate for the current generated subset. The gate now includes
`syn` parsing of `generated.rs`; a future Rust→Lean validator can replace the
current parser-backed subset checker once the generated Rust grammar is large
enough to justify semantic target-language reconstruction.

## Newly completed: payload enum pattern matching and first-order calls

`SurfaceExpr.matchEnum` now stores payload binders per branch. The extractor
lowers elaborated enum `casesOn`/`rec` branches with constructor payload lambdas,
and the emitter renders Rust patterns such as `Step::Jump(amount) => ...`.

`SurfaceExpr.call` now represents calls to other tagged first-order Lean
functions. The extractor checks the callee signature, translates each argument
with the expected parameter type, and the emitter keeps generated functions in a
stable dependency-aware order.

## Newly completed: SurfaceExpr evaluator and expanded differential coverage

`LeanRustCore.Surface` now defines `SurfaceValue`, `SurfaceEnv`,
`evalSurfaceExpr`, and `evalSurfaceFun`. The evaluator covers every currently
extracted expression family: scalar values, `let`, `if`, Bool/Option/enum
matches, wrapping arithmetic, structs, fields, enum payload constructors,
`Option`, `Result`, and first-order calls.

`LeanRustCore.Differential` now uses that evaluator for the extractor-owned
`extractedSurfaceFunctions` artifact instead of hand-mirrored `SurfaceFun`
fixtures or hard-coded expected values. The differential test suite covers
structs, enums, `Result`, monomorphized exports, payload matches, and call chains
against the generated Rust crate.

`LeanRustCore.SurfaceCoverage` now closes the remaining gap for the checked
surface layer: it enumerates every `SurfaceExpr` constructor, runs
`typeOfExpected` and `evalSurfaceExpr` coverage for each node, and is enforced
by the first-20 completion gate plus `rust/tests/first20_completion.rs`.

## Newly completed: full diagnostic corpus coverage

`LeanRustCore.Diagnostics.templates` remains the single source of truth for
stable `LRC001` through `LRC014` user-facing diagnostics, but the completion
gates now do more than check string presence. The negative and unsupported
corpus directories contain at least one fixture for every diagnostic template,
the fixture metadata must match each template's `nextFeature`,
`documentation`, and `requiresSpan` contract, and
`rust/tests/next20_completion.rs` plus `scripts/check-next-20-completion.py`
verify that the corpus also covers the four explicit extractor fallback
branches:

- `extract-regular-unsupported-export`
- `extract-mono-unsupported-export`
- `auto-helper-fixpoint-fuel`
- `auto-generated-specs-fixpoint-fuel`

This closes the remaining "unsupported path drift" gap: if a future edit drops a
diagnostic code, changes a span requirement, or removes an extractor rejection
branch from the checked corpus/docs, the next-20 gate fails before release.

## Newly completed: representative compositional target semantics

`LeanRustCore.IR.Denote` still provides the proved semantic carrier for the
typed IR, but Task 18 is now closed by adding a second layer:
`LeanRustCore.CompleteSemantics` defines a small compositional evaluator for
representative emitted target terms and values, and the validator crate mirrors
that evaluator with `TargetTerm`, `TargetValue`, and `eval_target_term`.

The representative semantics are intentionally concrete. They evaluate:

- struct literals
- enum values plus the admitted `Step::Jump`/`Step::Stay` match shape
- recursive tree construction and summation
- dependent `Fin` and `Vector` carriers
- closure capture/application
- dictionary-mediated `u32` addition
- pure `Option`/`Result` effect fragments
- box/deref, let/if, and builtin calls

The first-20 and remaining-completion gates now require the semantics docs to
separate proved semantics from tested semantics and require the Lean/Rust
representative evaluators to stay in sync.

## Newly completed: generalized parameterized-data discovery

The extractor's index-free inductive path now has artifact-backed coverage for
more than the original `Boxed`/`Tagged` slice. `LeanRustCore.ParameterizedExamples`
adds ordinary exported Lean declarations that prove:

- multi-parameter structure monomorphization via `PairBox UInt32 String`
- multi-parameter enum monomorphization via `PairChoice UInt32 String`
- nested parameterized payload lowering via `NestedPayload UInt32 String`

Those examples flow through the ordinary extraction pipeline, appear in
`generated.rs`, `differential_generated.rs`, and `target-validation.txt`, and
are backed by positive corpus fixtures. Dependent generic/indexed shapes such as
`Vector α n` remain explicitly rejected and are covered by the unsupported
corpus plus `docs/GENERICS.md`.

## Newly completed: Rust identifier hygiene and parser-backed validation

`LeanRustCore.RustHygiene` is now the single place that maps source names to
Rust identifiers. It sanitizes invalid characters, escapes or prefixes Rust
keywords, emits UpperCamelCase type/variant identifiers, and rejects generated
modules when two distinct source names collapse to the same Rust name.

`rust/tests/parser_validation.rs` now parses `rust/src/generated.rs` with `syn`
and validates the approved generated Rust AST shape: only structs, enums, and
safe monomorphic functions at top level; no raw FFI blocks; no unsafe blocks; and
no panic/todo/unimplemented macros.

## Newly completed: exact toolchain pins and release fallback ban

`lean-toolchain` is pinned to `leanprover/lean4:v4.22.0`, and
`rust-toolchain.toml` is pinned to Rust `1.85.0`. `scripts/check-toolchain-pins.sh`
checks those exact pins and the generated `rust/build-metadata.json` snapshot.

`rust/build.rs` no longer silently falls back to `src/generated.rs` for CI or
release builds. Local fallback is allowed only when `LEAN_RUST_CORE_ALLOW_FALLBACK=1`
and the Cargo profile is not `release`.

## Newly completed: automatic monomorphization

Generic calls inside concrete exported declarations are now discovered during
extraction. The extractor creates deterministic generated Rust names such as
`generic_identity__u32`, `generic_choose__point`, and
`generic_option_default__step`, emits those concrete instances, and lowers the
original exported function to a normal first-order Rust call.

## Large-subset roadmap

`docs/LARGE_SUBSET_PLAN.md` records the practical largest direct safe-Rust target:
a proof-erased, monomorphized executable Lean subset with recursion,
parameterized data, standard containers, controlled higher-order support, and
Rust→IR semantic validation added in stages.

## Phase 0-2 large-subset slice

The large-subset patch keeps the existing checked surface pipeline but widens the
runtime envelope in four concrete ways:

- `rust_emit_exports_with_report_and_surface` emits generated Rust, the
  compatibility report, and the extractor-owned `List SurfaceFun` used by the
  differential suite. This removes hand-mirrored surface fixtures from the
  validation path.
- The runtime type universe now includes `Char`, `String`, `List`, `Array`,
  `Prod`, `Sum`, unary function types, and concrete monomorphized
  parameterized structures/enums. `List` and `Array` use owned Rust `Vec<T>` in
  this phase.
- Extraction can pull in first-order helper definitions reachable from exported
  roots, erase conservative proof-shaped binders and supported resolved
  typeclass dictionaries from Rust signatures, lower unary function-valued
  arguments to safe Rust `fn(A) -> B` pointers, lower captured lambdas in
  recognized structural combinators by closing over Rust locals, lower exact
  `Nat`/`Int` through explicit `num_bigint` modes, and lower the initial
  `List.map`/`List.foldl` structural-recursion slice to explicit safe Rust loops.
- Sprint 10-12 extends the same safe lane with dependent-shape erasure:
  `Subtype` erases to its carrier, literal-bound `Fin` lowers to checked `u32`
  carriers, literal-length `Vector` lowers to checked `Vec<T>` carriers, and
  proof-only struct fields are omitted from emitted runtime layouts.
- Row 30 closes the remaining indexed-family slice without widening the default
  lane into general dependent computation: equality casts are admitted only when
  erased runtime carriers match, invariant `Sigma` codomains lower to runtime
  products, the fixture indexed family `FlagCarrier` erases to `u32`, and
  dependent matches are admitted only when every erased branch keeps the same
  runtime shape. Branch-shape-changing dependent matches remain rejected.

`LeanRustCore.RecursionPolicy` is retained as an analyzer/strict-compatibility
gate, but the default large-subset emission path no longer rejects generated
first-order call cycles before emission. General first-class closure conversion,
full generated typeclass dictionaries, and a complete Rust→IR semantics theorem
remain future hardening work.

## Phase 3 completed: Rust→target semantic validation

`LeanRustCore.TargetValidation` emits `rust/target-validation.txt` from the same
extractor-owned `SurfaceFun` artifact that drives generated Rust and differential
tests. The snapshot records Rust-facing type declarations, function signatures,
and normalized expression fingerprints.

`rust/tests/semantic_validation.rs` parses `rust/src/generated.rs` with `syn`,
reconstructs the generated-subset target fingerprints from the Rust AST, and
compares that reconstruction with the Lean-generated snapshot.
`rust/tests/target_interpreter.rs` now goes further: it parses the same
snapshot, generates sample inputs for every emitted function, interprets every
emitted target fingerprint, and compares those interpreted results with the
compiled generated Rust calls. The executable layer now covers the full
target-validation function set rather than a selected sample, so parser drift,
dispatcher drift, or interpreter gaps fail before release.

## Phase 4 completed: optional raw ABI boundary exporter

`LeanRustCore.BoundaryExport` emits `rust/src/ffi_generated.rs` for a conservative
C-compatible subset. This file is feature-gated by `rust/src/lib.rs` under the
Rust `ffi` feature and is not part of the default safe direct-emission lane.

## Generated artifact normalization and lint scope

`scripts/gen.sh` is the source of truth for checked-in generated artifacts. It
regenerates every Lean-owned artifact and then runs `rustfmt --edition 2021` on
the generated Rust files:

- `rust/src/generated.rs`
- `rust/src/ffi_generated.rs`
- `rust/tests/differential_generated.rs`

`scripts/check-extractor-snapshot.sh` applies the same formatting step to its
temporary Rust outputs before diffing them against the checked-in files, so the
snapshot gate and `cargo fmt --check --all` validate the same normalized source.

The generated crate now includes `generated.rs` through a dedicated internal
module with scoped lint allowances for mechanically emitted patterns. Handwritten
Rust in the crate still runs under the normal workspace `cargo clippy
--workspace --all-targets -- -D warnings` policy.

## CI Matrix Execution

The repository now drives multi-platform release validation through
`scripts/check-ci-e2e.sh`, which is the single entry point used by
`.github/workflows/ci.yml` for the Linux/macOS by default/`ffi` matrix.

- `./scripts/check-ci-e2e.sh default` runs the full pinned-toolchain release gate
  in `./scripts/check.sh`.
- `./scripts/check-ci-e2e.sh ffi` runs the same release gate and then executes
  `cargo test --workspace --features ffi` to prove the feature-enabled workspace
  lane on the same platform.

This keeps the CI matrix, release checklist, and scripted local verification on
the same command surface instead of maintaining separate ad hoc job steps.

## Final 16 completion layer

The final completion patch adds metadata and workspace structure around the
existing direct Lean-to-Rust pipeline rather than widening the executable subset
again. `LeanRustCore.PropertyCorpus`, `CoverageDashboard`, `Diagnostics`,
`CrateDesign`, and `ReleaseMatrix` define the completion metadata that feeds the
proof report, validation report, and coverage dashboard.

The Rust side is now an explicit workspace rooted at `Cargo.toml` with five
crates: the generated crate in `rust/`, plus dedicated runtime, ABI,
validation, and header crates under `crates/`. This keeps safe runtime helpers,
unsafe FFI contracts, artifact-validation code, and header generation isolated
while preserving `lean-rust-core-generated` as the main generated API surface.

The public release surface intentionally excludes local tooling artifacts such
as `.ai-history/` state and `repomix-output.xml`. Release checks validate the
tracked tree and documentation surface rather than machine-local assistant or
aggregation outputs.

`lean-rust-core-validate` now owns strict typed schemas for `rust/validation-report.json`, `rust/compatibility-report.json`, `rust/proof-report.json`, `rust/build-metadata.json`, and `rust/coverage-dashboard.json`. Those structs use `serde` with `deny_unknown_fields`, and `rust/tests/validation_report.rs` parses the checked-in reports through that crate before checking counts, status enums, and feature flags against generated artifacts.

## Publishing gate hardening

Task 73 is now enforced outside the metadata-only Lean summary path. The Rust
workspace manifests carry publishable crates.io metadata, versioned
intra-workspace path dependencies, and docs.rs configuration. The dedicated
publishing gate lives in `scripts/check-publishing.py` and
`scripts/check-publishing.sh`:

- `scripts/check-publishing.py` validates crate metadata, semver text, README
  coverage, changelog structure, and dependency license declarations from Cargo
  metadata.
- `scripts/check-publishing.sh` copies the repo into a clean temporary release
  tree, runs `cargo doc --workspace --no-deps`, captures `cargo tree --workspace`,
  and executes `cargo publish --dry-run -p <crate>` for all five workspace
  crates.
- `rust/build.rs` now detects packaged-crate verification and falls back to the
  checked-in `src/generated.rs` when the Lean workspace root is absent from the
  tarball, while keeping repo-local CI/release builds on the stricter `lake`
  regeneration path.

That release gate is wired into `scripts/check.sh`, `Makefile`, the release
checklist, and Rust tests that assert the publish metadata remains visible from
checked artifacts.

## Property generator hardening

Task 64 no longer stops at deterministic seed metadata. The real generator layer
now lives in the Rust crates:

- `lean-rust-core-runtime` exposes seeded randomized runtime-value generators and
  shrinkers for scalar, container, recursive, and closure/dictionary families.
- `lean-rust-core-validate` exposes seeded target-term generators plus shrink and
  minimization functions over the admitted target grammar.
- `lean-rust-core-abi` exposes seeded handle lifecycle trace generators and
  shrinkers for the raw boundary lane.

The remaining-completion gate checks those APIs directly, and the property tests
exercise both generation and minimization rather than only fixed seeds.

The boundary policy is intentionally narrow:

- primitive integers cross directly,
- `Bool` crosses as `u32`,
- `Result<u32,u32>` lowers to `ChStatus` plus `out_ok`/`out_err` pointers,
- Rust-native containers, strings, structs, enums, and `Option` do not cross the
  raw ABI boundary in this phase.

Default builds retain `unsafe_code` forbiddance. The optional boundary lane is
checked with `cargo test --features ffi`.

## Sprint 13-14 closure lane

Captured values are represented explicitly before emission. The safe direct lane now has two first-order encodings: environment structs for closure conversion and enum/apply-function pairs for finite defunctionalization. Both encodings remain monomorphic and avoid Rust `unsafe`, trait objects, and dynamic dispatch.

## Sprint 3-6: general pattern and recursion lowering

`LeanRustCore.Pattern` exposes the Sprint-3/4 constructor-pattern facade. The
actual pattern representation is `SurfacePattern`, and the checked match node is
`SurfaceExpr.matchPattern`. The extractor now routes supported Bool, Option,
Prod, and index-free enum recursor/casesOn shapes through that node, while the
Surface checker enforces exhaustiveness for the supported fragment and binder
uniqueness before Rust codegen.

`LeanRustCore.RecursionLowering` records the Sprint-5/6 recursion policy. The
current implementation adds `SurfaceExpr.listLength` for owned-list length and
`SurfaceExpr.tailRecNat` for one checked Nat accumulator tail-recursion lane. The
emitter turns these into safe Rust `len()` and `while` constructs, and the
Surface evaluator remains fuel-bounded.

## Sprint 15-16: recursive data and validation v2

Known recursive, index-free user inductives now lower recursive payload fields through owned `Box<T>` in the safe Rust lane. The initial fixtures are `BinaryTreeU32` and `ExprU32`, including recursive construction, recursive pattern matching, and recursive function calls.

The target-validation artifact now uses `lean-rust-core.target-validation.v2`, which records `box(...)` and `deref(...)` fingerprints. `LeanRustCore.ValidationV2` also emits `rust/coverage-dashboard.json`, a machine-readable feature-family dashboard consumed by validation gates.

Task 66 closes the last manual-dashboard gap: every supported dashboard entry is
now emitted with explicit `implementation`, `tests`, `docs`,
`generated_examples`, and `diagnostics` evidence lists. The Lean theorem
`LeanRustCore.ValidationV2.coverage_entries_require_evidence`, the typed
validator schema, `rust/tests/validation_report.rs`,
`rust/tests/final16_property_coverage.rs`, and
`scripts/check-final-16-completion.py` together ensure coverage claims stay
derived from real repo artifacts rather than drifting declaration rows.

## First-20 pipeline completion

The implementation now includes an explicit `ExtractIR` stage between elaborated
Lean declarations and checked `SurfaceExpr`. `ExtractIR` records source spans,
erased binders, recursor/Std-lowering recognition, dictionary metadata, feature
tags, and next-feature diagnostics. Policy-only `ExtractIR` nodes must be
discharged through `lowerExpr?` before Rust emission; otherwise they become
stable `LRC` diagnostics.

Supported declarations now flow through `ExtractIR` as a mandatory compiler
stage rather than a metadata-only sidecar. The extractor first builds
`ExtractDecl` records, lowers them through `LeanRustCore.ExtractIR.lowerDecl?`,
and snapshots the pre-surface declarations in `rust/extract-ir.txt`. That
snapshot is regenerated by `scripts/gen.sh`, diffed by
`scripts/check-extractor-snapshot.sh`, and checked against generated Rust
function order by `scripts/check-artifact-consistency.py` and
`rust/tests/first20_completion.rs`.

Runtime semantics for generated aggregate types are provided by `RuntimeValue`
and `runtimeValueHasType`, so structs, enums, and recursive payload names have a
checked semantic carrier rather than placeholder values. This is covered by
`docs/RUNTIME_SEMANTICS.md`, `rust/tests/first20_completion.rs`, and
`scripts/check-first-20-completion.py`.

The same first-20 gate now also proves exhaustive `SurfaceExpr` node coverage.
`LeanRustCore.SurfaceCoverage.surfaceCoverageConstructorNames` must match the
current `SurfaceExpr` definition exactly, and `docs/RUNTIME_SEMANTICS.md` must
document every constructor by name.

## Next-20 numeric mode completion

Task 28 now reaches the real extractor/emitter lane rather than stopping at
runtime helpers and metadata. `LeanRustCore.NumericExamples` defines exported
checked, saturating, preconditioned, and checked-cast examples; `LeanRustCore.Extract`
lowers those declarations to checked surface functions; and `LeanRustCore.EmitRust`
routes the admitted numeric helper calls to `crate::runtime`.

The generated lane now includes concrete `u32` checked add/sub/div/mod,
saturating add/sub, preconditioned div/mod with `Result<u32, String>`, and
checked `u64` to `u32` casts. Those functions are enforced by
`rust/tests/generated.rs`, `rust/tests/next20_completion.rs`,
`rust/target-validation.txt`, and the exhaustive target interpreter.
