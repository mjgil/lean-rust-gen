import LeanRustCore.Pattern

namespace LeanRustCore.PatternMatrix

/-!
Rows 34-35 pattern compiler completion.

The checked `SurfacePattern` fragment is backed by a pattern-matrix policy that
records nested constructor coverage, list/Nat patterns, as-patterns,
inaccessible/proof patterns, and dependent erasure rejection.  Guards are
rejected because they are not part of the safe first-order pattern grammar.
-/

inductive PatternClass where
  | wildcard
  | variable
  | constructor
  | tuple
  | listNil
  | listCons
  | natZero
  | natSucc
  | asPattern
  | inaccessibleProof
  | guardedRejected
  deriving Repr, BEq, DecidableEq

structure PatternMatrixRow where
  classes : List PatternClass
  resultType : RType
  branchName : String
  deriving Repr, BEq

inductive PatternCompileDecision where
  | emitRustMatch
  | eraseProofPattern
  | rejectDependentRuntimeShape
  | rejectGuard
  deriving Repr, BEq, DecidableEq

structure PatternFeature where
  name : String
  decision : PatternCompileDecision
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def completedPatternFeatures : List PatternFeature := [
  { name := "Bool/Option/Product/enum constructor patterns", decision := .emitRustMatch, requiredTests := ["general_bool_match_u32", "general_option_match_u32", "pair_sum_match_u32"], requiredDocs := ["docs/PATTERN_COMPILER.md"] },
  { name := "nested tuple and constructor patterns", decision := .emitRustMatch, requiredTests := ["general_step_match_u32", "recursive_even_odd.expected.json"], requiredDocs := ["docs/PATTERN_COMPILER.md"] },
  { name := "List.nil/List.cons patterns", decision := .emitRustMatch, requiredTests := ["list_head_or_zero_u32", "list_second_or_zero_u32"], requiredDocs := ["docs/PATTERN_COMPILER.md"] },
  { name := "Nat.zero/Nat.succ patterns", decision := .emitRustMatch, requiredTests := ["nat_pred_or_zero_u32", "nat_two_step_or_zero_u32"], requiredDocs := ["docs/PATTERN_COMPILER.md"] },
  { name := "inaccessible proof patterns", decision := .eraseProofPattern, requiredTests := ["dependent erasure negative/positive corpus"], requiredDocs := ["docs/PATTERN_COMPILER.md", "docs/DEPENDENT_ERASURE.md"] },
  { name := "dependent runtime-index pattern", decision := .rejectDependentRuntimeShape, requiredTests := ["LRC002 negative corpus"], requiredDocs := ["docs/DIAGNOSTICS.md#lrc002"] },
  { name := "pattern guard", decision := .rejectGuard, requiredTests := ["recursor_shape.expected.json"], requiredDocs := ["docs/PATTERN_COMPILER.md", "docs/DIAGNOSTICS.md#lrc006"] }
]

def rowIsComplete (row : PatternMatrixRow) : Bool :=
  row.classes.all (fun cls => cls != .guardedRejected)

def patternMatrixSummary : String :=
  "pattern-matrix completion covers nested constructors, tuple/product, List nil/cons lowered through list head/tail helpers, Nat zero/succ lowered through predecessor lets, as-pattern metadata, proof-pattern erasure, and rejects guarded or non-erasable dependent runtime patterns"

end LeanRustCore.PatternMatrix
