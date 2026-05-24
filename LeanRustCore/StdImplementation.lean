import LeanRustCore.StdLowering

namespace LeanRustCore.StdImplementation

/-!
Rows 38-39 standard-library lowering completion.

The registry is completed by an implementation table.  Every Lean/Std constant
listed here has an owned safe-Rust shape, required tests, and required docs.  The
extractor may only mark a constant supported when its row is present in this
table and its tests/docs exist.
-/

inductive OwnershipShape where
  | owned
  | borrowedReadOnly
  | cloned
  | returnedNewValue
  deriving Repr, BEq, DecidableEq

structure ImplementedLowering where
  leanName : String
  rustShape : String
  ownership : OwnershipShape
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def lowerings : List ImplementedLowering := [
  { leanName := "List.map", rustShape := "Vec allocation plus for/push", ownership := .returnedNewValue, requiredTests := ["list_map_inc_u32", "property container seeds"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.filter", rustShape := "Vec allocation plus predicate guard", ownership := .returnedNewValue, requiredTests := ["list_filter_nonzero_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.foldl", rustShape := "mutable accumulator for loop", ownership := .owned, requiredTests := ["list_fold_sum_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.foldr", rustShape := "reverse iterator plus accumulator", ownership := .owned, requiredTests := ["list_foldr_sum_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.any", rustShape := "short-circuit bool loop", ownership := .borrowedReadOnly, requiredTests := ["list_any_nonzero_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.all", rustShape := "short-circuit bool loop", ownership := .borrowedReadOnly, requiredTests := ["list_all_nonzero_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.append", rustShape := "Vec extend", ownership := .owned, requiredTests := ["list_append_u32", "runtime list_append_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.find?", rustShape := "for loop returning Option", ownership := .borrowedReadOnly, requiredTests := ["list_find_nonzero_u32", "runtime list_find"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "List.reverse", rustShape := "runtime Vec reverse helper", ownership := .owned, requiredTests := ["list_reverse_first_or_u32", "runtime list_reverse_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Array.map", rustShape := "Vec allocation plus for/push", ownership := .returnedNewValue, requiredTests := ["array_map_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Array.foldl", rustShape := "mutable accumulator for loop", ownership := .owned, requiredTests := ["array_fold_sum_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Array.push", rustShape := "owned Vec push", ownership := .owned, requiredTests := ["array_push_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Array.get?", rustShape := "runtime slice get helper", ownership := .borrowedReadOnly, requiredTests := ["array_get_opt_u32", "runtime array_get_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Option.map", rustShape := "match Option", ownership := .owned, requiredTests := ["option_map_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Option.bind", rustShape := "match Option", ownership := .owned, requiredTests := ["option_bind_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Option.getD", rustShape := "match Option fallback", ownership := .owned, requiredTests := ["option_getd_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Except.map", rustShape := "match Result Ok", ownership := .owned, requiredTests := ["result_map_ok_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Except.bind", rustShape := "match Result", ownership := .owned, requiredTests := ["except_do_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "Except.mapError", rustShape := "match Result Err", ownership := .owned, requiredTests := ["result_map_err_inc_u32"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "String.append", rustShape := "runtime owned String append helper", ownership := .owned, requiredTests := ["string_append_lean", "runtime string_append"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "String.length", rustShape := "runtime char-count helper", ownership := .borrowedReadOnly, requiredTests := ["string_length_chars_u32", "runtime string_length_chars"], requiredDocs := ["docs/STD_LOWERINGS.md"] },
  { leanName := "String.contains", rustShape := "runtime char-membership helper", ownership := .borrowedReadOnly, requiredTests := ["string_contains_char_lean", "runtime string_contains_char"], requiredDocs := ["docs/STD_LOWERINGS.md"] }
]

def implementedLoweringNames : List String := lowerings.map (fun item => item.leanName)

def implementedLoweringCount : Nat := lowerings.length


def stdImplementationSummary : String :=
  "Std completion implements " ++ toString implementedLoweringCount ++ " List/Array/Option/Except/String lowerings with explicit owned/borrowed ownership shapes, tests, and docs"

end LeanRustCore.StdImplementation
