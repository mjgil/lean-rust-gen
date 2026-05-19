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
- simple no-field inductive enums, emitted as Rust enum declarations plus Rust
  `match` expressions.

Payload enum constructors are supported as expressions. Payload enum pattern
matching remains intentionally out of scope for this pass.

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

`rust_mono_export` records concrete type instantiations of generic Lean
definitions. The extractor reuses the elaborated generic body, maps the leading
`Type` binders to concrete `RType`s, and emits one ordinary Rust function per
requested instance. This pass supports scalar concrete type arguments such as
`UInt32` and `UInt64`; generic structures/enums and automatically discovered
instances remain future work.

Example:

```lean
rust_mono_export generic_choose as choose_generic_u32 [UInt32]
```

## Completed step 6: structured compatibility reporting

`rust_emit_exports_with_report` emits Rust for every supported export and also
defines a JSON compatibility report. Unsupported tagged declarations are not
silently accepted and no longer abort the whole generation pass; they appear as
`unsupported-declaration` diagnostics in `rust/compatibility-report.json`.

```lean
rust_emit_exports_with_report generatedRust generatedCompatibilityReport
```
