import LeanRustCore.Surface

namespace LeanRustCore.Defunctionalization

/-!
Sprint 13–14 defunctionalization policy.

Known finite higher-order families are represented as ordinary Rust enums plus
first-order apply functions.  This keeps the direct lane safe and monomorphic:
no dynamic dispatch, trait objects, stored closures, or unsafe function pointers
are introduced.  Captured data becomes enum payloads or explicit closure
environment structs.
-/

/-- Finite function-family cases used by generated reports. -/
inductive DefunCaseShape where
  | noCapture : String → DefunCaseShape
  | captured : String → List RArg → DefunCaseShape
  deriving Repr, BEq

/-- Human-readable summary included in validation/proof reports. -/
def defunctionalizationSummary : String :=
  "known finite higher-order function families lower to monomorphic enum cases plus first-order apply functions; captured values become enum payloads or explicit closure environment fields"

end LeanRustCore.Defunctionalization
