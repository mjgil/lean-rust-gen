# lean-rust-core-runtime

This crate contains safe runtime helpers shared by generated Lean→Rust output.
It is intentionally separate from `lean-rust-core-generated` so numeric modes,
container helpers, typeclass dictionaries, pure-effect helpers, and closure
objects can be tested and documented independently.

A helper is not considered complete until it has unit/property tests in this
crate and documentation in `docs/CRATE_DESIGN.md` or the feature-specific docs.
