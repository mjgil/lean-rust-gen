# Architecture

This repo is intentionally back to the direct app shape:

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

## Implemented step 1: declaration extraction

`LeanRustCore.Export` defines the `@[rust_export]` tag attribute, and
`LeanRustCore.Extract` provides `extractConst`, which inspects ordinary Lean
constant bodies after elaboration. The example declarations are ordinary Lean
`def`s tagged with `@[rust_export]`; the command:

```lean
rust_emit_exports generatedRust
```

collects the tagged declarations visible in the current environment, lowers
them into checked `SurfaceFun`s, and emits the Rust module string. This replaces
the prior exact source-string recognizer.

## Implemented part of step 2: grow the IR

The typed IR and extracted surface IR now support:

- `let` bindings,
- `<=` and `>=`,
- explicit wrapping `u32` addition, subtraction, and multiplication,
- type checking of extracted first-order expressions before codegen.

The overflow policy is explicit: generated arithmetic uses Rust
`wrapping_add`, `wrapping_sub`, and `wrapping_mul`; the Lean evaluator mirrors
that policy with modular arithmetic.

## Boundary model

`ChimeraBoundary` is retained only as a small vendored ABI/result-lowering model
for future raw FFI exports. It is not the main compiler architecture.
