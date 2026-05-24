# Numeric semantics

Numeric lowering is explicit. Exact mathematical `Nat`/`Int` use BigUint/BigInt.
Fixed-width integers use one of four modes: wrapping, checked, saturating, or
preconditioned.

| Source shape | Rust shape | Mode | Completion requirement |
|---|---|---|---|
| `Nat` | `num_bigint::BigUint` | exact | BigUint add/mul/sub tests and docs |
| `Int` | `num_bigint::BigInt` | exact | BigInt add/mul tests and docs |
| `UInt32` arithmetic | `u32` | wrapping | boundary tests such as `u32::MAX + 1` |
| `UInt32` checked ops | `Option<u32>` | checked | overflow and division-by-zero tests |
| `UInt32` saturating ops | `u32` | saturating | max/min clamp tests |
| casts | `Option<T>` | checked | overflow tests |
| division/modulus | `Result`/`Option` | preconditioned or checked | zero-denominator diagnostics/tests |

## Implementation requirements

- Numeric rules live in `LeanRustCore.NumericSemantics.rules`.
- Exported generated examples live in `LeanRustCore.NumericExamples`.
- Runtime helpers live in `lean-rust-core-runtime`.
- Casts and division/modulus must never be silently emitted without an explicit
  checked or preconditioned rule.

## Generated examples required before completion

- `checked_add_u32`, `checked_sub_u32`, `checked_div_u32`, and `checked_mod_u32`
  must reach checked-in `rust/src/generated.rs` and `rust/target-validation.txt`.
- `saturating_add_u32` and `saturating_sub_u32` must prove overflow and
  underflow clamping in generated crate tests.
- `preconditioned_div_u32` and `preconditioned_mod_u32` must return
  `Result<u32, String>` and preserve `division-by-zero` / `modulus-by-zero`
  errors through generated Rust.
- `checked_cast_u64_to_u32` must prove cast overflow at the generated boundary.

## Tests required before completion

Runtime tests must cover zero, one, maximum values, signed minimum/maximum,
overflow, underflow, division by zero, modulus by zero, exact big integer values,
and cast overflow.

## Documentation required before completion

Every numeric mode admitted by the extractor must be listed here and in the
coverage dashboard before it can be marked complete.
