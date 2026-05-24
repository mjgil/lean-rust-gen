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

Task 18 is complete only when both the Lean representative evaluator and the
validator crate execute those cases and the release gates enforce the docs/tests
that separate the proved IR carrier from the tested target-semantics layer.
