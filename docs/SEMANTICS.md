# Complete generated-subset semantics

The generated-subset semantics covers every target grammar head emitted by the
current backend:

`literal`, `variable`, `let`, `if`, `match`, `loop`, `call`, `struct`, `enum`,
`box`, `deref`, `closure`, `dictionary`, and `effect`.

## Proved semantics

`LeanRustCore.IR.Denote` and `runtimeValueHasType` remain the proved semantic
carrier for the checked Rust-shaped IR. Primitive and ordinary container types
use direct Lean values, while generated structs, enums, and recursive payloads
use `RuntimeValue` subtype witnesses so aggregate denotations are no longer
placeholders.

## Tested semantics

`LeanRustCore.CompleteSemantics` now adds an executable compositional target
semantics layer for representative emitted constructs. The Lean examples and the
validator crate mirror each other for:

- struct construction
- enum construction and matching
- recursive tree construction and summation
- dependent `Fin` and `Vector` carriers
- closure capture and application
- dictionary-mediated `u32` addition
- pure `Option` and `Result` effect fragments
- boxed values, dereference, let/if, and builtin calls

`rust/tests/target_interpreter.rs` is the exhaustive executable layer for the
generated subset. It parses `rust/target-validation.txt`, generates sample
inputs for every emitted function, interprets every emitted fingerprint, and
compares the interpreted value with the compiled generated Rust function. The
current snapshot covers 126 emitted functions.

The executable fingerprint constructors covered by that exhaustive test are:

- `add`
- `array_push`
- `call`
- `call_value`
- `closure_apply`
- `compare`
- `default`
- `enum`
- `eq`
- `err`
- `field`
- `if`
- `let`
- `list_all`
- `list_any`
- `list_append`
- `list_filter`
- `list_find`
- `list_foldl`
- `list_foldr`
- `list_length`
- `list_map`
- `match_enum`
- `match_option`
- `match_pattern`
- `mul`
- `nat_fold`
- `none`
- `ok`
- `repr`
- `result_map_error`
- `some`
- `struct`
- `tail_rec_nat`
- `to_string`
- `var`

The supported executable value domain is:

- `()`
- `bool`
- `u32`
- `u64`
- `i32`
- `i64`
- `char`
- `String`
- `num_bigint::BigUint`
- `num_bigint::BigInt`
- `Vec<u32>`
- `Option<u32>`
- `Option<u64>`
- `Option<Step>`
- `Option<Option<u32>>`
- `Result<u32, u32>`
- `Result<u32, Option<u32>>`
- `Result<Option<u32>, u32>`
- `(u32, u32)`
- `Point`
- `Ordering`
- `Step`
- `Choice`
- `PairchoiceU32String`
- `PairboxU32String`
- `PairboxStringU32`
- `BoxedU32`
- `BoundedProof`
- `AddDeltaU32Env`
- `NestedpayloadU32String`
- `TaggedU32`
- `BinaryTreeU32`
- `ExprU32`
- `U32FnCase`
- `fn(u32) -> u32` arguments

Task 18 remains the representative Lean-side semantics milestone. Task 59 is
complete only when every emitted function is executable through this
fingerprint/value-domain interpreter and the remaining-completion gate enforces
that exhaustive test plus this constructor/domain list.
