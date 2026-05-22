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

/-- Current sprint-15 recursive user-data fixtures. -/
def supportedRecursiveTypes : List RecursiveTypePolicy := [
  { lean_name := "LeanRustCore.Examples.BinaryTreeU32", rust_name := "BinaryTreeU32", layout := .boxOwned, constructors := ["leaf", "node"] },
  { lean_name := "LeanRustCore.Examples.ExprU32", rust_name := "ExprU32", layout := .boxOwned, constructors := ["lit", "add"] }
]

/-- Human-readable summary used by reports and docs. -/
def recursiveDataSummary : String :=
  "recursive index-free user inductives lower through owned Box<T> payload fields in the safe Rust lane; arena/Rc layouts and mutually recursive SCCs remain future work"

end LeanRustCore.RecursiveData
