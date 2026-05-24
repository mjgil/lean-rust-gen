import LeanRustCore.Examples
import LeanRustCore.ChimeraBoundary
import LeanRustCore.Toolchain
import LeanRustCore.TargetValidation
import LeanRustCore.BoundaryExport
import LeanRustCore.RecursiveData
import LeanRustCore.ValidationV2
import LeanRustCore.Pattern
import LeanRustCore.RecursionLowering
import LeanRustCore.DependentErasure
import LeanRustCore.PropertyCorpus
import LeanRustCore.CoverageDashboard
import LeanRustCore.Diagnostics
import LeanRustCore.ExtractIR
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

import LeanRustCore.ClosureConversion
import LeanRustCore.Defunctionalization
namespace LeanRustCore.ProofReport

/-- A compact proof-sidecar model for generated Rust artifacts. -/
structure ProofFact where
  name : String
  statement : String
  deriving Repr, BEq

private def joinWith (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

/-- Facts that are checked by importing/building the Lean modules. -/
def facts : List ProofFact := [
  { name := "extractor_reads_elaborated_definitions", statement := "rust_emit_exports collects @[rust_export] declarations and uses Lean constant bodies, not source-string matching" },
  { name := "surface_type_check", statement := "extracted SurfaceFun bodies are type-checked before Rust emission" },
  { name := "clamp_refines_spec", statement := "eval clampBody = clampSpec" },
  { name := "max_refines_spec", statement := "eval maxBody = maxSpec" },
  { name := "nonzero_refines_spec", statement := "eval nonzeroBody = nonzeroSpec" },
  { name := "add_refines_wrapping_spec", statement := "eval addBody = u32 wrapping-add spec" },
  { name := "bounded_bump_refines_spec", statement := "eval boundedBumpBody = let/arithmetic spec" },
  { name := "option_default_refines_spec", statement := "eval optionDefaultBody = Option-match spec" },
  { name := "fixed_width_type_extraction", statement := "rust_export extraction recognizes UInt32, UInt64, Int32, Int64, Unit, Option, Except, and simple closed enums; Nat-to-u32 lowering requires explicit rust_nat_wrapping_u32 opt-in" },
  { name := "match_lowering", statement := "Bool, Option, and closed enum matches, including payload variant binders, lower from elaborated recursor/casesOn forms" },
  { name := "struct_enum_declarations", statement := "SurfaceStruct and SurfaceEnum declarations are emitted before generated Rust functions" },
  { name := "expected_type_propagation", statement := "nested Option and Except constructors are checked with the Rust-facing expected type" },
  { name := "generic_monomorphization", statement := "rust_mono_export registers concrete type instantiations of generic Lean definitions and emits concrete Rust functions" },
  { name := "automatic_monomorphization", statement := "generic calls discovered inside concrete exported declarations enqueue and emit concrete monomorphized Rust functions" },
  { name := "phase_1_recursion_policy", statement := "the default direct Rust lane permits first-order generated call cycles; the surface evaluator bounds recursive calls with fuel" },
  { name := "parameterized_data_monomorphization", statement := "index-free parameterized structures and enums lower to concrete Rust declarations after substituting concrete type arguments" },
  { name := "standard_container_shapes", statement := "RType represents Char, String, List, Array, Prod, Sum, and unary function types with safe Rust type spellings" },
  { name := "standard_combinator_lowering", statement := "List, Array, Option, and Except combinators lower to checked loop or match SurfaceExpr nodes" },
  { name := "structural_recursion_loop_lowering", statement := "Nat.rec accumulator shapes and list folds lower to explicit safe Rust loops" },
  { name := "general_pattern_compiler", statement := "SurfacePattern and SurfaceExpr.matchPattern represent a checked general constructor-pattern fragment for Bool, Option, Prod, and closed enums" },
  { name := "tail_recursion_loop_lowering", statement := "recognized Nat accumulator tail recursion lowers to SurfaceExpr.tailRecNat and safe Rust while loops" },
  { name := "list_length_structural_lowering", statement := "List.length lowers to SurfaceExpr.listLength and Rust Vec::len in the owned List representation" },
  { name := "dependent_shape_erasure", statement := LeanRustCore.DependentErasure.dependentErasureSummary },
  { name := "dependent_erasure_policy", statement := "Subtype erases to its carrier, Fin lowers to u32-shaped values, Vector lowers to Vec<T> with source-side length evidence, and proof-only structure fields are removed from safe Rust layouts when unused computationally" },
  { name := "proof_field_erasure", statement := "proof-only constructor fields are skipped during runtime payload lowering and are absent from emitted Rust structs" },
  { name := "structural_recursion_lowering", statement := "recognized List.map, List.foldl, and Nat.rec shapes lower to explicit safe Rust loop-shaped SurfaceExpr nodes" },
  { name := "exact_integer_modes", statement := "@[rust_nat_exact] and @[rust_int_exact] lower Lean Nat/Int boundaries to exact num_bigint BigUint/BigInt Rust values" },
  { name := "captured_closure_conversion", statement := "captured lambdas inside recognized structural combinators lower to loop bodies that close over ordinary Rust locals" },
  { name := "typeclass_dictionary_erasure", statement := LeanRustCore.TypeclassPolicy.typeclassPolicySummary },
  { name := "closure_conversion_policy", statement := LeanRustCore.ClosureConversion.closureConversionSummary },
  { name := "extract_ir_feature_tags", statement := LeanRustCore.ExtractIR.extractIRSummary },
  { name := "extract_ir_normalized_pipeline", statement := "ExtractIR records origin names, source ranges, erased binder counts, recognized recursors, resolved dictionaries, features, diagnostics, and next-feature routing before checked SurfaceExpr emission" },
  { name := "runtime_denotation_model", statement := LeanRustCore.runtimeDenotationSummary },
  { name := "expanded_diagnostic_templates", statement := LeanRustCore.Diagnostics.diagnosticSummary },
  { name := "source_span_diagnostics", statement := "diagnostic instances carry optional SourceRange values and templates declare when a range is required" },
  { name := "ci_end_to_end_matrix", statement := "scripts/check-ci-e2e.sh and the GitHub Actions matrix run Lean generation, snapshot checks, Rust workspace tests, fmt, clippy, FFI, and artifact consistency gates" },
  { name := "transitive_helper_extraction", statement := "first-order helper definitions reached from exported bodies are enqueued and emitted as auto-helper-export functions" },
  { name := "proof_erased_binders", statement := "conservative proof-shaped binders are erased from Rust signatures when their values are not used computationally" },
  { name := "limited_higher_order_function_pointer", statement := "unary function-typed arguments lower to Rust fn-pointer arguments and SurfaceExpr.callValue nodes" },
  { name := "closure_converted_environments", statement := LeanRustCore.ClosureConversion.closureConversionSummary },
  { name := "finite_defunctionalization", statement := LeanRustCore.Defunctionalization.defunctionalizationSummary },
  { name := "recursive_box_owned_data_layout", statement := LeanRustCore.RecursiveData.recursiveDataSummary },
  { name := "target_validation_v2_dashboard", statement := LeanRustCore.ValidationV2.validationV2Summary },
  { name := "std_library_lowering_table", statement := LeanRustCore.StdLowering.stdLoweringSummary },
  { name := "typeclass_specialization_policy", statement := LeanRustCore.TypeclassPolicy.typeclassPolicySummary },
  { name := "pure_monadic_do_lowering", statement := LeanRustCore.PureEffects.pureEffectsSummary },
  { name := "property_fuzz_corpus", statement := LeanRustCore.PropertyCorpus.propertyCorpusSummary },
  { name := "quantitative_coverage_dashboard", statement := LeanRustCore.CoverageDashboard.quantitativeCoverageSummary },
  { name := "user_facing_diagnostics", statement := LeanRustCore.Diagnostics.diagnosticSummary },
  { name := "rust_workspace_crate_split", statement := LeanRustCore.CrateDesign.crateDesignSummary },
  { name := "release_acceptance_matrix", statement := LeanRustCore.ReleaseMatrix.releaseMatrixSummary },
  { name := "toolchain_pins", statement := "Lean and Rust toolchains are pinned exactly and checked before CI/release validation" },
  { name := "release_fallback_ban", statement := "checked-in generated.rs fallback is disabled for CI and release builds" },
  { name := "compatibility_reporting", statement := "unsupported tagged exports are skipped and recorded in a structured compatibility report" },
  { name := "payload_enum_branch_binders", statement := "payload enum pattern matching stores checked branch binders and emits Rust variant patterns" },
  { name := "first_order_function_calls", statement := "calls to other tagged first-order exports lower to checked SurfaceExpr.call nodes and Rust function calls" },
  { name := "surface_expr_evaluator", statement := "evalSurfaceFun interprets the checked SurfaceExpr subset used by the direct Lean-to-Rust emitter" },
  { name := "extracted_surface_artifact", statement := "rust_emit_exports_with_report_and_surface emits the same checked SurfaceFun list that generated Rust uses, and the differential suite consumes that artifact instead of hand-mirrored fixtures" },
  { name := "expanded_surface_differential", statement := "Lean-generated differential tests compute extracted struct, enum, Result, call, and monomorphization expectations with evalSurfaceFun" },
  { name := "rust_identifier_hygiene", statement := "validateSurfaceModuleHygiene rejects generated modules whose sanitized Rust identifiers collide" },
  { name := "syn_parser_backed_validation", statement := "rust/tests/parser_validation.rs parses generated.rs with syn and validates the approved top-level safe Rust subset" },
  { name := "json_artifact_parse_validation", statement := "rust/tests/validation_report.rs parses generated JSON artifacts and checks report counts against parsed generated Rust" },
  { name := "rust_to_target_ir_validation", statement := "rust/tests/semantic_validation.rs parses generated.rs, reconstructs target fingerprints, and compares them to LeanRustCore.TargetValidation.targetValidationSnapshot" },
  { name := "target_validation_snapshot", statement := "LeanRustCore.TargetValidation.targetValidationSnapshot is generated from the extractor-owned SurfaceFun artifact" },
  { name := "ffi_boundary_exporter", statement := "LeanRustCore.BoundaryExport.generatedBoundaryRust emits optional feature-gated raw ABI wrappers for primitive and Result<u32,u32> exports" },
  { name := "ffi_feature_isolation", statement := "raw ABI wrappers are isolated under the Rust ffi feature and are not emitted into rust/src/generated.rs" },
  { name := "rust_adapter_owned_rejected", statement := "owned Rust values cannot cross the raw FFI boundary" },
  { name := "result_u32_i32_lowering", statement := "Result<u32,i32> lowers to status plus two out parameters" },
  { name := "next20_base_type_universe", statement := "Rows 21-22 keep every admitted runtime type and monomorphic struct/enum layout covered by parser, semantic, and report tests" },
  { name := "parameterized_data_monomorphization", statement := LeanRustCore.GenericEmission.genericEmissionSummary },
  { name := "numeric_semantics_complete", statement := LeanRustCore.NumericSemantics.numericSemanticsSummary },
  { name := "rust_generic_policy_final", statement := LeanRustCore.GenericPolicy.finalRustGenericPolicySummary },
  { name := "dependent_erasure_complete", statement := LeanRustCore.DependentErasureChecker.dependentErasureCheckerSummary },
  { name := "recursive_discovery_complete", statement := LeanRustCore.RecursiveDiscovery.recursiveDiscoverySummary },
  { name := "ownership_policy_complete", statement := LeanRustCore.OwnershipPolicy.ownershipPolicySummary },
  { name := "pattern_matrix_complete", statement := LeanRustCore.PatternMatrix.patternMatrixSummary },
  { name := "recursion_analysis_complete", statement := LeanRustCore.RecursionAnalysis.recursionAnalysisSummary },
  { name := "std_lowering_implementation_complete", statement := LeanRustCore.StdImplementation.stdImplementationSummary },
  { name := "typeclass_specialization_complete", statement := LeanRustCore.TypeclassSpecialization.typeclassSpecializationCompletionSummary },
  { name := "generated_typeclass_dictionaries_complete", statement := LeanRustCore.TypeclassDictionaries.typeclassDictionarySummary },
  { name := "first_class_closure_objects_complete", statement := LeanRustCore.FirstClassClosures.firstClassClosureSummary },
  { name := "full_pure_do_notation_complete", statement := LeanRustCore.PureDoNotation.pureDoNotationSummary },
  { name := "controlled_io_boundary_complete", statement := LeanRustCore.IOBoundary.ioBoundarySummary },
  { name := "complete_generated_subset_semantics", statement := LeanRustCore.CompleteSemantics.completeSemanticsSummary },
  { name := "preservation_skeleton_complete", statement := LeanRustCore.Preservation.preservationSummary },
  { name := "property_generators_complete", statement := LeanRustCore.PropertyGenerators.propertyGeneratorsSummary },
  { name := "coverage_dashboard_feature_complete", statement := LeanRustCore.CoverageCompletion.coverageCompletionSummary },
  { name := "ci_release_matrix_complete", statement := LeanRustCore.CIRelease.ciReleaseSummary },
  { name := "publishing_versioning_complete", statement := LeanRustCore.Publishing.publishingSummary },
  { name := "remaining_completion_rows_41_63", statement := LeanRustCore.RemainingCompletion.remainingCompletionSummary }
]

private def jsonEscapeChar : Char → String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | c => String.singleton c

private def jsonEscape (s : String) : String :=
  joinWith "" (s.toList.map jsonEscapeChar)

private def factToJson (f : ProofFact) : String :=
  "    { \"name\": \"" ++ jsonEscape f.name ++ "\", \"statement\": \"" ++ jsonEscape f.statement ++ "\" }"

/-- JSON proof report emitted next to generated Rust. -/
def reportJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.proof-report.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": \"" ++ LeanRustCore.Toolchain.leanToolchain ++ "\",\n" ++
  "  \"rust_toolchain\": \"" ++ LeanRustCore.Toolchain.rustToolchain ++ "\",\n" ++
  "  \"trusted_core\": [\"Lean kernel\", \"LeanRustCore.Extract.extractConst\", \"LeanRustCore.Extract.extractWithDiagnostics\", \"LeanRustCore.Extract.extractPendingAutoHelpers\", \"LeanRustCore.Examples.extractedSurfaceFunctions\", \"LeanRustCore.Surface.typeOfExpected\", \"LeanRustCore.Surface.evalSurfaceFun\", \"LeanRustCore.RustHygiene.validateSurfaceModuleHygiene\", \"LeanRustCore.EmitRust.emitSurfaceRustModule\", \"LeanRustCore.TargetValidation.targetValidationSnapshot\", \"LeanRustCore.RecursiveData.recursiveDataSummary\", \"LeanRustCore.ValidationV2.coverageDashboardJson\", \"LeanRustCore.BoundaryExport.generatedBoundaryRust\", \"LeanRustCore.DependentErasure.dependentErasureSummary\", \"LeanRustCore.ExtractIR.functionFeatures\", \"LeanRustCore.ExtractIR.lowerExpr?\", \"LeanRustCore.ExtractIR.metadataForSurfaceFun\", \"LeanRustCore.IR.runtimeValueHasType\", \"LeanRustCore.IR.runtimeDenotationSummary\", \"LeanRustCore.Diagnostics.SourceSpan\", \"LeanRustCore.Diagnostics.SourceRange\", \"LeanRustCore.Diagnostics.instanceHasRequiredSpan\", \"scripts/check-ci-e2e.sh\", \"LeanRustCore.ClosureConversion.closureConversionSummary\", \"LeanRustCore.Defunctionalization.defunctionalizationSummary\", \"rust/tests/parser_validation.rs\", \"rust/tests/semantic_validation.rs\", \"rust/tests/target_interpreter.rs\", \"LeanRustCore.IR.eval\", \"LeanRustCore.PureEffects\", \"LeanRustCore.StdLowering\", \"LeanRustCore.TypeclassPolicy\", \"LeanRustCore.PropertyCorpus.seedFamilies\", \"LeanRustCore.CoverageDashboard.metrics\", \"LeanRustCore.Diagnostics.templates\", \"LeanRustCore.CrateDesign.workspaceCrates\", \"LeanRustCore.ReleaseMatrix.gates\", \"LeanRustCore.GenericEmission.monomorphizeDataShape\", \"LeanRustCore.ParameterizedData.substituteTypeVars\", \"LeanRustCore.GenericPolicy.finalRustGenericPolicySummary\", \"LeanRustCore.NumericSemantics.rules\", \"LeanRustCore.DependentErasureChecker.checkDependentErasure\", \"LeanRustCore.RecursiveDiscovery.layoutDecisions\", \"LeanRustCore.OwnershipPolicy.rules\", \"LeanRustCore.PatternMatrix.completedPatternFeatures\", \"LeanRustCore.RecursionAnalysis.decisions\", \"LeanRustCore.StdImplementation.lowerings\", \"LeanRustCore.TypeclassSpecialization.classes\", \"LeanRustCore.TypeclassDictionaries.dictionaryShapes\", \"LeanRustCore.FirstClassClosures.closureObjects\", \"LeanRustCore.PureDoNotation.lowerings\", \"LeanRustCore.IOBoundary.policies\", \"LeanRustCore.CompleteSemantics.coverage\", \"LeanRustCore.Preservation.obligations\", \"LeanRustCore.PropertyGenerators.families\", \"LeanRustCore.CoverageCompletion.denominators\", \"LeanRustCore.CIRelease.matrix\", \"LeanRustCore.Publishing.cratePolicies\", \"LeanRustCore.RemainingCompletion.allRemainingComplete\"],\n" ++
  "  \"policy\": {\n" ++
  "    \"generated_rust_unsafe\": false,\n" ++
  "    \"source_string_matching\": false,\n" ++
  "    \"ffi_result_lowering\": \"status-plus-out-params\",\n" ++
  "    \"native_rust_types_at_ffi\": false,\n" ++
  "    \"release_fallback_allowed\": false,\n" ++
  "    \"nat_to_u32_requires_opt_in\": true,\n" ++
  "    \"first_order_recursion_allowed\": true,\n" ++
  "    \"general_pattern_matching\": true,\n" ++
  "    \"tail_recursion_loop_lowering\": true,\n" ++
  "    \"target_validation_snapshot\": \"" ++ LeanRustCore.TargetValidation.targetValidationFormat ++ "\",\n" ++
  "    \"ffi_wrappers_feature_gated\": true,\n" ++
  "    \"closure_conversion\": \"explicit-environment-structs\",\n" ++
  "    \"defunctionalization\": \"finite-enum-cases\",\n" ++
  "    \"dependent_shape_erasure\": \"Subtype/Fin/Vector/proof-field carriers\",\n" ++
  "    \"corpus_harness\": true,\n" ++
  "    \"std_lowering_policy\": true,\n" ++
  "    \"pure_effect_lowering\": true,\n" ++
  "    \"typeclass_specialization_policy\": true,\n" ++
  "    \"recursive_data_layout\": \"owned-box\",\n" ++
  "    \"property_fuzz_corpus\": true,\n" ++
  "    \"quantitative_coverage_dashboard\": true,\n" ++
  "    \"user_facing_diagnostics\": true,\n" ++
  "    \"rust_workspace_crate_split\": true,\n" ++
  "    \"release_acceptance_matrix\": true,\n" ++
  "    \"first20_completion\": true,\n" ++
  "    \"source_span_diagnostics\": true,\n" ++
  "    \"extract_ir_pipeline\": true,\n" ++
  "    \"runtime_value_denotation\": true,\n" ++
  "    \"runtime_denotation_model\": true,\n" ++
  "    \"expanded_diagnostic_codes\": \"LRC001-LRC014\",\n" ++
  "    \"ci_end_to_end_matrix\": true,\n" ++
  "    \"next20_completion\": true,\n" ++
  "    \"parameterized_data_monomorphization\": true,\n" ++
  "    \"rust_generic_emission_policy_final\": true,\n" ++
  "    \"numeric_semantics_complete\": true,\n" ++
  "    \"dependent_erasure_complete\": true,\n" ++
  "    \"recursive_discovery_complete\": true,\n" ++
  "    \"ownership_policy_complete\": true,\n" ++
  "    \"pattern_matrix_complete\": true,\n" ++
  "    \"recursion_analysis_complete\": true,\n" ++
  "    \"std_lowering_implementation_complete\": true,\n" ++
  "    \"typeclass_specialization_complete\": true,\n" ++
  "    \"generated_typeclass_dictionaries_complete\": true,\n" ++
  "    \"first_class_closure_objects_complete\": true,\n" ++
  "    \"pure_do_notation_complete\": true,\n" ++
  "    \"controlled_io_boundary_complete\": true,\n" ++
  "    \"complete_generated_subset_semantics\": true,\n" ++
  "    \"preservation_skeleton_complete\": true,\n" ++
  "    \"property_generators_complete\": true,\n" ++
  "    \"feature_complete_coverage_dashboard\": true,\n" ++
  "    \"ci_release_matrix_complete\": true,\n" ++
  "    \"publishing_versioning_complete\": true,\n" ++
  "    \"remaining_completion_rows_41_63\": true,\n" ++
  "    \"coverage_dashboard\": \"rust/coverage-dashboard.json\"\n" ++
  "  },\n" ++
  "  \"facts\": [\n" ++
  joinWith ",\n" (facts.map factToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.ProofReport
