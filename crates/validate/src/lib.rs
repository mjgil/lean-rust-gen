#![forbid(unsafe_code)]
//! Validation helpers for generated LeanRustCore artifacts.

use serde::de::DeserializeOwned;
use serde::Deserialize;
use std::collections::BTreeSet;

mod property_generators;
mod target_semantics;
mod target_validation;

pub use property_generators::{
    generate_target_term_cases, generated_terms_are_well_typed, minimize_target_term,
    shrink_target_term, target_term_head, PropertyRng,
};
pub use target_semantics::{
    eval_target_term, target_grammar_heads, RecursiveTree, TargetTerm, TargetValue,
};
pub use target_validation::{
    parse_target_validation_functions, TargetValidationArg, TargetValidationFunction,
    TargetValidationParseError,
};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct GeneratedSummary {
    pub functions: BTreeSet<String>,
    pub types: BTreeSet<String>,
}

pub fn parse_json_artifact(input: &str) -> Result<serde_json::Value, serde_json::Error> {
    serde_json::from_str(input)
}

fn parse_typed_artifact<T: DeserializeOwned>(input: &str) -> Result<T, serde_json::Error> {
    serde_json::from_str(input)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValidationFeatureSummary {
    pub exact_integer_functions: u64,
    pub ffi_wrapper_count: u64,
    pub final16_completion: Vec<String>,
    pub first20_completion: Vec<String>,
    pub pattern_matching_functions: u64,
    pub pure_effects: Vec<String>,
    pub remaining_completion: Vec<String>,
    pub std_lowerings: Vec<String>,
    pub structural_list_loop_functions: u64,
    pub tail_recursion_loop_functions: u64,
    pub typeclass_specialization: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ValidationCheckStatus {
    Passed,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValidationCheck {
    pub detail: String,
    pub name: String,
    pub status: ValidationCheckStatus,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ValidationReport {
    pub architecture: String,
    pub checks: Vec<ValidationCheck>,
    pub differential_assertion_count: u64,
    pub feature_summary: ValidationFeatureSummary,
    pub ffi_boundary_export_count: u64,
    pub format: String,
    pub generated_function_count: u64,
    pub generated_type_count: u64,
    pub lean_toolchain: String,
    pub required_functions: Vec<String>,
    pub required_types: Vec<String>,
    pub rust_toolchain: String,
    pub target_validation_format: String,
}

pub fn parse_validation_report(input: &str) -> Result<ValidationReport, serde_json::Error> {
    parse_typed_artifact(input)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CompatibilityDiagnosticCode {
    Supported,
    UnsupportedDeclaration,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompatibilityDiagnostic {
    pub code: CompatibilityDiagnosticCode,
    pub detail: String,
    pub features: Vec<String>,
    pub next_feature: Option<String>,
    pub rust_name: String,
    pub source: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CompatibilityReport {
    pub architecture: String,
    pub diagnostics: Vec<CompatibilityDiagnostic>,
    pub feature_tag_schema: String,
    pub format: String,
    pub generated_function_count: u64,
}

pub fn parse_compatibility_report(input: &str) -> Result<CompatibilityReport, serde_json::Error> {
    parse_typed_artifact(input)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProofFact {
    pub name: String,
    pub statement: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProofPolicy {
    pub ci_end_to_end_matrix: bool,
    pub ci_release_matrix_complete: bool,
    pub closure_conversion: String,
    pub complete_generated_subset_semantics: bool,
    pub controlled_io_boundary_complete: bool,
    pub corpus_harness: bool,
    pub coverage_dashboard: String,
    pub defunctionalization: String,
    pub dependent_erasure_complete: bool,
    pub dependent_shape_erasure: String,
    pub expanded_diagnostic_codes: String,
    pub extract_ir_pipeline: bool,
    pub feature_complete_coverage_dashboard: bool,
    pub ffi_result_lowering: String,
    pub ffi_wrappers_feature_gated: bool,
    pub first20_completion: bool,
    pub first_class_closure_objects_complete: bool,
    pub first_order_recursion_allowed: bool,
    pub general_pattern_matching: bool,
    pub generated_rust_unsafe: bool,
    pub generated_typeclass_dictionaries_complete: bool,
    pub nat_to_u32_requires_opt_in: bool,
    pub native_rust_types_at_ffi: bool,
    pub next20_completion: bool,
    pub numeric_semantics_complete: bool,
    pub ownership_policy_complete: bool,
    pub parameterized_data_monomorphization: bool,
    pub pattern_matrix_complete: bool,
    pub preservation_skeleton_complete: bool,
    pub property_fuzz_corpus: bool,
    pub property_generators_complete: bool,
    pub publishing_versioning_complete: bool,
    pub pure_do_notation_complete: bool,
    pub pure_effect_lowering: bool,
    pub quantitative_coverage_dashboard: bool,
    pub recursion_analysis_complete: bool,
    pub recursive_data_layout: String,
    pub recursive_discovery_complete: bool,
    pub release_acceptance_matrix: bool,
    pub release_fallback_allowed: bool,
    pub remaining_completion_rows_41_63: bool,
    pub runtime_denotation_model: bool,
    pub runtime_value_denotation: bool,
    pub surface_expr_constructor_coverage: bool,
    pub rust_generic_emission_policy_final: bool,
    pub rust_workspace_crate_split: bool,
    pub source_span_diagnostics: bool,
    pub source_string_matching: bool,
    pub std_lowering_implementation_complete: bool,
    pub std_lowering_policy: bool,
    pub tail_recursion_loop_lowering: bool,
    pub target_validation_snapshot: String,
    pub typeclass_specialization_complete: bool,
    pub typeclass_specialization_policy: bool,
    pub user_facing_diagnostics: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ProofReport {
    pub architecture: String,
    pub facts: Vec<ProofFact>,
    pub format: String,
    pub lean_toolchain: String,
    pub policy: ProofPolicy,
    pub rust_toolchain: String,
    pub trusted_core: Vec<String>,
}

pub fn parse_proof_report(input: &str) -> Result<ProofReport, serde_json::Error> {
    parse_typed_artifact(input)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct BuildMetadataReport {
    pub architecture: String,
    pub fallback_env_var: String,
    pub fallback_policy: String,
    pub format: String,
    pub generated_artifacts: Vec<String>,
    pub lean_toolchain: String,
    pub rust_toolchain: String,
    pub workspace_crates: Vec<String>,
}

pub fn parse_build_metadata_report(input: &str) -> Result<BuildMetadataReport, serde_json::Error> {
    parse_typed_artifact(input)
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CoverageMetricStatus {
    ClosedByThisPatch,
    DeterministicAndFuzzLaneComplete,
    DeterministicCiSeedsPresent,
    FeatureComplete,
    FullyImplementedWithTestsAndDocs,
    ImplementedWithTestsAndDocs,
    InterpreterComplete,
    InterpreterTestDocOwned,
    ProofSkeletonTestDocOwned,
    RequiredFinalDocsPresent,
    ScriptedReleaseMatrix,
    SplitWorkspacePresent,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageMetric {
    pub covered: u64,
    pub denominator: String,
    pub percent: u64,
    pub status: CoverageMetricStatus,
    pub total: u64,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum CoverageEntryStatus {
    Supported,
    SupportedComplete,
    SupportedDeterministicSeeds,
    SupportedFinalPolicy,
    SupportedKnownSlice,
    SupportedMetrics,
    SupportedScriptedGates,
    SupportedStableCodes,
    SupportedWorkspace,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageEvidence {
    pub diagnostics: Vec<String>,
    pub docs: Vec<String>,
    pub generated_examples: Vec<String>,
    pub implementation: Vec<String>,
    pub tests: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageEntry {
    pub evidence: CoverageEvidence,
    pub examples: Vec<String>,
    pub feature: String,
    pub status: CoverageEntryStatus,
}

#[derive(Clone, Debug, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CoverageDashboard {
    pub architecture: String,
    pub entries: Vec<CoverageEntry>,
    pub format: String,
    pub lean_toolchain: String,
    pub metrics: Vec<CoverageMetric>,
    pub recursive_data_policy: String,
    pub rust_toolchain: String,
    pub target_validation_format: String,
}

pub fn parse_coverage_dashboard(input: &str) -> Result<CoverageDashboard, serde_json::Error> {
    parse_typed_artifact(input)
}

pub fn summarize_generated_rust(source: &str) -> Result<GeneratedSummary, syn::Error> {
    let file = syn::parse_file(source)?;
    let mut functions = BTreeSet::new();
    let mut types = BTreeSet::new();
    for item in file.items {
        match item {
            syn::Item::Fn(item) => {
                functions.insert(item.sig.ident.to_string());
            }
            syn::Item::Struct(item) => {
                types.insert(item.ident.to_string());
            }
            syn::Item::Enum(item) => {
                types.insert(item.ident.to_string());
            }
            _ => {}
        }
    }
    Ok(GeneratedSummary { functions, types })
}

pub fn target_validation_counts(snapshot: &str) -> Option<(usize, usize)> {
    let mut type_count = None;
    let mut fn_count = None;
    for line in snapshot.lines() {
        if let Some(rest) = line.strip_prefix("TYPE_COUNT\t") {
            type_count = rest.parse::<usize>().ok();
        }
        if let Some(rest) = line.strip_prefix("FN_COUNT\t") {
            fn_count = rest.parse::<usize>().ok();
        }
    }
    match (type_count, fn_count) {
        (Some(t), Some(f)) => Some((t, f)),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const VALIDATION_REPORT_JSON: &str = include_str!("../../../rust/validation-report.json");
    const COMPATIBILITY_REPORT_JSON: &str = include_str!("../../../rust/compatibility-report.json");
    const PROOF_REPORT_JSON: &str = include_str!("../../../rust/proof-report.json");
    const BUILD_METADATA_JSON: &str = include_str!("../../../rust/build-metadata.json");
    const COVERAGE_DASHBOARD_JSON: &str = include_str!("../../../rust/coverage-dashboard.json");
    const TARGET_VALIDATION_TXT: &str = include_str!("../../../rust/target-validation.txt");

    #[test]
    fn parses_valid_json_and_rejects_malformed_json() {
        assert!(parse_json_artifact(r#"{"format":"ok"}"#).is_ok());
        assert!(parse_json_artifact(r#"{"format": "broken""#).is_err());
    }

    #[test]
    fn typed_report_parsers_accept_current_artifacts() {
        let validation = parse_validation_report(VALIDATION_REPORT_JSON).unwrap();
        assert_eq!(validation.format, "lean-rust-core.rust-validation.v1");
        assert_eq!(validation.checks[0].status, ValidationCheckStatus::Passed);

        let compatibility = parse_compatibility_report(COMPATIBILITY_REPORT_JSON).unwrap();
        assert_eq!(
            compatibility.diagnostics[0].code,
            CompatibilityDiagnosticCode::Supported
        );

        let proof = parse_proof_report(PROOF_REPORT_JSON).unwrap();
        assert_eq!(
            proof.policy.closure_conversion,
            "explicit-environment-structs"
        );
        assert!(proof.policy.extract_ir_pipeline);

        let build = parse_build_metadata_report(BUILD_METADATA_JSON).unwrap();
        assert_eq!(build.format, "lean-rust-core.build-metadata.v1");
        assert!(build
            .generated_artifacts
            .iter()
            .any(|path| path.ends_with("generated.rs")));

        let coverage = parse_coverage_dashboard(COVERAGE_DASHBOARD_JSON).unwrap();
        assert_eq!(coverage.format, "lean-rust-core.coverage-dashboard.v1");
        assert_eq!(
            coverage.metrics[0].status,
            CoverageMetricStatus::FullyImplementedWithTestsAndDocs
        );
        assert_eq!(
            coverage.entries[0].status,
            CoverageEntryStatus::SupportedKnownSlice
        );
        assert!(!coverage.entries[0].evidence.implementation.is_empty());
        assert!(!coverage.entries[0].evidence.tests.is_empty());
        assert!(!coverage.entries[0].evidence.docs.is_empty());
        assert!(!coverage.entries[0].evidence.generated_examples.is_empty());
        assert!(!coverage.entries[0].evidence.diagnostics.is_empty());
    }

    #[test]
    fn typed_report_parsers_reject_unknown_fields() {
        let invalid = r#"{
            "format": "lean-rust-core.build-metadata.v1",
            "architecture": "direct-lean-emits-rust",
            "lean_toolchain": "leanprover/lean4:v4.22.0",
            "rust_toolchain": "1.85.0",
            "fallback_env_var": "LEAN_RUST_CORE_ALLOW_FALLBACK",
            "fallback_policy": "local-only",
            "generated_artifacts": ["rust/src/generated.rs"],
            "workspace_crates": ["lean-rust-core-generated"],
            "extra": true
        }"#;
        assert!(parse_build_metadata_report(invalid).is_err());
    }

    #[test]
    fn summarizes_generated_rust_items() {
        let summary = summarize_generated_rust(
            "pub struct Point { pub x: u32 } pub enum E { A } pub fn f() {}",
        )
        .unwrap();
        assert!(summary.types.contains("Point"));
        assert!(summary.types.contains("E"));
        assert!(summary.functions.contains("f"));
    }

    #[test]
    fn parses_target_validation_counts() {
        assert_eq!(
            target_validation_counts("TYPE_COUNT\t2\nFN_COUNT\t3\n"),
            Some((2, 3))
        );
    }

    #[test]
    fn parses_current_target_validation_functions() {
        let functions = parse_target_validation_functions(TARGET_VALIDATION_TXT).unwrap();
        assert_eq!(functions.len(), 142);
        assert!(functions
            .iter()
            .any(|function| function.name == "tree_sum_u32"));
        assert!(functions.iter().any(|function| {
            function.name == "unsupported_higher_order_u32"
                && function.args.iter().any(|arg| arg.ty == "fn(u32) -> u32")
        }));
    }

    #[test]
    fn randomized_target_generators_cover_target_grammar_and_shrinking() {
        let terms = generate_target_term_cases(0x1234_5678, 28, 3);
        let heads = terms.iter().map(target_term_head).collect::<BTreeSet<_>>();
        for expected in [
            "literal",
            "let",
            "if",
            "match",
            "call",
            "struct",
            "enum",
            "box",
            "deref",
            "closure",
            "dictionary",
            "effect",
        ] {
            assert!(
                heads.contains(expected),
                "missing generated head {expected}"
            );
        }
        assert!(generated_terms_are_well_typed(0x1234_5678, 28, 3));

        let minimized = minimize_target_term(
            TargetTerm::Add(Box::new(TargetTerm::U32(8)), Box::new(TargetTerm::U32(8))),
            |term| matches!(eval_target_term(term), Some(TargetValue::U32(value)) if value >= 2),
        );
        assert_eq!(minimized, TargetTerm::U32(2));
    }
}
