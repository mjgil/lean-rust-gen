# Generics and parameterized data

The completed design-doc target is **monomorphization-only** for Rust-facing APIs.
Lean generic declarations may be exported only through concrete instantiations.
The extractor substitutes concrete `RType` arguments into index-free structures,
enums, functions, and helper calls before Rust emission.

## Implementation requirements

- `LeanRustCore.ParameterizedData.substituteTypeVars` substitutes every encoded
  type variable before emission.
- `LeanRustCore.ParameterizedData.decideMonomorphicInstance` rejects unresolved
  type variables.
- `LeanRustCore.GenericPolicy.finalRustGenericPolicySummary` records the final
  policy: do not emit Rust generics in this milestone.
- Generated Rust names for monomorphic instances must be deterministic.
- Unresolved typeclass dictionaries are rejected with `LRC001`.
- Requested Rust-generic emission is rejected with `LRC009`.

## Tests required before completion

A generic or parameterized-data feature is complete only when parser,
differential, target-validation, and unsupported-corpus tests cover it. Required
fixtures include explicit monomorphization, automatic monomorphization, duplicate
reuse, unsupported unresolved dictionaries, and unsupported Rust-generic emission.

## Documentation required before completion

This document and `docs/ARCHITECTURE.md` must identify the monomorphization-only
policy and must not imply that Rust trait-bound emission is supported.
