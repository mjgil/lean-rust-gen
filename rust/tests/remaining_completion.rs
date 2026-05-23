use lean_rust_core_generated::runtime::*;

const PROOF_REPORT: &str = include_str!("../proof-report.json");
const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");

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
        "remaining-preservation-skeleton",
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
