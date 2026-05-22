import LeanRustCore.Surface

namespace LeanRustCore.StdLowering

/-!
Sprint 7–8 standard-library lowering table.

This module records the Lean/Std combinators that the extractor lowers to the
checked first-order surface subset.  The lowering itself lives in
`LeanRustCore.Extract` and `LeanRustCore.Surface`; this file keeps the supported
set machine-readable for reports and coverage dashboards.
-/

structure StdLowering where
  leanName : String
  feature : String
  rustShape : String
  deriving Repr, BEq

def lowerings : List StdLowering := [
  { leanName := "List.map", feature := "list-map-loop", rustShape := "Vec allocation plus for/push" },
  { leanName := "List.filter", feature := "list-filter-loop", rustShape := "Vec allocation plus predicate guard" },
  { leanName := "List.foldl", feature := "list-foldl-loop", rustShape := "mutable accumulator for loop" },
  { leanName := "List.foldr", feature := "list-foldr-loop", rustShape := "reverse iterator plus mutable accumulator" },
  { leanName := "List.any", feature := "list-any-loop", rustShape := "short-circuiting bool loop" },
  { leanName := "List.all", feature := "list-all-loop", rustShape := "short-circuiting bool loop" },
  { leanName := "Array.map", feature := "array-map-loop", rustShape := "Vec allocation plus for/push" },
  { leanName := "Array.foldl", feature := "array-foldl-loop", rustShape := "mutable accumulator for loop" },
  { leanName := "Option.map", feature := "option-map-match", rustShape := "match Option" },
  { leanName := "Option.bind", feature := "option-bind-match", rustShape := "match Option" },
  { leanName := "Except.map", feature := "result-map-match", rustShape := "match Result" },
  { leanName := "Except.bind", feature := "result-bind-match", rustShape := "match Result" },
  { leanName := "Option.getD", feature := "option-getd-match", rustShape := "match Option with fallback" },
  { leanName := "Except.mapError", feature := "result-map-error-match", rustShape := "match Result error branch" },
  { leanName := "Array.push", feature := "array-push-owned", rustShape := "owned Vec push" },
  { leanName := "String.append", feature := "string-append-owned", rustShape := "owned String append" }
]

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Compact summary for validation reports. -/
def stdLoweringSummary : String :=
  "Sprint 7–8 Std lowering table covers " ++ Nat.toString lowerings.length ++
  " monomorphic List/Array/Option/Except/String combinator families using owned safe Rust loops and matches"

/-- Feature names exported for coverage dashboards. -/
def featureNames : List String := lowerings.map (fun item => item.feature)

end LeanRustCore.StdLowering
