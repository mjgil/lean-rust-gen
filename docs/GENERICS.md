# Generics and parameterized data

The completed design-doc target is **monomorphization-only** for Rust-facing APIs.
Lean generic declarations may be exported only through concrete instantiations.
The extractor substitutes concrete `RType` arguments into index-free structures,
enums, functions, and helper calls before Rust emission.

Accepted parameterized-data shapes include:

- multi-parameter index-free structures such as `PairBox UInt32 String`
- multi-parameter index-free enums such as `PairChoice UInt32 String`
- nested index-free payload shapes such as `NestedPayload UInt32 String`, where
  generic fields recurse only through admitted containers like `Option α` and
  `Except β α`

Rejected shapes remain explicit:

- dependent generic or indexed families such as `Vector α n`
- `Sigma`-style payloads whose runtime layout depends on indices or proofs
- any parameterized declaration whose runtime representation changes with a
  non-erasable proposition or index

## Implementation requirements

- `LeanRustCore.ParameterizedData.substituteTypeVars` substitutes every encoded
  type variable before emission.
- `LeanRustCore.ParameterizedData.decideMonomorphicInstance` rejects unresolved
  type variables.
- `LeanRustCore.GenericEmission.acceptedParameterizedFixtures` records the
  accepted multi-parameter and nested fixtures used by the release gates.
- `LeanRustCore.ParameterizedData.rejectedDependentGenericShapes` records the
  dependent generic/indexed families that stay outside the direct lane.
- `LeanRustCore.GenericPolicy.finalRustGenericPolicySummary` records the final
  policy: do not emit Rust generics in this milestone.
- Generated Rust names for monomorphic instances must be deterministic.
- Unresolved typeclass dictionaries are rejected with `LRC001`.
- Unsupported dependent generic/indexed shapes are documented through `LRC008`.
- Requested Rust-generic emission is exposed to users as `LRC013`; the older
  `GenericPolicy.LRC009` constant remains only as compatibility metadata for the
  existing next-20 facade.

## Tests required before completion

A generic or parameterized-data feature is complete only when parser,
differential, target-validation, and unsupported-corpus tests cover it. Required
fixtures include explicit monomorphization, automatic monomorphization, duplicate
reuse, multi-parameter structures/enums, nested payload shapes, unsupported
unresolved dictionaries, rejected dependent generic shapes, and unsupported Rust-generic emission.

## Documentation required before completion

This document and `docs/ARCHITECTURE.md` must identify the monomorphization-only
policy and must not imply that Rust trait-bound emission is supported.
