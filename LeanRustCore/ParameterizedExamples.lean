import LeanRustCore.Extract

namespace LeanRustCore.ParameterizedExamples

open LeanRustCore

/-!
Additional Task 25 examples for generalized parameterized-data discovery.

These declarations stay inside the current safe direct-emission subset while
covering:

- multi-parameter structures
- multi-parameter enums
- nested parameterized payloads built from `Option` and `Except`

Dependent generic shapes remain intentionally rejected outside this module and
are covered by the unsupported corpus/docs.
-/

structure PairBox (α β : Type) where
  left : α
  right : β

inductive PairChoice (α β : Type) where
  | left (value : α)
  | right (value : β)

structure NestedPayload (α β : Type) where
  primary : Option α
  secondary : Except β α

end LeanRustCore.ParameterizedExamples
