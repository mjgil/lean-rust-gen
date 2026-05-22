import LeanRustCore.TargetValidation
import LeanRustCore.EmitRust
import LeanRustCore.RecursiveData
import LeanRustCore.Toolchain

namespace LeanRustCore.ValidationV2

open LeanRustCore
open LeanRustCore.Toolchain

/-!
Sprint 16 validation-v2 metadata.

This module centralizes the machine-readable coverage dashboard that accompanies
`target-validation.txt` v2. It intentionally stays lightweight: the semantic
validation test still reconstructs generated Rust with `syn`, while the dashboard
records which large-subset families are expected to be covered by the current
artifact set.
-/

structure CoverageEntry where
  feature : String
  status : String
  examples : List String
  deriving Repr, BEq

private def jsonEscapeChar : Char → String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | c => String.singleton c

private def jsonEscape (s : String) : String :=
  joinWith "" (s.toList.map jsonEscapeChar)

private def jsonString (s : String) : String :=
  "\"" ++ jsonEscape s ++ "\""

private def jsonArray (items : List String) : String :=
  "[" ++ joinWith ", " (items.map jsonString) ++ "]"

def coverageEntries : List CoverageEntry := [
  { feature := "recursive-owned-box-data", status := "supported-known-slice", examples := ["BinaryTreeU32", "ExprU32", "tree_size_u32", "expr_eval_u32"] },
  { feature := "target-validation-v2", status := "supported", examples := ["FORMAT lean-rust-core.target-validation.v2", "box/deref fingerprints"] },
  { feature := "property-seed-validation", status := "supported-deterministic-seeds", examples := ["recursive tree size/sum", "expression evaluation", "closure/defun regression"] },
  { feature := "coverage-dashboard", status := "supported", examples := ["rust/coverage-dashboard.json"] }
]

private def coverageEntryJson (entry : CoverageEntry) : String :=
  "    { \"feature\": " ++ jsonString entry.feature ++
  ", \"status\": " ++ jsonString entry.status ++
  ", \"examples\": " ++ jsonArray entry.examples ++ " }"

/-- Machine-readable coverage dashboard emitted by `lake exe gen_coverage_dashboard`. -/
def coverageDashboardJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.coverage-dashboard.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": " ++ jsonString leanToolchain ++ ",\n" ++
  "  \"rust_toolchain\": " ++ jsonString rustToolchain ++ ",\n" ++
  "  \"target_validation_format\": " ++ jsonString LeanRustCore.TargetValidation.targetValidationFormat ++ ",\n" ++
  "  \"recursive_data_policy\": " ++ jsonString LeanRustCore.RecursiveData.recursiveDataSummary ++ ",\n" ++
  "  \"entries\": [\n" ++
  joinWith ",\n" (coverageEntries.map coverageEntryJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

/-- Human-readable validation-v2 summary. -/
def validationV2Summary : String :=
  "target-validation v2 records box/deref fingerprints for recursive data, and rust/coverage-dashboard.json records feature-family coverage from the same trusted metadata surface"

end LeanRustCore.ValidationV2
