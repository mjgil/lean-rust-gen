import Lean

namespace LeanRustCore.Export

open Lean

/-- Marks an ordinary Lean definition for the direct Lean→Rust extractor. -/
initialize rustExportAttr : TagAttribute ←
  registerTagAttribute `rust_export "export this elaborated Lean declaration to Rust"

/-- Exported declaration names in deterministic environment order. -/
def exportedNames (env : Environment) : List Name :=
  rustExportAttr.getTagged env |>.toList

end LeanRustCore.Export
