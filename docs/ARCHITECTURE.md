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

- `Nat` as the original `u32` arithmetic model,
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
defines a JSON compatibility report. Unsupported tagged declarations are not
silently accepted and no longer abort the whole generation pass; they appear as
`unsupported-declaration` diagnostics in `rust/compatibility-report.json`.

```lean
rust_emit_exports_with_report generatedRust generatedCompatibilityReport
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

`LeanRustCore.Differential` now uses that evaluator for the extracted surface
fixtures instead of hard-coded expected values. The differential test suite
covers structs, enums, `Result`, monomorphized exports, payload matches, and
call chains against the generated Rust crate.

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
