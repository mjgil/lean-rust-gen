import LeanRustCore.GenericEmission

namespace LeanRustCore.ParameterizedData

/-! Row 23 compatibility facade for parameterized data completion. -/

abbrev TypeVarSubstitution := LeanRustCore.GenericEmission.TypeSubstitution
abbrev MonomorphicInstance := LeanRustCore.GenericEmission.MonomorphizedDataShape

def substituteTypeVars (subs : List TypeVarSubstitution) (ty : RType) : RType :=
  LeanRustCore.GenericEmission.substituteType subs ty

def decideMonomorphicInstance (shape : LeanRustCore.GenericEmission.ParameterizedDataShape) (subs : List TypeVarSubstitution) : Except String MonomorphicInstance :=
  LeanRustCore.GenericEmission.monomorphizeDataShape shape subs

def acceptedParameterizedShapes : List String :=
  LeanRustCore.GenericEmission.acceptedParameterizedFixtures.map (fun fixture => fixture.leanName)

def rejectedDependentGenericShapes : List String :=
  LeanRustCore.GenericEmission.rejectedDependentParameterizedShapes

def parameterizedDataSummary : String :=
  "row 25 complete: parameterized data admits arbitrary eligible index-free structures/enums through concrete monomorphic instances with deterministic Rust names, including multi-parameter and nested shapes; dependent generic/indexed shapes remain explicitly rejected and documented"

end LeanRustCore.ParameterizedData
