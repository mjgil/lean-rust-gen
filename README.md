# LeanRustCore

A self-contained direct **Lean → Rust** workflow.

The current pass implements two concrete next steps:

1. It replaces exact source matching with extraction from **elaborated Lean
   declarations** tagged by `@[rust_export]`.
2. It grows the Rust-shaped IR with `let` bindings and explicit wrapping `u32`
   arithmetic.

## What is generated

The Lean generator emits:

```rust
pub fn clamp_u32(lo: u32, hi: u32, x: u32) -> u32
pub fn max_u32(a: u32, b: u32) -> u32
pub fn is_nonzero_u32(x: u32) -> bool
pub fn add_u32(a: u32, b: u32) -> u32
pub fn mul_u32(a: u32, b: u32) -> u32
pub fn bounded_bump_u32(x: u32) -> u32
```

`add_u32`, `mul_u32`, and the `let` binding inside `bounded_bump_u32` are emitted
from ordinary `@[rust_export]` Lean definitions in `LeanRustCore/Examples.lean` via `rust_emit_exports generatedRust`.

## Repository layout

```text
LeanRustCore/
  IR.lean                proof-carrying typed IR + Lean evaluator
  Surface.lean           first-order extracted IR + type checker
  Extract.lean           elaborated Lean declaration extractor
  EmitRust.lean          Rust emitter for typed and extracted IR
  Lowering.lean          compatibility/lowering seam
  ChimeraBoundary.lean   small ABI/result-lowering boundary model
  Examples.lean          ordinary Lean source defs + proof-carrying examples
  ProofReport.lean       proof-sidecar JSON model
Main.lean                `lake exe gen_rust`
ProofReportMain.lean     `lake exe gen_proof_report`
rust/
  build.rs               tries Lean generator, falls back to checked-in snapshot
  src/generated.rs       checked-in fallback generated Rust
  tests/generated.rs     Rust tests for generated functions
scripts/
  gen.sh                 regenerate Rust + proof report
  check-extractor-snapshot.sh
  check.sh
```

## Run

```bash
./scripts/gen.sh
./scripts/check.sh
```

The Rust crate forbids safe-code escape hatches with:

```rust
#![forbid(unsafe_code)]
```

## Current extraction subset

Supported now:

- `Nat` lowered to Rust `u32`,
- `Bool` lowered to Rust `bool`,
- variables, literals, `if`, `let`, equality,
- `<`, `<=`, `>`, `>=`,
- `+`, `-`, `*` lowered to `wrapping_add`, `wrapping_sub`, `wrapping_mul`.

Not implemented yet:

- structs/enums,
- pattern matching beyond `if`,
- `Option`/`Except` extraction,
- recursion/loops,
- generics and monomorphization,
- formal Rust operational semantics for emitted text.

## Fully working implementation steps remaining

1. Expand `typeOfLean` from `Nat`/`Bool` to `UInt32`, fixed-width signed types,
   structs, enums, `Option`, and `Except`.
2. Add extractor cases for Lean `match` / recursor forms, starting with Bool,
   Option, and simple inductive enums.
3. Add struct and enum declarations to `Surface.lean`, then emit Rust `struct`
   and `enum` items before functions.
4. Add monomorphization: collect concrete type instantiations used by exported
   declarations and emit one Rust function per concrete instance.
5. Add a richer compatibility report instead of failing command elaboration for
   unsupported exports.
6. Keep the snapshot gate: generated Rust must exactly match the checked-in
   fallback.
7. Add differential tests that evaluate the Lean IR and the generated Rust over
   the same cases.
8. Later, validate emitted Rust with a Rust→Lean translation path or a small
   formal semantics for the generated Rust subset.
