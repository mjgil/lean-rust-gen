import Lean

namespace LeanRustCore.Diagnostics

/-!
User-facing diagnostic templates and source-span metadata.

A feature cannot be marked complete unless unsupported constructs receive a
stable diagnostic code, a source declaration, source location metadata when Lean
can provide it, a next-feature hint, tests, and documentation.
-/

inductive DiagnosticSeverity where
  | info
  | warning
  | unsupported
  | error
  deriving Repr, BEq, DecidableEq

/-- A 1-based source position if Lean metadata can provide it. -/
structure SourcePos where
  line : Nat
  column : Nat
  deriving Repr, BEq

/-- Source span attached to diagnostics; `available = false` records a stable fallback. -/
structure SourceSpan where
  source : String
  file : Option String
  start? : Option SourcePos
  stop? : Option SourcePos
  available : Bool
  deriving Repr, BEq

namespace SourceSpan

/-- Fallback span used when an elaborated declaration has no source range metadata. -/
def unknown (source : String) : SourceSpan :=
  { source := source, file := none, start? := none, stop? := none, available := false }

/-- Construct an available source span. -/
def mkKnown (source file : String) (start stop : SourcePos) : SourceSpan :=
  { source := source, file := some file, start? := some start, stop? := some stop, available := true }

end SourceSpan

structure DiagnosticTemplate where
  code : String
  severity : DiagnosticSeverity
  construct : String
  nextFeature : String
  documentation : String
  requiresSpan : Bool
  deriving Repr, BEq

/-- A concrete diagnostic instance emitted by extraction/lowering. -/
structure DiagnosticInstance where
  template : DiagnosticTemplate
  sourceDecl : String
  span : SourceSpan
  detail : String
  deriving Repr, BEq

/-- Stable diagnostic templates used by the negative/unsupported corpus. -/
def templates : List DiagnosticTemplate := [
  { code := "LRC001", severity := .unsupported, construct := "unresolved typeclass dictionary", nextFeature := "generated typeclass dictionaries", documentation := "docs/DIAGNOSTICS.md#lrc001", requiresSpan := true },
  { code := "LRC002", severity := .unsupported, construct := "dependent runtime match", nextFeature := "dependent erasure checker", documentation := "docs/DIAGNOSTICS.md#lrc002", requiresSpan := true },
  { code := "LRC003", severity := .unsupported, construct := "escaping captured closure", nextFeature := "first-class closure object", documentation := "docs/DIAGNOSTICS.md#lrc003", requiresSpan := true },
  { code := "LRC004", severity := .unsupported, construct := "IO or external effect", nextFeature := "controlled IO boundary", documentation := "docs/DIAGNOSTICS.md#lrc004", requiresSpan := true },
  { code := "LRC005", severity := .error, construct := "Rust hygiene collision", nextFeature := "rename source declaration or binder", documentation := "docs/DIAGNOSTICS.md#lrc005", requiresSpan := false },
  { code := "LRC006", severity := .unsupported, construct := "unsupported recursor or equation compiler shape", nextFeature := "general recursion lowering", documentation := "docs/DIAGNOSTICS.md#lrc006", requiresSpan := true },
  { code := "LRC007", severity := .unsupported, construct := "unsupported Std or library constant", nextFeature := "Std lowering table implementation", documentation := "docs/DIAGNOSTICS.md#lrc007", requiresSpan := true },
  { code := "LRC008", severity := .unsupported, construct := "non-erasable proof or proposition dependency", nextFeature := "dependent erasure proof classifier", documentation := "docs/DIAGNOSTICS.md#lrc008", requiresSpan := true },
  { code := "LRC009", severity := .unsupported, construct := "unsupported numeric cast or arithmetic mode", nextFeature := "numeric semantics matrix", documentation := "docs/DIAGNOSTICS.md#lrc009", requiresSpan := true },
  { code := "LRC010", severity := .unsupported, construct := "unsupported closure representation", nextFeature := "closure object lowering", documentation := "docs/DIAGNOSTICS.md#lrc010", requiresSpan := true },
  { code := "LRC011", severity := .unsupported, construct := "recursive data layout failure", nextFeature := "recursive inductive SCC layout", documentation := "docs/DIAGNOSTICS.md#lrc011", requiresSpan := true },
  { code := "LRC012", severity := .unsupported, construct := "FFI ABI rejection", nextFeature := "opaque handle ABI layer", documentation := "docs/DIAGNOSTICS.md#lrc012", requiresSpan := false },
  { code := "LRC013", severity := .unsupported, construct := "unsupported polymorphic Rust generic emission", nextFeature := "Rust generic emission policy", documentation := "docs/DIAGNOSTICS.md#lrc013", requiresSpan := true },
  { code := "LRC014", severity := .unsupported, construct := "unsupported source module or import shape", nextFeature := "module/import lowering", documentation := "docs/DIAGNOSTICS.md#lrc014", requiresSpan := true }
]

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

private def findTemplateAux (code : String) : List DiagnosticTemplate → Option DiagnosticTemplate
  | [] => none
  | template :: rest => if template.code == code then some template else findTemplateAux code rest

/-- Look up a stable diagnostic template by code. -/
def templateFor? (code : String) : Option DiagnosticTemplate :=
  findTemplateAux code templates

/-- Construct a diagnostic instance with a source span or the stable unknown fallback. -/
def instantiate (code sourceDecl detail : String) (span? : Option SourceSpan := none) : Option DiagnosticInstance := do
  let template ← templateFor? code
  pure { template := template, sourceDecl := sourceDecl, span := span?.getD (SourceSpan.unknown sourceDecl), detail := detail }

/-- Human-readable summary for validation/proof reports. -/
def diagnosticSummary : String :=
  "user-facing diagnostics use stable LRC codes, source declarations, source-span metadata when available, construct kind, next feature, and docs: " ++
  joinWithLocal ", " (templates.map (fun template => template.code))

/-- Summary for the first-20 source-span completion checkpoint. -/
def sourceSpanSummary : String :=
  "diagnostics carry SourceSpan metadata with known file/range when available and a stable unknown-span fallback when Lean elaboration metadata lacks a range"

end LeanRustCore.Diagnostics
