# Recursion lowering

Recursive Lean definitions are classified before Rust emission. Lean totality is
still assumed at the source level, but the emitted Rust stack policy is tracked
explicitly in `LeanRustCore.RecursionAnalysis.decisions`.

## Supported decisions

- nonrecursive direct emission
- direct tail recursion lowered to `while` for Nat accumulator loops such as
  `tail_sum_down_u32` and `nat_sum_to_u32`
- direct decreasing recursion over a checked measure, currently including the
  subtraction-based `gcd_u32` lane
- structural recursion over `List` and known recursive data, including
  `reverse_accum_u32`, `tree_size_u32`, and `tree_sum_u32`
- mutual structural recursion with an SCC decision, currently
  `mutual_even_u32` and `mutual_odd_u32`
- explicit heap-stack traversal for tree walks that should not consume Rust call
  stack depth, currently `tree_sum_worklist_u32`
- rejection of partial or non-structural recursion with `LRC006`

## Implementation requirements

`LeanRustCore.RecursionAnalysis.decisions` records the recursion kind,
decreasing argument, stack policy, Rust shape, and required tests/docs.
`LeanRustCore.RecursionExamples` holds the source implementations, while
`LeanRustCore.Examples` re-exports the checked generated fixtures for
`gcd_u32`, `reverse_accum_u32`, `mutual_even_u32`, and `mutual_odd_u32`. The
extractor lowers those declarations through checked `SurfaceExpr.call`
recursion, while the explicit heap stack lane routes `tree_sum_worklist_u32` through
`rust/src/recursion_helpers.rs`. List-accumulator rebuilding uses the owned
runtime helper `list_prepend_u32`.

## Tests required before completion

Tests must cover `List.length`, `tail_sum_down_u32`, `nat_sum_to_u32`,
`gcd_u32`, `reverse_accum_u32`, `mutual_even_u32`, `mutual_odd_u32`,
`tree_sum_worklist_u32`, and the `corpus/unsupported/recursor_shape.expected.json`
`LRC006` rejection lane. The generated crate, target interpreter, corpus
fixtures, and `scripts/check-next-20-completion.py` all participate in the
release gate.

## Documentation required before completion

Every accepted recursion kind must list its Rust stack policy and representative
generated examples. Rejected recursion must cite `LRC006` and explain which
non-structural or partial forms remain outside the admitted subset.
