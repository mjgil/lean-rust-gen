use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;

use lean_rust_core_generated::runtime::*;
use lean_rust_core_generated::{
    checked_add_u32, checked_cast_u64_to_u32, checked_div_u32, checked_mod_u32, checked_sub_u32,
    preconditioned_div_u32, preconditioned_mod_u32, saturating_add_u32, saturating_sub_u32,
};
use num_bigint::{BigInt, BigUint};

const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf()
}

fn expected_fixture_files(directory: &str) -> Vec<PathBuf> {
    let path = repo_root().join(directory);
    let mut entries = fs::read_dir(path)
        .expect("fixture directory")
        .filter_map(|entry| entry.ok().map(|item| item.path()))
        .filter(|path| path.extension().and_then(|ext| ext.to_str()) == Some("json"))
        .collect::<Vec<_>>();
    entries.sort();
    entries
}

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
        "next20-diagnostic-corpus",
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
fn next20_diagnostic_corpus_covers_all_rejection_paths() {
    let mut codes = BTreeSet::new();
    let mut branches = BTreeSet::new();
    for directory in ["corpus/negative", "corpus/unsupported"] {
        for fixture in expected_fixture_files(directory) {
            let source = fs::read_to_string(&fixture).expect("fixture JSON");
            let value: serde_json::Value =
                serde_json::from_str(&source).expect("valid fixture JSON");
            let tests = value["tests"]
                .as_array()
                .expect("tests array")
                .iter()
                .filter_map(|item| item.as_str())
                .collect::<BTreeSet<_>>();
            assert!(tests.contains("scripts/check-next-20-completion.py"));
            assert!(tests.contains("rust/tests/next20_completion.rs"));

            let docs = value["documentation"]
                .as_array()
                .expect("documentation array")
                .iter()
                .filter_map(|item| item.as_str())
                .collect::<BTreeSet<_>>();
            let code = value["diagnostic_code"]
                .as_str()
                .expect("diagnostic code")
                .to_owned();
            let doc_anchor = format!("docs/DIAGNOSTICS.md#{}", code.to_lowercase());
            assert!(docs.contains(doc_anchor.as_str()));
            let expected_status = if code == "LRC005" {
                "error"
            } else {
                "unsupported"
            };
            assert_eq!(
                value["expected_status"].as_str(),
                Some(expected_status),
                "wrong expected status for {code}"
            );
            codes.insert(code);

            if let Some(branch) = value["extractor_branch"].as_str() {
                branches.insert(branch.to_owned());
            }
        }
    }

    let expected_codes = (1..=14)
        .map(|idx| format!("LRC{idx:03}"))
        .collect::<BTreeSet<_>>();
    assert_eq!(codes, expected_codes);
    assert_eq!(
        branches,
        BTreeSet::from([
            String::from("extract-regular-unsupported-export"),
            String::from("extract-mono-unsupported-export"),
            String::from("auto-helper-fixpoint-fuel"),
            String::from("auto-generated-specs-fixpoint-fuel"),
        ])
    );

    let diagnostics =
        fs::read_to_string(repo_root().join("docs/DIAGNOSTICS.md")).expect("diagnostics doc");
    for idx in 1..=14 {
        let code = format!("LRC{idx:03}");
        let marker = format!("## {code}");
        let start = diagnostics.find(&marker).expect("diagnostic section");
        let rest = &diagnostics[start + marker.len()..];
        let end = rest.find("\n## ").unwrap_or(rest.len());
        let section = &rest[..end];
        assert!(
            section.to_lowercase().contains("example"),
            "missing example for {code}"
        );
        assert!(
            section.contains("```lean"),
            "missing Lean example for {code}"
        );
    }
}

#[test]
fn next20_parameterized_data_examples_cover_multi_parameter_and_nested_shapes() {
    let generated =
        fs::read_to_string(repo_root().join("rust/src/generated.rs")).expect("generated Rust");
    for needle in [
        "pub fn checked_add_u32",
        "pub fn checked_sub_u32",
        "pub fn checked_div_u32",
        "pub fn checked_mod_u32",
        "pub fn saturating_add_u32",
        "pub fn saturating_sub_u32",
        "pub fn preconditioned_div_u32",
        "pub fn preconditioned_mod_u32",
        "pub fn checked_cast_u64_to_u32",
        "pub struct PairboxU32String",
        "pub struct PairboxStringU32",
        "pub enum PairchoiceU32String",
        "pub struct NestedpayloadU32String",
        "pub fn pair_box_make_u32_string",
        "pub fn pair_box_swap_u32_string",
        "pub fn pair_choice_left_u32_string",
        "pub fn pair_choice_default_u32_string",
        "pub fn nested_payload_ok_u32_string",
        "pub fn nested_payload_err_u32_string",
        "pub fn nested_payload_value_or_u32_string",
    ] {
        assert!(
            generated.contains(needle),
            "missing generated item {needle}"
        );
    }

    let target_validation = fs::read_to_string(repo_root().join("rust/target-validation.txt"))
        .expect("target validation");
    for needle in [
        "FN\tchecked_add_u32",
        "FN\tchecked_sub_u32",
        "FN\tchecked_div_u32",
        "FN\tchecked_mod_u32",
        "FN\tsaturating_add_u32",
        "FN\tsaturating_sub_u32",
        "FN\tpreconditioned_div_u32",
        "FN\tpreconditioned_mod_u32",
        "FN\tchecked_cast_u64_to_u32",
        "TYPE\tstruct\tPairboxU32String",
        "TYPE\tstruct\tPairboxStringU32",
        "TYPE\tenum\tPairchoiceU32String",
        "TYPE\tstruct\tNestedpayloadU32String",
        "FN\tpair_box_make_u32_string",
        "FN\tpair_box_swap_u32_string",
        "FN\tpair_choice_default_u32_string",
        "FN\tnested_payload_value_or_u32_string",
    ] {
        assert!(
            target_validation.contains(needle),
            "missing target-validation item {needle}"
        );
    }

    let pair_box = serde_json::from_str::<serde_json::Value>(include_str!(
        "../../corpus/positive/parameterized_pair_box.expected.json"
    ))
    .unwrap();
    assert_eq!(pair_box["kind"].as_str(), Some("positive"));
    assert_eq!(pair_box["expected_status"].as_str(), Some("supported"));
    assert_eq!(
        pair_box["required_features"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|item| item.as_str())
            .collect::<BTreeSet<_>>(),
        BTreeSet::from(["generic-monomorphization", "struct-enum-shape"])
    );

    let nested = serde_json::from_str::<serde_json::Value>(include_str!(
        "../../corpus/positive/parameterized_nested_payload.expected.json"
    ))
    .unwrap();
    assert_eq!(nested["kind"].as_str(), Some("positive"));
    assert_eq!(nested["expected_status"].as_str(), Some("supported"));
    assert_eq!(
        nested["required_features"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|item| item.as_str())
            .collect::<BTreeSet<_>>(),
        BTreeSet::from([
            "container-shape",
            "generic-monomorphization",
            "struct-enum-shape",
        ])
    );

    let dependent = serde_json::from_str::<serde_json::Value>(include_str!(
        "../../corpus/unsupported/dependent_generic_index.expected.json"
    ))
    .unwrap();
    assert_eq!(dependent["kind"].as_str(), Some("unsupported"));
    assert_eq!(dependent["diagnostic_code"].as_str(), Some("LRC008"));
    assert_eq!(
        dependent["next_feature"].as_str(),
        Some("dependent erasure proof classifier")
    );

    let generics_doc =
        fs::read_to_string(repo_root().join("docs/GENERICS.md")).expect("generics doc");
    for phrase in [
        "multi-parameter",
        "nested",
        "dependent generic",
        "index-free",
        "LRC013",
    ] {
        assert!(
            generics_doc.contains(phrase),
            "docs/GENERICS.md missing {phrase}"
        );
    }
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
    assert_eq!(checked_add_u32(u32::MAX, 1), None);
    assert_eq!(checked_sub_u32(0, 1), None);
    assert_eq!(checked_div_u32(12, 0), None);
    assert_eq!(checked_mod_u32(12, 0), None);
    assert_eq!(saturating_add_u32(u32::MAX, 1), u32::MAX);
    assert_eq!(saturating_sub_u32(0, 1), 0);
    assert_eq!(
        preconditioned_div_u32(12, 0),
        Err(String::from("division-by-zero"))
    );
    assert_eq!(
        preconditioned_mod_u32(12, 0),
        Err(String::from("modulus-by-zero"))
    );
    assert_eq!(checked_cast_u64_to_u32(u64::from(u32::MAX) + 1), None);

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
