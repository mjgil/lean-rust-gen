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
compares that reconstruction with the Lean-generated snapshot. `rust/tests/target_interpreter.rs`
executes selected target fingerprints for exact integers, captured structural
lambdas, and erased typeclass equality, then compares those interpreted results
with compiled generated Rust functions. This is stronger than the previous
parser-only gate: the Rust source must now be parseable, reconstructible into
the approved generated target subset, and semantically sampled through the target
fingerprint interpreter.

## Phase 4 completed: optional raw ABI boundary exporter

`LeanRustCore.BoundaryExport` emits `rust/src/ffi_generated.rs` for a conservative
C-compatible subset. This file is feature-gated by `rust/src/lib.rs` under the
Rust `ffi` feature and is not part of the default safe direct-emission lane.

## Final 16 completion layer

The final completion patch adds metadata and workspace structure around the
existing direct Lean-to-Rust pipeline rather than widening the executable subset
again. `LeanRustCore.PropertyCorpus`, `CoverageDashboard`, `Diagnostics`,
`CrateDesign`, and `ReleaseMatrix` define the completion metadata that feeds the
proof report, validation report, and coverage dashboard.

The Rust side is now an explicit workspace rooted at [Cargo.toml](/home/m/git/lean-rust-gen/Cargo.toml) with five crates: the generated crate in `rust/`, plus dedicated runtime, ABI, validation, and header crates under `crates/`. This keeps safe runtime helpers, unsafe FFI contracts, artifact-validation code, and header generation isolated while preserving `lean-rust-core-generated` as the main generated API surface.

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
