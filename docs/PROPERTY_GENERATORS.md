# Property generators

Deterministic seeds are still mandatory in CI, but Task 64 now requires real
seeded randomized generators and shrinkers in the Rust crates. Optional nightly
fuzzing may expand these generators, but fuzz-only coverage is not accepted as a
completion criterion.

Families:

| Family | Minimization policy |
|---|---|
| base scalars | smallest numeric counterexample |
| containers | shortest collection, then smallest elements |
| recursive data | minimum tree/expression depth |
| closures and dictionaries | smallest closure/dictionary tag |
| target grammar | smallest target term depth |
| FFI handles | shortest handle lifecycle trace |

## Algorithms

- Base scalars: `runtime::generate_runtime_value_cases` uses a stable xorshift
  PRNG and shrinks by `0`, `1`, halving, then predecessor.
- Containers: vector generators use the same PRNG with bounded lengths and
  shrink by empty vector, half-length prefix, then element shrink on the head.
- Recursive data: tree generators are depth-bounded and shrink toward `Leaf`,
  then toward subtrees, so counterexamples minimize by structure depth first.
- Closures and dictionaries: generated `(delta, lhs, rhs)` cases shrink numeric
  payloads before changing the closure/dictionary shape.
- Target grammar: `validate::generate_target_term_cases` alternates through the
  supported target heads and shrinks toward subterms, literals, and shallower
  vectors/recursive nodes.
- FFI handles: `abi::generate_handle_traces` creates handle lifecycle traces and
  shrinks by shortening the trace, then reducing payload operations.

## CI and shrinking

- CI uses deterministic seeds to keep failures reproducible.
- Shrinkers are part of the contract: every generator family must provide a
  minimization path, not only random sampling.
- The remaining-completion gate checks for the generator, shrink, and minimizer
  APIs in `runtime`, `validate`, and `abi`.

Every generator family must have stable seeds, tests, documentation, and a
minimization policy.
