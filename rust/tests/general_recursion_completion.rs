use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;

use lean_rust_core_generated::{
    gcd_u32, mutual_even_u32, mutual_odd_u32, reverse_accum_u32, tree_leaf_u32, tree_node_u32,
    tree_sum_worklist_u32,
};

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf()
}

#[test]
fn task40_general_recursion_examples_and_docs_are_complete() {
    let generated =
        fs::read_to_string(repo_root().join("rust/src/generated.rs")).expect("generated Rust");
    for needle in [
        "pub fn gcd_u32",
        "pub fn reverse_accum_u32",
        "pub fn mutual_even_u32",
        "pub fn mutual_odd_u32",
        "pub fn tree_sum_worklist_u32",
    ] {
        assert!(
            generated.contains(needle),
            "missing generated item {needle}"
        );
    }

    let target_validation = fs::read_to_string(repo_root().join("rust/target-validation.txt"))
        .expect("target validation");
    for needle in [
        "FN\tgcd_u32",
        "FN\treverse_accum_u32",
        "FN\tmutual_even_u32",
        "FN\tmutual_odd_u32",
        "FN\ttree_sum_worklist_u32",
        "call(gcd_u32",
        "call(mutual_odd_u32",
        "call(__runtime_list_prepend_u32",
        "call(__runtime_tree_sum_worklist_u32",
    ] {
        assert!(
            target_validation.contains(needle),
            "missing target-validation item {needle}"
        );
    }

    assert_eq!(gcd_u32(42, 30), 6);
    assert_eq!(reverse_accum_u32(vec![1, 2, 3], vec![9]), vec![3, 2, 1, 9]);
    assert!(mutual_even_u32(8));
    assert!(mutual_odd_u32(7));
    let tree = tree_node_u32(
        tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
        40,
        tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
    );
    assert_eq!(tree_sum_worklist_u32(tree), 42);

    for (path, source, features) in [
        (
            "corpus/positive/recursion_gcd.expected.json",
            "LeanRustCore.Examples.gcd_u32",
            BTreeSet::from(["general-recursion", "tail-recursion"]),
        ),
        (
            "corpus/positive/recursion_reverse_accum.expected.json",
            "LeanRustCore.Examples.reverse_accum_u32",
            BTreeSet::from(["general-recursion", "structural-list-recursion"]),
        ),
        (
            "corpus/positive/recursion_mutual_parity.expected.json",
            "LeanRustCore.Examples.mutual_even_u32",
            BTreeSet::from(["general-recursion", "mutual-recursion"]),
        ),
        (
            "corpus/positive/recursion_tree_worklist.expected.json",
            "LeanRustCore.Examples.tree_sum_worklist_u32",
            BTreeSet::from(["explicit-stack-recursion", "recursive-direct-scc"]),
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
            .any(|item| item == "docs/RECURSION_LOWERING.md"));
    }

    let unsupported = serde_json::from_str::<serde_json::Value>(include_str!(
        "../../corpus/unsupported/recursor_shape.expected.json"
    ))
    .unwrap();
    assert_eq!(unsupported["diagnostic_code"].as_str(), Some("LRC006"));
    assert_eq!(
        unsupported["next_feature"].as_str(),
        Some("general recursion lowering")
    );

    let docs =
        fs::read_to_string(repo_root().join("docs/RECURSION_LOWERING.md")).expect("recursion doc");
    for phrase in [
        "gcd_u32",
        "reverse_accum_u32",
        "mutual_even_u32",
        "tree_sum_worklist_u32",
        "explicit heap stack",
        "LRC006",
    ] {
        assert!(
            docs.contains(phrase),
            "docs/RECURSION_LOWERING.md missing phrase {phrase}"
        );
    }
}
