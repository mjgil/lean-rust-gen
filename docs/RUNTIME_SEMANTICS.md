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

## SurfaceExpr node meanings

Task 16 is complete only when every `SurfaceExpr` constructor is covered by
both `typeOfExpected` and `evalSurfaceExpr`. The repository now enforces that
with `LeanRustCore.SurfaceCoverage`, `rust/tests/first20_completion.rs`, and
`scripts/check-first-20-completion.py`.

| Family | Constructors | Meaning |
|---|---|---|
| Variables and literals | `var`, `litUnit`, `litBool`, `litNat`, `litInt`, `litU32`, `litU64`, `litI32`, `litI64`, `litChar`, `litString` | Read a checked local or embed a primitive runtime literal. |
| Control flow | `letIn`, `ite`, `matchBool`, `matchOption`, `matchEnum`, `matchPattern` | Evaluate a binding, branch on a boolean, or pattern-match over checked option/enum/general-pattern scrutinees. |
| Boolean and comparison operators | `not`, `and`, `or`, `eq`, `lt`, `le`, `gt`, `ge`, `compare` | Perform boolean logic, runtime equality, ordered comparisons, or produce `Ordering`. |
| Arithmetic | `add`, `sub`, `mul`, `min`, `max` | Execute the Rust-facing numeric mode already chosen by the checker for the embedded `RType`. |
| Sum/product constructors | `optionNone`, `optionSome`, `resultOk`, `resultErr`, `prodLit` | Build `Option`, `Result`, and pair runtime values after checking payload types. |
| Aggregate construction | `structLit`, `field`, `enumVariant` | Construct a checked struct or enum payload and project a struct field. |
| First-order calls | `call`, `callValue` | Call a generated first-order function by name, or represent a checked function-valued argument application that the evaluator intentionally rejects outside differential fixtures. |
| Box and closure nodes | `boxNew`, `boxDeref`, `closureApply` | Allocate/dereference owned boxed values and apply an explicitly closure-converted environment binder. |
| Dictionary-style semantic helpers | `defaultValue`, `toStringValue`, `reprValue` | Materialize a default inhabitant or the supported `ToString`/`Repr` rendering for a checked runtime value. |
| List combinators | `listMap`, `listFilter`, `listFoldl`, `listFoldr`, `listAny`, `listAll`, `listAppend`, `listFind`, `listLength` | Interpret owned-list structural loops and queries over the checked `List` carrier. |
| Array combinators | `arrayMap`, `arrayFoldl`, `arrayPush` | Interpret the admitted safe `Array` structural operations over owned element values. |
| Pure effect nodes | `optionMap`, `optionBind`, `resultMapOk`, `resultMapErr`, `resultBind` | Execute the pure `Option` and `Result` effect fragment used by recognized do-notation lowering. |
| Dependent-erasure and semantic nodes | `subtypeErase`, `subtypeVal`, `finCheck`, `finMk`, `finVal`, `vectorCheck`, `vectorErase`, `vectorMap` | Represent proof/index erasure and checked runtime carriers for `Subtype`, `Fin`, and `Vector`. |
| Structural recursion nodes | `natFold`, `tailRecNat` | Execute the admitted structural `Nat.rec` accumulator loop and tail-recursive countdown loop shapes. |
