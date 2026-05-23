# lean-rust-core-validate

This crate contains validation helpers for generated artifacts: strict typed
JSON report schemas, `syn`-based Rust summaries, and target-validation count
parsing.

Each validator helper must have tests for valid and malformed inputs before it
can be used as a release gate.

## Target semantics

The validator crate includes `TargetTerm`, `TargetValue`, and `eval_target_term`
for the completed generated-subset semantics lane. Every target grammar head
must be represented in `target_grammar_heads()` before the coverage dashboard can
mark semantics complete.
