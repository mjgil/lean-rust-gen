# LeanRustCore

A self-contained direct **Lean → Rust** workflow.

This pass extends the direct Lean emits Rust implementation through the baseline validation work and the phase-0/1/2 large-subset slice: payload enum pattern matching, first-order call lowering, a SurfaceExpr evaluator, expanded differential tests, Rust hygiene, syn-backed parser validation, exact toolchain pins, automatic monomorphization, explicit Nat-to-u32 opt-in, extractor-owned surface artifacts, parameterized data, standard owned containers, transitive helper extraction, proof-binder erasure, and limited function-pointer higher-order support. The larger roadmap is in `docs/LARGE_SUBSET_PLAN.md`:

1. Export extraction accepts `UInt32`, `UInt64`, `Int32`, `Int64`, `Unit`,
   `Option`, `Except`, and closed inductive/structure types in addition to
   `Bool` and explicitly opted-in `Nat`/`u32` wrapping boundaries.
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
   computed by the Lean proof-carrying IR evaluator and the checked SurfaceExpr evaluator.
8. A generated Rust-validation report plus shell/Rust gates validate the current
   safe emitted subset: snapshot reproducibility, no unsafe/FFI markers, no
   malformed emitter markers, and the differential test suite.
9. Rust identifier hygiene sanitizes keywords/invalid characters, emits stable
   type and variant names, and rejects post-sanitization collisions before emission.
10. `rust/tests/parser_validation.rs` parses generated Rust with `syn` and checks
   the approved top-level safe Rust subset by AST.
11. Lean and Rust toolchains are pinned exactly and checked by
   `scripts/check-toolchain-pins.sh`; CI/release builds cannot silently use the
   checked-in generated Rust fallback.
12. Generic calls inside concrete exported declarations are automatically
   monomorphized into deterministic generated Rust functions.
13. Lean `Nat` only lowers to Rust `u32` when an exported declaration explicitly
   opts into wrapping semantics with `@[rust_nat_wrapping_u32]`.
14. The differential suite consumes `extractedSurfaceFunctions`, emitted by the
   same extractor command as generated Rust, instead of hand-mirrored
   `SurfaceFun` fixtures.
15. Parameterized index-free structures and enums are monomorphized into stable
   Rust-facing type names.
16. `Char`, `String`, `List`, `Array`, `Prod`, `Sum`, and unary function types
   are represented in the Rust-shaped runtime type universe.
17. Exported roots can pull in first-order helper definitions automatically.
18. Conservative proof-shaped binders are erased from Rust signatures.
19. Unary function-valued arguments lower to safe Rust `fn` pointer arguments.

## What is generated

The Lean generator emits:

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Point { pub x: u32, pub y: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BoxedU32 { pub value: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Choice { First, Second }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TaggedU32 { Missing, Present(u32) }

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
pub fn echo_char(x: char) -> char
pub fn echo_string(x: String) -> String
pub fn echo_list_u32(xs: Vec<u32>) -> Vec<u32>
pub fn echo_array_u32(xs: Vec<u32>) -> Vec<u32>
pub fn echo_prod_u32(x: (u32, u32)) -> (u32, u32)
pub fn echo_sum_u32(x: Result<u32, u32>) -> Result<u32, u32>
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
pub fn generic_identity__u32(x: u32) -> u32
pub fn generic_choose__point(flag: bool, when_true: Point, when_false: Point) -> Point
pub fn generic_option_default__step(x: Option<Step>, fallback: Step) -> Step
pub fn auto_identity_u32(x: u32) -> u32
pub fn auto_choose_point(flag: bool, left: Point, right: Point) -> Point
pub fn auto_option_default_step(x: Option<Step>, fallback: Step) -> Step
pub fn proof_erased_u32(x: u32) -> u32
pub fn boxed_u32(x: u32) -> BoxedU32
pub fn boxed_value_u32(b: BoxedU32) -> u32
pub fn tagged_missing_u32(_x: ()) -> TaggedU32
pub fn tagged_present_u32(x: u32) -> TaggedU32
pub fn tagged_default_u32(t: TaggedU32, fallback: u32) -> u32
pub fn unsupported_higher_order_u32(f: fn(u32) -> u32, x: u32) -> u32
pub fn helper_inc_fixed(x: u32) -> u32
pub fn helper_chain_u32(x: u32) -> u32
```

The non-generic functions are emitted from ordinary `@[rust_export]` Lean definitions. The examples that intentionally expose Lean `Nat` as Rust `u32` use the explicit `@[rust_nat_wrapping_u32]` opt-in. Generic examples use both explicit concrete monomorphization specs and automatically discovered instances from concrete exported call sites:

```lean
rust_mono_export generic_identity as identity_u64 [UInt64]
rust_mono_export generic_choose as choose_generic_u32 [UInt32]
rust_mono_export generic_option_default as option_default_u64 [UInt64]

@[rust_export]
def auto_choose_point (flag : Bool) (left right : Point) : Point :=
  generic_choose Point flag left right

rust_emit_exports_with_report_and_surface generatedRust generatedCompatibilityReport extractedSurfaceFunctions
```

## Repository layout

```text
LeanRustCore/
  IR.lean                proof-carrying typed IR + Lean evaluator
  Surface.lean           first-order extracted IR + declaration model + type checker + evaluator
  Extract.lean           elaborated Lean declaration extractor
  EmitRust.lean          Rust emitter for typed and extracted IR
  RustHygiene.lean       Rust identifier sanitization and collision checks
  Lowering.lean          compatibility/lowering seam
  ChimeraBoundary.lean   small ABI/result-lowering boundary model
  Examples.lean          ordinary Lean source defs + proof-carrying examples
  ProofReport.lean       proof-sidecar JSON model
  Differential.lean      Lean IR + SurfaceExpr differential test generation
  RustValidation.lean    validation report for the current emitted subset
  Toolchain.lean         exact toolchain/build-metadata policy
Main.lean                `lake exe gen_rust`
ProofReportMain.lean     `lake exe gen_proof_report`
CompatibilityReportMain.lean `lake exe gen_compatibility_report`
DifferentialMain.lean    `lake exe gen_differential_tests`
ValidationReportMain.lean `lake exe gen_validation_report`
BuildMetadataMain.lean   `lake exe gen_build_metadata`
rust/
  build.rs               runs Lean generator; dev fallback requires LEAN_RUST_CORE_ALLOW_FALLBACK=1
  src/generated.rs       checked-in fallback generated Rust
  tests/generated.rs     Rust tests for generated functions
  tests/differential_generated.rs Lean-generated differential tests
  tests/parser_validation.rs syn-backed AST validation for generated Rust
  validation-report.json Rust-validation manifest for the emitted subset
  build-metadata.json    exact toolchain and fallback-policy metadata
scripts/
  gen.sh                 regenerate Rust, reports, and differential tests
  check-extractor-snapshot.sh
  check-toolchain-pins.sh
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

- `Nat` lowered to Rust `u32` only for declarations marked
  `@[rust_nat_wrapping_u32]`; fixed-width `UInt32`/`UInt64` are preferred for
  normal exported boundaries,
- `UInt32`, `UInt64`, `Int32`, `Int64`, `Unit`, `Bool`, `Char`, and `String`,
- `List T` and `Array T`, emitted as owned Rust `Vec<T>` values for this phase,
- `Prod A B` and `Sum A B`, emitted as Rust tuples and `Result<B, A>` respectively,
- `Option T` and `Except E T`, emitted as Rust `Option<T>` and `Result<T, E>`,
- index-free structures and inductive enums, including concrete monomorphized parameterized types such as `Boxed UInt32` and `Tagged UInt32`,
- variables, literals, `if`, `let`, equality,
- `<`, `<=`, `>`, `>=` for fixed-width numeric types,
- `+`, `-`, `*` lowered to Rust `wrapping_*` operations,
- Lean `match` over `Bool`, `Option`, and closed enums including payload variants,
- struct constructors and field projection,
- enum constructors with payload fields,
- first-order calls to other tagged exported Lean declarations and automatically extracted first-order helper definitions,
- generated first-order call cycles are allowed through Rust emission; differential evaluation remains fuel-bounded,
- expected-type propagation through nested `Option`/`Except` constructors,
- explicit concrete monomorphizations of generic functions,
- automatic monomorphization for generic calls discovered inside concrete exported declarations,
- structured compatibility reports for unsupported tagged exports,
- Lean-generated differential tests for proof-carrying IR and extractor-owned SurfaceExpr-backed cases,
- validation reports and repository gates for the current safe Rust subset,
- Rust identifier hygiene and collision detection before emission,
- parser-backed generated Rust validation through `syn`,
- conservative proof-shaped binder erasure for exported runtime signatures,
- unary function-pointer arguments for simple higher-order exports.

Still intentionally out of scope:

- exact mathematical `Nat`/`Int` runtime semantics unless a future exact-integer
  backend is added,
- loop lowering for accumulator recursions and proof that emitted recursion is structurally bounded,
- captured closures and defunctionalized local lambdas beyond unary Rust `fn` pointer arguments,
- generated typeclass dictionaries beyond the current monomorphization/inlining-oriented path,
- a full Rust→Lean translation validator for arbitrary Rust text beyond the generated subset.

## Validation gates

The step 7/8 gates are:

```bash
lake exe gen_differential_tests rust/tests/differential_generated.rs
lake exe gen_validation_report rust/validation-report.json
lake exe gen_build_metadata rust/build-metadata.json
./scripts/check-toolchain-pins.sh
./scripts/check-extractor-snapshot.sh
./scripts/check-rust-validation.sh
cd rust && cargo test
```

`rust/tests/differential_generated.rs` is generated by Lean and uses expected
values computed from `LeanRustCore.IR.eval` and `LeanRustCore.Surface.evalSurfaceFun`.
`rust/validation-report.json` records the current direct Lean→Rust validation checks, and `check-rust-validation.sh`
rejects unsafe, raw FFI, panic/todo/unimplemented, malformed-emitter markers,
and missing parser-validation coverage in the generated Rust snapshot. The toolchain gate checks exact Lean/Rust pins and the release fallback policy. The Rust
`parser_validation` integration test additionally parses `generated.rs` with `syn`
and checks the generated top-level AST shape.

## Large-subset implementation steps remaining

The full staged plan is in `docs/LARGE_SUBSET_PLAN.md`. The next high-leverage
items are:

1. Add loop lowering and termination/stack policy for structurally accepted recursive definitions.
2. Extend automatic monomorphization through recursive generic functions and richer nested generic shapes.
3. Add generated typeclass dictionaries or instance inlining for typeclass-heavy APIs.
4. Replace the current generated-subset `syn` validator with a Rust→Lean
   translation validator or a full formal semantics for the generated Rust subset.
5. Add closure conversion/defunctionalization for captured lambdas and known top-level function values.
