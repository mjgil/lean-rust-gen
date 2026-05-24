import LeanRustCore.IR
import LeanRustCore.EmitRust

namespace LeanRustCore.Examples

structure ClampArgs where
  lo : Nat
  hi : Nat
  x : Nat

private def vLo : RExpr ClampArgs .u32 := .var "lo" (fun a => a.lo)
private def vHi : RExpr ClampArgs .u32 := .var "hi" (fun a => a.hi)
private def vX : RExpr ClampArgs .u32 := .var "x" (fun a => a.x)

def clampBody : RExpr ClampArgs .u32 :=
  .ite (.ltU32 vX vLo)
    vLo
    (.ite (.gtU32 vX vHi) vHi vX)

def clampSpec (a : ClampArgs) : Nat :=
  if decide (a.x < a.lo) then a.lo else if decide (a.x > a.hi) then a.hi else a.x

theorem clamp_refines_spec (a : ClampArgs) :
  eval clampBody a = clampSpec a := by
  by_cases hLo : a.x < a.lo
  · simp [clampBody, clampSpec, vLo, vHi, vX, eval, hLo]
  · by_cases hHi : a.hi < a.x
    · simp [clampBody, clampSpec, vLo, vHi, vX, eval, hLo, hHi]
    · simp [clampBody, clampSpec, vLo, vHi, vX, eval, hLo, hHi]

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
  simp [nonzeroBody, nonzeroSpec, nzX, eval, u32Wrap]

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
  have hTen : 10 % u32Modulus = 10 := by
    native_decide
  by_cases h : 10 < (a.x + 1) % u32Modulus
  · simp [boundedBumpBody, boundedBumpSpec, bumpX, bumpY, eval, u32Wrap, h, hTen]
  · simp [boundedBumpBody, boundedBumpSpec, bumpX, bumpY, eval, u32Wrap, h, hTen]

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
  cases a with
  | mk x fallback =>
      cases x <;> simp [optionDefaultBody, optionDefaultSpec, optX, optFallback, optValue, eval]

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
