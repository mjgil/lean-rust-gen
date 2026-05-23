# Complete generated-subset semantics

The generated-subset semantics covers every target grammar head emitted by the
current backend:

`literal`, `variable`, `let`, `if`, `match`, `loop`, `call`, `struct`, `enum`,
`box`, `deref`, `closure`, `dictionary`, and `effect`.

The Lean metadata module `LeanRustCore.CompleteSemantics` records interpreter,
test, and documentation ownership for each head. The Rust validator crate mirrors
this with `TargetTerm`, `TargetValue`, and `eval_target_term` tests. A target
head cannot be marked complete without implementation, tests, and docs.
