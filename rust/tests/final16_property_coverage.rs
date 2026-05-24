use std::collections::BTreeSet;
use std::path::PathBuf;

use lean_rust_core_generated::runtime::*;
use lean_rust_core_generated::*;

const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");
const PROPERTY_SEEDS: &str = include_str!("../../corpus/property/seeds.json");

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("rust crate should live under the repo root")
        .to_path_buf()
}

#[test]
fn property_seed_families_are_present_and_exercised() {
    for family in [
        "numeric-edge-cases",
        "container-roundtrip",
        "closure-and-dictionary",
        "ffi-handle-lifecycle",
        "generated-subset-target-grammar",
    ] {
        assert!(
            PROPERTY_SEEDS.contains(family),
            "missing property seed family {family}"
        );
    }

    assert_eq!(u32_checked_add(u32::MAX, 1), None);
    assert_eq!(u32_preconditioned_mod(8, 0), Err("modulus-by-zero"));
    assert_eq!(list_reverse_u32(vec![0, 1, u32::MAX]), vec![u32::MAX, 1, 0]);
    assert!(dictionary_beq_u32(BEQ_U32, 42, 42));
    assert_eq!(closure_return_add_delta(5).apply(37), 42);

    let tree = tree_node_u32(tree_leaf_u32(()), 42, tree_leaf_u32(()));
    assert_eq!(tree_size_u32(tree.clone()), 1);
    assert_eq!(tree_sum_u32(tree), 42);
}

#[test]
fn quantitative_coverage_dashboard_has_required_denominators() {
    let dashboard: serde_json::Value = serde_json::from_str(COVERAGE_DASHBOARD).unwrap();
    let denominators = dashboard["metrics"]
        .as_array()
        .expect("coverage dashboard metrics")
        .iter()
        .filter_map(|metric| metric["denominator"].as_str())
        .collect::<BTreeSet<_>>();

    for denominator in [
        "checklist_rows_41_56",
        "rust_workspace_crates",
        "final_docs",
        "property_seed_families",
        "release_acceptance_gates",
    ] {
        assert!(
            denominators.contains(denominator),
            "missing dashboard denominator {denominator}"
        );
    }
}

#[test]
fn coverage_dashboard_entries_are_evidence_backed() {
    let dashboard: serde_json::Value = serde_json::from_str(COVERAGE_DASHBOARD).unwrap();
    let docs = include_str!("../../docs/COVERAGE.md");

    for entry in dashboard["entries"]
        .as_array()
        .expect("coverage dashboard entries")
    {
        let feature = entry["feature"].as_str().expect("coverage feature");
        let evidence = entry["evidence"].as_object().expect("coverage evidence");
        for key in [
            "implementation",
            "tests",
            "docs",
            "generated_examples",
            "diagnostics",
        ] {
            let values = evidence[key].as_array().expect("coverage evidence list");
            assert!(
                !values.is_empty(),
                "coverage entry {feature} is missing {key} evidence"
            );
            if key != "diagnostics" {
                for value in values {
                    let relative = value.as_str().expect("coverage evidence path");
                    assert!(
                        repo_root().join(relative).exists(),
                        "coverage entry {feature} points to missing {key} path {relative}"
                    );
                }
            }
        }
    }

    assert!(docs.contains("evidence"));
    assert!(docs.contains("generated_examples"));
    assert!(docs.contains("diagnostics"));
}
