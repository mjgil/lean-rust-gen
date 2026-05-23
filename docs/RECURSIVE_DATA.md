# Recursive data

Recursive user data is completed through an explicit type graph and layout
policy. The default layout is owned `Box<T>`. Sharing-heavy data may opt into
safe `Rc<T>` or arena-index layouts.

## Implementation requirements

- `LeanRustCore.RecursiveDiscovery.completedEdges` records direct, nested, and
  mutual recursion edges.
- `LeanRustCore.RecursiveDiscovery.layoutDecisions` records the selected layout
  for each SCC.
- `Box<T>` remains the default emitted layout for generated recursive enums.
- `Rc<T>` and arena modes are safe runtime policies and do not use raw pointers.

## Tests required before completion

Tests must cover direct recursive trees, expression ASTs, nested recursion,
mutual SCC policy, `Rc` shared tree helpers, arena index validation, invalid
arena indices, and recursive property seeds.

## Documentation required before completion

Every layout mode must be documented with ownership, performance, and rejection
rules before it may be marked complete.
