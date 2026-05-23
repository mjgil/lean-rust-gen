import Lean

namespace LeanRustCore.Diagnostics

/-!
Task 43 user-facing diagnostic templates.

Every unsupported construct should have a stable code, source declaration,
construct kind, next feature, and a documentation link.  The negative corpus
snapshots these codes so wording changes are intentional.
-/

inductive DiagnosticSeverity where
  | info
  | warning
  | unsupported
  | error
  deriving Repr, BEq, DecidableEq

structure DiagnosticTemplate where
  code : String
  severity : DiagnosticSeverity
  construct : String
  nextFeature : String
  documentation : String
  deriving Repr, BEq

/-- Stable diagnostic templates used by the negative/unsupported corpus. -/
def templates : List DiagnosticTemplate := [
  { code := "LRC001", severity := .unsupported, construct := "unresolved typeclass dictionary", nextFeature := "generated typeclass dictionaries", documentation := "docs/DIAGNOSTICS.md#lrc001" },
  { code := "LRC002", severity := .unsupported, construct := "dependent runtime match", nextFeature := "dependent erasure checker", documentation := "docs/DIAGNOSTICS.md#lrc002" },
  { code := "LRC003", severity := .unsupported, construct := "escaping captured closure", nextFeature := "first-class closure object", documentation := "docs/DIAGNOSTICS.md#lrc003" },
  { code := "LRC004", severity := .unsupported, construct := "IO or external effect", nextFeature := "controlled IO boundary", documentation := "docs/DIAGNOSTICS.md#lrc004" },
  { code := "LRC005", severity := .error, construct := "Rust hygiene collision", nextFeature := "rename source declaration or binder", documentation := "docs/DIAGNOSTICS.md#lrc005" }
]

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Human-readable summary for validation/proof reports. -/
def diagnosticSummary : String :=
  "user-facing diagnostics use stable LRC codes with source declaration, construct kind, next feature, and docs: " ++
  joinWithLocal ", " (templates.map (fun template => template.code))

end LeanRustCore.Diagnostics
