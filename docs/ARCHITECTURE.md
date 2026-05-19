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
- closed parameter-free inductive enums.

The surface checker in `LeanRustCore.Surface` verifies every extracted function
body against the declared Rust-facing return type before emission.

## Completed step 2: match lowering

`LeanRustCore.Extract` now recognizes elaborated recursor/casesOn shapes for:

- `Bool`, emitted as Rust `match flag { true => ..., false => ... }`,
- `Option`, emitted as Rust `match option { None => ..., Some(value) => ... }`,
- simple no-field inductive enums, emitted as Rust enum declarations plus Rust
  `match` expressions.

The enum support is intentionally narrow: the inductive must be closed,
parameter-free, and its constructors must not carry payload fields.

## Boundary model

`ChimeraBoundary` is retained only as a small vendored ABI/result-lowering model
for future raw FFI exports. It is not the main compiler architecture.
