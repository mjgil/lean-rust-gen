# LeanRustCore

A self-contained direct **Lean → Rust** workflow.

This pass extends the direct Lean emits Rust implementation through steps 1-8, plus the next two implementation items: payload enum pattern matching and first-order function-call lowering:

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
5. `rust_mono_export` registers concrete type instantiations of generic Lean
   definitions and emits concrete Rust functions.
6. Unsupported tagged exports are skipped and recorded in
   `rust/compatibility-report.json` instead of aborting Rust generation.
7. Lean-generated differential tests compare generated Rust calls against values
   computed by the Lean proof-carrying IR evaluator.
8. A generated Rust-validation report plus shell/Rust gates validate the current
   safe emitted subset: snapshot reproducibility, no unsafe/FFI markers, no
   malformed emitter markers, and the differential test suite.

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
pub fn inc_u32(x: u32) -> u32
pub fn inc_twice_u32(x: u32) -> u32
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
pub fn step_amount_or(s: Step, fallback: u32) -> u32
pub fn step_amount_plus_one_or(s: Step, fallback: u32) -> u32
pub fn nested_none_u32(_x: ()) -> Option<Option<u32>>
pub fn result_ok_none_u32(_x: ()) -> Result<Option<u32>, u32>
pub fn result_err_some_u32(e: u32) -> Result<u32, Option<u32>>
pub fn identity_u64(x: u64) -> u64
pub fn choose_generic_u32(flag: bool, when_true: u32, when_false: u32) -> u32
pub fn option_default_u64(x: Option<u64>, fallback: u64) -> u64
```

The non-generic functions are emitted from ordinary `@[rust_export]` Lean definitions; the generic examples use explicit concrete monomorphization specs:

```lean
rust_mono_export generic_identity as identity_u64 [UInt64]
rust_mono_export generic_choose as choose_generic_u32 [UInt32]
rust_mono_export generic_option_default as option_default_u64 [UInt64]
rust_emit_exports_with_report generatedRust generatedCompatibilityReport
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
  Differential.lean      Lean-evaluator differential test generation
  RustValidation.lean    validation report for the current emitted subset
Main.lean                `lake exe gen_rust`
ProofReportMain.lean     `lake exe gen_proof_report`
CompatibilityReportMain.lean `lake exe gen_compatibility_report`
DifferentialMain.lean    `lake exe gen_differential_tests`
ValidationReportMain.lean `lake exe gen_validation_report`
rust/
  build.rs               tries Lean generator, falls back to checked-in snapshot
  src/generated.rs       checked-in fallback generated Rust
  tests/generated.rs     Rust tests for generated functions
  tests/differential_generated.rs Lean-generated differential tests
  validation-report.json Rust-validation manifest for the emitted subset
scripts/
  gen.sh                 regenerate Rust, reports, and differential tests
  check-extractor-snapshot.sh
  check-rust-validation.sh
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
- Lean `match` over `Bool`, `Option`, and closed enums including payload variants,
- struct constructors and field projection,
- enum constructors with payload fields,
- first-order calls to other tagged exported Lean declarations,
- expected-type propagation through nested `Option`/`Except` constructors,
- explicit concrete monomorphizations of generic functions with scalar type arguments,
- structured compatibility reports for unsupported tagged exports,
- Lean-generated differential tests for evaluator-backed cases,
- validation reports and repository gates for the current safe Rust subset.

Still intentionally out of scope:

- recursive functions and loops,
- higher-order functions and closures,
- implicit / discovered monomorphization; concrete generic exports currently use `rust_mono_export`,
- a full parser-backed Rust→Lean translation validator for arbitrary Rust text.

## Validation gates

The step 7/8 gates are:

```bash
lake exe gen_differential_tests rust/tests/differential_generated.rs
lake exe gen_validation_report rust/validation-report.json
./scripts/check-extractor-snapshot.sh
./scripts/check-rust-validation.sh
cd rust && cargo test
```

`rust/tests/differential_generated.rs` is generated by Lean and uses expected
values computed from `LeanRustCore.IR.eval`. `rust/validation-report.json` records
the current direct Lean→Rust validation checks, and `check-rust-validation.sh`
rejects unsafe, raw FFI, panic/todo/unimplemented, and malformed-emitter markers
in the generated Rust snapshot.

## Fully working implementation steps remaining

1. Add ordinary recursion or an explicit final no-recursion policy.
2. Extend monomorphization from explicit scalar type arguments to discovered
   concrete instantiations and generic structures/enums.
3. Expand the differential suite from evaluator-backed scalar/option cases to
   all extracted structs, payload enums, calls, and future recursive functions.
4. Replace the current emitted-subset validation manifest with a parser-backed
   Rust→Lean translation validator or a full formal semantics for the generated
   Rust subset.
