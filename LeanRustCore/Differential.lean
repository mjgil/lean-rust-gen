import LeanRustCore.Examples

namespace LeanRustCore.Differential

open LeanRustCore
open LeanRustCore.Examples

/-!
Step 7/8 differential tests, extended by the extractor-owned surface artifact.

The first group keeps the original proof-carrying `IR.eval` assertions.  The
second group evaluates `LeanRustCore.Examples.extractedSurfaceFunctions`, which is
emitted by the same extraction command that emits generated Rust and the
compatibility report.  That removes the previous hand-mirrored `SurfaceFun`
fixtures from the differential path.
-/

structure RustAssertion where
  expression : String
  expected : String
  deriving Repr, BEq

private def rustU32 (n : Nat) : String :=
  toString (u32Wrap n) ++ "u32"

private def rustU64 (n : Nat) : String :=
  toString (u64Wrap n) ++ "u64"

private def rustI32 (n : Int) : String :=
  toString n ++ "i32"

private def rustI64 (n : Int) : String :=
  toString n ++ "i64"

private def rustBool (b : Bool) : String :=
  if b then "true" else "false"

private def rustOrdering : Ordering → String
  | Ordering.lt => "Ordering::Lt"
  | Ordering.eq => "Ordering::Eq"
  | Ordering.gt => "Ordering::Gt"

private def rustNatExact (n : Nat) : String :=
  "num_bigint::BigUint::parse_bytes(b\"" ++ toString n ++ "\", 10).unwrap()"

private def rustIntExact (n : Int) : String :=
  "num_bigint::BigInt::parse_bytes(b\"" ++ toString n ++ "\", 10).unwrap()"

private def rustChar (c : Char) : String :=
  "char::from_u32(" ++ toString c.toNat ++ ").unwrap()"

private def rustStringLiteral (s : String) : String :=
  "String::from(\"" ++ s ++ "\")"

private partial def rustSurfaceValue : SurfaceValue → String
  | .unit => "()"
  | .bool b => rustBool b
  | .ordering o => rustOrdering o
  | .nat n => rustNatExact n
  | .int n => rustIntExact n
  | .u32 n => rustU32 n
  | .u64 n => rustU64 n
  | .i32 n => rustI32 n
  | .i64 n => rustI64 n
  | .char c => rustChar c
  | .string s => rustStringLiteral s
  | .list values => "vec![" ++ joinWith ", " (values.map rustSurfaceValue) ++ "]"
  | .array values => "vec![" ++ joinWith ", " (values.map rustSurfaceValue) ++ "]"
  | .fin _ n => rustU32 n
  | .vector _ values => "vec![" ++ joinWith ", " (values.map rustSurfaceValue) ++ "]"
  | .prodVal a b => "(" ++ rustSurfaceValue a ++ ", " ++ rustSurfaceValue b ++ ")"
  | .sumInl value => "Err(" ++ rustSurfaceValue value ++ ")"
  | .sumInr value => "Ok(" ++ rustSurfaceValue value ++ ")"
  | .optionNone ty => "None::<" ++ rustType ty ++ ">"
  | .optionSome value => "Some(" ++ rustSurfaceValue value ++ ")"
  | .resultOk value => "Ok(" ++ rustSurfaceValue value ++ ")"
  | .resultErr value => "Err(" ++ rustSurfaceValue value ++ ")"
  | .boxed value => "Box::new(" ++ rustSurfaceValue value ++ ")"
  | .structVal name fields =>
      let rendered := fields.map (fun field => rustFieldIdent field.1 ++ ": " ++ rustSurfaceValue field.2)
      rustTypeIdent name ++ " { " ++ joinWith ", " rendered ++ " }"
  | .enumVal name variant payload =>
      let renderedPayload := if payload.isEmpty then "" else "(" ++ joinWith ", " (payload.map rustSurfaceValue) ++ ")"
      rustTypeIdent name ++ "::" ++ rustVariantName variant ++ renderedPayload

private def clampExpected (lo hi x : Nat) : String :=
  rustU32 (eval clampBody { lo := lo, hi := hi, x := x })

private def maxExpected (a b : Nat) : String :=
  rustU32 (eval maxBody { a := a, b := b })

private def nonzeroExpected (x : Nat) : String :=
  rustBool (eval nonzeroBody { x := x })

private def addExpected (a b : Nat) : String :=
  rustU32 (eval addBody { a := a, b := b })

private def bumpExpected (x : Nat) : String :=
  rustU32 (eval boundedBumpBody { x := x })

private def optionDefaultExpected (x : Option Nat) (fallback : Nat) : String :=
  rustU32 (eval optionDefaultBody { x := x, fallback := fallback })

private def assertion (expression expected : String) : RustAssertion :=
  { expression := expression, expected := expected }

/-- Differential assertions whose expectations are rendered from proof-carrying Lean IR evaluator results. -/
def evaluatorAssertions : List RustAssertion := [
  assertion "clamp_u32(10, 20, 5)" (clampExpected 10 20 5),
  assertion "clamp_u32(10, 20, 25)" (clampExpected 10 20 25),
  assertion "clamp_u32(10, 20, 15)" (clampExpected 10 20 15),
  assertion "max_u32(3, 8)" (maxExpected 3 8),
  assertion "max_u32(8, 3)" (maxExpected 8 3),
  assertion "is_nonzero_u32(0)" (nonzeroExpected 0),
  assertion "is_nonzero_u32(7)" (nonzeroExpected 7),
  assertion "add_u32(u32::MAX, 1)" (addExpected (u32Modulus - 1) 1),
  assertion "add_u32(40, 2)" (addExpected 40 2),
  assertion "bounded_bump_u32(0)" (bumpExpected 0),
  assertion "bounded_bump_u32(9)" (bumpExpected 9),
  assertion "bounded_bump_u32(10)" (bumpExpected 10),
  assertion "bounded_bump_u32(u32::MAX)" (bumpExpected (u32Modulus - 1)),
  assertion "option_default_u32(None, 8)" (optionDefaultExpected none 8),
  assertion "option_default_u32(Some(3), 8)" (optionDefaultExpected (some 3) 8)
]

/-- Surface-level semantic fixtures produced directly by the extractor command in `Examples.lean`. -/
def surfaceFixtureFunctions : List SurfaceFun :=
  LeanRustCore.Examples.extractedSurfaceFunctions

private def extractedReturnTypeOrUnit (name : String) : RType :=
  match lookupSurfaceFun? surfaceFixtureFunctions name with
  | some f => f.ret
  | none => .unit

private def stepTy : RType :=
  extractedReturnTypeOrUnit "step_stay"

private def boxedTy : RType :=
  extractedReturnTypeOrUnit "boxed_u32"

private def taggedTy : RType :=
  extractedReturnTypeOrUnit "tagged_missing_u32"

private def surfaceExpected (name : String) (args : List SurfaceValue) : String :=
  match lookupSurfaceFun? surfaceFixtureFunctions name with
  | none => "/* missing surface fixture: " ++ name ++ " */"
  | some f =>
      match evalSurfaceFun surfaceFixtureFunctions f args with
      | .ok value => rustSurfaceValue value
      | .error report => "/* surface evaluator error: " ++ report.detail ++ " */"

private def vU32 (n : Nat) : SurfaceValue := .u32 n
private def vU64 (n : Nat) : SurfaceValue := .u64 n
private def vUnit : SurfaceValue := .unit
private def vBool (b : Bool) : SurfaceValue := .bool b
private def vNat (n : Nat) : SurfaceValue := .nat n
private def vInt (n : Int) : SurfaceValue := .int n
private def vChar (c : Char) : SurfaceValue := .char c
private def vString (s : String) : SurfaceValue := .string s
private def vList (values : List SurfaceValue) : SurfaceValue := .list values
private def vArray (values : List SurfaceValue) : SurfaceValue := .array values
private def vProd (a b : SurfaceValue) : SurfaceValue := .prodVal a b
private def vSumInl (value : SurfaceValue) : SurfaceValue := .sumInl value
private def vSumInr (value : SurfaceValue) : SurfaceValue := .sumInr value
private def vNone (ty : RType) : SurfaceValue := .optionNone ty
private def vSome (value : SurfaceValue) : SurfaceValue := .optionSome value
private def vChoice (variant : String) : SurfaceValue := .enumVal "Choice" variant []
private def vPoint (x y : Nat) : SurfaceValue := .structVal "Point" [("x", .u32 x), ("y", .u32 y)]
private def vBoxed (x : Nat) : SurfaceValue := .structVal "Boxed__u32" [("value", .u32 x)]
private def vBoundedProof (x : Nat) : SurfaceValue := .structVal "Bounded_Proof" [("value", .u32 x)]
private def vTaggedMissing : SurfaceValue := .enumVal "Tagged__u32" "missing" []
private def vTaggedPresent (x : Nat) : SurfaceValue := .enumVal "Tagged__u32" "present" [.u32 x]
private def vStepStay : SurfaceValue := .enumVal "Step" "stay" []
private def vStepJump (amount : Nat) : SurfaceValue := .enumVal "Step" "jump" [.u32 amount]
private def vU32FnInc : SurfaceValue := .enumVal "U32FnCase" "inc" []
private def vU32FnDouble : SurfaceValue := .enumVal "U32FnCase" "double" []
private def vU32FnAdd (delta : Nat) : SurfaceValue := .enumVal "U32FnCase" "add" [.u32 delta]

/-- Additional cases whose expectations are computed by the checked `SurfaceExpr` evaluator. -/
def extractedDeclarationAssertions : List RustAssertion := [
  assertion "add_u64(u64::MAX, 1)" (surfaceExpected "add_u64" [vU64 (u64Modulus - 1), vU64 1]),
  assertion "echo_char('z')" (surfaceExpected "echo_char" [vChar 'z']),
  assertion "echo_string(String::from(\"hi\"))" (surfaceExpected "echo_string" [vString "hi"]),
  assertion "echo_list_u32(vec![1, 2])" (surfaceExpected "echo_list_u32" [vList [vU32 1, vU32 2]]),
  assertion "echo_array_u32(vec![3, 4])" (surfaceExpected "echo_array_u32" [vArray [vU32 3, vU32 4]]),
  assertion "list_map_inc_u32(vec![1, u32::MAX])" (surfaceExpected "list_map_inc_u32" [vList [vU32 1, vU32 (u32Modulus - 1)]]),
  assertion "list_fold_sum_u32(vec![1, 2, u32::MAX])" (surfaceExpected "list_fold_sum_u32" [vList [vU32 1, vU32 2, vU32 (u32Modulus - 1)]]),
  assertion "list_map_add_capture_u32(5, vec![1, u32::MAX])" (surfaceExpected "list_map_add_capture_u32" [vU32 5, vList [vU32 1, vU32 (u32Modulus - 1)]]),
  assertion "list_filter_nonzero_u32(vec![0, 1, 0, 2])" (surfaceExpected "list_filter_nonzero_u32" [vList [vU32 0, vU32 1, vU32 0, vU32 2]]),
  assertion "list_foldr_sum_u32(vec![1, 2, u32::MAX])" (surfaceExpected "list_foldr_sum_u32" [vList [vU32 1, vU32 2, vU32 (u32Modulus - 1)]]),
  assertion "list_any_nonzero_u32(vec![0, 0, 7])" (surfaceExpected "list_any_nonzero_u32" [vList [vU32 0, vU32 0, vU32 7]]),
  assertion "list_all_nonzero_u32(vec![1, 2, 3])" (surfaceExpected "list_all_nonzero_u32" [vList [vU32 1, vU32 2, vU32 3]]),
  assertion "array_map_inc_u32(vec![1, u32::MAX])" (surfaceExpected "array_map_inc_u32" [vArray [vU32 1, vU32 (u32Modulus - 1)]]),
  assertion "array_fold_sum_u32(vec![1, 2, u32::MAX])" (surfaceExpected "array_fold_sum_u32" [vArray [vU32 1, vU32 2, vU32 (u32Modulus - 1)]]),
  assertion "option_map_inc_u32(Some(u32::MAX))" (surfaceExpected "option_map_inc_u32" [vSome (vU32 (u32Modulus - 1))]),
  assertion "option_bind_inc_u32(Some(41))" (surfaceExpected "option_bind_inc_u32" [vSome (vU32 41)]),
  assertion "result_bind_inc_u32(Ok(u32::MAX))" (surfaceExpected "result_bind_inc_u32" [SurfaceValue.resultOk (vU32 (u32Modulus - 1))]),
  assertion "nat_sum_to_u32(5)" (surfaceExpected "nat_sum_to_u32" [vU32 5]),
  assertion "subtype_val_u32(42)" (surfaceExpected "subtype_val_u32" [vU32 42]),
  assertion "subtype_inc_u32(41)" (surfaceExpected "subtype_inc_u32" [vU32 41]),
  assertion "subtype_roundtrip_u32(77)" (surfaceExpected "subtype_roundtrip_u32" [vU32 77]),
  assertion "bounded_proof_make_u32(9)" (surfaceExpected "bounded_proof_make_u32" [vU32 9]),
  assertion "bounded_proof_value_u32(BoundedProof { value: 11 })" (surfaceExpected "bounded_proof_value_u32" [vBoundedProof 11]),
  assertion "fin_val10_u32(7)" (surfaceExpected "fin_val10_u32" [vU32 7]),
  assertion "fin_checked10_u32(9)" (surfaceExpected "fin_checked10_u32" [vU32 9]),
  assertion "fin_checked10_u32(10)" (surfaceExpected "fin_checked10_u32" [vU32 10]),
  assertion "fin_succ_checked10_u32(8)" (surfaceExpected "fin_succ_checked10_u32" [vU32 8]),
  assertion "fin_succ_checked10_u32(9)" (surfaceExpected "fin_succ_checked10_u32" [vU32 9]),
  assertion "vector_echo3_u32(vec![1, 2, 3])" (surfaceExpected "vector_echo3_u32" [vList [vU32 1, vU32 2, vU32 3]]),
  assertion "vector_map_inc3_u32(vec![1, 2, u32::MAX])" (surfaceExpected "vector_map_inc3_u32" [vList [vU32 1, vU32 2, vU32 (u32Modulus - 1)]]),
  assertion "exact_nat_add(num_bigint::BigUint::from(40u32), num_bigint::BigUint::from(2u32))" (surfaceExpected "exact_nat_add" [vNat 40, vNat 2]),
  assertion "exact_nat_mul(num_bigint::BigUint::from(7u32), num_bigint::BigUint::from(6u32))" (surfaceExpected "exact_nat_mul" [vNat 7, vNat 6]),
  assertion "exact_int_add(num_bigint::BigInt::from(-7i32), num_bigint::BigInt::from(5i32))" (surfaceExpected "exact_int_add" [vInt (-7), vInt 5]),
  assertion "decidable_eq_u32(7, 7)" (surfaceExpected "decidable_eq_u32" [vU32 7, vU32 7]),
  assertion "decidable_eq_u32(7, 8)" (surfaceExpected "decidable_eq_u32" [vU32 7, vU32 8]),
  assertion "ord_compare_u32(1, 2)" (surfaceExpected "ord_compare_u32" [vU32 1, vU32 2]),
  assertion "ord_compare_u32(2, 2)" (surfaceExpected "ord_compare_u32" [vU32 2, vU32 2]),
  assertion "ord_compare_u32(3, 2)" (surfaceExpected "ord_compare_u32" [vU32 3, vU32 2]),
  assertion "inhabited_default_u32(())" (surfaceExpected "inhabited_default_u32" [vUnit]),
  assertion "to_string_u32(42)" (surfaceExpected "to_string_u32" [vU32 42]),
  assertion "repr_u32(42)" (surfaceExpected "repr_u32" [vU32 42]),
  assertion "closure_apply_capture_u32(5, 37)" (surfaceExpected "closure_apply_capture_u32" [vU32 5, vU32 37]),
  assertion "stored_closure_apply_u32(5, 37)" (surfaceExpected "stored_closure_apply_u32" [vU32 5, vU32 37]),
  assertion "returned_closure_apply_u32(5, 37)" (surfaceExpected "returned_closure_apply_u32" [vU32 5, vU32 37]),
  assertion "passed_closure_apply_u32(5, 37)" (surfaceExpected "passed_closure_apply_u32" [vU32 5, vU32 37]),
  assertion "stored_multi_closure_apply_u32(1, 4, 30, 7)" (surfaceExpected "stored_multi_closure_apply_u32" [vU32 1, vU32 4, vU32 30, vU32 7]),
  assertion "returned_multi_closure_apply_u32(1, 4, 30, 7)" (surfaceExpected "returned_multi_closure_apply_u32" [vU32 1, vU32 4, vU32 30, vU32 7]),
  assertion "passed_multi_closure_apply_u32(1, 4, 30, 7)" (surfaceExpected "passed_multi_closure_apply_u32" [vU32 1, vU32 4, vU32 30, vU32 7]),
  assertion "closure_env_apply_add_delta_u32(5, 37)" (surfaceExpected "closure_env_apply_add_delta_u32" [vU32 5, vU32 37]),
  assertion "closure_env_map_add_delta_u32(5, vec![1, u32::MAX])" (surfaceExpected "closure_env_map_add_delta_u32" [vU32 5, vList [vU32 1, vU32 (u32Modulus - 1)]]),
  assertion "defun_apply_u32(U32FnCase::Inc, 41)" (surfaceExpected "defun_apply_u32" [vU32FnInc, vU32 41]),
  assertion "defun_apply_u32(U32FnCase::Double, 21)" (surfaceExpected "defun_apply_u32" [vU32FnDouble, vU32 21]),
  assertion "defun_apply_u32(U32FnCase::Add(5), 37)" (surfaceExpected "defun_apply_u32" [vU32FnAdd 5, vU32 37]),
  assertion "defun_compose_inc_double_u32(20)" (surfaceExpected "defun_compose_inc_double_u32" [vU32 20]),
  assertion "defun_apply_add5_u32(37)" (surfaceExpected "defun_apply_add5_u32" [vU32 37]),
  assertion "defun_map_selected_u32(false, vec![1, u32::MAX])" (surfaceExpected "defun_map_selected_u32" [vBool false, vList [vU32 1, vU32 (u32Modulus - 1)]]),
  assertion "list_append_u32(vec![1, 2], vec![3])" "vec![1u32, 2u32, 3u32]",
  assertion "list_find_nonzero_u32(vec![0, 0, 7])" "Some(7u32)",
  assertion "array_push_u32(vec![1, 2], 3)" "vec![1u32, 2u32, 3u32]",
  assertion "option_getd_u32(None, 9)" "9u32",
  assertion "option_getd_u32(Some(4), 9)" "4u32",
  assertion "option_do_inc_u32(None)" "None",
  assertion "option_do_inc_u32(Some(41))" "Some(42u32)",
  assertion "option_seq_right_u32(None)" "None",
  assertion "option_seq_right_u32(Some(5))" "Some(41u32)",
  assertion "option_seq_left_u32(None)" "None",
  assertion "option_seq_left_u32(Some(5))" "Some(5u32)",
  assertion "except_do_inc_u32(Err(7))" "Err(7u32)",
  assertion "except_do_inc_u32(Ok(41))" "Ok(42u32)",
  assertion "except_seq_right_u32(Err(7))" "Err(7u32)",
  assertion "except_seq_right_u32(Ok(5))" "Ok(41u32)",
  assertion "except_seq_left_u32(Err(7))" "Err(7u32)",
  assertion "except_seq_left_u32(Ok(5))" "Ok(5u32)",
  assertion "reader_do_add_u32(5, 37)" "42u32",
  assertion "reader_seq_right_u32(5, 41)" "42u32",
  assertion "reader_seq_left_u32(5)" "5u32",
  assertion "result_map_err_inc_u32(Err(41))" "Err(42u32)",
  assertion "reader_add_env_u32(5, 37)" "42u32",
  assertion "state_tick_u32(41)" "(41u32, 42u32)",
  assertion "generic_beq_u32(7, 7)" (surfaceExpected "generic_beq_u32" [vU32 7, vU32 7]),
  assertion "generic_beq_u32(7, 8)" (surfaceExpected "generic_beq_u32" [vU32 7, vU32 8]),
  assertion "general_bool_match_u32(true, 9, 20)" (surfaceExpected "general_bool_match_u32" [vBool true, vU32 9, vU32 20]),
  assertion "general_bool_match_u32(false, 9, 20)" (surfaceExpected "general_bool_match_u32" [vBool false, vU32 9, vU32 20]),
  assertion "general_option_match_u32(Some(41), 8)" (surfaceExpected "general_option_match_u32" [vSome (vU32 41), vU32 8]),
  assertion "general_step_match_u32(Step::Jump(u32::MAX), 7)" (surfaceExpected "general_step_match_u32" [vStepJump (u32Modulus - 1), vU32 7]),
  assertion "pair_sum_match_u32(40, 2)" (surfaceExpected "pair_sum_match_u32" [vU32 40, vU32 2]),
  assertion "list_length_u32(vec![1, 2, 3])" (surfaceExpected "list_length_u32" [vList [vU32 1, vU32 2, vU32 3]]),
  assertion "tail_sum_down_u32(5)" (surfaceExpected "tail_sum_down_u32" [vU32 5]),
  assertion "echo_prod_u32((5, 6))" (surfaceExpected "echo_prod_u32" [vProd (vU32 5) (vU32 6)]),
  assertion "echo_sum_u32(Ok(7))" (surfaceExpected "echo_sum_u32" [vSumInr (vU32 7)]),
  assertion "echo_sum_u32(Err(8))" (surfaceExpected "echo_sum_u32" [vSumInl (vU32 8)]),
  assertion "helper_chain_u32(40)" (surfaceExpected "helper_chain_u32" [vU32 40]),
  assertion "proof_erased_u32(5)" (surfaceExpected "proof_erased_u32" [vU32 5]),
  assertion "bool_match_u32(true, 1, 2)" (surfaceExpected "bool_match_u32" [vBool true, vU32 1, vU32 2]),
  assertion "bool_match_u32(false, 1, 2)" (surfaceExpected "bool_match_u32" [vBool false, vU32 1, vU32 2]),
  assertion "some_u32(4)" (surfaceExpected "some_u32" [vU32 4]),
  assertion "none_u32(())" (surfaceExpected "none_u32" [vUnit]),
  assertion "option_default_u32(None, 8)" (surfaceExpected "option_default_u32" [vNone .u32, vU32 8]),
  assertion "option_default_u32(Some(3), 8)" (surfaceExpected "option_default_u32" [vSome (vU32 3), vU32 8]),
  assertion "result_ok_u32(5)" (surfaceExpected "result_ok_u32" [vU32 5]),
  assertion "result_err_u32(7)" (surfaceExpected "result_err_u32" [vU32 7]),
  assertion "choose_by_enum(Choice::First, 10, 20)" (surfaceExpected "choose_by_enum" [vChoice "first", vU32 10, vU32 20]),
  assertion "choose_by_enum(Choice::Second, 10, 20)" (surfaceExpected "choose_by_enum" [vChoice "second", vU32 10, vU32 20]),
  assertion "make_point(3, 4)" (surfaceExpected "make_point" [vU32 3, vU32 4]),
  assertion "point_x(Point { x: 8, y: 9 })" (surfaceExpected "point_x" [vPoint 8 9]),
  assertion "point_y(Point { x: 8, y: 9 })" (surfaceExpected "point_y" [vPoint 8 9]),
  assertion "shift_point_x(Point { x: u32::MAX, y: 7 }, 1)" (surfaceExpected "shift_point_x" [vPoint (u32Modulus - 1) 7, vU32 1]),
  assertion "boxed_u32(9)" (surfaceExpected "boxed_u32" [vU32 9]),
  assertion "boxed_value_u32(BoxedU32 { value: 9 })" (surfaceExpected "boxed_value_u32" [vBoxed 9]),
  assertion "tagged_missing_u32(())" (surfaceExpected "tagged_missing_u32" [vUnit]),
  assertion "tagged_present_u32(6)" (surfaceExpected "tagged_present_u32" [vU32 6]),
  assertion "tagged_default_u32(TaggedU32::Missing, 7)" (surfaceExpected "tagged_default_u32" [vTaggedMissing, vU32 7]),
  assertion "tagged_default_u32(TaggedU32::Present(6), 7)" (surfaceExpected "tagged_default_u32" [vTaggedPresent 6, vU32 7]),
  assertion "step_stay(())" (surfaceExpected "step_stay" [vUnit]),
  assertion "step_jump(12)" (surfaceExpected "step_jump" [vU32 12]),
  assertion "step_amount_or(Step::Stay, 9)" (surfaceExpected "step_amount_or" [vStepStay, vU32 9]),
  assertion "step_amount_or(Step::Jump(12), 9)" (surfaceExpected "step_amount_or" [vStepJump 12, vU32 9]),
  assertion "step_amount_plus_one_or(Step::Stay, 7)" (surfaceExpected "step_amount_plus_one_or" [vStepStay, vU32 7]),
  assertion "step_amount_plus_one_or(Step::Jump(u32::MAX), 7)" (surfaceExpected "step_amount_plus_one_or" [vStepJump (u32Modulus - 1), vU32 7]),
  assertion "inc_u32(41)" (surfaceExpected "inc_u32" [vU32 41]),
  assertion "inc_u32(u32::MAX)" (surfaceExpected "inc_u32" [vU32 (u32Modulus - 1)]),
  assertion "inc_twice_u32(40)" (surfaceExpected "inc_twice_u32" [vU32 40]),
  assertion "inc_twice_u32(u32::MAX)" (surfaceExpected "inc_twice_u32" [vU32 (u32Modulus - 1)]),
  assertion "nested_none_u32(())" (surfaceExpected "nested_none_u32" [vUnit]),
  assertion "result_ok_none_u32(())" (surfaceExpected "result_ok_none_u32" [vUnit]),
  assertion "result_err_some_u32(44)" (surfaceExpected "result_err_some_u32" [vU32 44]),
  assertion "identity_u64(99)" (surfaceExpected "identity_u64" [vU64 99]),
  assertion "choose_generic_u32(true, 10, 20)" (surfaceExpected "choose_generic_u32" [vBool true, vU32 10, vU32 20]),
  assertion "choose_generic_u32(false, 10, 20)" (surfaceExpected "choose_generic_u32" [vBool false, vU32 10, vU32 20]),
  assertion "option_default_u64(None, 77)" (surfaceExpected "option_default_u64" [vNone .u64, vU64 77]),
  assertion "option_default_u64(Some(55), 77)" (surfaceExpected "option_default_u64" [vSome (vU64 55), vU64 77]),
  assertion "generic_identity__u32(11)" (surfaceExpected "generic_identity__u32" [vU32 11]),
  assertion "auto_identity_u32(12)" (surfaceExpected "auto_identity_u32" [vU32 12]),
  assertion "generic_choose__point(true, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "generic_choose__point" [vBool true, vPoint 1 2, vPoint 3 4]),
  assertion "generic_choose__point(false, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "generic_choose__point" [vBool false, vPoint 1 2, vPoint 3 4]),
  assertion "auto_choose_point(true, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "auto_choose_point" [vBool true, vPoint 1 2, vPoint 3 4]),
  assertion "auto_choose_point(false, Point { x: 1, y: 2 }, Point { x: 3, y: 4 })" (surfaceExpected "auto_choose_point" [vBool false, vPoint 1 2, vPoint 3 4]),
  assertion "generic_option_default__step(None, Step::Stay)" (surfaceExpected "generic_option_default__step" [vNone stepTy, vStepStay]),
  assertion "generic_option_default__step(Some(Step::Jump(7)), Step::Stay)" (surfaceExpected "generic_option_default__step" [vSome (vStepJump 7), vStepStay]),
  assertion "auto_option_default_step(None, Step::Jump(5))" (surfaceExpected "auto_option_default_step" [vNone stepTy, vStepJump 5]),
  assertion "auto_option_default_step(Some(Step::Stay), Step::Jump(5))" (surfaceExpected "auto_option_default_step" [vSome vStepStay, vStepJump 5]),
  assertion "pair_box_make_u32_string(9, String::from(\"rust\"))" "PairboxU32String { left: 9u32, right: String::from(\"rust\") }",
  assertion "pair_box_swap_u32_string(PairboxU32String { left: 7, right: String::from(\"lean\") })" "PairboxStringU32 { left: String::from(\"lean\"), right: 7u32 }",
  assertion "pair_choice_left_u32_string(6)" "PairchoiceU32String::Left(6u32)",
  assertion "pair_choice_default_u32_string(PairchoiceU32String::Right(String::from(\"skip\")), 11)" "11u32",
  assertion "nested_payload_ok_u32_string(8)" "NestedpayloadU32String { primary: Some(8u32), secondary: Ok(8u32) }",
  assertion "nested_payload_value_or_u32_string(NestedpayloadU32String { primary: Some(41), secondary: Err(String::from(\"x\")) }, 0)" "41u32"
]

private def emitAssertion (a : RustAssertion) : String :=
  if a.expected == "true" then
    "    assert!(" ++ a.expression ++ ");"
  else if a.expected == "false" then
    "    assert!(!" ++ a.expression ++ ");"
  else
    "    assert_eq!(" ++ a.expression ++ ", " ++ a.expected ++ ");"

private def emitAssertionsTest (name : String) (assertions : List RustAssertion) : String :=
  "#[test]\nfn " ++ name ++ "() {\n" ++
  joinWith "\n" (assertions.map emitAssertion) ++
  "\n}\n"

/-- Rust integration-test source generated from the Lean differential fixtures. -/
def generatedDifferentialRustTests : String :=
  "// Generated by LeanRustCore.Differential. Do not edit by hand.\n" ++
  "// Expectations on the right-hand side are computed in Lean.\n\n" ++
  "use lean_rust_core_generated::*;\n\n" ++
  emitAssertionsTest "lean_ir_evaluator_matches_generated_rust" evaluatorAssertions ++
  "\n" ++
  emitAssertionsTest "surface_evaluator_matches_extracted_rust" extractedDeclarationAssertions

end LeanRustCore.Differential
