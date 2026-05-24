import LeanRustCore.IR
import LeanRustCore.EmitRust
import LeanRustCore.Extract

namespace LeanRustCore.RecursionExamples

open LeanRustCore
open LeanRustCore.Extract

def list_head_or_zero_u32 (xs : List UInt32) : UInt32 :=
  match xs with
  | [] => 0
  | head :: _ => head

def list_second_or_zero_u32 (xs : List UInt32) : UInt32 :=
  match xs with
  | _ :: second :: _ => second
  | _ => 0

def nat_pred_or_zero_u32 (n : Nat) : Nat :=
  match n with
  | 0 => 0
  | Nat.succ pred => pred

def nat_two_step_or_zero_u32 (n : Nat) : Nat :=
  match n with
  | Nat.succ (Nat.succ k) => k + 2
  | _ => 0

def list_length_u32 (xs : List UInt32) : Nat :=
  xs.length

/-- Recognized tail-recursive Nat accumulator lane used by the Sprint-5/6 loop-lowering gate. -/
def tail_sum_down_u32 (n : Nat) : Nat :=
  Nat.rec 0 (fun k acc => acc + (n - k)) n

def nat_sum_to_u32 (n : Nat) : Nat :=
  Nat.rec 0 (fun k acc => acc + k) n

def gcd_u32 (a b : Nat) : Nat :=
  Nat.gcd a b

def reverse_accum_u32 (xs acc : List UInt32) : List UInt32 :=
  match xs with
  | [] => acc
  | head :: tail => reverse_accum_u32 tail (head :: acc)

mutual
  def mutual_even_u32 (n : Nat) : Bool :=
    match n with
    | 0 => true
    | Nat.succ k => mutual_odd_u32 k

  def mutual_odd_u32 (n : Nat) : Bool :=
    match n with
    | 0 => false
    | Nat.succ k => mutual_even_u32 k
end

end LeanRustCore.RecursionExamples
