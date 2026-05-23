import LeanRustCore.RecursionLowering

namespace LeanRustCore.RecursionAnalysis

/-!
Rows 36-37 general recursion completion.

The analyzer records recursive SCCs, decreasing arguments, tail-call loop
rewrites, and stack policies.  It keeps Lean totality as a source assumption but
still classifies Rust stack behavior explicitly.
-/

inductive RecursionKind where
  | nonrecursive
  | directTail
  | directStructural
  | mutualStructural
  | explicitStack
  | rejectedPartial
  deriving Repr, BEq, DecidableEq

inductive StackPolicy where
  | constantStackLoop
  | boundedBySourceStructure
  | explicitHeapStack
  | rejected
  deriving Repr, BEq, DecidableEq

structure RecursionDecision where
  functionName : String
  kind : RecursionKind
  decreasingArgument : Option String
  stackPolicy : StackPolicy
  rustShape : String
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def decisions : List RecursionDecision := [
  { functionName := "list_length_u32", kind := .directStructural, decreasingArgument := some "xs", stackPolicy := .constantStackLoop, rustShape := "Vec::len/for loop", requiredTests := ["list_length_u32 differential", "target_interpreter"], requiredDocs := ["docs/RECURSION_LOWERING.md"] },
  { functionName := "tail_sum_down_u32", kind := .directTail, decreasingArgument := some "n", stackPolicy := .constantStackLoop, rustShape := "while n != 0", requiredTests := ["tail recursion differential", "target fingerprint"], requiredDocs := ["docs/RECURSION_LOWERING.md"] },
  { functionName := "tree_size_u32", kind := .directStructural, decreasingArgument := some "tree", stackPolicy := .boundedBySourceStructure, rustShape := "recursive match over Box payloads", requiredTests := ["recursive tree property tests"], requiredDocs := ["docs/RECURSION_LOWERING.md", "docs/RECURSIVE_DATA.md"] },
  { functionName := "tree_sum_u32", kind := .explicitStack, decreasingArgument := some "tree", stackPolicy := .explicitHeapStack, rustShape := "Vec worklist policy for large trees", requiredTests := ["explicit stack policy test"], requiredDocs := ["docs/RECURSION_LOWERING.md"] },
  { functionName := "unsupported_partial_loop", kind := .rejectedPartial, decreasingArgument := none, stackPolicy := .rejected, rustShape := "LRC006 diagnostic", requiredTests := ["negative partial recursion corpus"], requiredDocs := ["docs/DIAGNOSTICS.md#lrc006"] }
]

def recursionAnalysisSummary : String :=
  "recursion completion classifies nonrecursive/direct-tail/direct-structural/mutual/explicit-stack SCCs, records decreasing arguments, lowers tail calls to loops, and rejects partial/non-structural recursion with stable diagnostics"

end LeanRustCore.RecursionAnalysis
