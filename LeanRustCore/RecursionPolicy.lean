import LeanRustCore.Surface
import LeanRustCore.EmitRust

namespace LeanRustCore

/-!
A small recursion-policy analyzer for the generated first-order surface subset.

The default Lean→Rust lane permits first-order call cycles because Rust can
compile them and the SurfaceExpr evaluator is explicitly fuel-bounded.  Recognized
structural recursors (`List.map`, `List.foldl`, `List.length`, `Nat.rec`, and `tailRecNat` in the current
slice) are lowered into explicit loop-shaped `SurfaceExpr` nodes before emission.
This module keeps the policy visible for reports and for a stricter future gate
without making recursion a build blocker for the large-subset lane.
-/

private def containsString (needle : String) : List String → Bool
  | [] => false
  | x :: xs => x == needle || containsString needle xs

private def callsOf (f : SurfaceFun) : List String :=
  collectSurfaceCalls f.body

/-- A generated function is syntactically self-recursive if its body calls its own Rust-facing name. -/
def functionIsSelfRecursive (f : SurfaceFun) : Bool :=
  containsString f.name (callsOf f)

/-- Functions in a module that contain direct self calls. -/
def directSelfRecursiveFunctions (fns : List SurfaceFun) : List String :=
  fns.filterMap (fun f => if functionIsSelfRecursive f then some f.name else none)

/-- Human-readable summary included in validation reports. -/
def recursionPolicySummary : String :=
  "first-order generated call cycles are permitted in Rust emission; recognized List.map/List.foldl/List.length/Nat.rec/tailRecNat shapes lower to explicit SurfaceExpr loop nodes, and Lean-side SurfaceExpr differential evaluation remains bounded by explicit fuel"

end LeanRustCore
