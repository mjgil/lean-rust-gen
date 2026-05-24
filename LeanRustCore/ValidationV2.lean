import LeanRustCore.TargetValidation
import LeanRustCore.EmitRust
import LeanRustCore.RecursiveData
import LeanRustCore.Toolchain
import LeanRustCore.PropertyCorpus
import LeanRustCore.CoverageDashboard
import LeanRustCore.Diagnostics
import LeanRustCore.SurfaceCoverage
import LeanRustCore.CrateDesign
import LeanRustCore.ReleaseMatrix
import LeanRustCore.TypeclassSpecialization
import LeanRustCore.DependentErasureChecker
import LeanRustCore.GenericPolicy
import LeanRustCore.ParameterizedData
import LeanRustCore.GenericEmission
import LeanRustCore.NumericSemantics
import LeanRustCore.RecursiveDiscovery
import LeanRustCore.OwnershipPolicy
import LeanRustCore.PatternMatrix
import LeanRustCore.RecursionAnalysis
import LeanRustCore.StdImplementation
import LeanRustCore.TypeclassDictionaries
import LeanRustCore.FirstClassClosures
import LeanRustCore.PureDoNotation
import LeanRustCore.IOBoundary
import LeanRustCore.CompleteSemantics
import LeanRustCore.Preservation
import LeanRustCore.PropertyGenerators
import LeanRustCore.CoverageCompletion
import LeanRustCore.CIRelease
import LeanRustCore.Publishing
import LeanRustCore.RemainingCompletion

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

structure CoverageEvidence where
  implementation : List String
  tests : List String
  docs : List String
  generatedExamples : List String
  diagnostics : List String
  deriving Repr, BEq

structure CoverageEntry where
  feature : String
  status : String
  examples : List String
  evidence : CoverageEvidence
  deriving Repr, BEq

private def mkEvidence
    (implementation tests docs generatedExamples diagnostics : List String) :
    CoverageEvidence :=
  { implementation, tests, docs, generatedExamples, diagnostics }

private def mkEntry
    (feature status : String)
    (examples implementation tests docs generatedExamples diagnostics : List String) :
    CoverageEntry :=
  { feature, status, examples, evidence := mkEvidence implementation tests docs generatedExamples diagnostics }

def coverageEntryHasRequiredEvidence (entry : CoverageEntry) : Bool :=
  !entry.evidence.implementation.isEmpty &&
  !entry.evidence.tests.isEmpty &&
  !entry.evidence.docs.isEmpty &&
  !entry.evidence.generatedExamples.isEmpty &&
  !entry.evidence.diagnostics.isEmpty

def coverageEntries : List CoverageEntry := [
  mkEntry "recursive-owned-box-data" "supported-known-slice"
    ["BinaryTreeU32", "ExprU32", "RoseTreeU32", "EvenNode", "OddNode", "tree_size_u32", "expr_eval_u32", "rose_branch_u32", "even_step_u32", "odd_step_u32"]
    ["LeanRustCore/RecursiveData.lean", "LeanRustCore/Extract.lean"]
    ["rust/tests/generated.rs", "rust/tests/next20_completion.rs", "rust/tests/validation_report.rs"]
    ["docs/RECURSIVE_DATA.md", "docs/ARCHITECTURE.md"]
    ["rust/src/generated.rs", "rust/target-validation.txt", "corpus/positive/recursive_rose_tree.expected.json", "corpus/positive/recursive_even_odd.expected.json"]
    ["recursive-user-data-box-layout"],
  mkEntry "target-validation-v2" "supported"
    ["FORMAT lean-rust-core.target-validation.v2", "box/deref fingerprints"]
    ["LeanRustCore/TargetValidation.lean", "LeanRustCore/ValidationV2.lean"]
    ["rust/tests/semantic_validation.rs", "rust/tests/validation_report.rs"]
    ["docs/TRUSTED_CORE.md", "docs/ARCHITECTURE.md"]
    ["rust/target-validation.txt", "rust/coverage-dashboard.json"]
    ["target-validation-v2-coverage-dashboard"],
  mkEntry "property-seed-validation" "supported-deterministic-seeds"
    ["recursive tree size/sum", "expression evaluation", "closure/defun regression"]
    ["LeanRustCore/PropertyCorpus.lean"]
    ["rust/tests/final16_property_coverage.rs", "rust/tests/property_validation.rs"]
    ["docs/TESTING.md", "docs/PROPERTY_GENERATORS.md"]
    ["corpus/property/seeds.json", "rust/coverage-dashboard.json"]
    ["property-fuzz-corpus"],
  mkEntry "coverage-dashboard" "supported"
    ["rust/coverage-dashboard.json"]
    ["LeanRustCore/ValidationV2.lean", "LeanRustCore/CoverageDashboard.lean"]
    ["rust/tests/final16_property_coverage.rs", "rust/tests/validation_report.rs"]
    ["docs/COVERAGE.md", "docs/ARCHITECTURE.md"]
    ["rust/coverage-dashboard.json"]
    ["coverage-dashboard-json-parse-validation", "coverage-dashboard-evidence-derived"],
  mkEntry "property-fuzz-corpus" "supported-deterministic-seeds"
    ["PropertyCorpus.seedFamilies", "corpus/property/seeds.json", "rust/tests/final16_property_coverage.rs"]
    ["LeanRustCore/PropertyCorpus.lean"]
    ["rust/tests/final16_property_coverage.rs", "scripts/check-final-16-completion.py"]
    ["docs/TESTING.md", "docs/COVERAGE.md"]
    ["corpus/property/seeds.json", "rust/coverage-dashboard.json"]
    ["property-fuzz-corpus"],
  mkEntry "quantitative-coverage-dashboard" "supported-metrics"
    ["CoverageDashboard.metrics", "explicit denominators", "docs/COVERAGE.md"]
    ["LeanRustCore/CoverageDashboard.lean", "LeanRustCore/CoverageCompletion.lean"]
    ["rust/tests/final16_property_coverage.rs", "scripts/check-final-16-completion.py"]
    ["docs/COVERAGE.md", "docs/COVERAGE_COMPLETION.md"]
    ["rust/coverage-dashboard.json", "rust/proof-report.json"]
    ["quantitative-coverage-dashboard"],
  mkEntry "user-facing-diagnostics" "supported-stable-codes"
    ["Diagnostics.templates", "LRC001-LRC014", "docs/DIAGNOSTICS.md"]
    ["LeanRustCore/Diagnostics.lean"]
    ["rust/tests/final16_diagnostics_and_crates.rs", "rust/tests/next20_completion.rs"]
    ["docs/DIAGNOSTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/compatibility-report.json", "rust/coverage-dashboard.json"]
    ["LRC001", "LRC014", "user-facing-diagnostics"],
  mkEntry "rust-workspace-crate-split" "supported-workspace"
    ["lean-rust-core-generated", "lean-rust-core-runtime", "lean-rust-core-abi", "lean-rust-core-validate", "lean-rust-core-headers"]
    ["LeanRustCore/CrateDesign.lean", "Cargo.toml"]
    ["rust/tests/final16_diagnostics_and_crates.rs", "scripts/check-final-16-completion.py"]
    ["docs/CRATE_DESIGN.md", "docs/ARCHITECTURE.md"]
    ["rust/build-metadata.json", "rust/coverage-dashboard.json"]
    ["rust-workspace-crate-split"],
  mkEntry "release-acceptance-matrix" "supported-scripted-gates"
    ["ReleaseMatrix.gates", "scripts/check-final-16-completion.py", "docs/RELEASE_CHECKLIST.md"]
    ["LeanRustCore/ReleaseMatrix.lean", ".github/workflows/ci.yml"]
    ["scripts/check.sh", "scripts/check-final-16-completion.py"]
    ["docs/RELEASE_CHECKLIST.md", "docs/PUBLISHING.md"]
    ["rust/validation-report.json", "rust/coverage-dashboard.json"]
    ["release-acceptance-matrix"],
  mkEntry "first20-completion" "supported-complete"
    ["ExtractIR", "RuntimeValue", "SurfaceExpr coverage", "expanded diagnostics", "source spans", "CI e2e matrix"]
    ["LeanRustCore/ExtractIR.lean", "LeanRustCore/SurfaceCoverage.lean"]
    ["rust/tests/first20_completion.rs", "scripts/check-first-20-completion.py"]
    ["docs/EXTRACT_IR.md", "docs/RUNTIME_SEMANTICS.md"]
    ["rust/extract-ir.txt", "rust/proof-report.json"]
    ["first20-completion-gate"],
  mkEntry "extract-ir-pipeline" "supported"
    ["DeclarationMetadata", "functionFeatureTags", "extractIRSnapshot"]
    ["LeanRustCore/ExtractIR.lean"]
    ["rust/tests/first20_completion.rs", "scripts/check-first-20-completion.py"]
    ["docs/EXTRACT_IR.md", "docs/ARCHITECTURE.md"]
    ["rust/extract-ir.txt", "rust/validation-report.json"]
    ["extract-ir-pipeline"],
  mkEntry "runtime-value-denotation" "supported"
    ["RuntimeValue", "runtimeValueHasType", "runtimeDenotationSummary"]
    ["LeanRustCore/IR.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/remaining_completion.rs"]
    ["docs/TRUSTED_CORE.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["runtime-value-denotation"],
  mkEntry "surface-expr-node-coverage" "supported"
    ["SurfaceCoverage.surfaceCoverageComplete", "typeOfExpected", "evalSurfaceExpr"]
    ["LeanRustCore/SurfaceCoverage.lean", "LeanRustCore/Surface.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/validation_report.rs"]
    ["docs/RUNTIME_SEMANTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/validation-report.json"]
    ["surface-expr-node-coverage"],
  mkEntry "expanded-diagnostics" "supported"
    ["LRC001-LRC014", "SourceRange", "instanceHasRequiredSpan"]
    ["LeanRustCore/Diagnostics.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/next20_completion.rs"]
    ["docs/DIAGNOSTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/compatibility-report.json", "rust/validation-report.json"]
    ["expanded-diagnostic-codes"],
  mkEntry "source-span-diagnostics" "supported"
    ["SourceSpan", "sourceSpanSummary", "instanceHasRequiredSpan"]
    ["LeanRustCore/Diagnostics.lean", "LeanRustCore/ExtractIR.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/validation_report.rs"]
    ["docs/DIAGNOSTICS.md", "docs/EXTRACT_IR.md"]
    ["rust/extract-ir.txt", "rust/compatibility-report.json"]
    ["source-span-aware-diagnostics"],
  mkEntry "runtime-denotation-model" "supported"
    ["RuntimeValue", "runtimeValueHasType", "runtimeDenotationSummary"]
    ["LeanRustCore/IR.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/remaining_completion.rs"]
    ["docs/TRUSTED_CORE.md", "docs/SEMANTICS.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["runtime-denotation-model"],
  mkEntry "expanded-diagnostic-coverage" "supported"
    ["LRC001-LRC014", "SourceRange", "instanceHasRequiredSpan"]
    ["LeanRustCore/Diagnostics.lean"]
    ["rust/tests/first20_completion.rs", "rust/tests/next20_completion.rs"]
    ["docs/DIAGNOSTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/compatibility-report.json", "rust/coverage-dashboard.json"]
    ["expanded-diagnostic-coverage"],
  mkEntry "ci-end-to-end-matrix" "supported-scripted-gates"
    ["scripts/check-ci-e2e.sh", "linux+macos workflow matrix"]
    ["LeanRustCore/CIRelease.lean", ".github/workflows/ci.yml"]
    ["scripts/check-ci-e2e.sh", "scripts/check.sh"]
    ["docs/RELEASE_CHECKLIST.md", "docs/ARCHITECTURE.md"]
    [".github/workflows/ci.yml", "rust/validation-report.json"]
    ["ci-end-to-end-matrix"],
  mkEntry "next20-completion" "supported-complete"
    ["rows 21-40", "scripts/check-next-20-completion.py", "rust/tests/next20_completion.rs"]
    ["LeanRustCore/GenericEmission.lean", "LeanRustCore/StdImplementation.lean"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py"]
    ["docs/GENERICS.md", "docs/STD_LOWERINGS.md"]
    ["rust/validation-report.json", "rust/coverage-dashboard.json"]
    ["next20-base-type-universe"],
  mkEntry "next20-diagnostic-corpus" "supported-complete"
    ["corpus/negative", "corpus/unsupported", "extract-regular-unsupported-export", "docs/DIAGNOSTICS.md"]
    ["LeanRustCore/Diagnostics.lean", "corpus/unsupported/dependent_generic_index.expected.json"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py"]
    ["docs/DIAGNOSTICS.md", "docs/GENERICS.md"]
    ["corpus/negative", "corpus/unsupported"]
    ["next20-diagnostic-corpus", "extract-regular-unsupported-export"],
  mkEntry "parameterized-data-monomorphization" "supported-complete"
    ["PairboxU32String", "NestedpayloadU32String", "corpus/positive/parameterized_pair_box.expected.json", "docs/GENERICS.md"]
    ["LeanRustCore/ParameterizedData.lean", "LeanRustCore/ParameterizedExamples.lean"]
    ["rust/tests/generated.rs", "rust/tests/next20_completion.rs"]
    ["docs/GENERICS.md", "docs/ARCHITECTURE.md"]
    ["rust/src/generated.rs", "corpus/positive/parameterized_pair_box.expected.json"]
    ["next20-parameterized-data"],
  mkEntry "rust-generic-policy" "supported-final-policy"
    ["GenericPolicy.finalRustGenericPolicySummary", "LRC009", "docs/GENERICS.md"]
    ["LeanRustCore/GenericPolicy.lean"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py"]
    ["docs/GENERICS.md", "docs/DIAGNOSTICS.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["LRC009", "next20-generic-policy"],
  mkEntry "complete-numeric-semantics" "supported-complete"
    ["NumericSemantics.rules", "runtime numeric helpers", "docs/NUMERIC_SEMANTICS.md"]
    ["LeanRustCore/NumericSemantics.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/generated.rs", "rust/tests/next20_completion.rs"]
    ["docs/NUMERIC_SEMANTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-numeric-semantics"],
  mkEntry "complete-dependent-erasure" "supported-complete"
    ["DependentErasureChecker.checkDependentErasure", "docs/DEPENDENT_ERASURE.md"]
    ["LeanRustCore/DependentErasure.lean", "LeanRustCore/DependentErasureChecker.lean"]
    ["rust/tests/generated.rs", "rust/tests/next20_completion.rs"]
    ["docs/DEPENDENT_ERASURE.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-dependent-erasure"],
  mkEntry "recursive-discovery-layouts" "supported-complete"
    ["RecursiveDiscovery.layoutDecisions", "RoseTreeU32", "EvenNode", "OddNode", "RcTreeU32", "ArenaTreeU32"]
    ["LeanRustCore/RecursiveDiscovery.lean", "LeanRustCore/Extract.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py", "rust/tests/target_interpreter.rs"]
    ["docs/RECURSIVE_DATA.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json", "corpus/positive/recursive_binary_tree.expected.json", "corpus/positive/recursive_rose_tree.expected.json", "corpus/positive/recursive_even_odd.expected.json"]
    ["next20-recursive-discovery"],
  mkEntry "ownership-borrowing-policy" "supported-complete"
    ["OwnershipPolicy.rules", "OwnershipPolicy.approvedReferenceForms", "borrowed_vec_len_u32", "docs/OWNERSHIP.md"]
    ["LeanRustCore/OwnershipPolicy.lean", "crates/runtime/src/lib.rs", "crates/validate/src/ownership_validation.rs"]
    ["rust/tests/next20_completion.rs", "rust/tests/parser_validation.rs", "crates/validate/src/lib.rs"]
    ["docs/OWNERSHIP.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-ownership-policy", "ownership-reference-allowlist"],
  mkEntry "pattern-matrix-compiler" "supported-complete"
    ["PatternMatrix.completedPatternFeatures", "docs/PATTERN_COMPILER.md"]
    ["LeanRustCore/PatternMatrix.lean"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py"]
    ["docs/PATTERN_COMPILER.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-pattern-matrix"],
  mkEntry "recursion-analysis-lowering" "supported-complete"
    ["RecursionAnalysis.decisions", "docs/RECURSION_LOWERING.md"]
    ["LeanRustCore/RecursionAnalysis.lean"]
    ["rust/tests/next20_completion.rs", "scripts/check-next-20-completion.py"]
    ["docs/RECURSION_LOWERING.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-recursion-analysis"],
  mkEntry "std-lowering-implementation" "supported-complete"
    ["StdImplementation.lowerings", "runtime Std helpers", "docs/STD_LOWERINGS.md"]
    ["LeanRustCore/StdImplementation.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/next20_completion.rs", "rust/tests/generated.rs"]
    ["docs/STD_LOWERINGS.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-std-implementation"],
  mkEntry "typeclass-specialization-complete" "supported-complete"
    ["TypeclassSpecialization.classes", "docs/TYPECLASSES.md"]
    ["LeanRustCore/TypeclassSpecialization.lean"]
    ["rust/tests/next20_completion.rs", "rust/tests/generated.rs"]
    ["docs/TYPECLASSES.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["next20-typeclass-specialization"],
  mkEntry "remaining-typeclass-dictionaries" "supported-complete"
    ["TypeclassDictionaries.dictionaryShapes", "AddDictU32", "docs/TYPECLASS_DICTIONARIES.md"]
    ["LeanRustCore/TypeclassDictionaries.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/TYPECLASS_DICTIONARIES.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-typeclass-dictionaries"],
  mkEntry "remaining-first-class-closures" "supported-complete"
    ["FirstClassClosures.closureObjects", "StoredClosureU32", "docs/FIRST_CLASS_CLOSURES.md"]
    ["LeanRustCore/FirstClassClosures.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/FIRST_CLASS_CLOSURES.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-first-class-closures"],
  mkEntry "remaining-pure-do-notation" "supported-complete"
    ["PureDoNotation.lowerings", "Option/Except/State/Reader/ExceptT", "docs/PURE_DO_NOTATION.md"]
    ["LeanRustCore/PureDoNotation.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/PURE_DO_NOTATION.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-pure-do-notation"],
  mkEntry "remaining-controlled-io-boundary" "supported-complete"
    ["IOBoundary.policies", "ControlledIoProgram", "docs/IO_BOUNDARY.md"]
    ["LeanRustCore/IOBoundary.lean", "crates/runtime/src/lib.rs"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/IO_BOUNDARY.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-controlled-io-boundary"],
  mkEntry "remaining-complete-semantics" "supported-complete"
    ["CompleteSemantics.coverage", "validate::TargetTerm", "docs/SEMANTICS.md"]
    ["LeanRustCore/CompleteSemantics.lean", "crates/validate/src/target_semantics.rs"]
    ["rust/tests/remaining_completion.rs", "rust/tests/validation_report.rs"]
    ["docs/SEMANTICS.md", "docs/ARCHITECTURE.md"]
    ["rust/target-validation.txt", "rust/coverage-dashboard.json"]
    ["remaining-complete-generated-semantics"],
  mkEntry "remaining-preservation-skeleton" "supported-complete"
    ["Preservation.obligations", "docs/PRESERVATION.md"]
    ["LeanRustCore/Preservation.lean"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/PRESERVATION.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-preservation-skeleton"],
  mkEntry "remaining-property-generators" "supported-complete"
    ["PropertyGenerators.families", "docs/PROPERTY_GENERATORS.md"]
    ["LeanRustCore/PropertyGenerators.lean", "crates/runtime/src/property_generators.rs"]
    ["rust/tests/remaining_completion.rs", "rust/tests/property_validation.rs"]
    ["docs/PROPERTY_GENERATORS.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-property-generators"],
  mkEntry "remaining-feature-complete-dashboard" "supported-complete"
    ["CoverageCompletion.denominators", "docs/COVERAGE_COMPLETION.md"]
    ["LeanRustCore/CoverageCompletion.lean", "LeanRustCore/CoverageDashboard.lean"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/COVERAGE_COMPLETION.md", "docs/COVERAGE.md"]
    ["rust/coverage-dashboard.json", "rust/proof-report.json"]
    ["remaining-feature-complete-coverage"],
  mkEntry "remaining-ci-release-matrix" "supported-complete"
    ["CIRelease.matrix", ".github/workflows/ci.yml", "docs/RELEASE_CHECKLIST.md"]
    ["LeanRustCore/CIRelease.lean", ".github/workflows/ci.yml"]
    ["scripts/check-ci-e2e.sh", "scripts/check-remaining-completion.py"]
    ["docs/RELEASE_CHECKLIST.md", "docs/ARCHITECTURE.md"]
    [".github/workflows/ci.yml", "rust/coverage-dashboard.json"]
    ["remaining-ci-release-matrix"],
  mkEntry "remaining-publishing-versioning" "supported-complete"
    ["Publishing.cratePolicies", "CHANGELOG.md", "docs/PUBLISHING.md"]
    ["LeanRustCore/Publishing.lean", "scripts/check-publishing.sh"]
    ["rust/tests/final16_diagnostics_and_crates.rs", "scripts/check-publishing.sh"]
    ["docs/PUBLISHING.md", "docs/RELEASE_CHECKLIST.md"]
    ["CHANGELOG.md", "rust/coverage-dashboard.json"]
    ["remaining-publishing-versioning"],
  mkEntry "remaining-completion-rows-41-63" "supported-complete"
    ["RemainingCompletion.rows", "scripts/check-remaining-completion.py"]
    ["LeanRustCore/RemainingCompletion.lean"]
    ["rust/tests/remaining_completion.rs", "scripts/check-remaining-completion.py"]
    ["docs/COVERAGE_COMPLETION.md", "docs/ARCHITECTURE.md"]
    ["rust/proof-report.json", "rust/coverage-dashboard.json"]
    ["remaining-completion-gate"]
]

theorem coverage_entries_require_evidence :
    coverageEntries.all coverageEntryHasRequiredEvidence = true := by
  native_decide

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

private def evidenceJson (evidence : CoverageEvidence) : String :=
  "      \"implementation\": " ++ jsonArray evidence.implementation ++ ",\n" ++
  "      \"tests\": " ++ jsonArray evidence.tests ++ ",\n" ++
  "      \"docs\": " ++ jsonArray evidence.docs ++ ",\n" ++
  "      \"generated_examples\": " ++ jsonArray evidence.generatedExamples ++ ",\n" ++
  "      \"diagnostics\": " ++ jsonArray evidence.diagnostics ++ "\n"

private def coverageEntryJson (entry : CoverageEntry) : String :=
  "    { \"feature\": " ++ jsonString entry.feature ++
  ", \"status\": " ++ jsonString entry.status ++
  ", \"examples\": " ++ jsonArray entry.examples ++ ",\n" ++
  "      \"evidence\": {\n" ++ evidenceJson entry.evidence ++ "      } }"

private def coverageMetricJson (metric : LeanRustCore.CoverageDashboard.CoverageMetric) : String :=
  "    { \"denominator\": " ++ jsonString metric.denominator ++
  ", \"covered\": " ++ toString metric.covered ++
  ", \"total\": " ++ toString metric.total ++
  ", \"percent\": " ++ toString (LeanRustCore.CoverageDashboard.metricPercent metric) ++
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
  "target-validation v2 records box/deref fingerprints, completed rows 21-40 numeric/generic/dependent-erasure/recursive-layout/diagnostic-corpus/ownership/pattern-matrix/recursion-analysis/Std/typeclass coverage, first-20 ExtractIR/runtime-denotation/SurfaceExpr-coverage/diagnostic/source-span/CI coverage, and remaining rows 41-63 dictionary/closure/pure-do/IO/semantics/preservation/generator/coverage/CI/publishing coverage; rust/coverage-dashboard.json now derives every supported entry from explicit implementation, test, documentation, generated-example, and diagnostic evidence"

end LeanRustCore.ValidationV2
