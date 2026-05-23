# Pattern matrix compiler

The full pattern compiler lowers a checked Lean pattern matrix into safe Rust
`match` expressions or rejects the construct with a stable diagnostic.

## Supported pattern classes

- wildcard and variable patterns
- constructor patterns
- nested tuple/product patterns
- `List.nil` and `List.cons`
- `Nat.zero` and `Nat.succ`
- as-pattern metadata
- inaccessible/proof patterns when erased safely

Pattern guards are rejected in this milestone. Dependent patterns are admitted
only when dependent erasure proves that the erased index cannot affect runtime
branch shape.

## Implementation requirements

`LeanRustCore.PatternMatrix.completedPatternFeatures` is the machine-readable
feature table. `SurfaceExpr.matchPattern` remains the checked Surface IR node.

## Tests required before completion

Positive tests must cover Bool, Option, product, closed enum payloads, nested
constructors, List, Nat, and tree-like recursive matches. Negative tests must
cover non-erasable dependent matches and guards.

## Documentation required before completion

Every admitted pattern class and every rejection class must be listed here with
the diagnostic code or emitted Rust shape.
