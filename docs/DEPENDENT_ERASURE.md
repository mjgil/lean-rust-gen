# Dependent erasure

Dependent erasure is allowed only when erased evidence cannot change runtime
representation or when the emitted Rust performs an explicit check.

| Shape | Runtime representation | Completion rule |
|---|---|---|
| `Subtype p` | carrier value | proof erased, carrier kept |
| `Fin n` | `u32`/index value | bound proof erased, constructor/check emitted |
| `Vector α n` | `Vec<T>` | length proof erased, length check emitted |
| proof fields | omitted field | proof not used computationally |
| runtime `Sigma` | product/struct | both runtime components represented |
| dependent runtime match | rejected | diagnostic `LRC002` |

## Implementation requirements

`LeanRustCore.DependentErasureChecker` classifies every dependent shape as
runtime, proof-only, index-only, erased-with-check, or not-erasable before
emission.

## Tests required before completion

Positive tests must cover `Subtype`, `Fin`, `Vector`, proof-field structures, and
runtime `Sigma` policy cases. Negative tests must cover dependent matches whose
erased index changes branch shape.

## Documentation required before completion

Every admitted dependent shape must be documented here with its Rust runtime
representation and required checks.
