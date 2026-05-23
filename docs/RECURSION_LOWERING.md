# Recursion lowering

Recursive Lean definitions are classified before Rust emission. Lean totality is
a source assumption, but Rust stack behavior is still made explicit.

## Supported decisions

- nonrecursive direct emission
- direct tail recursion lowered to `while`
- structural recursion over `Nat`, `List`, arrays, and known recursive data
- mutual structural recursion with an SCC decision
- explicit heap-stack traversal for large tree-like traversals
- rejection of partial or non-structural recursion

## Implementation requirements

`LeanRustCore.RecursionAnalysis.decisions` records the recursion kind,
decreasing argument, stack policy, and Rust shape. `SurfaceExpr.tailRecNat` and
loop-shaped nodes handle the currently emitted functions.

## Tests required before completion

Tests must cover `List.length`, folds, `tail_sum_down_u32`, `nat_sum_to_u32`,
`gcd`/Nat-style loops, tree traversal, mutual SCC policy, and rejected partial
recursion.

## Documentation required before completion

Every accepted recursion kind must list its Rust stack policy. Rejected recursion
must cite the diagnostic used by the negative corpus.
