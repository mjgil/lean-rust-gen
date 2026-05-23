use std::collections::BTreeSet;

use lean_rust_core_generated::runtime::*;
use num_bigint::{BigInt, BigUint};

const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");

#[test]
fn next20_reports_mark_rows_21_40_complete() {
    let validation: serde_json::Value = serde_json::from_str(VALIDATION_REPORT).unwrap();
    let checks = validation["checks"]
        .as_array()
        .expect("validation checks")
        .iter()
        .filter_map(|item| item["name"].as_str())
        .collect::<BTreeSet<_>>();
    for check in [
        "next20-base-type-universe",
        "next20-parameterized-data",
        "next20-generic-policy",
        "next20-numeric-semantics",
        "next20-dependent-erasure",
        "next20-recursive-discovery",
        "next20-ownership-policy",
        "next20-pattern-matrix",
        "next20-recursion-analysis",
        "next20-std-implementation",
        "next20-typeclass-specialization",
    ] {
        assert!(checks.contains(check), "missing validation check {check}");
    }

    let proof: serde_json::Value = serde_json::from_str(PROOF_REPORT).unwrap();
    let policy = proof["policy"].as_object().expect("proof policy");
    for flag in [
        "next20_completion",
        "parameterized_data_monomorphization",
        "rust_generic_emission_policy_final",
        "numeric_semantics_complete",
        "dependent_erasure_complete",
        "recursive_discovery_complete",
        "ownership_policy_complete",
        "pattern_matrix_complete",
        "recursion_analysis_complete",
        "std_lowering_implementation_complete",
        "typeclass_specialization_complete",
    ] {
        assert_eq!(
            policy.get(flag).and_then(|value| value.as_bool()),
            Some(true)
        );
    }

    let dashboard: serde_json::Value = serde_json::from_str(COVERAGE_DASHBOARD).unwrap();
    let metrics = dashboard["metrics"]
        .as_array()
        .expect("coverage metrics")
        .iter()
        .filter_map(|metric| metric["denominator"].as_str())
        .collect::<BTreeSet<_>>();
    assert!(metrics.contains("checklist_rows_21_40"));
}

#[test]
fn next20_runtime_helpers_cover_numeric_std_and_layouts() {
    // RcTreeU32 and ArenaTreeU32 are the row-32 runtime layout fixtures.
    assert_eq!(u32_checked_add(u32::MAX, 1), None);
    assert_eq!(u32_checked_div(12, 3), Some(4));
    assert_eq!(u32_checked_div(12, 0), None);
    assert_eq!(u32_checked_mod(12, 0), None);
    assert_eq!(u32_saturating_mul(u32::MAX, 2), u32::MAX);
    assert_eq!(i32_checked_add(i32::MAX, 1), None);
    assert_eq!(i64_checked_mul(i64::MAX, 2), None);
    assert_eq!(u64_to_u32_checked(u64::from(u32::MAX) + 1), None);
    assert_eq!(
        exact_nat_sub_checked(BigUint::from(42u32), BigUint::from(40u32)),
        Some(BigUint::from(2u32))
    );
    assert_eq!(
        exact_int_mul(BigInt::from(-7i32), BigInt::from(6i32)),
        BigInt::from(-42i32)
    );

    assert_eq!(list_append_u32(vec![1, 2], vec![3, 4]), vec![1, 2, 3, 4]);
    assert_eq!(list_find_nonzero_u32(&[0, 0, 42]), Some(42));
    assert_eq!(
        list_partition_nonzero_u32(vec![0, 1, 2, 0]),
        (vec![1, 2], vec![0, 0])
    );
    assert_eq!(array_get_u32(&[5, 6], 1), Some(6));
    assert_eq!(array_set_u32(vec![5, 6], 0, 9), Some(vec![9, 6]));
    assert_eq!(string_append(String::from("lean"), "-rust"), "lean-rust");
    assert!(string_contains("lean-rust-core", "rust"));
    assert_eq!(borrowed_vec_len_u32(&[1, 2, 3]), 3);
    assert_eq!(clone_vec_for_shared_use(&[9, 8]), vec![9, 8]);

    let leaf = rc_tree_leaf_u32();
    let tree = rc_tree_node_u32(leaf.clone(), 42, leaf);
    assert_eq!(rc_tree_sum_u32(&tree), 42);

    let mut arena = ArenaTreeU32::new();
    let left = arena.leaf();
    let right = arena.leaf();
    let root = arena.node(left, 42, right).unwrap();
    assert_eq!(arena.sum(root), Some(42));
    assert_eq!(arena.node(ArenaNodeId(999), 1, root), None);

    assert!(dictionary_beq_u32(BEQ_U32, 7, 7));
    assert_eq!(
        dictionary_compare_u32(ORD_U32, 1, 2),
        std::cmp::Ordering::Less
    );
}
