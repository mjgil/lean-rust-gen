# LeanRustCore

A self-contained direct **Lean → Rust** workflow.

This pass extends the direct Lean emits Rust implementation through the baseline validation work and the phase-0/1/2 large-subset slice: payload enum pattern matching, first-order call lowering, a SurfaceExpr evaluator, expanded differential tests, Rust hygiene, syn-backed parser validation, exact toolchain pins, automatic monomorphization, explicit Nat-to-u32 opt-in, extractor-owned surface artifacts, parameterized data, standard owned containers, transitive helper extraction, proof-binder erasure, dependent-shape/proof-field erasure, and limited function-pointer higher-order support, phase-3 target validation, phase-4 feature-gated raw ABI wrappers, Sprint-3/6 general pattern/recursion lowering, recursive user-data lowering with owned `Box<T>` payloads, and validation-v2 coverage-dashboard metadata. The larger roadmap is in `docs/LARGE_SUBSET_PLAN.md`:

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
20. `rust/target-validation.txt` records Lean-side target fingerprints and `rust/tests/semantic_validation.rs` compares them against a parsed Rust AST reconstruction.
21. `@[rust_nat_exact]`/`@[rust_int_exact]` lower exact Lean `Nat`/`Int` to `num_bigint::BigUint`/`BigInt`.
22. Captured lambdas inside recognized structural combinators lower to loop bodies that close over Rust locals.
23. Supported resolved typeclass dictionaries are erased when monomorphic `RType` lowering selects the target operation.
24. `rust/tests/target_interpreter.rs` executes selected target fingerprints and compares them with compiled Rust.
25. `LeanRustCore.BoundaryExport` emits optional `ffi`-feature raw ABI wrappers in `rust/src/ffi_generated.rs`, separate from the default safe lane.
26. Sprint-3/4 adds `SurfacePattern` and `SurfaceExpr.matchPattern` for checked Bool/Option/Prod/index-free-enum constructor patterns.
27. Sprint-3/4 lowers tuple/product destructuring and general pattern examples to ordinary safe Rust `match` expressions.
28. Sprint-5/6 adds `SurfaceExpr.listLength` for owned-List/Vec length lowering.
29. Sprint-5/6 adds `SurfaceExpr.tailRecNat`, the first checked Nat accumulator tail-recursion loop lowering to safe Rust `while`.
30. Known recursive index-free user inductives lower recursive fields through safe owned `Box<T>` payloads.
31. `rust/coverage-dashboard.json` records validation-v2 feature-family coverage alongside `rust/target-validation.txt`.

## What is generated

The Lean generator emits:

```rust
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Point { pub x: u32, pub y: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BoundedProof { pub value: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct BoxedU32 { pub value: u32 }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Choice { First, Second }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum TaggedU32 { Missing, Present(u32) }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Step { Stay, Jump(u32) }

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Ordering { Lt, Eq, Gt }

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
pub fn list_map_inc_u32(xs: Vec<u32>) -> Vec<u32>
pub fn list_fold_sum_u32(xs: Vec<u32>) -> u32
pub fn list_map_add_capture_u32(delta: u32, xs: Vec<u32>) -> Vec<u32>
pub fn list_filter_nonzero_u32(xs: Vec<u32>) -> Vec<u32>
pub fn list_foldr_sum_u32(xs: Vec<u32>) -> u32
pub fn list_any_nonzero_u32(xs: Vec<u32>) -> bool
pub fn list_all_nonzero_u32(xs: Vec<u32>) -> bool
pub fn array_map_inc_u32(xs: Vec<u32>) -> Vec<u32>
pub fn array_fold_sum_u32(xs: Vec<u32>) -> u32
pub fn option_map_inc_u32(x: Option<u32>) -> Option<u32>
pub fn option_bind_inc_u32(x: Option<u32>) -> Option<u32>
pub fn result_bind_inc_u32(x: Result<u32, u32>) -> Result<u32, u32>
pub fn nat_sum_to_u32(n: u32) -> u32
pub fn subtype_val_u32(x: u32) -> u32
pub fn fin_val10_u32(i: u32) -> u32
pub fn vector_echo3_u32(xs: Vec<u32>) -> Vec<u32>
pub fn general_bool_match_u32(flag: bool, when_true: u32, when_false: u32) -> u32
pub fn general_option_match_u32(x: Option<u32>, fallback: u32) -> u32
pub fn general_step_match_u32(s: Step, fallback: u32) -> u32
pub fn pair_sum_match_u32(a: u32, b: u32) -> u32
pub fn list_length_u32(xs: Vec<u32>) -> u32
pub fn tail_sum_down_u32(n: u32) -> u32
pub fn exact_nat_add(a: num_bigint::BigUint, b: num_bigint::BigUint) -> num_bigint::BigUint
pub fn exact_nat_mul(a: num_bigint::BigUint, b: num_bigint::BigUint) -> num_bigint::BigUint
pub fn exact_int_add(a: num_bigint::BigInt, b: num_bigint::BigInt) -> num_bigint::BigInt
pub fn decidable_eq_u32(a: u32, b: u32) -> bool
pub fn inhabited_default_u32(_x: ()) -> u32
pub fn to_string_u32(x: u32) -> String
pub fn repr_u32(x: u32) -> String
pub fn ord_compare_u32(a: u32, b: u32) -> Ordering
pub fn option_do_inc_u32(x: Option<u32>) -> Option<u32>
pub fn closure_apply_capture_u32(delta: u32, x: u32) -> u32
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
pub fn generic_beq_u32(a: u32, b: u32) -> bool
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
rust_mono_export generic_beq as generic_beq_u32 [UInt32]

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
  TargetValidation.lean  Lean-side Rust target fingerprint snapshot
  BoundaryExport.lean    optional feature-gated raw ABI wrapper generation
  Toolchain.lean         exact toolchain/build-metadata policy
Main.lean                `lake exe gen_rust`
ProofReportMain.lean     `lake exe gen_proof_report`
CompatibilityReportMain.lean `lake exe gen_compatibility_report`
DifferentialMain.lean    `lake exe gen_differential_tests`
ValidationReportMain.lean `lake exe gen_validation_report`
TargetValidationMain.lean `lake exe gen_target_validation`
BoundaryMain.lean        `lake exe gen_boundary_exports`
BuildMetadataMain.lean   `lake exe gen_build_metadata`
rust/
  build.rs               runs Lean generator; dev fallback requires LEAN_RUST_CORE_ALLOW_FALLBACK=1
  src/generated.rs       checked-in fallback generated Rust
  tests/generated.rs     Rust tests for generated functions
  tests/differential_generated.rs Lean-generated differential tests
  tests/parser_validation.rs syn-backed AST validation for generated Rust
  tests/semantic_validation.rs Rust→target fingerprint validation
  tests/target_interpreter.rs target-fingerprint interpreter samples
  tests/ffi_boundary.rs optional ffi-feature boundary tests
  validation-report.json Rust-validation manifest for the emitted subset
  target-validation.txt  Lean-side target validation snapshot
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

The default Rust crate forbids safe-code escape hatches with a feature gate:

```rust
#![cfg_attr(not(feature = "ffi"), forbid(unsafe_code))]
```

The optional `ffi` feature enables a separate raw ABI wrapper module. It is not included in the default direct safe-Rust lane.

## Current extraction subset

Supported now:

- `Nat` lowered to Rust `u32` only for declarations marked
  `@[rust_nat_wrapping_u32]`; exact `Nat`/`Int` lower through
  `@[rust_nat_exact]`/`@[rust_int_exact]` to `num_bigint::BigUint`/`BigInt`;
  fixed-width `UInt32`/`UInt64` are preferred for normal exported boundaries,
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
- `List.map` and `List.foldl` over owned `List` values, lowered to explicit safe Rust loop-shaped expressions,
- generated first-order call cycles are allowed through Rust emission; differential evaluation remains fuel-bounded,
- captured lambdas inside recognized structural combinators close over ordinary Rust locals,
- resolved `BEq`/`LT`/`LE`/`HAdd`/`HSub`/`HMul`/`OfNat` dictionaries are erased when monomorphic lowering selects the target operation,
- expected-type propagation through nested `Option`/`Except` constructors,
- explicit concrete monomorphizations of generic functions,
- automatic monomorphization for generic calls discovered inside concrete exported declarations,
- structured compatibility reports for unsupported tagged exports,
- Lean-generated differential tests for proof-carrying IR and extractor-owned SurfaceExpr-backed cases,
- validation reports and repository gates for the current safe Rust subset,
- Rust identifier hygiene and collision detection before emission,
- parser-backed generated Rust validation through `syn`,
- Rust→target-IR fingerprint validation against `rust/target-validation.txt`,
- optional feature-gated raw ABI wrappers for a primitive/result subset,
- conservative proof-shaped binder erasure for exported runtime signatures,
- unary function-pointer arguments for simple higher-order exports.

Still intentionally out of scope:

- broader structural-recursion lowering beyond the current `List.map`/`List.foldl` slice, including richer accumulator recursions and proofs that emitted recursion is structurally bounded,
- general first-class captured closures and defunctionalized local lambdas beyond recognized structural combinators and unary Rust `fn` pointer arguments,
- generated typeclass dictionaries beyond the current erased/resolved monomorphization path,
- a full Rust→Lean translation validator for arbitrary Rust text beyond the generated subset and selected target-fingerprint interpreter.

## Validation gates

The step 7/8 gates are:

```bash
lake exe gen_differential_tests rust/tests/differential_generated.rs
lake exe gen_validation_report rust/validation-report.json
lake exe gen_target_validation rust/target-validation.txt
lake exe gen_boundary_exports rust/src/ffi_generated.rs
lake exe gen_build_metadata rust/build-metadata.json
./scripts/check-toolchain-pins.sh
./scripts/check-extractor-snapshot.sh
./scripts/check-rust-validation.sh
cd rust && cargo test
cd rust && cargo test --features ffi
```

`rust/tests/differential_generated.rs` is generated by Lean and uses expected
values computed from `LeanRustCore.IR.eval` and `LeanRustCore.Surface.evalSurfaceFun`.
`rust/validation-report.json` records the current direct Lean→Rust validation checks, and `check-rust-validation.sh`
rejects unsafe, raw FFI, panic/todo/unimplemented, malformed-emitter markers,
and missing parser-validation coverage in the generated Rust snapshot. The toolchain gate checks exact Lean/Rust pins and the release fallback policy. The Rust
`parser_validation` integration test additionally parses `generated.rs` with `syn`
and checks the generated top-level AST shape. The Rust `semantic_validation` integration test parses generated Rust into a generated-subset target fingerprint and compares it with the Lean-generated `rust/target-validation.txt` snapshot. The `target_interpreter` integration test executes selected target fingerprints and checks them against compiled generated Rust. Optional raw ABI wrappers are generated in `rust/src/ffi_generated.rs` and tested only under `cargo test --features ffi`.

## Large-subset implementation steps remaining

The full staged plan is in `docs/LARGE_SUBSET_PLAN.md`. The next high-leverage
items are:

4. Extend exact integer lowering to additional operations and precondition modes.
5. Generalize closure conversion/defunctionalization beyond recognized structural combinators.
6. Replace selected target-fingerprint interpreter samples with a full generated-subset semantics theorem or Rust→Lean translation validator.
7. Expand the raw ABI lane with handles for strings, slices, structs, enums, and generated C headers.

## Sprint 13-14 closure conversion and defunctionalization

This snapshot adds the next closure/higher-order slice for the direct safe Rust lane:

- captured unary closures can lower to explicit first-order environment structs such as `AddDeltaU32Env`;
- finite known function families can lower to defunctionalized enum cases such as `U32FnCase`;
- generated apply functions remain monomorphic safe Rust and avoid dynamic dispatch, trait objects, and unsafe closure storage;
- raw ABI wrappers are generated only for the primitive-returning subset of these new exports.

### Sprint 7-9 coverage checkpoint

The Sprint 7-9 patch adds machine-readable policy modules for broad Std
lowerings, typeclass specialization, and pure monadic `do` lowering. The
default generated Rust lane remains safe Rust; raw ABI wrappers stay isolated
behind the `ffi` feature.

## Final rows 41-56 checkpoint

The final completion layer now includes deterministic property seeds, a
quantitative coverage dashboard, stable diagnostic templates, a split Rust
workspace, crate-local tests/docs, and a release acceptance matrix. The generated
safe crate remains `lean-rust-core-generated`; runtime helpers, raw ABI handles,
validation tooling, and header generation live in dedicated workspace crates.

Run `scripts/check-final-16-completion.py` for the non-toolchain gate, and
`docs/RELEASE_CHECKLIST.md` lists the full release matrix.

## First-20 completion gate

Rows 1 through 20 of the implementation checklist are guarded by:

```bash
scripts/check-first-20-completion.py
```

The gate checks the explicit `ExtractIR` layer, `RuntimeValue` denotations,
expanded `LRC001`-`LRC014` diagnostics, source-span metadata, positive/negative
/unsupported corpus fixtures, generated report metadata, tests, and docs.

## Rows 21-40 completion patch

The second checklist block is gated by `scripts/check-next-20-completion.py`.
It completes the design-doc rows for the runtime type universe, monomorphic data,
generic policy, numeric semantics, dependent erasure, recursive layouts,
ownership, pattern matrix, recursion analysis, Std lowering implementation, and
resolved typeclass specialization. Each feature has a concrete Lean metadata
module, Rust/runtime tests, and feature-specific documentation.
