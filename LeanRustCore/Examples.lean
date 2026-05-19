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
matching in this path.
-/

@[rust_export]
def clamp_u32 (lo hi x : Nat) : Nat :=
  if x < lo then lo else if x > hi then hi else x

@[rust_export]
def max_u32 (a b : Nat) : Nat :=
  if a < b then b else a

@[rust_export]
def is_nonzero_u32 (x : Nat) : Bool :=
  if x = 0 then false else true

@[rust_export]
def add_u32 (a b : Nat) : Nat :=
  a + b

@[rust_export]
def mul_u32 (a b : Nat) : Nat :=
  a * b

@[rust_export]
def bounded_bump_u32 (x : Nat) : Nat :=
  let y := x + 1
  if y > 10 then 10 else y

rust_emit_exports generatedRust

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

/-- Proof-carrying examples retained for evaluator/codegen regression checks. -/
def proofCarryingFunctions : List RFun := [
  { Ctx := ClampArgs, name := "clamp_u32", args := [("lo", .u32), ("hi", .u32), ("x", .u32)], ret := .u32, body := clampBody },
  { Ctx := MaxArgs, name := "max_u32", args := [("a", .u32), ("b", .u32)], ret := .u32, body := maxBody },
  { Ctx := NonzeroArgs, name := "is_nonzero_u32", args := [("x", .u32)], ret := .bool, body := nonzeroBody },
  { Ctx := AddArgs, name := "add_u32", args := [("a", .u32), ("b", .u32)], ret := .u32, body := addBody },
  { Ctx := BumpArgs, name := "bounded_bump_u32", args := [("x", .u32)], ret := .u32, body := boundedBumpBody }
]

/-- Rust source emitted from proof-carrying examples; used as a regression oracle. -/
def generatedRustFromTypedIR : String :=
  emitRustModule proofCarryingFunctions

end LeanRustCore.Examples
