# Pattern matrix compiler

The pattern compiler lowers elaborated Lean recursors into safe Rust branch
code or rejects the construct with a stable diagnostic.

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
branch shape. Guard-shaped equation-compiler output is rejected with `LRC006`.

## Implementation requirements

`LeanRustCore.PatternMatrix.completedPatternFeatures` is the machine-readable
feature table. `SurfaceExpr.matchPattern` remains the checked Surface IR node
for Bool, Option, product, and closed-enum matches.

`List.nil` and `List.cons` lower from elaborated `List.casesOn` into first-order
surface code shaped like:

- `if list_length(xs) == 0 { ... } else { ... }`
- `list_head_clone(&xs)` for the head binder
- `list_tail_clone(&xs)` for the tail binder

`Nat.zero` and `Nat.succ` lower from elaborated `Nat.casesOn` into first-order
surface code shaped like:

- `if n == 0 { ... } else { let pred = n.wrapping_sub(1); ... }`

As-pattern metadata does not add a dedicated runtime node. When Lean’s equation
compiler preserves an alias, it appears as an ordinary branch-local `let`.
Inaccessible/proof patterns are erased earlier by dependent erasure, so the
runtime branch shape ignores them.

## Tests required before completion

Positive tests must cover Bool, Option, product, closed enum payloads, nested
constructors, `List.nil`/`List.cons`, `Nat.zero`/`Nat.succ`, and tree-like
recursive matches. Negative tests must cover non-erasable dependent matches and
guards.

## Documentation required before completion

Every admitted pattern class and every rejection class must be listed here with
the diagnostic code or emitted Rust shape.
