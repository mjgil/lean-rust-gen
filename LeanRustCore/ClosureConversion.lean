import LeanRustCore.Surface

namespace LeanRustCore.ClosureConversion

/-!
Closure-conversion policy for the current direct backend.

Captured unary lambdas that are applied immediately are lowered to
`SurfaceExpr.closureApply`, which binds the argument explicitly and evaluates the
body in the surrounding environment. This covers local captured lambdas outside
recognized structural combinators without introducing Rust `unsafe` or dynamic
dispatch. Escaping/stored captured closures and arbitrary higher-order closure
arguments remain outside this phase.
-/

/-- Human-readable policy string recorded in generated validation/proof reports. -/
def closureConversionSummary : String :=
  "captured unary lambdas outside recognized structural combinators lower to explicit closure-apply SurfaceExpr nodes; escaping or stored captured closures remain rejected"

end LeanRustCore.ClosureConversion
