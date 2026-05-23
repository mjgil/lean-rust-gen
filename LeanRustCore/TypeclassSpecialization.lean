import LeanRustCore.TypeclassPolicy

namespace LeanRustCore.TypeclassSpecialization

/-! Row 40 completion metadata for resolved monomorphic typeclass specialization. -/

structure SpecializedClass where
  className : String
  lowering : String
  requiresResolvedDictionary : Bool
  tests : List String
  docs : List String
  deriving Repr, BEq

def classes : List SpecializedClass := [
  { className := "BEq", lowering := "eq SurfaceExpr", requiresResolvedDictionary := true, tests := ["generic_beq_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "DecidableEq", lowering := "eq/branch SurfaceExpr", requiresResolvedDictionary := true, tests := ["decidable_eq_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "Ord", lowering := "compare SurfaceExpr", requiresResolvedDictionary := true, tests := ["ord_compare_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "Inhabited", lowering := "defaultValue SurfaceExpr", requiresResolvedDictionary := true, tests := ["inhabited_default_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "ToString", lowering := "toStringValue SurfaceExpr", requiresResolvedDictionary := true, tests := ["to_string_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "Repr", lowering := "reprValue SurfaceExpr", requiresResolvedDictionary := true, tests := ["repr_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "Monad.Option", lowering := "match Option", requiresResolvedDictionary := true, tests := ["option_do_inc_u32"], docs := ["docs/TYPECLASSES.md"] },
  { className := "Monad.Except", lowering := "match Result", requiresResolvedDictionary := true, tests := ["except_do_inc_u32"], docs := ["docs/TYPECLASSES.md"] }
]

def typeclassSpecializationCompletionSummary : String :=
  "row 40 complete: resolved monomorphic dictionaries specialize to first-order SurfaceExpr lowerings; unresolved dictionaries remain rejected with stable diagnostics"

end LeanRustCore.TypeclassSpecialization
