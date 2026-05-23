# Runtime semantics

`LeanRustCore.IR.Denote` gives the proof/evaluator side of the Rust-shaped IR a
Lean meaning. The first-20 completion checkpoint removes the old placeholder
semantics for generated aggregates.

## Aggregate semantics

Primitive and ordinary container types use direct Lean values:

| `RType` family | Denotation |
|---|---|
| `Unit`, `Bool`, `Ordering`, fixed integers, exact `Nat`/`Int`, `Char`, `String` | Lean primitive values |
| `Option`, `Except`, `List`, `Array`, `Prod`, `Sum`, function types | Corresponding Lean type constructors |
| `Subtype`, `Fin`, `Vector` | Runtime carrier values with the dependent proof/index erased or checked by the dependent-erasure policy |

Generated structs, enums, and named recursive payloads use
`RuntimeValue` subtype witnesses:

RuntimeValue subtype witnesses are the concrete completion rule for generated
aggregate denotations.

```lean
{ value : RuntimeValue // runtimeValueHasType value ty = true }
```

That means a generated struct is checked field-by-field, a generated enum is
checked by constructor payload, and a recursive payload records the expected
recursive type name. These cases no longer collapse to `Unit` or arbitrary `Nat`.

## Testing requirement

Every new `RType` constructor must have tests that cover:

1. Surface typechecking/evaluation when the constructor appears in expressions;
2. target-validation fingerprints when the constructor appears in emitted Rust;
3. `runtimeValueHasType` coverage for aggregate runtime values; and
4. documentation of any abstraction boundary that remains.
