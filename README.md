# LeanRustCore

A self-contained direct **Lean → Rust** workflow.

This pass extends the direct Lean emits Rust implementation through steps 1-4:

1. Export extraction accepts `UInt32`, `UInt64`, `Int32`, `Int64`, `Unit`,
   `Option`, `Except`, and closed inductive/structure types in addition to the
   original `Nat`/`Bool` slice.
2. The extractor lowers Lean `match` forms for `Bool`, `Option`, and simple
   no-field inductive enums by recognizing their elaborated recursor/casesOn
   shapes.
3. The surface IR now has declaration models for structs/enums, struct literals,
   field projection, and enum variant constructors with payload fields.
4. Type checking and extraction propagate expected types through nested
   `Option.none`, `Option.some`, `Except.ok`, and `Except.error` constructors.

## What is generated

The Lean generator emits:

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Point { pub x: u32, pub y: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Choice { First, Second }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Step { Stay, Jump(u32) }

pub fn clamp_u32(lo: u32, hi: u32, x: u32) -> u32
pub fn max_u32(a: u32, b: u32) -> u32
pub fn is_nonzero_u32(x: u32) -> bool
pub fn add_u32(a: u32, b: u32) -> u32
pub fn mul_u32(a: u32, b: u32) -> u32
pub fn bounded_bump_u32(x: u32) -> u32
pub fn echo_u32(x: u32) -> u32
pub fn echo_u64(x: u64) -> u64
pub fn echo_i32(x: i32) -> i32
pub fn echo_i64(x: i64) -> i64
pub fn add_u64(a: u64, b: u64) -> u64
pub fn unit_roundtrip(x: ()) -> ()
pub fn bool_match_u32(flag: bool, when_true: u32, when_false: u32) -> u32
pub fn option_identity_u32(x: Option<u32>) -> Option<u32>
pub fn none_u32(_x: ()) -> Option<u32>
pub fn some_u32(x: u32) -> Option<u32>
pub fn option_default_u32(x: Option<u32>, fallback: u32) -> u32
pub fn result_ok_u32(x: u32) -> Result<u32, u32>
pub fn result_err_u32(e: u32) -> Result<u32, u32>
pub fn choose_by_enum(choice: Choice, left: u32, right: u32) -> u32
pub fn make_point(x: u32, y: u32) -> Point
pub fn point_x(p: Point) -> u32
pub fn point_y(p: Point) -> u32
pub fn shift_point_x(p: Point, dx: u32) -> Point
pub fn step_stay(_x: ()) -> Step
pub fn step_jump(amount: u32) -> Step
pub fn nested_none_u32(_x: ()) -> Option<Option<u32>>
pub fn result_ok_none_u32(_x: ()) -> Result<Option<u32>, u32>
pub fn result_err_some_u32(e: u32) -> Result<u32, Option<u32>>
```

All of these are emitted from ordinary `@[rust_export]` Lean definitions in
`LeanRustCore/Examples.lean` via:

```lean
rust_emit_exports generatedRust
```

## Repository layout

```text
LeanRustCore/
  IR.lean                proof-carrying typed IR + Lean evaluator
  Surface.lean           first-order extracted IR + declaration model + type checker
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

- `Nat` lowered to Rust `u32` for the original arithmetic slice,
- `UInt32`, `UInt64`, `Int32`, `Int64`, `Unit`, and `Bool`,
- `Option T` and `Except E T`, emitted as Rust `Option<T>` and `Result<T, E>`,
- closed structures and inductive enums, emitted as Rust `struct`s and `enum`s,
- variables, literals, `if`, `let`, equality,
- `<`, `<=`, `>`, `>=` for fixed-width numeric types,
- `+`, `-`, `*` lowered to Rust `wrapping_*` operations,
- Lean `match` over `Bool`, `Option`, and simple no-field enums,
- struct constructors and field projection,
- enum constructors with payload fields,
- expected-type propagation through nested `Option`/`Except` constructors.

Still intentionally out of scope:

- payload enum pattern matching,
- recursive functions and loops,
- higher-order functions and closures,
- generics and monomorphization,
- formal Rust operational semantics for emitted text.

## Fully working implementation steps remaining

1. Add payload enum pattern lowering.
2. Add a richer compatibility report instead of failing command elaboration for
   unsupported exports.
3. Add monomorphization: collect concrete type instantiations used by exported
   declarations and emit one Rust function per concrete instance.
4. Keep the snapshot gate: generated Rust must exactly match the checked-in
   fallback.
5. Add differential tests that evaluate the Lean IR and the generated Rust over
   the same cases.
6. Later, validate emitted Rust with a Rust→Lean translation path or a small
   formal semantics for the generated Rust subset.
