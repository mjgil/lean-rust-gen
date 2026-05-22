use lean_rust_core_generated::*;

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
