use lean_rust_core_generated::runtime::{
    generate_runtime_value_cases, minimize_runtime_value_case,
    runtime_case_exercises_first_order_helpers, RuntimeValueCase, ADD_U32,
};
use lean_rust_core_generated::*;
use lean_rust_core_validate::{
    eval_target_term, generate_target_term_cases, generated_terms_are_well_typed,
    minimize_target_term, target_term_head, TargetTerm, TargetValue,
};

#[test]
fn deterministic_recursive_tree_property_seeds() {
    for value in [0u32, 1, 7, 41, u32::MAX] {
        let singleton = tree_node_u32(tree_leaf_u32(()), value, tree_leaf_u32(()));
        assert_eq!(tree_size_u32(singleton.clone()), 1);
        assert_eq!(tree_sum_u32(singleton), value);
    }

    let left = tree_node_u32(tree_leaf_u32(()), 10, tree_leaf_u32(()));
    let right = tree_node_u32(tree_leaf_u32(()), 32, tree_leaf_u32(()));
    let root = tree_node_u32(left, 0, right);
    assert_eq!(tree_size_u32(root.clone()), 3);
    assert_eq!(tree_sum_u32(root), 42);
}

#[test]
fn deterministic_expr_property_seeds() {
    for value in [0u32, 1, 41, u32::MAX] {
        assert_eq!(expr_eval_u32(expr_lit_u32(value)), value);
    }

    let expr = expr_add_u32(expr_lit_u32(u32::MAX), expr_lit_u32(1));
    assert_eq!(expr_eval_u32(expr), 0);

    let nested = expr_add_u32(
        expr_lit_u32(20),
        expr_add_u32(expr_lit_u32(21), expr_lit_u32(1)),
    );
    assert_eq!(expr_eval_u32(nested), 42);
}

#[test]
fn closure_and_defun_regression_seeds_remain_first_order() {
    assert_eq!(closure_env_apply_add_delta_u32(5, 37), 42);
    assert_eq!(defun_apply_u32(U32FnCase::Inc, 41), 42);
    assert_eq!(defun_apply_u32(U32FnCase::Double, 21), 42);
    assert_eq!(
        defun_map_selected_u32(false, vec![0, 37, u32::MAX]),
        vec![1, 38, 0]
    );
}

#[test]
fn randomized_runtime_and_target_generators_stay_semantic() {
    let runtime_cases = generate_runtime_value_cases(0xA11CE, 12);
    assert!(runtime_cases
        .iter()
        .all(|case| runtime_case_exercises_first_order_helpers(case, ADD_U32)));
    assert!(runtime_cases
        .iter()
        .any(|case| matches!(case, RuntimeValueCase::RecursiveTree(_))));

    let terms = generate_target_term_cases(0xA11CE, 28, 3);
    assert!(generated_terms_are_well_typed(0xA11CE, 28, 3));
    assert!(terms
        .iter()
        .any(|term| target_term_head(term) == "dictionary"));
    assert!(terms.iter().all(|term| eval_target_term(term).is_some()));
}

#[test]
fn generator_minimizers_record_small_counterexamples() {
    let runtime_min = minimize_runtime_value_case(
        RuntimeValueCase::BaseScalar(17),
        |case| matches!(case, RuntimeValueCase::BaseScalar(value) if *value >= 2),
    );
    assert_eq!(runtime_min, RuntimeValueCase::BaseScalar(2));

    let target_min = minimize_target_term(
        TargetTerm::Add(Box::new(TargetTerm::U32(9)), Box::new(TargetTerm::U32(9))),
        |term| matches!(eval_target_term(term), Some(TargetValue::U32(value)) if value >= 2),
    );
    assert_eq!(target_min, TargetTerm::U32(2));
}
