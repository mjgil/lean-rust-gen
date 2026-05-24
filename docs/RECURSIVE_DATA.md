# Recursive data

Recursive user data is completed through extractor-driven SCC discovery over
Lean constructor payloads. The default safe layout is owned `Box<T>` on
cycle-breaking edges. Sharing-heavy data may opt into safe `Rc<T>` or
arena-index layouts through explicit runtime policies.

## Implementation requirements

- `LeanRustCore.Extract.ctorRuntimePayloadFieldsWithParams` must derive direct,
  nested, and mutual SCC members from Lean inductive declarations instead of a
  fixed recursive fixture table.
- `LeanRustCore.RecursiveDiscovery.completedEdges` records direct recursion,
  nested recursion, and mutual recursion edges discovered for the supported
  fixture corpus.
- `LeanRustCore.RecursiveDiscovery.layoutDecisions` records layout selection
  for each SCC.
- Direct recursion and mutual recursion use owned `Box<T>` for cycle-breaking
  payload edges when no existing container indirection is present.
- Nested recursion through `List/Array/Vec` fields is accepted without adding
  another `Box<T>` because the container already provides the required runtime
  indirection.
- `Rc<T>` and arena modes are safe runtime policies and do not use raw pointers.

## Tests required before completion

Tests must cover direct recursive trees, expression ASTs, nested recursion,
mutual SCC policy, rejected recursive shapes, `Rc` shared tree helpers, arena
index validation, invalid arena indices, and recursive property seeds.

## Documentation required before completion

Every layout mode must be documented with ownership, performance, rejection
rules, and layout selection criteria before it may be marked complete.

## Accepted graph shapes

- Direct recursion: fields such as `BinaryTreeU32.left/right` and
  `ExprU32.left/right` lower through `Box<T>` because the recursive occurrence
  appears inline.
- Nested recursion: fields such as `RoseTreeU32.children : List RoseTreeU32`
  are accepted because `List/Array/Vec` provide the cycle-breaking allocation.
- Mutual recursion: SCCs such as `EvenNode <-> OddNode` are accepted when each
  member is index-free and cycle edges can be boxed safely.

## Layout selection

- `boxOwned` is the default layout selection for direct recursion and mutual
  recursion in the generated Rust lane.
- Nested recursion keeps the enclosing `List/Array/Vec` layout and only boxes
  a recursive occurrence when the path back into the SCC no longer has
  container indirection.
- `rcShared` and `arenaIndexed` remain explicit runtime-only choices for shared
  or index-based policies and are validated separately from generated Lean
  extraction.
