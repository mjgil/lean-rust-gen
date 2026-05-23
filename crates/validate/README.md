# lean-rust-core-validate

This crate contains validation helpers for generated artifacts: JSON parsing,
`syn`-based Rust summaries, and target-validation count parsing.

Each validator helper must have tests for valid and malformed inputs before it
can be used as a release gate.
