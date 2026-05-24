import LeanRustCore.IR
import LeanRustCore.EmitRust
import LeanRustCore.Extract
import LeanRustCore.NumericExamples
import LeanRustCore.ParameterizedExamples
import LeanRustCore.RecursionExamples
import LeanRustCore.TypeclassDictionaryExamples
import LeanRustCore.TypedIRExamples

namespace LeanRustCore.Examples

open LeanRustCore
open LeanRustCore.Extract

/-!
## Elaboration-extracted Lean source declarations

These are ordinary Lean definitions tagged with `@[rust_export]`. The
`rust_emit_exports` command reads their elaborated constant bodies from the Lean
environment and emits Rust for the supported subset. There is no source-string
matching in this path. The `Nat` examples below explicitly opt into wrapping
`u32` boundary semantics with `@[rust_nat_wrapping_u32]`.
-/

inductive Choice where
  | first
  | second

structure Point where
  x : UInt32
  y : UInt32

inductive Step where
  | stay
  | jump (amount : UInt32)

structure Boxed (α : Type) where
  value : α

/-- Explicit closure-converted environment used by the Sprint 13-14 examples. -/
structure AddDeltaU32Env where
  delta : UInt32

/-- Finite defunctionalized family for selected UInt32 unary functions. -/
inductive U32FnCase where
  | inc
  | double
  | add (delta : UInt32)

inductive BinaryTreeU32 where
  | leaf
  | node (left : BinaryTreeU32) (value : UInt32) (right : BinaryTreeU32)

inductive ExprU32 where
  | lit (value : UInt32)
  | add (left : ExprU32) (right : ExprU32)

inductive RoseTreeU32 where
  | node (value : UInt32) (children : List RoseTreeU32)

mutual

inductive EvenNode where
  | terminal (value : UInt32)
  | step (value : UInt32) (next : OddNode)

inductive OddNode where
  | terminal (value : UInt32)
  | step (value : UInt32) (next : EvenNode)

end

structure Bounded_Proof where
  value : UInt32
  proof : value = value

inductive FlagCarrier : Bool → Type where
  | mk (value : UInt32) : FlagCarrier flag

structure InnerProofValue where
  value : UInt32
  proof : value = value

structure NestedProofWrapper where
  inner : InnerProofValue
  witness : inner.value = inner.value

inductive Tagged (α : Type) where
  | missing
  | present (value : α)

structure PairBox (α β : Type) where
  left : α
  right : β

inductive PairChoice (α β : Type) where
  | left (value : α)
  | right (value : β)

structure NestedPayload (α β : Type) where
  primary : Option α
  secondary : Except β α

@[rust_export, rust_nat_wrapping_u32]
def clamp_u32 (lo hi x : Nat) : Nat :=
  if x < lo then lo else if x > hi then hi else x

@[rust_export, rust_nat_wrapping_u32]
def max_u32 (a b : Nat) : Nat :=
  if a < b then b else a

@[rust_export, rust_nat_wrapping_u32]
def is_nonzero_u32 (x : Nat) : Bool :=
  if x = 0 then false else true

@[rust_export, rust_nat_wrapping_u32]
def add_u32 (a b : Nat) : Nat :=
  a + b

@[rust_export, rust_nat_wrapping_u32]
def mul_u32 (a b : Nat) : Nat :=
  a * b

@[rust_export, rust_nat_wrapping_u32]
def bounded_bump_u32 (x : Nat) : Nat :=
  let y := x + 1
  if y > 10 then 10 else y

@[rust_export]
def echo_u32 (x : UInt32) : UInt32 :=
  x

@[rust_export]
def echo_u64 (x : UInt64) : UInt64 :=
  x

@[rust_export]
def echo_i32 (x : Int32) : Int32 :=
  x

@[rust_export]
def echo_i64 (x : Int64) : Int64 :=
  x

@[rust_export]
def echo_char (x : Char) : Char :=
  x

@[rust_export]
def echo_string (x : String) : String :=
  x

@[rust_export]
def echo_list_u32 (xs : List UInt32) : List UInt32 :=
  xs

@[rust_export]
def echo_array_u32 (xs : Array UInt32) : Array UInt32 :=
  xs

@[rust_export]
def list_map_inc_u32 (xs : List UInt32) : List UInt32 :=
  List.map (fun x => x + 1) xs

@[rust_export]
def list_fold_sum_u32 (xs : List UInt32) : UInt32 :=
  List.foldl (fun acc x => acc + x) 0 xs

@[rust_export]
def list_map_add_capture_u32 (delta : UInt32) (xs : List UInt32) : List UInt32 :=
  List.map (fun x => x + delta) xs

@[rust_export]
def list_filter_nonzero_u32 (xs : List UInt32) : List UInt32 :=
  List.filter (fun x => x > 0) xs

@[rust_export]
def list_foldr_sum_u32 (xs : List UInt32) : UInt32 :=
  List.foldr (fun x acc => x + acc) 0 xs

@[rust_export]
def list_any_nonzero_u32 (xs : List UInt32) : Bool :=
  List.any xs (fun x => x > 0)

@[rust_export]
def list_all_nonzero_u32 (xs : List UInt32) : Bool :=
  List.all xs (fun x => x > 0)

@[rust_export]
def array_map_inc_u32 (xs : Array UInt32) : Array UInt32 :=
  xs.map (fun x => x + 1)

@[rust_export]
def array_fold_sum_u32 (xs : Array UInt32) : UInt32 :=
  xs.foldl (fun acc x => acc + x) 0

@[rust_export]
def option_map_inc_u32 (x : Option UInt32) : Option UInt32 :=
  Option.map (fun y => y + 1) x

@[rust_export]
def option_bind_inc_u32 (x : Option UInt32) : Option UInt32 :=
  Option.bind x (fun y => some (y + 1))

@[rust_export]
def result_bind_inc_u32 (x : Except UInt32 UInt32) : Except UInt32 UInt32 :=
  Except.bind x (fun y => Except.ok (y + 1))

@[rust_export]
def subtype_val_u32 (x : { n : UInt32 // True }) : UInt32 :=
  x.val

@[rust_export]
def subtype_inc_u32 (x : { n : UInt32 // True }) : UInt32 :=
  x.val + 1

@[rust_export]
def subtype_roundtrip_u32 (x : { n : UInt32 // True }) : { n : UInt32 // True } :=
  x

@[rust_export, rust_nat_wrapping_u32]
def fin_val10_u32 (i : Fin 10) : Nat :=
  i.val

@[rust_export, rust_nat_wrapping_u32]
def fin_checked10_u32 (x : Nat) : Option (Fin 10) :=
  if h : x < 10 then some ⟨x, h⟩ else none

@[rust_export, rust_nat_wrapping_u32]
def fin_succ_checked10_u32 (i : Fin 10) : Option (Fin 10) :=
  let j := i.val + 1
  if h : j < 10 then some ⟨j, h⟩ else none

@[rust_export]
def vector_echo3_u32 (xs : Vector UInt32 3) : Vector UInt32 3 :=
  xs

@[rust_export]
def vector_map_inc3_u32 (xs : Vector UInt32 3) : Vector UInt32 3 :=
  xs.map (fun x => x + 1)

@[rust_export]
def bounded_proof_make_u32 (x : UInt32) : Bounded_Proof :=
  { value := x, proof := rfl }

@[rust_export]
def bounded_proof_value_u32 (b : Bounded_Proof) : UInt32 :=
  b.value

@[rust_export]
def equality_cast_subtype_value_u32 (x : UInt32) : UInt32 :=
  let wrapped : { n : UInt32 // True } := ⟨x, trivial⟩
  let casted : { n : UInt32 // True } := cast (by rfl) wrapped
  casted.val

@[rust_export]
def sigma_runtime_pair_echo_u32
    (pair : Sigma (fun _ : UInt32 => UInt32)) :
    Sigma (fun _ : UInt32 => UInt32) :=
  pair

@[rust_export]
def sigma_runtime_pair_sum_u32
    (pair : Sigma (fun _ : UInt32 => UInt32)) : UInt32 :=
  match pair with
  | ⟨tag, value⟩ => tag + value

@[rust_export]
def flag_carrier_true_roundtrip_u32
    (x : FlagCarrier true) : FlagCarrier true :=
  x

@[rust_export]
def flag_carrier_false_value_u32
    (x : FlagCarrier false) : UInt32 :=
  match x with
  | .mk value => value

@[rust_export]
def flag_carrier_match_invariant_u32 (flag : Bool) (x : UInt32) : UInt32 :=
  match flag with
  | true =>
      let carrier : FlagCarrier true := .mk x
      match carrier with
      | .mk value => value + 1
  | false =>
      let carrier : FlagCarrier false := .mk x
      match carrier with
      | .mk value => value

@[rust_export]
def nested_proof_wrapper_value_u32 (x : UInt32) : UInt32 :=
  let nested : NestedProofWrapper := {
    inner := { value := x, proof := rfl },
    witness := rfl
  }
  nested.inner.value

@[rust_export]
def general_bool_match_u32 (flag : Bool) (when_true when_false : UInt32) : UInt32 :=
  match flag with
  | true => when_true + 1
  | false => when_false + 1

@[rust_export]
def general_option_match_u32 (x : Option UInt32) (fallback : UInt32) : UInt32 :=
  match x with
  | none => fallback
  | some value => value + 1

@[rust_export]
def general_step_match_u32 (s : Step) (fallback : UInt32) : UInt32 :=
  match s with
  | .stay => fallback
  | .jump amount => amount + 1

@[rust_export]
def pair_sum_match_u32 (a b : UInt32) : UInt32 :=
  match (a, b) with
  | (x, y) => x + y

@[rust_export, rust_nat_exact]
def exact_nat_add (a b : Nat) : Nat :=
  a + b

@[rust_export, rust_nat_exact]
def exact_nat_mul (a b : Nat) : Nat :=
  a * b

@[rust_export, rust_int_exact]
def exact_int_add (a b : Int) : Int :=
  a + b

@[rust_export, rust_int_exact]
def exact_int_mul (a b : Int) : Int :=
  a * b

@[rust_export] def checked_add_u32 (a b : UInt32) : Option UInt32 := LeanRustCore.NumericExamples.checked_add_u32 a b
@[rust_export] def checked_sub_u32 (a b : UInt32) : Option UInt32 := LeanRustCore.NumericExamples.checked_sub_u32 a b
@[rust_export] def checked_div_u32 (a b : UInt32) : Option UInt32 := LeanRustCore.NumericExamples.checked_div_u32 a b
@[rust_export] def checked_mod_u32 (a b : UInt32) : Option UInt32 := LeanRustCore.NumericExamples.checked_mod_u32 a b
@[rust_export] def saturating_add_u32 (a b : UInt32) : UInt32 := LeanRustCore.NumericExamples.saturating_add_u32 a b
@[rust_export] def saturating_sub_u32 (a b : UInt32) : UInt32 := LeanRustCore.NumericExamples.saturating_sub_u32 a b
@[rust_export] def preconditioned_div_u32 (a b : UInt32) : Except String UInt32 := LeanRustCore.NumericExamples.preconditioned_div_u32 a b
@[rust_export] def preconditioned_mod_u32 (a b : UInt32) : Except String UInt32 := LeanRustCore.NumericExamples.preconditioned_mod_u32 a b
@[rust_export] def checked_cast_u64_to_u32 (x : UInt64) : Option UInt32 := LeanRustCore.NumericExamples.checked_cast_u64_to_u32 x


@[rust_export]
def decidable_eq_u32 (a b : UInt32) : Bool :=
  a == b

@[rust_export]
def inhabited_default_u32 (_x : Unit) : UInt32 :=
  default

@[rust_export]
def to_string_u32 (x : UInt32) : String :=
  toString x

@[rust_export]
def repr_u32 (x : UInt32) : String :=
  reprStr x

@[rust_export]
def ord_compare_u32 (a b : UInt32) : Ordering :=
  compare a b

@[rust_export] def generated_dict_beq_u32 (a b : UInt32) : Bool := apply_beq_dict_u32 beq_dict_u32_inst a b
@[rust_export] def generated_dict_compare_u32 (a b : UInt32) : Ordering := apply_compare_dict_u32 compare_dict_u32_inst a b
@[rust_export] def generated_dict_add_u32 (a b : UInt32) : UInt32 := apply_add_dict_u32 add_dict_u32_inst a b
@[rust_export] def generated_dict_default_u32 (_x : Unit) : UInt32 := apply_default_dict_u32 default_dict_u32_inst
@[rust_export] def generated_dict_to_string_u32 (x : UInt32) : String := apply_to_string_dict_u32 to_string_dict_u32_inst x

@[rust_export]
def option_do_inc_u32 (x : Option UInt32) : Option UInt32 := do
  let v ← x
  pure (v + 1)


@[rust_export]
def list_append_u32 (xs ys : List UInt32) : List UInt32 :=
  xs ++ ys

@[rust_export]
def list_find_nonzero_u32 (xs : List UInt32) : Option UInt32 :=
  xs.find? (fun x => x > 0)

@[rust_export]
def array_push_u32 (xs : Array UInt32) (x : UInt32) : Array UInt32 :=
  xs.push x

@[rust_export]
def option_getd_u32 (x : Option UInt32) (fallback : UInt32) : UInt32 :=
  x.getD fallback

@[rust_export] def result_map_ok_inc_u32 (x : Except UInt32 UInt32) : Except UInt32 UInt32 := Except.map (fun y => y + 1) x

@[rust_export] def list_reverse_first_or_u32 (xs : List UInt32) (fallback : UInt32) : UInt32 := (List.reverse xs).foldl (fun _ x => x) fallback

@[rust_export] def list_head_or_zero_u32 (xs : List UInt32) : UInt32 := match xs with | [] => 0 | head :: _ => head

@[rust_export] def list_second_or_zero_u32 (xs : List UInt32) : UInt32 := match xs with | _ :: second :: _ => second | _ => 0

@[rust_export, rust_nat_wrapping_u32] def nat_pred_or_zero_u32 (n : Nat) : Nat := match n with | 0 => 0 | Nat.succ pred => pred

@[rust_export, rust_nat_wrapping_u32] def nat_two_step_or_zero_u32 (n : Nat) : Nat := match n with | Nat.succ (Nat.succ k) => k + 2 | _ => 0

@[rust_export, rust_nat_wrapping_u32] def list_length_u32 (xs : List UInt32) : Nat := xs.length

@[rust_export, rust_nat_wrapping_u32] def tail_sum_down_u32 (n : Nat) : Nat := Nat.rec 0 (fun k acc => acc + (n - k)) n

@[rust_export, rust_nat_wrapping_u32] def nat_sum_to_u32 (n : Nat) : Nat := Nat.rec 0 (fun k acc => acc + k) n
@[rust_export, rust_nat_wrapping_u32] def gcd_u32 (a b : Nat) : Nat := LeanRustCore.RecursionExamples.gcd_u32 a b
@[rust_export] def reverse_accum_u32 (xs acc : List UInt32) : List UInt32 := LeanRustCore.RecursionExamples.reverse_accum_u32 xs acc
@[rust_export, rust_nat_wrapping_u32] def mutual_even_u32 (n : Nat) : Bool := LeanRustCore.RecursionExamples.mutual_even_u32 n
@[rust_export, rust_nat_wrapping_u32] def mutual_odd_u32 (n : Nat) : Bool := LeanRustCore.RecursionExamples.mutual_odd_u32 n

@[rust_export, rust_nat_wrapping_u32] def array_get_opt_u32 (xs : Array UInt32) (i : Nat) : Option UInt32 := Array.get? xs i

@[rust_export] def string_append_lean (left right : String) : String := String.append left right

@[rust_export, rust_nat_wrapping_u32] def string_length_chars_u32 (s : String) : Nat := String.length s

@[rust_export] def string_contains_char_lean (s : String) (c : Char) : Bool := String.contains s c

@[rust_export]
def result_map_err_inc_u32 (x : Except UInt32 UInt32) : Except UInt32 UInt32 :=
  match x with
  | Except.ok value => Except.ok value
  | Except.error err => Except.error (err + 1)

@[rust_export]
def except_do_inc_u32 (x : Except UInt32 UInt32) : Except UInt32 UInt32 := do
  let v ← x
  pure (v + 1)

@[rust_export]
def reader_add_env_u32 (env x : UInt32) : UInt32 :=
  (fun cfg => x + cfg) env

@[rust_export]
def state_tick_u32 (s : UInt32) : UInt32 × UInt32 :=
  let old := s
  (old, s + 1)

@[rust_export]
def closure_apply_capture_u32 (delta x : UInt32) : UInt32 :=
  (fun y => y + delta) x

@[rust_export]
def closure_env_apply_add_delta_u32 (delta x : UInt32) : UInt32 :=
  let env : AddDeltaU32Env := { delta := delta }
  x + env.delta

@[rust_export]
def closure_env_map_add_delta_u32 (delta : UInt32) (xs : List UInt32) : List UInt32 :=
  let env : AddDeltaU32Env := { delta := delta }
  List.map (fun x => x + env.delta) xs

@[rust_export]
def defun_apply_u32 (f : U32FnCase) (x : UInt32) : UInt32 :=
  match f with
  | .inc => x + 1
  | .double => x + x
  | .add delta => x + delta

@[rust_export]
def defun_compose_inc_double_u32 (x : UInt32) : UInt32 :=
  defun_apply_u32 .double (defun_apply_u32 .inc x)

@[rust_export]
def defun_apply_add5_u32 (x : UInt32) : UInt32 :=
  defun_apply_u32 (.add 5) x

@[rust_export]
def defun_map_selected_u32 (useDouble : Bool) (xs : List UInt32) : List UInt32 :=
  List.map (fun x => if useDouble then defun_apply_u32 .double x else defun_apply_u32 .inc x) xs

@[rust_export]
def tree_leaf_u32 (_x : Unit) : BinaryTreeU32 :=
  BinaryTreeU32.leaf

@[rust_export]
def tree_node_u32 (left : BinaryTreeU32) (value : UInt32) (right : BinaryTreeU32) : BinaryTreeU32 :=
  BinaryTreeU32.node left value right

@[rust_export]
def tree_size_u32 (t : BinaryTreeU32) : UInt32 :=
  match t with
  | BinaryTreeU32.leaf => 0
  | BinaryTreeU32.node left _value right => tree_size_u32 left + 1 + tree_size_u32 right

@[rust_export]
def tree_sum_u32 (t : BinaryTreeU32) : UInt32 :=
  match t with
  | BinaryTreeU32.leaf => 0
  | BinaryTreeU32.node left value right => tree_sum_u32 left + value + tree_sum_u32 right

@[rust_export]
def tree_sum_worklist_u32 (t : BinaryTreeU32) : UInt32 :=
  match t with
  | BinaryTreeU32.leaf => 0
  | BinaryTreeU32.node left value right => tree_sum_worklist_u32 left + value + tree_sum_worklist_u32 right

@[rust_export]
def expr_lit_u32 (value : UInt32) : ExprU32 :=
  ExprU32.lit value

@[rust_export]
def expr_add_u32 (left right : ExprU32) : ExprU32 :=
  ExprU32.add left right

@[rust_export]
def expr_eval_u32 (e : ExprU32) : UInt32 :=
  match e with
  | ExprU32.lit value => value
  | ExprU32.add left right => expr_eval_u32 left + expr_eval_u32 right

def rose_leaf_u32 (value : UInt32) : RoseTreeU32 :=
  RoseTreeU32.node value []

@[rust_export]
def rose_branch_u32 (value : UInt32) (children : List RoseTreeU32) : RoseTreeU32 :=
  RoseTreeU32.node value children

def rose_child_count_u32 (tree : RoseTreeU32) : Nat :=
  match tree with
  | RoseTreeU32.node _ children => children.length

@[rust_export]
def even_terminal_u32 (value : UInt32) : EvenNode :=
  EvenNode.terminal value

@[rust_export]
def odd_terminal_u32 (value : UInt32) : OddNode :=
  OddNode.terminal value

@[rust_export]
def even_step_u32 (value : UInt32) (next : OddNode) : EvenNode :=
  EvenNode.step value next

@[rust_export]
def odd_step_u32 (value : UInt32) (next : EvenNode) : OddNode :=
  OddNode.step value next

def even_next_value_or_u32 (node : EvenNode) (fallback : UInt32) : UInt32 :=
  match node with
  | EvenNode.terminal value => value
  | EvenNode.step _ next =>
      match next with
      | OddNode.terminal value => value
      | OddNode.step value _ => value

@[rust_export]
def echo_prod_u32 (x : UInt32 × UInt32) : UInt32 × UInt32 :=
  x

@[rust_export]
def echo_sum_u32 (x : Sum UInt32 UInt32) : Sum UInt32 UInt32 :=
  x

@[rust_export]
def add_u64 (a b : UInt64) : UInt64 :=
  a + b

@[rust_export]
def inc_u32 (x : UInt32) : UInt32 :=
  x + 1

@[rust_export]
def inc_twice_u32 (x : UInt32) : UInt32 :=
  inc_u32 (inc_u32 x)

def helper_inc_fixed (x : UInt32) : UInt32 :=
  x + 1

@[rust_export]
def helper_chain_u32 (x : UInt32) : UInt32 :=
  helper_inc_fixed (helper_inc_fixed x)

@[rust_export]
def proof_erased_u32 (x : UInt32) (_h : x = x) : UInt32 :=
  x

@[rust_export]
def unit_roundtrip (x : Unit) : Unit :=
  x

@[rust_export]
def bool_match_u32 (flag : Bool) (when_true when_false : UInt32) : UInt32 :=
  match flag with
  | true => when_true
  | false => when_false

@[rust_export]
def option_identity_u32 (x : Option UInt32) : Option UInt32 :=
  x

@[rust_export]
def none_u32 (_x : Unit) : Option UInt32 :=
  none

@[rust_export]
def some_u32 (x : UInt32) : Option UInt32 :=
  some x

@[rust_export]
def option_default_u32 (x : Option UInt32) (fallback : UInt32) : UInt32 :=
  match x with
  | none => fallback
  | some value => value

@[rust_export]
def result_ok_u32 (x : UInt32) : Except UInt32 UInt32 :=
  Except.ok x

@[rust_export]
def result_err_u32 (e : UInt32) : Except UInt32 UInt32 :=
  Except.error e

@[rust_export]
def choose_by_enum (choice : Choice) (left right : UInt32) : UInt32 :=
  match choice with
  | Choice.first => left
  | Choice.second => right

@[rust_export]
def make_point (x y : UInt32) : Point :=
  { x := x, y := y }

@[rust_export]
def point_x (p : Point) : UInt32 :=
  p.x

@[rust_export]
def point_y (p : Point) : UInt32 :=
  p.y

@[rust_export]
def shift_point_x (p : Point) (dx : UInt32) : Point :=
  { x := p.x + dx, y := p.y }

@[rust_export]
def boxed_u32 (x : UInt32) : Boxed UInt32 :=
  { value := x }

@[rust_export]
def boxed_value_u32 (b : Boxed UInt32) : UInt32 :=
  b.value

@[rust_export]
def tagged_missing_u32 (_x : Unit) : Tagged UInt32 :=
  Tagged.missing

@[rust_export]
def tagged_present_u32 (x : UInt32) : Tagged UInt32 :=
  Tagged.present x

@[rust_export]
def tagged_default_u32 (t : Tagged UInt32) (fallback : UInt32) : UInt32 :=
  match t with
  | Tagged.missing => fallback
  | Tagged.present value => value

@[rust_export]
def pair_box_make_u32_string (x : UInt32) (label : String) :
    PairBox UInt32 String :=
  { left := x, right := label }

@[rust_export]
def pair_box_swap_u32_string
    (pair : PairBox UInt32 String) :
    PairBox String UInt32 :=
  { left := pair.right, right := pair.left }

@[rust_export]
def pair_choice_left_u32_string (x : UInt32) :
    PairChoice UInt32 String :=
  .left x

@[rust_export]
def pair_choice_default_u32_string
    (choice : PairChoice UInt32 String)
    (fallback : UInt32) : UInt32 :=
  PairChoice.casesOn choice (fun value => value) (fun _ => fallback)

@[rust_export]
def nested_payload_ok_u32_string (x : UInt32) :
    NestedPayload UInt32 String :=
  { primary := some x, secondary := Except.ok x }

@[rust_export]
def nested_payload_err_u32_string (message : String) (fallback : UInt32) :
    NestedPayload UInt32 String :=
  { primary := some fallback, secondary := Except.error message }

@[rust_export]
def nested_payload_value_or_u32_string
    (payload : NestedPayload UInt32 String)
    (fallback : UInt32) : UInt32 :=
  Option.casesOn payload.primary fallback (fun value => value)

@[rust_export]
def step_stay (_x : Unit) : Step :=
  Step.stay

@[rust_export]
def step_jump (amount : UInt32) : Step :=
  Step.jump amount

@[rust_export]
def step_amount_or (s : Step) (fallback : UInt32) : UInt32 :=
  match s with
  | Step.stay => fallback
  | Step.jump amount => amount

@[rust_export]
def step_amount_plus_one_or (s : Step) (fallback : UInt32) : UInt32 :=
  match s with
  | Step.stay => fallback
  | Step.jump amount => amount + 1

@[rust_export]
def nested_none_u32 (_x : Unit) : Option (Option UInt32) :=
  some none

@[rust_export]
def result_ok_none_u32 (_x : Unit) : Except UInt32 (Option UInt32) :=
  Except.ok none

@[rust_export]
def result_err_some_u32 (e : UInt32) : Except (Option UInt32) UInt32 :=
  Except.error (some e)

/-- A generic source function. It is exported only through explicit concrete monomorphizations. -/
def generic_identity (α : Type) (x : α) : α :=
  x

/-- A generic source function whose concrete instances become Rust functions. -/
def generic_choose (α : Type) (flag : Bool) (when_true when_false : α) : α :=
  if flag then when_true else when_false

/-- A generic source function with an `Option` argument. -/
def generic_option_default (α : Type) (x : Option α) (fallback : α) : α :=
  match x with
  | none => fallback
  | some value => value

/-- A generic source function that exercises erased resolved typeclass dictionaries. -/
def generic_beq (α : Type) [BEq α] (a b : α) : Bool :=
  a == b

rust_mono_export generic_identity as identity_u64 [UInt64]
rust_mono_export generic_choose as choose_generic_u32 [UInt32]
rust_mono_export generic_option_default as option_default_u64 [UInt64]
rust_mono_export generic_beq as generic_beq_u32 [UInt32]

/-- A concrete exported declaration that triggers automatic monomorphization of `generic_identity`. -/
@[rust_export]
def auto_identity_u32 (x : UInt32) : UInt32 :=
  generic_identity UInt32 x

/-- A concrete exported declaration that triggers automatic monomorphization of a generic function over a struct. -/
@[rust_export]
def auto_choose_point (flag : Bool) (left right : Point) : Point :=
  generic_choose Point flag left right

/-- A concrete exported declaration that triggers automatic monomorphization of a generic function over an enum. -/
@[rust_export]
def auto_option_default_step (x : Option Step) (fallback : Step) : Step :=
  generic_option_default Step x fallback

/-- Demonstrates step 6: unsupported tagged exports are reported and skipped instead of aborting codegen. -/
@[rust_export]
def unsupported_higher_order_u32 (f : UInt32 → UInt32) (x : UInt32) : UInt32 :=
  f x

rust_emit_exports_with_report_and_surface generatedRust generatedCompatibilityReport extractedSurfaceFunctions extractedIRSnapshot

end LeanRustCore.Examples
