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

/-- Exported declaration names in deterministic environment order. -/
def exportedNames (env : Environment) : List Name :=
  rustExportAttr.getTagged env |>.toList

private def containsTaggedName (declName : Name) : List Name → Bool
  | [] => false
  | tagged :: rest => tagged == declName || containsTaggedName declName rest

/-- Whether an exported declaration has opted into `Nat` → wrapping `u32`. -/
def natWrappingU32Allowed (env : Environment) (decl : Name) : Bool :=
  containsTaggedName decl (rustNatWrappingU32Attr.getTagged env |>.toList)

end LeanRustCore.Export
