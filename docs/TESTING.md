# Testing and property corpus

Every feature must have implementation tests before it is marked complete. The
minimum is a deterministic test that runs in CI plus documentation for what the
seed covers. Optional fuzzing may expand coverage, but fuzz-only coverage is not
a completion criterion.

## Numeric edge cases

Numeric helpers must test zero, one, maximum values, overflow, underflow,
division by zero, exact integer values, checked modes, saturating modes, and
preconditioned modes. Runtime tests live in `crates/runtime` and generated-lane
regression tests live in `rust/tests`.

## Container roundtrip

List, Array, String, Option, Except, struct, enum, and recursive data helpers
must have empty, singleton, multi-item, and boundary-value seeds.

## Closure and dictionary

Closure-object and dictionary tests must cover no-capture, captured, composed,
returned, stored, equality, comparison, and rejected unresolved cases.

## FFI handle lifecycle

The ABI lane must test handle creation, use, destructor, double-drop rejection,
null out-parameters, and status-code lowering. Raw native Rust containers must
not cross the C ABI directly.

## Generated subset target grammar

Semantic validation must cover every emitted target grammar head with at least
one deterministic seed, and must document unsupported grammar heads.
