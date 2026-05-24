import LeanRustCore.IR

namespace LeanRustCore

private def wrappingMethod : RType → String → Option String
  | .u32, op => some ("wrapping_" ++ op)
  | .u64, op => some ("wrapping_" ++ op)
  | .i32, op => some ("wrapping_" ++ op)
  | .i64, op => some ("wrapping_" ++ op)
  | _, _ => none

private def emitWrapping (op : String) (t : RType) (a b : String) : String :=
  match wrappingMethod t op with
  | some method => "(" ++ a ++ ")." ++ method ++ "(" ++ b ++ ")"
  | none => "(" ++ a ++ " /* unsupported wrapping op */ " ++ b ++ ")"

private def borrowExpr (expr : String) : String :=
  "(&(" ++ expr ++ "))"

def emitExactArithmetic (op : String) (t : RType) (a b : String) : String :=
  match t, op with
  | .nat, "add" => borrowExpr a ++ " + " ++ borrowExpr b
  | .nat, "mul" => borrowExpr a ++ " * " ++ borrowExpr b
  | .nat, "sub" => "if " ++ borrowExpr a ++ " < " ++ borrowExpr b ++ " { num_bigint::BigUint::from(0u8) } else { " ++ borrowExpr a ++ " - " ++ borrowExpr b ++ " }"
  | .int, "add" => borrowExpr a ++ " + " ++ borrowExpr b
  | .int, "sub" => borrowExpr a ++ " - " ++ borrowExpr b
  | .int, "mul" => borrowExpr a ++ " * " ++ borrowExpr b
  | _, _ => emitWrapping op t a b

def emitArithmetic (op : String) (t : RType) (a b : String) : String :=
  match t with
  | .nat | .int => emitExactArithmetic op t a b
  | _ => emitWrapping op t a b

def emitRuntimeCall? (name : String) (args : List String) : Option String :=
  match name, args with
  | "__runtime_u32_checked_add", [a, b] => some s!"crate::runtime::u32_checked_add({a}, {b})"
  | "__runtime_u32_checked_sub", [a, b] => some s!"crate::runtime::u32_checked_sub({a}, {b})"
  | "__runtime_u32_checked_div", [a, b] => some s!"crate::runtime::u32_checked_div({a}, {b})"
  | "__runtime_u32_checked_mod", [a, b] => some s!"crate::runtime::u32_checked_mod({a}, {b})"
  | "__runtime_u32_saturating_add", [a, b] => some s!"crate::runtime::u32_saturating_add({a}, {b})"
  | "__runtime_u32_saturating_sub", [a, b] => some s!"crate::runtime::u32_saturating_sub({a}, {b})"
  | "__runtime_u32_preconditioned_div", [a, b] => some s!"crate::runtime::u32_preconditioned_div({a}, {b}).map_err(String::from)"
  | "__runtime_u32_preconditioned_mod", [a, b] => some s!"crate::runtime::u32_preconditioned_mod({a}, {b}).map_err(String::from)"
  | "__runtime_u64_to_u32_checked", [x] => some s!"crate::runtime::u64_to_u32_checked({x})"
  | "__runtime_list_head_clone", [xs] => some s!"crate::runtime::list_head_clone(&({xs}))"
  | "__runtime_list_tail_clone", [xs] => some s!"crate::runtime::list_tail_clone(&({xs}))"
  | "__runtime_list_prepend_u32", [head, xs] => some s!"crate::runtime::list_prepend_u32({head}, {xs})"
  | "__runtime_list_reverse_u32", [xs] => some s!"crate::runtime::list_reverse_u32({xs})"
  | "__runtime_tree_sum_worklist_u32", [tree] => some s!"crate::recursion_helpers::tree_sum_worklist_u32({tree})"
  | "__runtime_array_get_u32", [xs, index] => some s!"crate::runtime::array_get_u32(&({xs}), ({index}) as usize)"
  | "__runtime_string_append", [left, right] => some s!"crate::runtime::string_append({left}, &({right}))"
  | "__runtime_string_length_chars", [s] => some s!"crate::runtime::string_length_chars(&({s})) as u32"
  | "__runtime_string_contains_char", [s, c] => some s!"crate::runtime::string_contains_char(&({s}), {c})"
  | "__runtime_dictionary_beq_u32_const", [a, b] => some s!"crate::runtime::dictionary_beq_u32(crate::runtime::BEQ_U32, {a}, {b})"
  | "__runtime_dictionary_compare_u32_const", [a, b] =>
      some ("match crate::runtime::dictionary_compare_u32(crate::runtime::ORD_U32, " ++ a ++ ", " ++ b ++
        ") { std::cmp::Ordering::Less => Ordering::Lt, std::cmp::Ordering::Equal => Ordering::Eq, std::cmp::Ordering::Greater => Ordering::Gt }")
  | "__runtime_dictionary_add_u32_const", [a, b] => some s!"crate::runtime::dictionary_add_u32(crate::runtime::ADD_U32, {a}, {b})"
  | "__runtime_dictionary_default_u32_const", [] => some "crate::runtime::dictionary_default_u32(crate::runtime::DEFAULT_U32)"
  | "__runtime_dictionary_to_string_u32_const", [value] => some s!"crate::runtime::dictionary_to_string_u32(crate::runtime::TO_STRING_U32, {value})"
  | _, _ => none

end LeanRustCore
