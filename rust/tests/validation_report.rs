use std::collections::BTreeSet;

use lean_rust_core_validate::{
    parse_build_metadata_report, parse_compatibility_report, parse_coverage_dashboard,
    parse_proof_report, parse_validation_report, summarize_generated_rust, BuildMetadataReport,
    CompatibilityDiagnosticCode, CompatibilityReport, CoverageDashboard, ProofReport,
    ValidationCheckStatus, ValidationReport,
};
use serde_json::Value;

const GENERATED_SOURCE: &str = include_str!("../src/generated.rs");
const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const COMPATIBILITY_REPORT: &str = include_str!("../compatibility-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const BUILD_METADATA: &str = include_str!("../build-metadata.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");

fn parse_json_artifact(name: &str, source: &str) -> Value {
    serde_json::from_str(source).unwrap_or_else(|err| panic!("{name} should be valid JSON: {err}"))
}

fn generated_symbols() -> (BTreeSet<String>, BTreeSet<String>) {
    let summary = summarize_generated_rust(GENERATED_SOURCE).expect("generated Rust should parse");
    (summary.functions, summary.types)
}

fn typed_validation_report() -> ValidationReport {
    parse_validation_report(VALIDATION_REPORT)
        .unwrap_or_else(|err| panic!("validation-report.json should match typed schema: {err}"))
}

fn typed_compatibility_report() -> CompatibilityReport {
    parse_compatibility_report(COMPATIBILITY_REPORT)
        .unwrap_or_else(|err| panic!("compatibility-report.json should match typed schema: {err}"))
}

fn typed_proof_report() -> ProofReport {
    parse_proof_report(PROOF_REPORT)
        .unwrap_or_else(|err| panic!("proof-report.json should match typed schema: {err}"))
}

fn typed_build_metadata() -> BuildMetadataReport {
    parse_build_metadata_report(BUILD_METADATA)
        .unwrap_or_else(|err| panic!("build-metadata.json should match typed schema: {err}"))
}

fn typed_coverage_dashboard() -> CoverageDashboard {
    parse_coverage_dashboard(COVERAGE_DASHBOARD)
        .unwrap_or_else(|err| panic!("coverage-dashboard.json should match typed schema: {err}"))
}

#[test]
fn generated_json_artifacts_are_valid_json() {
    for (name, source) in [
        ("validation-report.json", VALIDATION_REPORT),
        ("compatibility-report.json", COMPATIBILITY_REPORT),
        ("proof-report.json", PROOF_REPORT),
        ("build-metadata.json", BUILD_METADATA),
        ("coverage-dashboard.json", COVERAGE_DASHBOARD),
    ] {
        parse_json_artifact(name, source);
    }
}

#[test]
fn typed_report_schemas_are_strict_and_complete() {
    let validation = typed_validation_report();
    assert_eq!(validation.format, "lean-rust-core.rust-validation.v1");
    assert_eq!(validation.architecture, "direct-lean-emits-rust");
    assert_eq!(validation.lean_toolchain, "leanprover/lean4:v4.22.0");
    assert_eq!(validation.rust_toolchain, "1.85.0");
    assert_eq!(
        validation.target_validation_format,
        "lean-rust-core.target-validation.v2"
    );
    assert_eq!(validation.checks[0].status, ValidationCheckStatus::Passed);
    assert!(!validation.feature_summary.std_lowerings.is_empty());
    assert!(!validation
        .feature_summary
        .typeclass_specialization
        .is_empty());
    assert!(!validation.feature_summary.final16_completion.is_empty());
    assert!(!validation.feature_summary.remaining_completion.is_empty());

    let compatibility = typed_compatibility_report();
    assert_eq!(
        compatibility.format,
        "lean-rust-core.compatibility-report.v1"
    );
    assert_eq!(compatibility.architecture, "direct-lean-emits-rust");
    assert_eq!(
        compatibility.feature_tag_schema,
        "lean-rust-core.feature-tags.v1"
    );
    assert!(compatibility
        .diagnostics
        .iter()
        .all(|diagnostic| !diagnostic.detail.is_empty() && !diagnostic.source.is_empty()));

    let proof = typed_proof_report();
    assert_eq!(proof.format, "lean-rust-core.proof-report.v1");
    assert_eq!(proof.architecture, "direct-lean-emits-rust");
    assert_eq!(proof.lean_toolchain, "leanprover/lean4:v4.22.0");
    assert_eq!(proof.rust_toolchain, "1.85.0");
    assert!(!proof.trusted_core.is_empty());
    assert!(!proof.facts.is_empty());

    let build = typed_build_metadata();
    assert_eq!(build.format, "lean-rust-core.build-metadata.v1");
    assert_eq!(build.architecture, "direct-lean-emits-rust");
    assert_eq!(build.fallback_env_var, "LEAN_RUST_CORE_ALLOW_FALLBACK");
    assert!(!build.generated_artifacts.is_empty());
    assert!(!build.workspace_crates.is_empty());

    let coverage = typed_coverage_dashboard();
    assert_eq!(coverage.format, "lean-rust-core.coverage-dashboard.v1");
    assert_eq!(coverage.architecture, "direct-lean-emits-rust");
    assert_eq!(coverage.lean_toolchain, "leanprover/lean4:v4.22.0");
    assert_eq!(coverage.rust_toolchain, "1.85.0");
    assert_eq!(
        coverage.target_validation_format,
        "lean-rust-core.target-validation.v2"
    );
    assert!(!coverage.recursive_data_policy.is_empty());
    assert!(!coverage.metrics.is_empty());
    assert!(!coverage.entries.is_empty());
}

#[test]
fn compatibility_report_records_feature_tags() {
    let report = typed_compatibility_report();
    assert_eq!(report.feature_tag_schema, "lean-rust-core.feature-tags.v1");
    assert!(report.diagnostics.iter().any(|diagnostic| {
        diagnostic
            .features
            .iter()
            .any(|tag| tag == "structural-list-loop")
    }));
    assert!(report.diagnostics.iter().any(|diagnostic| {
        diagnostic
            .features
            .iter()
            .any(|tag| tag == "exact-integer-mode")
    }));
    assert!(report
        .diagnostics
        .iter()
        .any(|diagnostic| diagnostic.next_feature.is_none()));
    assert!(report
        .diagnostics
        .iter()
        .any(|diagnostic| diagnostic.next_feature.as_deref() == Some("closure-conversion")));
}

#[test]
fn typed_report_counts_and_feature_flags_match_generated_artifacts() {
    let validation = typed_validation_report();
    let compatibility = typed_compatibility_report();
    let proof = typed_proof_report();
    let build = typed_build_metadata();
    let coverage = typed_coverage_dashboard();
    let (functions, types) = generated_symbols();

    assert_eq!(validation.generated_function_count, functions.len() as u64);
    assert_eq!(validation.generated_type_count, types.len() as u64);
    assert_eq!(
        validation.feature_summary.ffi_wrapper_count,
        validation.ffi_boundary_export_count
    );
    assert!(validation
        .feature_summary
        .first20_completion
        .iter()
        .any(|item| item == "ExtractIR pipeline"));
    assert!(validation.checks.iter().any(|check| {
        check.name == "next20-base-type-universe" && check.status == ValidationCheckStatus::Passed
    }));
    assert!(validation.checks.iter().any(|check| {
        check.name == "next20-std-implementation" && check.status == ValidationCheckStatus::Passed
    }));
    assert!(validation
        .feature_summary
        .remaining_completion
        .iter()
        .any(|item| item == "publishing"));

    assert_eq!(
        compatibility.generated_function_count,
        functions.len() as u64
    );
    assert!(compatibility.diagnostics.iter().all(|diagnostic| {
        matches!(
            diagnostic.code,
            CompatibilityDiagnosticCode::Supported
                | CompatibilityDiagnosticCode::UnsupportedDeclaration
        )
    }));

    assert_eq!(
        proof.policy.target_validation_snapshot,
        validation.target_validation_format
    );
    assert_eq!(
        proof.policy.coverage_dashboard,
        "rust/coverage-dashboard.json"
    );
    assert!(proof.policy.extract_ir_pipeline);
    assert!(proof.policy.runtime_value_denotation);
    assert!(proof.policy.source_span_diagnostics);
    assert!(proof.policy.ci_end_to_end_matrix);
    assert!(proof.policy.remaining_completion_rows_41_63);
    assert_eq!(proof.policy.expanded_diagnostic_codes, "LRC001-LRC014");

    assert_eq!(build.generated_artifacts.len(), 9);
    assert!(build
        .workspace_crates
        .iter()
        .any(|crate_name| crate_name == "lean-rust-core-validate"));
    assert!(build
        .generated_artifacts
        .iter()
        .any(|path| path == "rust/coverage-dashboard.json"));

    assert!(coverage
        .metrics
        .iter()
        .all(|metric| metric.covered <= metric.total));
    assert!(coverage.metrics.iter().all(|metric| metric.percent <= 100));
    assert!(coverage
        .entries
        .iter()
        .any(|entry| entry.feature == "extract-ir-pipeline"));
    assert!(coverage
        .entries
        .iter()
        .any(|entry| entry.feature == "remaining-completion-rows-41-63"));
}

#[test]
fn validation_report_counts_match_generated_rust() {
    let (functions, types) = generated_symbols();
    let report = typed_validation_report();

    assert_eq!(report.generated_function_count, functions.len() as u64);
    assert_eq!(report.generated_type_count, types.len() as u64);

    let required_functions = &report.required_functions;
    assert_eq!(required_functions.len(), functions.len());
    for name in required_functions {
        assert!(
            functions.contains(name),
            "required function {name} was not generated"
        );
    }

    let required_types = &report.required_types;
    assert_eq!(required_types.len(), types.len());
    for name in required_types {
        assert!(
            types.contains(name),
            "required type {name} was not generated"
        );
    }
}

#[test]
fn compatibility_report_diagnostics_match_generated_output() {
    let (functions, _) = generated_symbols();
    let report = typed_compatibility_report();

    assert_eq!(report.generated_function_count, functions.len() as u64);

    let mut supported_functions = BTreeSet::new();

    for diagnostic in &report.diagnostics {
        let rust_name = &diagnostic.rust_name;
        assert!(
            !diagnostic.features.is_empty()
                || diagnostic.code == CompatibilityDiagnosticCode::UnsupportedDeclaration,
            "supported diagnostic {rust_name} should carry at least one feature tag"
        );

        match diagnostic.code {
            CompatibilityDiagnosticCode::Supported => {
                assert!(
                    functions.contains(rust_name),
                    "supported diagnostic {rust_name} should be generated"
                );
                supported_functions.insert(rust_name.clone());
            }
            CompatibilityDiagnosticCode::UnsupportedDeclaration => {
                assert!(
                    !functions.contains(rust_name),
                    "unsupported diagnostic {rust_name} must not be generated"
                );
            }
        }
    }

    for function in functions {
        assert!(
            supported_functions.contains(&function),
            "generated function {function} lacks a supported diagnostic"
        );
    }
}

#[test]
fn validation_report_records_current_subset_gates() {
    let report = include_str!("../validation-report.json");

    assert!(report.contains("lean-rust-core.rust-validation.v1"));
    assert!(report.contains("direct-lean-emits-rust"));
    assert!(report.contains("lean-evaluator-differential-tests"));
    assert!(report.contains("safe-rust-subset-gate"));
    assert!(report.contains("payload-enum-match-lowering"));
    assert!(report.contains("general-pattern-compiler"));
    assert!(report.contains("constructor-pattern-rust-emission"));
    assert!(report.contains("first-order-call-lowering"));
    assert!(report.contains("surface-evaluator-extracted-subset-tests"));
    assert!(report.contains("extractor-owned-surface-artifact"));
    assert!(report.contains("rust-identifier-hygiene"));
    assert!(report.contains("syn-parser-backed-validation"));
    assert!(report.contains("json-artifact-parse-validation"));
    assert!(report.contains("compatibility-report-output-consistency"));
    assert!(report.contains("exact-toolchain-pins"));
    assert!(report.contains("release-fallback-ban"));
    assert!(report.contains("automatic-monomorphization"));
    assert!(report.contains("phase-1-recursion-policy"));
    assert!(report.contains("parameterized-data-lowering"));
    assert!(report.contains("standard-container-shapes"));
    assert!(report.contains("standard-combinator-lowering"));
    assert!(report.contains("structural-recursion-lowering"));
    assert!(report.contains("std-library-lowering-table"));
    assert!(report.contains("pure-monadic-do-lowering"));
    assert!(report.contains("tail-recursion-loop-lowering"));
    assert!(report.contains("list-length-structural-lowering"));
    assert!(report.contains("dependent-shape-erasure"));
    assert!(report.contains("proof-field-erasure"));
    assert!(report.contains("exact-integer-modes"));
    assert!(report.contains("captured-closure-conversion"));
    assert!(report.contains("closure-converted-environment-lowering"));
    assert!(report.contains("finite-defunctionalization"));
    assert!(report.contains("recursive-user-data-box-layout"));
    assert!(report.contains("target-validation-v2-coverage-dashboard"));
    assert!(report.contains("coverage-dashboard-json-parse-validation"));
    assert!(report.contains("typeclass-dictionary-erasure"));
    assert!(report.contains("transitive-helper-extraction"));
    assert!(report.contains("proof-erased-binders"));
    assert!(report.contains("limited-higher-order-function-pointer"));
    assert!(report.contains("rust-to-target-ir-translation-validation"));
    assert!(report.contains("target-validation-snapshot"));
    assert!(report.contains("target-fingerprint-interpreter"));
    assert!(report.contains("property-differential-seeds"));
    assert!(report.contains("ffi-boundary-exporter"));
    assert!(report.contains("ffi-feature-isolation"));
    assert!(report.contains("ffi-result-status-out-params"));
    assert!(report.contains("lean-rust-core.target-validation.v2"));
    assert!(report.contains("leanprover/lean4:v4.22.0"));
    assert!(report.contains("1.85.0"));
    assert!(!report.contains("\"status\": \"failed\""));
}

#[test]
fn generated_source_stays_inside_safe_subset_textually() {
    let source = include_str!("../src/generated.rs");

    for banned in [
        "unsafe",
        "extern \"C\"",
        "panic!",
        "todo!",
        "unimplemented!",
        "/* malformed",
        "unsupported wrapping op",
    ] {
        assert!(
            !source.contains(banned),
            "generated Rust contained banned fragment: {banned}"
        );
    }

    for required in [
        "pub struct Point",
        "pub struct BoundedProof",
        "pub struct BoxedU32",
        "pub struct AddDeltaU32Env",
        "pub enum Choice",
        "pub enum TaggedU32",
        "pub enum Step",
        "pub enum U32FnCase",
        "pub enum BinaryTreeU32",
        "pub enum ExprU32",
        "pub enum Ordering",
        "pub fn clamp_u32",
        "pub fn echo_string",
        "pub fn echo_list_u32",
        "pub fn echo_array_u32",
        "pub fn list_map_inc_u32",
        "pub fn list_fold_sum_u32",
        "pub fn list_filter_nonzero_u32",
        "pub fn list_foldr_sum_u32",
        "pub fn exact_nat_add",
        "pub fn exact_int_add",
        "pub fn exact_int_mul",
        "pub fn list_append_u32",
        "pub fn list_find_nonzero_u32",
        "pub fn array_push_u32",
        "pub fn option_getd_u32",
        "pub fn result_map_err_inc_u32",
        "pub fn except_do_inc_u32",
        "pub fn reader_add_env_u32",
        "pub fn state_tick_u32",
        "pub fn echo_prod_u32",
        "pub fn echo_sum_u32",
        "pub fn helper_chain_u32",
        "pub fn proof_erased_u32",
        "pub fn bounded_proof_make_u32",
        "pub fn bounded_proof_value_u32",
        "pub fn subtype_val_u32",
        "pub fn subtype_inc_u32",
        "pub fn subtype_roundtrip_u32",
        "pub fn fin_checked10_u32",
        "pub fn vector_map_inc3_u32",
        "pub fn boxed_u32",
        "pub fn tagged_default_u32",
        "pub fn unsupported_higher_order_u32",
        "pub fn option_default_u64",
        "pub fn generic_beq_u32",
        "pub fn step_amount_or",
        "pub fn inc_twice_u32",
        "pub fn step_amount_plus_one_or",
        "pub fn generic_identity__u32",
        "pub fn generic_choose__point",
        "pub fn generic_option_default__step",
        "pub fn helper_inc_fixed",
        "pub fn nat_sum_to_u32",
        "pub fn vector_echo3_u32",
        "pub fn general_bool_match_u32",
        "pub fn general_option_match_u32",
        "pub fn general_step_match_u32",
        "pub fn pair_sum_match_u32",
        "pub fn list_length_u32",
        "pub fn tail_sum_down_u32",
        "pub fn option_do_inc_u32",
        "pub fn closure_apply_capture_u32",
        "pub fn closure_env_apply_add_delta_u32",
        "pub fn closure_env_map_add_delta_u32",
        "pub fn defun_apply_u32",
        "pub fn defun_compose_inc_double_u32",
        "pub fn defun_apply_add5_u32",
        "pub fn defun_map_selected_u32",
        "pub fn tree_leaf_u32",
        "pub fn tree_node_u32",
        "pub fn tree_size_u32",
        "pub fn tree_sum_u32",
        "pub fn expr_lit_u32",
        "pub fn expr_add_u32",
        "pub fn expr_eval_u32",
        "pub fn auto_identity_u32",
        "pub fn auto_choose_point",
        "pub fn auto_option_default_step",
    ] {
        assert!(
            source.contains(required),
            "generated Rust did not contain required fragment: {required}"
        );
    }
}

#[test]
fn build_metadata_records_pins_and_fallback_policy() {
    let metadata = include_str!("../build-metadata.json");

    assert!(metadata.contains("lean-rust-core.build-metadata.v1"));
    assert!(metadata.contains("leanprover/lean4:v4.22.0"));
    assert!(metadata.contains("1.85.0"));
    assert!(metadata.contains("LEAN_RUST_CORE_ALLOW_FALLBACK"));
    assert!(metadata.contains("rust/target-validation.txt"));
    assert!(metadata.contains("rust/src/ffi_generated.rs"));
    assert!(metadata.contains("rust/coverage-dashboard.json"));
}

#[test]
fn target_validation_snapshot_records_generated_subset() {
    let snapshot = include_str!("../target-validation.txt");

    assert!(snapshot.contains("FORMAT\tlean-rust-core.target-validation.v2"));
    assert!(snapshot.contains("TYPE\tstruct\tBoundedProof"));
    assert!(snapshot.contains("TYPE\tstruct\tBoxedU32"));
    assert!(snapshot.contains("TYPE\tenum\tOrdering"));
    assert!(snapshot.contains("FN\tclamp_u32"));
    assert!(snapshot.contains("FN\tunsupported_higher_order_u32"));
    assert!(snapshot.contains("call_value(var(f),var(x))"));
    assert!(snapshot.contains("FN\tlist_map_inc_u32"));
    assert!(snapshot.contains("list_map(x,var(xs),add(var(x),lit(1)))"));
    assert!(snapshot.contains("FN\tlist_fold_sum_u32"));
    assert!(snapshot.contains("list_foldl(acc,x,lit(0),var(xs),add(var(acc),var(x)))"));
    assert!(snapshot.contains("FN\tlist_filter_nonzero_u32"));
    assert!(snapshot.contains("FN\tnat_sum_to_u32"));
    assert!(snapshot.contains("FN\tvector_echo3_u32"));
    assert!(snapshot.contains("FN\tgeneral_bool_match_u32"));
    assert!(snapshot.contains("FN\tlist_length_u32"));
    assert!(snapshot.contains("FN\ttail_sum_down_u32"));
    assert!(snapshot.contains("FN\texact_nat_add"));
    assert!(snapshot.contains("num_bigint::BigUint"));
    assert!(snapshot.contains("FN\tgeneric_beq_u32"));
    assert!(snapshot.contains("FN\tdecidable_eq_u32"));
    assert!(snapshot.contains("FN\tord_compare_u32"));
    assert!(snapshot.contains("compare(var(a),var(b))"));
    assert!(snapshot.contains("FN\toption_do_inc_u32"));
    assert!(snapshot.contains("match_option(var(x),none=>none|some(v)=>some(add(var(v),lit(1))))"));
    assert!(snapshot.contains("FN\tclosure_apply_capture_u32"));
    assert!(snapshot.contains("closure_apply(y,var(x),add(var(y),var(delta)))"));
    assert!(snapshot.contains("TYPE\tstruct\tAddDeltaU32Env"));
    assert!(snapshot.contains("TYPE\tenum\tU32FnCase"));
    assert!(snapshot.contains("TYPE\tenum\tBinaryTreeU32"));
    assert!(snapshot.contains("TYPE\tenum\tExprU32"));
    assert!(snapshot.contains("FN\tclosure_env_apply_add_delta_u32"));
    assert!(snapshot.contains("FN\tclosure_env_map_add_delta_u32"));
    assert!(snapshot.contains("FN\tdefun_apply_u32"));
    assert!(snapshot.contains("FN\tdefun_compose_inc_double_u32"));
    assert!(snapshot.contains("FN\ttree_size_u32"));
    assert!(snapshot.contains("FN\texpr_eval_u32"));
    assert!(snapshot.contains("box(var(left))"));
    assert!(snapshot.contains("deref(var(left))"));
    assert!(snapshot.contains("FN\tbounded_proof_make_u32"));
    assert!(snapshot.contains("FN\tsubtype_val_u32"));
    assert!(snapshot.contains("FN\tsubtype_inc_u32"));
    assert!(snapshot.contains("FN\tsubtype_roundtrip_u32"));
    assert!(snapshot.contains("FN\tfin_checked10_u32"));
    assert!(snapshot.contains("FN\tvector_map_inc3_u32"));
    assert!(snapshot.contains("FN\tlist_append_u32"));
    assert!(snapshot.contains("FN\treader_add_env_u32"));
    assert!(snapshot.contains("FN\tstate_tick_u32"));
}

#[test]
fn coverage_dashboard_records_feature_families() {
    let dashboard = parse_json_artifact("coverage-dashboard.json", COVERAGE_DASHBOARD);
    assert_eq!(
        dashboard["format"].as_str(),
        Some("lean-rust-core.coverage-dashboard.v1")
    );
    assert_eq!(
        dashboard["target_validation_format"].as_str(),
        Some("lean-rust-core.target-validation.v2")
    );
    let text = include_str!("../coverage-dashboard.json");
    assert!(text.contains("recursive-owned-box-data"));
    assert!(text.contains("property-seed-validation"));
    assert!(text.contains("BinaryTreeU32"));
    assert!(text.contains("ExprU32"));
}

#[test]
fn ffi_boundary_snapshot_is_feature_gated_and_separate() {
    let ffi = include_str!("../src/ffi_generated.rs");
    let lib = include_str!("../src/lib.rs");

    assert!(lib.contains("#[cfg(feature = \"ffi\")]"));
    assert!(ffi.contains("extern \"C\" fn lrc_add_u32"));
    assert!(ffi.contains("unsafe extern \"C\" fn lrc_result_ok_u32"));
    assert!(ffi.contains("lower_result_u32_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_general_bool_match_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_pair_sum_match_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_tail_sum_down_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_reader_add_env_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_closure_env_apply_add_delta_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_defun_compose_inc_double_u32"));
    assert!(!ffi.contains("lrc_except_do_inc_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_subtype_inc_u32"));
    assert!(ffi.contains("extern \"C\" fn lrc_subtype_roundtrip_u32"));
}

#[test]
fn proof_report_records_closure_and_defunctionalization_policies() {
    let report = parse_json_artifact("proof-report.json", PROOF_REPORT);

    assert_eq!(
        report["policy"]["closure_conversion"].as_str(),
        Some("explicit-environment-structs")
    );
    assert_eq!(
        report["policy"]["defunctionalization"].as_str(),
        Some("finite-enum-cases")
    );
    assert_eq!(
        report["policy"]["recursive_data_layout"].as_str(),
        Some("owned-box")
    );
    assert_eq!(
        report["policy"]["coverage_dashboard"].as_str(),
        Some("rust/coverage-dashboard.json")
    );
}
