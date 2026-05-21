# Practical largest Lean → Rust subset plan

The practical largest direct source backend is a proof-erased, monomorphized,
computable Lean subset that emits ordinary safe Rust for the default lane and
keeps any raw ABI wrappers in a separate feature-gated boundary lane.

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

Still future work for a larger phase 2+:

- Closure conversion for captured lambdas.
- Defunctionalization for known higher-order functions.
- Generated typeclass dictionaries or aggressive typeclass instance inlining.
- Exact `Nat`/`Int` backends in addition to explicit fixed-width/wrapping modes.

## Phase 3 — semantic validation and release hardening

Completed in this branch:

- `LeanRustCore.TargetValidation` emits a Lean-side target-validation snapshot from the checked extractor-owned `SurfaceFun` list.
- `rust/tests/semantic_validation.rs` parses `generated.rs` with `syn`, reconstructs Rust-facing declarations and expression fingerprints, and compares them to `rust/target-validation.txt`.
- `scripts/gen.sh` and `scripts/check-extractor-snapshot.sh` now regenerate and diff the target-validation artifact.
- The validation report records the phase-3 target-IR translation-validation gate.

Remaining phase-3 hardening options:

- Add randomized/property differential generation over generated type shapes.
- Add a target semantics theorem for the reconstructed Rust subset rather than only fingerprint equality.
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
