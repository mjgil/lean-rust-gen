import LeanRustCore.Export
import LeanRustCore.NumericSemantics

namespace LeanRustCore.NumericExamples

private def optionNatToU32 : Option Nat → Option UInt32
  | some value => some (UInt32.ofNat value)
  | none => none

private def exceptNatToU32 : Except String Nat → Except String UInt32
  | .ok value => .ok (UInt32.ofNat value)
  | .error err => .error err

@[rust_export]
def checked_add_u32 (a b : UInt32) : Option UInt32 :=
  optionNatToU32 (LeanRustCore.NumericSemantics.checkedAddU32 a.toNat b.toNat)

@[rust_export]
def checked_sub_u32 (a b : UInt32) : Option UInt32 :=
  optionNatToU32 (LeanRustCore.NumericSemantics.checkedSubU32 a.toNat b.toNat)

@[rust_export]
def checked_div_u32 (a b : UInt32) : Option UInt32 :=
  if b == 0 then none else some (a / b)

@[rust_export]
def checked_mod_u32 (a b : UInt32) : Option UInt32 :=
  if b == 0 then none else some (a % b)

@[rust_export]
def saturating_add_u32 (a b : UInt32) : UInt32 :=
  UInt32.ofNat (LeanRustCore.NumericSemantics.saturatingAddU32 a.toNat b.toNat)

@[rust_export]
def saturating_sub_u32 (a b : UInt32) : UInt32 :=
  UInt32.ofNat (LeanRustCore.NumericSemantics.saturatingSubU32 a.toNat b.toNat)

@[rust_export]
def preconditioned_div_u32 (a b : UInt32) : Except String UInt32 :=
  exceptNatToU32 (LeanRustCore.NumericSemantics.preconditionedDivU32 a.toNat b.toNat)

@[rust_export]
def preconditioned_mod_u32 (a b : UInt32) : Except String UInt32 :=
  exceptNatToU32 (LeanRustCore.NumericSemantics.preconditionedModU32 a.toNat b.toNat)

@[rust_export]
def checked_cast_u64_to_u32 (x : UInt64) : Option UInt32 :=
  if x.toNat < LeanRustCore.u32Modulus then
    some (UInt32.ofNat x.toNat)
  else
    none

end LeanRustCore.NumericExamples
