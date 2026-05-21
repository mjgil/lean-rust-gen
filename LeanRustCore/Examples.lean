import LeanRustCore.IR
import LeanRustCore.EmitRust
import LeanRustCore.Extract

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

inductive Tagged (α : Type) where
  | missing
  | present (value : α)

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

rust_mono_export generic_identity as identity_u64 [UInt64]
rust_mono_export generic_choose as choose_generic_u32 [UInt32]
rust_mono_export generic_option_default as option_default_u64 [UInt64]

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

rust_emit_exports_with_report_and_surface generatedRust generatedCompatibilityReport extractedSurfaceFunctions

/-!
## Proof-carrying IR examples

The direct generator above uses elaborated Lean declarations. These IR examples
remain in the repo as the checked semantic model and as regression fixtures for
feature family growth.
-/

structure ClampArgs where
  lo : Nat
  hi : Nat
  x : Nat

private def vLo : RExpr ClampArgs .u32 := .var "lo" (fun a => a.lo)
private def vHi : RExpr ClampArgs .u32 := .var "hi" (fun a => a.hi)
private def vX  : RExpr ClampArgs .u32 := .var "x"  (fun a => a.x)

def clampBody : RExpr ClampArgs .u32 :=
  .ite (.ltU32 vX vLo)
    vLo
    (.ite (.gtU32 vX vHi) vHi vX)

def clampSpec (a : ClampArgs) : Nat :=
  if decide (a.x < a.lo) then a.lo else if decide (a.x > a.hi) then a.hi else a.x

theorem clamp_refines_spec (a : ClampArgs) :
  eval clampBody a = clampSpec a := by
  simp [clampBody, clampSpec, vLo, vHi, vX, eval]

structure MaxArgs where
  a : Nat
  b : Nat

private def vA : RExpr MaxArgs .u32 := .var "a" (fun x => x.a)
private def vB : RExpr MaxArgs .u32 := .var "b" (fun x => x.b)

def maxBody : RExpr MaxArgs .u32 :=
  .maxU32 vA vB

def maxSpec (x : MaxArgs) : Nat :=
  if decide (x.a < x.b) then x.b else x.a

theorem max_refines_spec (x : MaxArgs) :
  eval maxBody x = maxSpec x := by
  simp [maxBody, maxSpec, vA, vB, eval]

structure NonzeroArgs where
  x : Nat

private def nzX : RExpr NonzeroArgs .u32 := .var "x" (fun a => a.x)

def nonzeroBody : RExpr NonzeroArgs .bool :=
  .not (.eqU32 nzX (.litU32 0))

def nonzeroSpec (a : NonzeroArgs) : Bool :=
  !(decide (a.x = 0))

theorem nonzero_refines_spec (a : NonzeroArgs) :
  eval nonzeroBody a = nonzeroSpec a := by
  simp [nonzeroBody, nonzeroSpec, nzX, eval]

structure AddArgs where
  a : Nat
  b : Nat

private def addA : RExpr AddArgs .u32 := .var "a" (fun x => x.a)
private def addB : RExpr AddArgs .u32 := .var "b" (fun x => x.b)

def addBody : RExpr AddArgs .u32 :=
  .addU32 addA addB

def addSpec (x : AddArgs) : Nat :=
  u32Wrap (x.a + x.b)

theorem add_refines_wrapping_spec (x : AddArgs) :
  eval addBody x = addSpec x := by
  simp [addBody, addSpec, addA, addB, eval, u32Wrap]

structure BumpArgs where
  x : Nat

private def bumpX : RExpr BumpArgs .u32 := .var "x" (fun a => a.x)
private def bumpY : RExpr (Nat × BumpArgs) .u32 := .var "y" (fun env => env.1)

def boundedBumpBody : RExpr BumpArgs .u32 :=
  .letIn "y" (.addU32 bumpX (.litU32 1))
    (.ite (.gtU32 bumpY (.litU32 10)) (.litU32 10) bumpY)

def boundedBumpSpec (a : BumpArgs) : Nat :=
  let y := u32Wrap (a.x + 1)
  if decide (y > 10) then 10 else y

theorem bounded_bump_refines_spec (a : BumpArgs) :
  eval boundedBumpBody a = boundedBumpSpec a := by
  simp [boundedBumpBody, boundedBumpSpec, bumpX, bumpY, eval, u32Wrap]

structure OptionArgs where
  x : Option Nat
  fallback : Nat

private def optX : RExpr OptionArgs (.option .u32) := .var "x" (fun a => a.x)
private def optFallback : RExpr OptionArgs .u32 := .var "fallback" (fun a => a.fallback)
private def optValue : RExpr (Nat × OptionArgs) .u32 := .var "value" (fun env => env.1)

def optionDefaultBody : RExpr OptionArgs .u32 :=
  .matchOption optX optFallback optValue

def optionDefaultSpec (a : OptionArgs) : Nat :=
  match a.x with
  | none => a.fallback
  | some value => value

theorem option_default_refines_spec (a : OptionArgs) :
  eval optionDefaultBody a = optionDefaultSpec a := by
  cases a.x <;> simp [optionDefaultBody, optionDefaultSpec, optX, optFallback, optValue, eval]

/-- Proof-carrying examples retained for evaluator/codegen regression checks. -/
def proofCarryingFunctions : List RFun := [
  { Ctx := ClampArgs, name := "clamp_u32", args := [("lo", .u32), ("hi", .u32), ("x", .u32)], ret := .u32, body := clampBody },
  { Ctx := MaxArgs, name := "max_u32", args := [("a", .u32), ("b", .u32)], ret := .u32, body := maxBody },
  { Ctx := NonzeroArgs, name := "is_nonzero_u32", args := [("x", .u32)], ret := .bool, body := nonzeroBody },
  { Ctx := AddArgs, name := "add_u32", args := [("a", .u32), ("b", .u32)], ret := .u32, body := addBody },
  { Ctx := BumpArgs, name := "bounded_bump_u32", args := [("x", .u32)], ret := .u32, body := boundedBumpBody },
  { Ctx := OptionArgs, name := "option_default_u32", args := [("x", .option .u32), ("fallback", .u32)], ret := .u32, body := optionDefaultBody }
]

/-- Rust source emitted from proof-carrying examples; used as a regression oracle. -/
def generatedRustFromTypedIR : String :=
  emitRustModule proofCarryingFunctions

end LeanRustCore.Examples
