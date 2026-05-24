use lean_rust_core_generated::runtime::*;
use lean_rust_core_generated::*;
use lean_rust_core_validate::{
    eval_target_term, generate_target_term_cases, generated_terms_are_well_typed,
    minimize_target_term, target_term_head, RecursiveTree, TargetTerm, TargetValue,
};
use std::fs;
use std::path::PathBuf;

const PROOF_REPORT: &str = include_str!("../proof-report.json");
const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf()
}

#[test]
fn remaining_rows_reports_and_dashboard_are_complete() {
    for needle in [
        "generated_typeclass_dictionaries_complete",
        "first_class_closure_objects_complete",
        "pure_do_notation_complete",
        "controlled_io_boundary_complete",
        "complete_generated_subset_semantics",
        "preservation_skeleton_complete",
        "property_generators_complete",
        "feature_complete_coverage_dashboard",
        "ci_release_matrix_complete",
        "publishing_versioning_complete",
        "remaining_completion_rows_41_63",
    ] {
        assert!(
            PROOF_REPORT.contains(needle),
            "proof report missing {needle}"
        );
    }

    for check in [
        "remaining-typeclass-dictionaries",
        "remaining-first-class-closures",
        "remaining-pure-do-notation",
        "remaining-controlled-io-boundary",
        "remaining-complete-generated-semantics",
        "remaining-preservation-proved-lemmas",
        "remaining-property-generators",
        "remaining-feature-complete-coverage",
        "remaining-ci-release-matrix",
        "remaining-publishing-versioning",
        "remaining-completion-gate",
    ] {
        assert!(
            VALIDATION_REPORT.contains(check),
            "validation report missing {check}"
        );
    }

    for denominator in [
        "checklist_rows_41_63",
        "generated_subset_semantics_heads",
        "preservation_obligations",
        "lean_feature_families",
        "property_generators",
    ] {
        assert!(
            COVERAGE_DASHBOARD.contains(denominator),
            "coverage dashboard missing {denominator}"
        );
    }
}

#[test]
fn remaining_runtime_features_are_exercised() {
    assert_eq!(dictionary_add_u32(ADD_U32, u32::MAX, 1), 0);
    assert_eq!(dictionary_default_u32(DEFAULT_U32), 0);
    assert_eq!(dictionary_to_string_u32(TO_STRING_U32, 42), "42");

    let stored = closure_store_add_delta(5);
    assert_eq!(closure_apply_stored(&stored, 37), 42);
    assert_eq!(
        closure_apply_stored(&closure_return_stored_inc_then_add(4), 37),
        42
    );

    assert_eq!(option_result_do_runtime(Some(Ok(41))), Ok(Some(42)));
    assert_eq!(except_state_do_runtime(Ok(40), 2), (Ok(42), 3));
    assert_eq!(reader_state_do_runtime(5, 37), (42, 38));

    let transcript = ControlledIoProgram::new()
        .print_line("hello")
        .read_env("HOME")
        .monotonic_time(42)
        .transcript();
    assert_eq!(transcript, vec!["print:hello", "read-env:HOME", "time:42"]);

    assert_eq!(
        scalar_property_values_u32(),
        vec![0, 1, 2, 41, 42, u32::MAX]
    );
    assert_eq!(container_property_values_u32()[2], vec![1, 2, u32::MAX]);
}

#[test]
fn remaining_pure_do_generated_examples_cover_bind_and_seq_shapes() {
    assert_eq!(option_do_inc_u32(Some(41)), Some(42));
    assert_eq!(option_seq_right_u32(Some(5)), Some(41));
    assert_eq!(option_seq_left_u32(Some(5)), Some(5));
    assert_eq!(except_do_inc_u32(Ok(41)), Ok(42));
    assert_eq!(except_seq_right_u32(Ok(5)), Ok(41));
    assert_eq!(except_seq_left_u32(Ok(5)), Ok(5));
    assert_eq!(reader_do_add_u32(5, 37), 42);
    assert_eq!(reader_seq_right_u32(5, 41), 42);
    assert_eq!(reader_seq_left_u32(5), 5);
    assert_eq!(state_do_tick_u32(41), (41, 42));
    assert_eq!(state_seq_right_u32(5), (6, 5));
    assert_eq!(state_seq_left_u32(5), (5, 6));
    assert_eq!(except_state_do_u32(Err(7), 2), (Err(7), 2));
    assert_eq!(except_state_do_u32(Ok(40), 2), (Ok(42), 3));
    assert_eq!(except_state_seq_right_u32(Err(7), 2), (Err(7), 2));
    assert_eq!(except_state_seq_right_u32(Ok(40), 2), (Ok(3), 2));
    assert_eq!(except_state_seq_left_u32(Err(7), 2), (Err(7), 2));
    assert_eq!(except_state_seq_left_u32(Ok(40), 2), (Ok(40), 3));
}

#[test]
fn remaining_source_level_closure_lowerings_are_exercised() {
    assert_eq!(stored_closure_apply_u32(5, 37), 42);
    assert_eq!(returned_closure_apply_u32(5, 37), 42);
    assert_eq!(passed_closure_apply_u32(5, 37), 42);
    assert_eq!(stored_multi_closure_apply_u32(1, 4, 30, 7), 42);
    assert_eq!(returned_multi_closure_apply_u32(1, 4, 30, 7), 42);
    assert_eq!(passed_multi_closure_apply_u32(1, 4, 30, 7), 42);
}

#[test]
fn remaining_preservation_theorems_are_named_and_documented() {
    for theorem in [
        "extraction_metadata_preserved",
        "dependent_erasure_runtime_carriers_preserved",
        "checked_surface_typing_preserved",
        "checked_surface_evaluation_preserved",
        "target_lowering_snapshot_preserved",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
    ] {
        assert!(
            PROOF_REPORT.contains(theorem),
            "proof report missing theorem fact {theorem}"
        );
    }

    let preservation =
        fs::read_to_string(repo_root().join("LeanRustCore/Preservation.lean")).expect("lean file");
    for theorem in [
        "extraction_metadata_preserved",
        "dependent_erasure_runtime_carriers_preserved",
        "checked_surface_typing_preserved",
        "checked_surface_evaluation_preserved",
        "target_lowering_snapshot_preserved",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
        "preservation_lemmas_completion_gate",
    ] {
        assert!(
            preservation.contains(theorem),
            "missing preservation theorem {theorem}"
        );
    }

    let docs =
        fs::read_to_string(repo_root().join("docs/PRESERVATION.md")).expect("preservation docs");
    for needle in [
        "proved Lean theorems",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
    ] {
        assert!(
            docs.contains(needle),
            "missing preservation doc text {needle}"
        );
    }

    let trusted =
        fs::read_to_string(repo_root().join("docs/TRUSTED_CORE.md")).expect("trusted core docs");
    for needle in ["proved Lean theorems", "regression-tested facts"] {
        assert!(
            trusted.contains(needle),
            "missing trusted-core text {needle}"
        );
    }
}

#[test]
fn remaining_validate_semantics_cover_representative_values() {
    let closure_term = TargetTerm::ClosureApply(
        Box::new(TargetTerm::ClosureAddDelta(Box::new(TargetTerm::U32(5)))),
        Box::new(TargetTerm::U32(37)),
    );
    assert_eq!(eval_target_term(&closure_term), Some(TargetValue::U32(42)));

    let dictionary_term = TargetTerm::DictionaryApply(
        Box::new(TargetTerm::DictionaryAdd),
        Box::new(TargetTerm::U32(u32::MAX)),
        Box::new(TargetTerm::U32(1)),
    );
    assert_eq!(
        eval_target_term(&dictionary_term),
        Some(TargetValue::U32(0))
    );

    let effect_term = TargetTerm::EffectResultBindAdd1(Box::new(TargetTerm::ResultOkU32(
        Box::new(TargetTerm::U32(41)),
    )));
    assert_eq!(
        eval_target_term(&effect_term),
        Some(TargetValue::ResultU32U32(Ok(42)))
    );

    let recursive_term = TargetTerm::RecursiveSum(Box::new(TargetTerm::Value(
        TargetValue::RecursiveTree(RecursiveTree::Node(
            Box::new(RecursiveTree::Leaf),
            42,
            Box::new(RecursiveTree::Leaf),
        )),
    )));
    assert_eq!(
        eval_target_term(&recursive_term),
        Some(TargetValue::U32(42))
    );
}

#[test]
fn remaining_property_generators_are_randomized_and_shrinkable() {
    let runtime_cases = generate_runtime_value_cases(0x5EED, 12);
    assert!(runtime_cases
        .iter()
        .all(|case| runtime_case_exercises_first_order_helpers(case, ADD_U32)));
    let runtime_min = minimize_runtime_value_case(
        RuntimeValueCase::BaseScalar(33),
        |case| matches!(case, RuntimeValueCase::BaseScalar(value) if *value >= 2),
    );
    assert_eq!(runtime_min, RuntimeValueCase::BaseScalar(2));

    let target_terms = generate_target_term_cases(0x5EED, 28, 3);
    assert!(generated_terms_are_well_typed(0x5EED, 28, 3));
    assert!(target_terms
        .iter()
        .any(|term| target_term_head(term) == "closure"));
    let target_min = minimize_target_term(
        TargetTerm::Add(Box::new(TargetTerm::U32(12)), Box::new(TargetTerm::U32(5))),
        |term| matches!(eval_target_term(term), Some(TargetValue::U32(value)) if value >= 2),
    );
    assert_eq!(target_min, TargetTerm::U32(2));
}
