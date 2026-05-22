# Practical largest Lean → Rust subset plan

The practical largest direct source backend is a proof-erased, monomorphized,
computable Lean subset that emits ordinary safe Rust for the default lane and
keeps any raw ABI wrappers in a separate feature-gated boundary lane.


## Sprint 1/2 implementation checkpoint

Completed in this patch:

- Sprint 1 adds a repository corpus harness with positive, negative, and intentionally unsupported Lean fixtures.
- Sprint 1 adds `scripts/check-artifact-consistency.py`, which parses generated Rust/reports and checks JSON validity, function/type counts, target-validation counts, FFI wrapper counts, and report/source ordering before Lean or Cargo are required.
- Sprint 1 normalizes checked-in generated artifacts so `generated.rs`, compatibility, validation, proof, target-validation, and FFI snapshots agree.
- Sprint 2 adds `LeanRustCore.ExtractIR`, a small metadata layer that records normalized declaration feature tags and next-feature diagnostics.
- Sprint 2 extends compatibility and validation reports with feature-tag metadata and module-level feature summaries.


## Sprint 3–6 implementation checkpoint

Completed in this patch:

- Sprint 3/4 adds `SurfacePattern` plus `SurfaceExpr.matchPattern` for a checked constructor-pattern fragment.
- General patterns now cover Bool, Option, Prod/tuple destructuring, wildcard/variable binders, and index-free enum constructors with payload binders.
- Surface checking validates pattern exhaustiveness for the supported fragment, duplicate binders, and branch type consistency before Rust emission.
- The extractor lowers Bool, Option, Prod.casesOn, and index-free enum recursor/casesOn shapes through the general pattern node instead of only the older specialized match nodes.
- Sprint 5/6 adds `SurfaceExpr.listLength` and the example `list_length_u32`, lowering Lean `List.length` over the owned list representation to safe Rust `Vec::len() as u32`.
- Sprint 5/6 adds `SurfaceExpr.tailRecNat` and the example `tail_sum_down_u32`, the first explicit Nat accumulator tail-recursion lane emitted as a safe Rust `while` loop.
- Target fingerprints, differential tests, parser/semantic validation, target-interpreter samples, FFI wrappers, compatibility reports, and proof reports now cover the new pattern and recursion features.

## Phase 0 — baseline consistency and artifact trust

Completed in this branch:

- Lean `Nat` → Rust `u32` requires explicit `@[rust_nat_wrapping_u32]` opt-in.
- The compatibility report distinguishes wrapping-`Nat` exports from fixed-width exports.
- The extractor emits `Examples.extractedSurfaceFunctions` alongside generated Rust and the compatibility report.
- Differential tests consume the extractor-owned `SurfaceFun` artifact rather than hand-mirrored fixtures.

## Phase 1 — medium executable subset

Completed in this branch as the first medium-subset slice:

- `RType` includes `Char`, `String`, `List`, `Array`, `Prod`, `Sum`, and unary function types.
- These shapes lower to safe Rust type spellings: `char`, `String`, `Vec<T>`, tuples, `Result<B,A>`, and `fn(A) -> B`.
- Index-free parameterized structures/enums can be monomorphized to concrete Rust declarations such as `BoxedU32` and `TaggedU32`.
- First-order generated call cycles are permitted in Rust emission; Lean-side differential evaluation remains fuel-bounded.

## Phase 2 — large pure-functional subset slice

Completed in this branch as the first large-subset slice:

- Concrete exported roots can pull in first-order helper definitions transitively.
- Conservative proof-shaped binders are erased from Rust signatures when not used computationally.
- Unary function-valued arguments lower to Rust `fn` pointers and `SurfaceExpr.callValue`.
- `List.map`, `List.filter`, `List.foldl`, `List.foldr`, `List.any`, and `List.all` over owned `List` values lower to explicit safe Rust loop-shaped `SurfaceExpr` nodes.
- `Array.map` and `Array.foldl` lower to the same owned-`Vec<T>` loop lane used by the current Array representation.
- `Option.map`/`Option.bind` and `Except.map`/`Except.bind` lower to safe Rust `match` expressions.
- `@[rust_nat_exact]` and `@[rust_int_exact]` lower Lean `Nat`/`Int` boundaries to exact `num_bigint::BigUint`/`BigInt` values.
- Captured lambdas inside recognized structural combinators lower by converting the closure environment into ordinary Rust loop locals.
- Resolved `BEq`/`LT`/`LE`/`HAdd`/`HSub`/`HMul`/`OfNat` dictionaries are erased when the operation is selected by the monomorphic `RType`; unsupported dictionaries remain rejected.
- A first structural `Nat.rec` accumulator-recursion lane lowers to bounded `for` loops in Rust.
- `Subtype`, literal-bound `Fin`, and literal-length `Vector` have erased/checked runtime shapes: carriers erase, `Fin n` uses `u32`, and `Vector α n` uses `Vec<T>` with checked-constructor support.
- Proof-only constructor fields are erased from emitted runtime structs when they are not used computationally; `BoundedProof` is the regression example for this lane.

Still future work for a larger phase 2+:

- Broader structural recursion lowering for additional recursors, mutual recursion, trees, and tail-recursive helpers.
- General closure conversion for first-class captured lambdas outside recognized combinators.
- Defunctionalization for known higher-order functions.
- Full generated typeclass dictionaries for class-heavy generic programs that cannot be erased or monomorphically resolved.
- Broader proof-shape recognition beyond the current Eq/True/False/And/Or/Not/Iff/Exists/LT/LE slice, plus equality-cast and `Sigma`-shape erasure.

## Phase 3 — semantic validation and release hardening

Completed in this branch:

- `LeanRustCore.TargetValidation` emits a Lean-side target-validation snapshot from the checked extractor-owned `SurfaceFun` list.
- `rust/tests/semantic_validation.rs` parses `generated.rs` with `syn`, reconstructs Rust-facing declarations and expression fingerprints, and compares them to `rust/target-validation.txt`.
- `rust/tests/target_interpreter.rs` executes selected Lean-generated target fingerprints and compares those interpreted results with compiled generated Rust functions.
- `scripts/gen.sh` and `scripts/check-extractor-snapshot.sh` now regenerate and diff the target-validation artifact.
- The validation report records the phase-3 target-IR translation-validation and target-fingerprint interpreter gates.

Remaining phase-3 hardening options:

- Add randomized/property differential generation over generated type shapes.
- Extend the target interpreter from selected fingerprints to the full generated target grammar, then replace the Rust test with a Lean theorem where practical.
- Emit stable machine-readable target validation JSON if downstream tooling needs structured ingestion.

## Phase 4 — optional raw ABI boundary exporter

Completed in this branch:

- `LeanRustCore.BoundaryExport` emits `rust/src/ffi_generated.rs` for a conservative primitive/result subset.
- Raw ABI wrappers are isolated under the Rust `ffi` feature and are not included in the default safe direct-emission lane.
- Primitive values cross directly; `Bool` crosses as `u32`.
- `Result<u32,u32>` lowers to `ChStatus` plus `out_ok` and `out_err` pointers.
- Default builds retain `unsafe_code` forbiddance; `cargo test --features ffi` exercises the optional boundary lane.

Future phase-4 expansion:

- C-compatible handles for owned structs/enums.
- Slice/string handle policy.
- Panic policy enforcement for boundary wrappers.
- Header generation and C integration tests.

## Sprint 13-14 - closure conversion and finite defunctionalization

Implemented in this patch:

- explicit closure environment structs for captured unary closures;
- finite function-family enums plus first-order apply functions;
- generated examples for closure environment application/mapping and defunctionalized UInt32 function cases;
- validation/proof report entries for the closure-conversion and defunctionalization policies.

Still future work:

- escaping stored closures;
- polymorphic closure objects;
- `FnMut`/`FnOnce` semantics;
- Rust trait-object or generic `Fn`-bound emission.

## Sprint 7-9 checkpoint - Std lowering, specialization, pure effects

This patch adds the Sprint 7-9 policy layer on top of the existing surface
subset:

- `LeanRustCore.StdLowering` records the monomorphic Std combinators lowered
  into owned safe Rust loops and matches.
- `LeanRustCore.TypeclassPolicy` records the resolved-dictionary specialization
  lane for common executable classes.
- `LeanRustCore.PureEffects` records the pure `do`-notation lane for
  `Option`, `Except`, `StateM`, and `ReaderT`; `IO` stays outside the default
  safe direct lane.

The new examples exercise additional `List`/`Array`/`Option`/`Except` APIs plus
Reader/State-shaped pure effects without introducing unsafe Rust in
`generated.rs`.
