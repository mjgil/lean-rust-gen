# ExtractIR

`LeanRustCore.ExtractIR` is the explicit pre-`SurfaceExpr` stage for the direct
Lean-to-Rust backend. It does not replace the checked executable `SurfaceExpr`;
it records the facts that must be available before a declaration is allowed to
emit Rust.

## Required data per declaration

Each declaration metadata record contains:

| Field | Requirement |
|---|---|
| `source` | Fully-qualified Lean declaration when available. |
| `rustName` | Rust-facing symbol after hygiene. |
| `sourceSpan` | `SourceSpan` with file/range when Lean metadata provides it, or a stable unknown-span fallback. |
| `status` | `supported` or a stable diagnostic/rejection status. |
| `erasedBinderCount` | Count of proof/index binders erased before Rust emission. |
| `features` | Stable feature tags, such as `primitive`, `std-lowering`, or `dependent-erasure`. |
| `recognizedRecursors` | Recursor/equation-compiler shapes recognized before they lower to Surface IR. |
| `dictionaries` | Resolved typeclass dictionary metadata before specialization, erasure, or rejection. |
| `nextFeature` | The implementation feature needed for rejected declarations. |

## Lowering rule

Every supported declaration is first normalized into an `ExtractDecl` record:

| Field | Requirement |
|---|---|
| `source` | Lean declaration name used for reports and diagnostics. |
| `rustName` | Final Rust-facing symbol that will be emitted if lowering succeeds. |
| `args` | Rust-facing checked argument list. |
| `ret` | Rust-facing checked return type. |
| `body` | Mandatory pre-surface `ExtractExpr` tree. |

`lowerDecl?` is the only supported path from `ExtractDecl` to `SurfaceFun`.
Only `ExtractExpr.surface` may enter the Rust emitter. The
`lowerExpr?` check is intentionally conservative: recognized recursors,
unresolved dictionary arguments, policy-only Std-lowering placeholders, and
explicit rejected nodes must be discharged to a checked `SurfaceExpr` or turned
into a diagnostic first.

## Lowering obligations per node

| `ExtractExpr` node | Obligation before Rust emission |
|---|---|
| `surface expr` | May lower directly through `lowerExpr?`. |
| `erasedBinder name ty body` | Must lower by discarding the erased binder wrapper and continuing with `body`. |
| `recognizedRecursor family args` | Must be discharged to executable `SurfaceExpr`; reaching `lowerExpr?` is a failure. |
| `recognizedStdLowering family args` | Must be discharged to executable `SurfaceExpr`; reaching `lowerExpr?` is a failure. |
| `dictionaryArgument cls inst` | Must be specialized or rejected before Rust emission. |
| `rejected code detail` | Must stay a diagnostic and may not emit Rust. |

## Golden snapshot

`scripts/gen.sh` generates `rust/extract-ir.txt` from the same
extractor-owned declaration list that later feeds Rust emission. The snapshot is
checked by `scripts/check-extractor-snapshot.sh`, validated by
`scripts/check-artifact-consistency.py`, and compared against the generated Rust
function order in `rust/tests/first20_completion.rs`.

## Completion rule

A new extraction feature is not complete until it has:

1. a concrete `ExtractIR` representation or explicit rejection path;
2. a positive or negative corpus fixture;
3. a generated validation/proof-report entry;
4. Rust or Lean tests covering the emitted or rejected shape; and
5. documentation in this file or a feature-specific document.
