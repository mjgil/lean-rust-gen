import LeanRustCore.TargetValidation
import LeanRustCore.EmitRust
import LeanRustCore.RecursiveData
import LeanRustCore.Toolchain
import LeanRustCore.PropertyCorpus
import LeanRustCore.CoverageDashboard
import LeanRustCore.Diagnostics
import LeanRustCore.CrateDesign
import LeanRustCore.ReleaseMatrix

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
  { feature := "extract-ir-pipeline", status := "supported-first20", examples := ["LeanRustCore.ExtractIR", "lowerExpr?", "DeclarationMetadata"] },
  { feature := "runtime-value-denotation", status := "supported-first20", examples := ["RuntimeValue", "runtimeValueHasType", "docs/RUNTIME_SEMANTICS.md"] },
  { feature := "expanded-diagnostics", status := "supported-first20", examples := ["LRC001-LRC014", "SourceSpan", "docs/DIAGNOSTICS.md"] },
  { feature := "source-span-diagnostics", status := "supported-first20", examples := ["DiagnosticInstance", "SourceSpan.unknown", "corpus negative fixtures"] },
  { feature := "first20-completion", status := "supported-scripted-gate", examples := ["scripts/check-first-20-completion.py", "rust/tests/first20_completion.rs", "positive/negative/unsupported corpus"] },
  { feature := "recursive-owned-box-data", status := "supported-known-slice", examples := ["BinaryTreeU32", "ExprU32", "tree_size_u32", "expr_eval_u32"] },
  { feature := "target-validation-v2", status := "supported", examples := ["FORMAT lean-rust-core.target-validation.v2", "box/deref fingerprints"] },
  { feature := "property-seed-validation", status := "supported-deterministic-seeds", examples := ["recursive tree size/sum", "expression evaluation", "closure/defun regression"] },
  { feature := "coverage-dashboard", status := "supported", examples := ["rust/coverage-dashboard.json"] },
  { feature := "property-fuzz-corpus", status := "supported-deterministic-seeds", examples := ["PropertyCorpus.seedFamilies", "corpus/property/seeds.json", "rust/tests/final16_property_coverage.rs"] },
  { feature := "quantitative-coverage-dashboard", status := "supported-metrics", examples := ["CoverageDashboard.metrics", "explicit denominators", "docs/COVERAGE.md"] },
  { feature := "user-facing-diagnostics", status := "supported-stable-codes", examples := ["Diagnostics.templates", "LRC001-LRC014", "docs/DIAGNOSTICS.md"] },
  { feature := "rust-workspace-crate-split", status := "supported-workspace", examples := ["lean-rust-core-generated", "lean-rust-core-runtime", "lean-rust-core-abi", "lean-rust-core-validate", "lean-rust-core-headers"] },
  { feature := "release-acceptance-matrix", status := "supported-scripted-gates", examples := ["ReleaseMatrix.gates", "scripts/check-final-16-completion.py", "docs/RELEASE_CHECKLIST.md"] }
]

private def coverageEntryJson (entry : CoverageEntry) : String :=
  "    { \"feature\": " ++ jsonString entry.feature ++
  ", \"status\": " ++ jsonString entry.status ++
  ", \"examples\": " ++ jsonArray entry.examples ++ " }"

private def coverageMetricJson (metric : LeanRustCore.CoverageDashboard.CoverageMetric) : String :=
  "    { \"denominator\": " ++ jsonString metric.denominator ++
  ", \"covered\": " ++ Nat.toString metric.covered ++
  ", \"total\": " ++ Nat.toString metric.total ++
  ", \"percent\": " ++ Nat.toString (LeanRustCore.CoverageDashboard.metricPercent metric) ++
  ", \"status\": " ++ jsonString metric.status ++ " }"

/-- Machine-readable coverage dashboard emitted by `lake exe gen_coverage_dashboard`. -/
def coverageDashboardJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.coverage-dashboard.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": " ++ jsonString leanToolchain ++ ",\n" ++
  "  \"rust_toolchain\": " ++ jsonString rustToolchain ++ ",\n" ++
  "  \"target_validation_format\": " ++ jsonString LeanRustCore.TargetValidation.targetValidationFormat ++ ",\n" ++
  "  \"recursive_data_policy\": " ++ jsonString LeanRustCore.RecursiveData.recursiveDataSummary ++ ",\n" ++
  "  \"metrics\": [\n" ++
  joinWith ",\n" (LeanRustCore.CoverageDashboard.metrics.map coverageMetricJson) ++ "\n" ++
  "  ],\n" ++
  "  \"entries\": [\n" ++
  joinWith ",\n" (coverageEntries.map coverageEntryJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

/-- Human-readable validation-v2 summary. -/
def validationV2Summary : String :=
  "target-validation v2 records first-20 ExtractIR/runtime-denotation/diagnostic/source-span completion, box/deref fingerprints, next-20 numeric/pattern/recursion/Std/typeclass/effect/closure/ABI/semantic-validator/preservation coverage and final property/coverage/diagnostic/crate/release coverage, and rust/coverage-dashboard.json records feature-family coverage from the same trusted metadata surface"

end LeanRustCore.ValidationV2