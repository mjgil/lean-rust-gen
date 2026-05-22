import LeanRustCore.Surface

namespace LeanRustCore.ClosureConversion

/-!
Closure-conversion policy for the current direct backend.

Captured unary lambdas that are applied immediately still lower to
`SurfaceExpr.closureApply`. Sprints 13-14 add the next representation: captured
values can be made explicit as first-order environment structs, and known finite
higher-order families may be defunctionalized into enum cases plus apply
functions. Escaping/stored dynamic closures remain outside this phase.
-/

/-- Runtime representation summary for a closure environment accepted by this lane. -/
structure ClosureEnvironmentShape where
  name : String
  fields : List RArg
  deriving Repr, BEq

/-- Human-readable policy string recorded in generated validation/proof reports. -/
def closureConversionSummary : String :=
  "captured unary lambdas lower either to immediate closure-apply SurfaceExpr nodes or to explicit first-order environment structs; escaping or stored dynamic closures remain rejected"

end LeanRustCore.ClosureConversion
