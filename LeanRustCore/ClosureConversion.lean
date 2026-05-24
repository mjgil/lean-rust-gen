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
  "captured unary and multi-argument lambdas lower through helper-normalized let chains, immediate application lowering, or explicit first-order environment structs; mutation-sensitive or ambient-effect closure classes remain rejected"

end LeanRustCore.ClosureConversion
