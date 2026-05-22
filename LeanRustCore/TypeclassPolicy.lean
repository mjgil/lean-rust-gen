import LeanRustCore.Surface

namespace LeanRustCore.TypeclassPolicy

/-!
Sprint 7–9 typeclass-specialization policy.

The direct safe-Rust lane specializes resolved, monomorphic class dictionaries
into explicit `SurfaceExpr` nodes before emission.  This keeps generated Rust
first-order and avoids Rust trait/dynamic-dispatch obligations in the default
lane.  Unresolved dictionaries remain rejected with diagnostics.
-/

/-- Typeclass families currently handled by specialization rather than dictionary emission. -/
def specializedClasses : List String := [
  "BEq", "Decidable", "DecidableEq", "Ord", "LT", "LE",
  "HAdd", "HSub", "HMul", "OfNat", "Inhabited", "ToString", "Repr",
  "Functor.Option", "Functor.Except", "Applicative.Option", "Applicative.Except",
  "Monad.Option", "Monad.Except"
]

/-- Future class families recognized by the policy but still requiring explicit lowering work. -/
def futureDictionaryClasses : List String := [
  "Hashable", "Monad.State", "Monad.Reader", "Monad.IO", "Coe", "CoeTail"
]

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Human-readable policy summary recorded in validation/proof reports. -/
def typeclassPolicySummary : String :=
  "resolved monomorphic dictionaries for " ++ joinWithLocal ", " specializedClasses ++
  " specialize into first-order SurfaceExpr nodes; unresolved dictionaries and runtime dictionary passing remain rejected"

end LeanRustCore.TypeclassPolicy
