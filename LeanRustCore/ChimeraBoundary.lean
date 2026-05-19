import Lean

namespace LeanRustCore.ChimeraBoundary

/-!
A small, self-contained Chimera/RustAdapter-inspired boundary model.

This is not the main compiler. The main app is direct Lean → Rust. This module
only keeps the FFI/result-lowering rules that are useful when an emitted Rust
function is later exposed through a raw ABI boundary.
-/

inductive Ownership where
  | borrow
  | owned
  deriving Repr, BEq, DecidableEq

inductive ChType where
  | unit
  | bool
  | i32
  | u32
  | u64
  | status
  | ptr : ChType → ChType
  | owned : ChType → ChType
  | slice : ChType → Ownership → ChType
  | str
  | result : ChType → ChType → ChType
  deriving Repr, BEq, DecidableEq

namespace ChType

/-- Primitive types accepted directly at the boundary. -/
def isPrimitive : ChType → Bool
  | .bool | .i32 | .u32 | .u64 | .status => true
  | _ => false

/-- C-compatible values in this first pass. -/
def isCCompatible : ChType → Bool
  | .unit | .bool | .i32 | .u32 | .u64 | .status | .ptr _ => true
  | _ => false

end ChType

inductive RustAdapterRule where
  | noNativeRustTypes
  | reprCRequired
  | noDynamicDispatch
  | resultLowering
  | panicPolicyRespected
  deriving Repr, BEq, DecidableEq

structure RustAdapter where
  rules : List RustAdapterRule
  deriving Repr, BEq

namespace RustAdapter

def default : RustAdapter := {
  rules := [.noNativeRustTypes, .reprCRequired, .noDynamicDispatch, .resultLowering, .panicPolicyRespected]
}

/-- Check whether a semantic boundary type may cross raw Rust FFI directly. -/
def isAllowedType (_adapter : RustAdapter) : ChType → Bool
  | .owned _ => false
  | .slice _ _ => false
  | .str => false
  | .result _ _ => true
  | ty => ty.isPrimitive || ty.isCCompatible

theorem primitive_allowed (adapter : RustAdapter) :
  adapter.isAllowedType .i32 = true := by
  simp [isAllowedType, ChType.isPrimitive, ChType.isCCompatible]

theorem owned_rejected (adapter : RustAdapter) :
  adapter.isAllowedType (.owned .u32) = false := by
  simp [isAllowedType]

theorem slice_rejected (adapter : RustAdapter) :
  adapter.isAllowedType (.slice .u32 .borrow) = false := by
  simp [isAllowedType]

end RustAdapter

inductive PanicPolicy where
  | abort
  | catchUnwind
  | forbidden
  deriving Repr, BEq, DecidableEq

inductive PhysicalType where
  | void
  | i32
  | u32
  | u64
  | ptr
  deriving Repr, BEq, DecidableEq

structure PhysicalSignature where
  params : List PhysicalType
  ret : PhysicalType
  deriving Repr, BEq

def lowerType : ChType → Except String PhysicalType
  | .unit => .ok .void
  | .bool => .ok .u32
  | .i32 => .ok .i32
  | .u32 => .ok .u32
  | .u64 => .ok .u64
  | .status => .ok .i32
  | .ptr _ => .ok .ptr
  | .owned _ => .error "owned value must lower through a handle before FFI"
  | .slice _ _ => .error "slice cannot cross raw FFI directly"
  | .str => .error "string cannot cross raw FFI directly"
  | .result _ _ => .error "Result must be lowered with lowerResultSignature"

/-- Result lowering: `Result<T,E>` becomes `i32 status + out_ok + out_err`. -/
def lowerResultSignature (ok err : ChType) (params : List ChType) : Except String PhysicalSignature := do
  let _okPhys ← lowerType ok
  let _errPhys ← lowerType err
  let loweredParams ← params.mapM lowerType
  pure { params := [.ptr, .ptr] ++ loweredParams, ret := .i32 }

theorem result_u32_i32_uses_status_and_out_params :
  lowerResultSignature .u32 .i32 [] = .ok { params := [.ptr, .ptr], ret := .i32 } := by
  rfl

end LeanRustCore.ChimeraBoundary
