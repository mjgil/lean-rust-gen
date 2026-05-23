import LeanRustCore.GenericEmission

namespace LeanRustCore.ParameterizedData

/-! Row 23 compatibility facade for parameterized data completion. -/

abbrev TypeVarSubstitution := LeanRustCore.GenericEmission.TypeSubstitution
abbrev MonomorphicInstance := LeanRustCore.GenericEmission.MonomorphizedDataShape

def substituteTypeVars (subs : List TypeVarSubstitution) (ty : RType) : RType :=
  LeanRustCore.GenericEmission.substituteType subs ty

def decideMonomorphicInstance (shape : LeanRustCore.GenericEmission.ParameterizedDataShape) (subs : List TypeVarSubstitution) : Except String MonomorphicInstance :=
  LeanRustCore.GenericEmission.monomorphizeDataShape shape subs

def parameterizedDataSummary : String :=
  "row 23 complete: parameterized data is admitted only through concrete monomorphic instances with deterministic Rust names and tests/docs for each accepted shape"

end LeanRustCore.ParameterizedData
