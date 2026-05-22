import Lean

namespace LeanRustCore.Export

open Lean

/-- Marks an ordinary Lean definition for the direct Lean→Rust extractor. -/
initialize rustExportAttr : TagAttribute ←
  registerTagAttribute `rust_export "export this elaborated Lean declaration to Rust"

/--
Opt-in marker allowing an exported Lean `Nat` boundary to be interpreted as a
Rust `u32` with wrapping arithmetic.  This keeps exact mathematical `Nat` from
being silently collapsed to fixed-width Rust unless the source declaration makes
that policy explicit.
-/
initialize rustNatWrappingU32Attr : TagAttribute ←
  registerTagAttribute `rust_nat_wrapping_u32 "allow this rust_export declaration to lower Nat boundaries to wrapping Rust u32"

/-- Opt-in marker lowering Lean `Nat` with exact mathematical semantics. -/
initialize rustNatExactAttr : TagAttribute ←
  registerTagAttribute `rust_nat_exact "allow this rust_export declaration to lower Nat boundaries to exact Rust BigUint values"

/-- Opt-in marker lowering Lean `Int` with exact mathematical semantics. -/
initialize rustIntExactAttr : TagAttribute ←
  registerTagAttribute `rust_int_exact "allow this rust_export declaration to lower Int boundaries to exact Rust BigInt values"

/-- Exported declaration names in deterministic environment order. -/
def exportedNames (env : Environment) : List Name :=
  let tagged := rustExportAttr.ext.getState env
  let names := tagged.fold (fun acc declName => acc.push declName) #[]
  names.qsort Name.quickLt |>.toList

/-- Whether an exported declaration has opted into `Nat` → wrapping `u32`. -/
def natWrappingU32Allowed (env : Environment) (decl : Name) : Bool :=
  rustNatWrappingU32Attr.hasTag env decl

/-- Whether an exported declaration has opted into exact `Nat` lowering. -/
def natExactAllowed (env : Environment) (decl : Name) : Bool :=
  rustNatExactAttr.hasTag env decl

/-- Whether an exported declaration has opted into exact `Int` lowering. -/
def intExactAllowed (env : Environment) (decl : Name) : Bool :=
  rustIntExactAttr.hasTag env decl

end LeanRustCore.Export
