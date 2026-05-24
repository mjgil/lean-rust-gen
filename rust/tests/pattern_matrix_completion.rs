use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;

use lean_rust_core_generated::{
    list_head_or_zero_u32, list_second_or_zero_u32, nat_pred_or_zero_u32, nat_two_step_or_zero_u32,
    tree_leaf_u32, tree_node_u32, tree_sum_u32,
};

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf()
}

#[test]
fn pattern_matrix_examples_cover_list_nat_tree_and_nested_shapes() {
    let generated =
        fs::read_to_string(repo_root().join("rust/src/generated.rs")).expect("generated Rust");
    for needle in [
        "pub fn list_head_or_zero_u32",
        "pub fn list_second_or_zero_u32",
        "pub fn nat_pred_or_zero_u32",
        "pub fn nat_two_step_or_zero_u32",
        "pub fn tree_sum_u32",
    ] {
        assert!(
            generated.contains(needle),
            "missing generated item {needle}"
        );
    }

    let target_validation = fs::read_to_string(repo_root().join("rust/target-validation.txt"))
        .expect("target validation");
    for needle in [
        "FN\tlist_head_or_zero_u32",
        "FN\tlist_second_or_zero_u32",
        "FN\tnat_pred_or_zero_u32",
        "FN\tnat_two_step_or_zero_u32",
        "FN\ttree_sum_u32",
    ] {
        assert!(
            target_validation.contains(needle),
            "missing target-validation item {needle}"
        );
    }

    assert_eq!(list_head_or_zero_u32(vec![]), 0);
    assert_eq!(list_head_or_zero_u32(vec![41, 7]), 41);
    assert_eq!(list_second_or_zero_u32(vec![41]), 0);
    assert_eq!(list_second_or_zero_u32(vec![41, 7, 9]), 7);
    assert_eq!(nat_pred_or_zero_u32(0), 0);
    assert_eq!(nat_pred_or_zero_u32(5), 4);
    assert_eq!(nat_two_step_or_zero_u32(1), 0);
    assert_eq!(nat_two_step_or_zero_u32(5), 5);
    assert_eq!(
        tree_sum_u32(tree_node_u32(tree_leaf_u32(()), 42, tree_leaf_u32(()))),
        42
    );

    for (path, source, features) in [
        (
            "corpus/positive/pattern_list_head.expected.json",
            "LeanRustCore.Examples.list_head_or_zero_u32",
            BTreeSet::from(["container-shape", "general-pattern-match"]),
        ),
        (
            "corpus/positive/pattern_list_second.expected.json",
            "LeanRustCore.Examples.list_second_or_zero_u32",
            BTreeSet::from(["container-shape", "general-pattern-match"]),
        ),
        (
            "corpus/positive/pattern_nat_pred.expected.json",
            "LeanRustCore.Examples.nat_pred_or_zero_u32",
            BTreeSet::from(["general-pattern-match", "primitive"]),
        ),
        (
            "corpus/positive/pattern_nat_two_step.expected.json",
            "LeanRustCore.Examples.nat_two_step_or_zero_u32",
            BTreeSet::from(["general-pattern-match", "primitive"]),
        ),
        (
            "corpus/positive/pattern_tree_sum.expected.json",
            "LeanRustCore.Examples.tree_sum_u32",
            BTreeSet::from([
                "general-pattern-match",
                "recursive-direct-scc",
                "recursive-owned-box-data",
            ]),
        ),
    ] {
        let fixture = serde_json::from_str::<serde_json::Value>(
            &fs::read_to_string(repo_root().join(path)).expect("fixture"),
        )
        .unwrap();
        assert_eq!(fixture["kind"].as_str(), Some("positive"));
        assert_eq!(fixture["source"].as_str(), Some(source));
        assert_eq!(fixture["expected_status"].as_str(), Some("supported"));
        assert_eq!(
            fixture["required_features"]
                .as_array()
                .unwrap()
                .iter()
                .filter_map(|item| item.as_str())
                .collect::<BTreeSet<_>>(),
            features
        );
        assert!(fixture["documentation"]
            .as_array()
            .unwrap()
            .iter()
            .filter_map(|item| item.as_str())
            .any(|item| item == "docs/PATTERN_COMPILER.md"));
    }

    let pattern_doc =
        fs::read_to_string(repo_root().join("docs/PATTERN_COMPILER.md")).expect("pattern doc");
    for phrase in [
        "List.nil",
        "List.cons",
        "Nat.zero",
        "Nat.succ",
        "list_head_clone",
        "list_tail_clone",
        "as-pattern",
        "LRC006",
    ] {
        assert!(
            pattern_doc.contains(phrase),
            "docs/PATTERN_COMPILER.md missing {phrase}"
        );
    }
}
