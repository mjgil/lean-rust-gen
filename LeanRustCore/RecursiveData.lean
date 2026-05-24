import LeanRustCore.Surface
import LeanRustCore.EmitRust

namespace LeanRustCore.RecursiveData

/-!
Sprint 15 recursive-user-data policy.

The direct backend now has a conservative layout lane for known recursive,
index-free inductives. Recursive constructor fields are represented through
`Box<T>` in the Rust target shape, while the public function signatures keep the
ordinary Rust enum type. This keeps the default lane safe and first-order: there
is no arena, raw pointer, reference-counting, or unsafe self-reference policy in
this sprint.
-/

/-- The recursive payload layout selected for the current sprint. -/
inductive RecursiveLayout where
  | boxOwned
  deriving Repr, BEq, DecidableEq

/-- Metadata recorded for recursive user-data declarations admitted by this lane. -/
structure RecursiveTypePolicy where
  lean_name : String
  rust_name : String
  layout : RecursiveLayout
  constructors : List String
  deriving Repr, BEq

/-- Current recursive user-data fixtures accepted by the safe direct lane. -/
def supportedRecursiveTypes : List RecursiveTypePolicy := [
  { lean_name := "LeanRustCore.Examples.BinaryTreeU32", rust_name := "BinaryTreeU32", layout := .boxOwned, constructors := ["leaf", "node"] },
  { lean_name := "LeanRustCore.Examples.ExprU32", rust_name := "ExprU32", layout := .boxOwned, constructors := ["lit", "add"] },
  { lean_name := "LeanRustCore.Examples.RoseTreeU32", rust_name := "RoseTreeU32", layout := .boxOwned, constructors := ["node"] },
  { lean_name := "LeanRustCore.Examples.EvenNode", rust_name := "EvenNode", layout := .boxOwned, constructors := ["terminal", "step"] },
  { lean_name := "LeanRustCore.Examples.OddNode", rust_name := "OddNode", layout := .boxOwned, constructors := ["terminal", "step"] }
]

/-- Human-readable summary used by reports and docs. -/
def recursiveDataSummary : String :=
  "direct, nested, and mutual index-free recursive inductive SCCs lower from Lean declarations in the safe Rust lane; cycle-breaking payload edges use owned Box<T>, while List/Array/Vec fields satisfy the recursive indirection requirement without unsafe layouts"

end LeanRustCore.RecursiveData
