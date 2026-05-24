import LeanRustCore.Extract

namespace LeanRustCore.ClosureLoweringExamples

open LeanRustCore
open LeanRustCore.Extract

/-- Explicit closure-converted environment used by the closure examples. -/
structure AddDeltaU32Env where
  delta : UInt32

/-- Finite defunctionalized family for selected UInt32 unary functions. -/
inductive U32FnCase where
  | inc
  | double
  | add (delta : UInt32)

/-- Higher-order helper used by source-level passed-closure examples. -/
def apply_closure_u32 (f : UInt32 → UInt32) (x : UInt32) : UInt32 :=
  f x

/-- Higher-order helper used by source-level returned-closure examples. -/
def make_add_delta_u32 (delta : UInt32) : UInt32 → UInt32 :=
  fun value => value + delta

/-- Higher-order helper used by multi-argument passed-closure examples. -/
def apply_binary_closure_u32 (f : UInt32 → UInt32 → UInt32) (x y : UInt32) : UInt32 :=
  f x y

/-- Higher-order helper used by multi-argument returned-closure examples. -/
def make_add_pair_u32 (a b : UInt32) : UInt32 → UInt32 → UInt32 :=
  fun x y => x + y + a + b

end LeanRustCore.ClosureLoweringExamples
