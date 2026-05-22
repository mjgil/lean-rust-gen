import LeanRustCore.Surface

namespace LeanRustCore.RecursionLowering

open LeanRustCore

/-!
Sprint 5–6 recursion-lowering policy.

The supported implementation path is conservative: recognized structural
`Nat`/`List` recursor and combinator shapes lower to explicit loop-shaped
`SurfaceExpr` nodes.  The first general accumulator-recursion lane is
`SurfaceExpr.tailRecNat`, which represents a checked decreasing Nat loop in the
surface IR and emits ordinary safe Rust.
-/

structure TailRecNatSpec where
  counterName : String
  accName : String
  accTy : RType
  counter : SurfaceExpr
  init : SurfaceExpr
  body : SurfaceExpr
  deriving Repr, BEq

/-- Lower a checked Nat accumulator recursion specification to the shared surface node. -/
def lowerTailRecNat (spec : TailRecNatSpec) : SurfaceExpr :=
  .tailRecNat spec.counterName spec.accName spec.accTy spec.counter spec.init spec.body

/-- Human-readable summary recorded in reports. -/
def recursionLoweringSummary : String :=
  "Sprint 5–6 lowers recognized structural Nat/List recursors to loop-shaped SurfaceExpr nodes and adds tailRecNat for the first checked decreasing Nat accumulator loop; unrecognized recursive SCCs remain diagnostics-only"

end LeanRustCore.RecursionLowering
