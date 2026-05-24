# Dependent erasure

Dependent erasure is allowed only when erased evidence cannot change runtime
representation or when the emitted Rust performs an explicit check.

| Shape | Runtime representation | Completion rule |
|---|---|---|
| `Subtype p` | carrier value | proof erased, carrier kept |
| equality cast | unchanged erased carrier | admitted only when erased source/target runtime representations match |
| `Fin n` | `u32`/index value | bound proof erased, constructor/check emitted |
| `Vector α n` | `Vec<T>` | length proof erased, length check emitted |
| proof fields | omitted field | proof not used computationally |
| nested proof fields | runtime field path only | every proof-only layer must erase without changing the remaining runtime layout |
| runtime `Sigma` | product/struct | admitted only when the codomain has an invariant erased runtime shape |
| invariant indexed family | carrier value | admitted only when every constructor erases to the same runtime carrier |
| dependent runtime match with invariant runtime shape | same runtime carrier in every branch | admitted by dedicated fixture policy when the erased branch layout is identical |
| dependent runtime match with changing runtime shape | rejected | diagnostic `LRC002` |

## Classification

`LeanRustCore.DependentErasureChecker` records every checked shape as one of:

- `runtime`: already a runtime-represented value with no erasure step required.
- `proofOnly`: proposition/evidence that disappears from the Rust-facing layout.
- `indexOnly`: source-only index data that does not survive as runtime storage.
- `erasedSafe`: erased to an existing carrier without a runtime check.
- `erasedWithCheck`: erased to a carrier only after an explicit bound/shape check.
- `notErasable`: rejected because erasure would change runtime behavior or layout.

## Implementation requirements

`LeanRustCore.DependentErasureChecker` classifies every dependent shape as
runtime, proof-only, index-only, erased-with-check, or not-erasable before
emission.

The current completed slice is exercised by exported fixtures in
`LeanRustCore.DependentErasureExamples`:

- `equality_cast_subtype_value_u32` proves equality casts erase when the runtime carrier stays `u32`.
- `sigma_runtime_pair_echo_u32` and `sigma_runtime_pair_sum_u32` prove `Sigma (fun _ : UInt32 => UInt32)` lowers to the runtime pair `(u32, u32)`.
- `flag_carrier_true_roundtrip_u32` and `flag_carrier_false_value_u32` prove the invariant indexed family `FlagCarrier` erases to the carrier `u32`.
- `flag_carrier_match_invariant_u32` proves a dependent match is admitted when every erased branch keeps the same runtime shape.
- `nested_proof_wrapper_value_u32` proves nested proof fields disappear while the runtime value path remains intact.

## Tests required before completion

Positive tests must cover `Subtype`, equality-cast erasure, `Fin`, `Vector`,
nested proof-field structures, runtime `Sigma`, invariant indexed families, and
dependent matches whose erased runtime shape stays invariant. Negative tests
must cover dependent matches whose erased index changes branch shape plus
non-erasable proof dependencies.

## Documentation required before completion

Every admitted dependent shape must be documented here with its Rust runtime
representation and required checks. The documentation must explicitly separate
proof/index/runtime classification and describe why each admitted shape keeps an
invariant runtime shape after erasure.
