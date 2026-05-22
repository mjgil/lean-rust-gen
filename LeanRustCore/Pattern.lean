import LeanRustCore.Surface

namespace LeanRustCore.Pattern

open LeanRustCore

/-!
Sprint 3–4 constructor-pattern compiler facade.

The canonical pattern representation now lives in `LeanRustCore.Surface` as
`SurfacePattern`; this module keeps the lowering policy and diagnostics visible
without introducing a second pattern syntax.  Extraction code lowers elaborated
recursor/casesOn output to `SurfaceExpr.matchPattern`, and the Surface checker
performs the exhaustiveness, binder, and branch-type validation before Rust
emission.
-/

/-- One compiled-pattern arm before lowering to the checked surface match node. -/
structure PatternArm where
  pattern : LeanRustCore.SurfacePattern
  body : SurfaceExpr
  deriving Repr, BEq

/-- Lower constructor-pattern arms into the checked SurfaceExpr pattern-match node. -/
def compileConstructorMatch (targetTy : RType) (target : SurfaceExpr) (arms : List PatternArm) : SurfaceExpr :=
  .matchPattern targetTy target (arms.map (fun arm => (arm.pattern, arm.body)))

/-- Human-readable summary included in generated validation/proof reports. -/
def patternCompilerSummary : String :=
  "Sprint 3–4 constructor-pattern compiler lowers elaborated Bool/Option/Prod/index-free-enum patterns into checked SurfaceExpr.matchPattern nodes; Surface.typeOfExpected validates exhaustiveness, binder uniqueness, and branch type consistency"

end LeanRustCore.Pattern
