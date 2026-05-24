import LeanRustCore.DependentErasure

namespace LeanRustCore.DependentErasureChecker

/-! Row 30 compatibility facade for completed dependent erasure. -/

abbrev RuntimeRelevance := LeanRustCore.DependentErasure.RuntimeRelevance
abbrev ErasureDecision := LeanRustCore.DependentErasure.ErasureDecision

def checkDependentErasure (source : String) (ty : RType) : ErasureDecision :=
  LeanRustCore.DependentErasure.checkDependentErasure source ty

def dependentErasureCheckerSummary : String :=
  LeanRustCore.DependentErasure.dependentErasureSummary

end LeanRustCore.DependentErasureChecker
