use lean_rust_core_generated::*;
use num_bigint::{BigInt, BigUint};

#[test]
fn clamp_handles_low_high_and_middle() {
    assert_eq!(clamp_u32(10, 20, 5), 10);
    assert_eq!(clamp_u32(10, 20, 25), 20);
    assert_eq!(clamp_u32(10, 20, 15), 15);
}

#[test]
fn max_and_nonzero_work() {
    assert_eq!(max_u32(3, 8), 8);
    assert_eq!(max_u32(8, 3), 8);
    assert!(!is_nonzero_u32(0));
    assert!(is_nonzero_u32(7));
}

#[test]
fn arithmetic_uses_wrapping_semantics() {
    assert_eq!(add_u32(u32::MAX, 1), 0);
    assert_eq!(add_u32(40, 2), 42);
    assert_eq!(mul_u32(u32::MAX, 2), u32::MAX.wrapping_mul(2));
    assert_eq!(add_u64(u64::MAX, 1), 0);
}

#[test]
fn let_lowering_keeps_local_value() {
    assert_eq!(bounded_bump_u32(0), 1);
    assert_eq!(bounded_bump_u32(9), 10);
    assert_eq!(bounded_bump_u32(10), 10);
    assert_eq!(bounded_bump_u32(u32::MAX), 0);
}

#[test]
fn expanded_scalar_types_round_trip() {
    assert_eq!(echo_u32(17), 17);
    assert_eq!(echo_u64(u64::MAX), u64::MAX);
    assert_eq!(echo_i32(-17), -17);
    assert_eq!(echo_i64(i64::MIN), i64::MIN);
    assert_eq!(echo_char('z'), 'z');
    assert_eq!(echo_string(String::from("hi")), String::from("hi"));
    unit_roundtrip(());
}

#[test]
fn standard_container_shapes_round_trip() {
    assert_eq!(echo_list_u32(vec![1, 2, 3]), vec![1, 2, 3]);
    assert_eq!(echo_array_u32(vec![4, 5]), vec![4, 5]);
    assert_eq!(list_map_inc_u32(vec![1, u32::MAX]), vec![2, 0]);
    assert_eq!(list_fold_sum_u32(vec![1, 2, u32::MAX]), 2);
    assert_eq!(list_append_u32(vec![1, 2], vec![3]), vec![1, 2, 3]);
    assert_eq!(list_find_nonzero_u32(vec![0, 0, 7]), Some(7));
    assert_eq!(list_find_nonzero_u32(vec![0, 0, 0]), None);
    assert_eq!(array_push_u32(vec![1, 2], 3), vec![1, 2, 3]);
    assert_eq!(echo_prod_u32((1, 2)), (1, 2));
    assert_eq!(echo_sum_u32(Ok(3)), Ok(3));
    assert_eq!(echo_sum_u32(Err(4)), Err(4));
}

#[test]
fn captured_lambda_list_map_lowers_to_loop_body() {
    assert_eq!(list_map_add_capture_u32(5, vec![1, u32::MAX]), vec![6, 4]);
}

#[test]
fn exact_nat_and_int_modes_use_bigints() {
    assert_eq!(
        exact_nat_add(BigUint::from(u64::MAX), BigUint::from(1u32)),
        BigUint::from(u64::MAX) + BigUint::from(1u32)
    );
    assert_eq!(
        exact_nat_mul(BigUint::from(7u32), BigUint::from(6u32)),
        BigUint::from(42u32)
    );
    assert_eq!(
        exact_int_add(BigInt::from(-7i32), BigInt::from(5i32)),
        BigInt::from(-2i32)
    );
    assert_eq!(
        exact_int_mul(BigInt::from(-7i32), BigInt::from(6i32)),
        BigInt::from(-42i32)
    );
}

#[test]
fn typeclass_and_closure_specializations_lower() {
    assert!(decidable_eq_u32(7, 7));
    assert!(!decidable_eq_u32(7, 8));
    assert_eq!(inhabited_default_u32(()), 0);
    assert_eq!(to_string_u32(42), String::from("42"));
    assert_eq!(repr_u32(42), String::from("42"));
    assert_eq!(ord_compare_u32(1, 2), Ordering::Lt);
    assert_eq!(ord_compare_u32(2, 2), Ordering::Eq);
    assert_eq!(ord_compare_u32(3, 2), Ordering::Gt);
    assert_eq!(option_do_inc_u32(Some(41)), Some(42));
    assert_eq!(option_do_inc_u32(None), None);
    assert_eq!(option_getd_u32(None, 9), 9);
    assert_eq!(option_getd_u32(Some(4), 9), 4);
    assert_eq!(result_map_err_inc_u32(Ok(5)), Ok(5));
    assert_eq!(result_map_err_inc_u32(Err(41)), Err(42));
    assert_eq!(except_do_inc_u32(Ok(41)), Ok(42));
    assert_eq!(except_do_inc_u32(Err(7)), Err(7));
    assert_eq!(reader_add_env_u32(5, 37), 42);
    assert_eq!(state_tick_u32(41), (41, 42));
    assert_eq!(closure_apply_capture_u32(5, 37), 42);
    assert_eq!(closure_env_apply_add_delta_u32(5, 37), 42);
    assert_eq!(closure_env_apply_add_delta_u32(1, u32::MAX), 0);
    assert_eq!(
        closure_env_map_add_delta_u32(5, vec![1, u32::MAX]),
        vec![6, 4]
    );
    assert_eq!(defun_apply_u32(U32FnCase::Inc, 41), 42);
    assert_eq!(defun_apply_u32(U32FnCase::Double, 21), 42);
    assert_eq!(defun_apply_u32(U32FnCase::Add(5), 37), 42);
    assert_eq!(defun_compose_inc_double_u32(20), 42);
    assert_eq!(defun_apply_add5_u32(37), 42);
    assert_eq!(defun_map_selected_u32(false, vec![1, u32::MAX]), vec![2, 0]);
    assert_eq!(
        defun_map_selected_u32(true, vec![1, u32::MAX]),
        vec![2, u32::MAX.wrapping_add(u32::MAX)]
    );
}

#[test]
fn recursive_user_data_uses_owned_box_layout() {
    let leaf = tree_leaf_u32(());
    assert_eq!(tree_size_u32(leaf.clone()), 0);
    assert_eq!(tree_sum_u32(leaf), 0);

    let tree = tree_node_u32(
        tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
        40,
        tree_node_u32(tree_leaf_u32(()), 1, tree_leaf_u32(())),
    );
    assert_eq!(tree_size_u32(tree.clone()), 3);
    assert_eq!(tree_sum_u32(tree), 42);

    let expr = expr_add_u32(
        expr_lit_u32(40),
        expr_add_u32(expr_lit_u32(1), expr_lit_u32(1)),
    );
    assert_eq!(expr_eval_u32(expr), 42);
}

#[test]
fn bool_and_option_matches_lower() {
    assert_eq!(bool_match_u32(true, 1, 2), 1);
    assert_eq!(bool_match_u32(false, 1, 2), 2);
    assert_eq!(option_identity_u32(Some(9)), Some(9));
    assert_eq!(none_u32(()), None);
    assert_eq!(some_u32(4), Some(4));
    assert_eq!(option_default_u32(None, 8), 8);
    assert_eq!(option_default_u32(Some(3), 8), 3);
    assert_eq!(general_bool_match_u32(true, 9, 20), 10);
    assert_eq!(general_bool_match_u32(false, 9, 20), 21);
    assert_eq!(general_option_match_u32(None, 8), 8);
    assert_eq!(general_option_match_u32(Some(41), 8), 42);
}

#[test]
fn except_lowers_to_rust_result() {
    assert_eq!(result_ok_u32(5), Ok(5));
    assert_eq!(result_err_u32(7), Err(7));
}

#[test]
fn simple_enum_match_lowers() {
    assert_eq!(choose_by_enum(Choice::First, 10, 20), 10);
    assert_eq!(choose_by_enum(Choice::Second, 10, 20), 20);
}

#[test]
fn struct_literals_and_field_projection_lower() {
    let p = make_point(3, 4);
    assert_eq!(p, Point { x: 3, y: 4 });
    assert_eq!(point_x(Point { x: 8, y: 9 }), 8);
    assert_eq!(point_y(Point { x: 8, y: 9 }), 9);
    assert_eq!(
        shift_point_x(Point { x: u32::MAX, y: 7 }, 1),
        Point { x: 0, y: 7 }
    );
}

#[test]
fn dependent_shape_and_proof_field_erasure_lower() {
    assert_eq!(subtype_val_u32(42), 42);
    assert_eq!(subtype_inc_u32(41), 42);
    assert_eq!(subtype_roundtrip_u32(77), 77);
    assert_eq!(fin_val10_u32(7), 7);
    assert_eq!(vector_echo3_u32(vec![1, 2, 3]), vec![1, 2, 3]);

    let bounded = bounded_proof_make_u32(9);
    assert_eq!(bounded, BoundedProof { value: 9 });
    assert_eq!(bounded_proof_value_u32(BoundedProof { value: 11 }), 11);
}

#[test]
fn parameterized_structs_and_enums_are_monomorphized() {
    assert_eq!(boxed_u32(9), BoxedU32 { value: 9 });
    assert_eq!(boxed_value_u32(BoxedU32 { value: 11 }), 11);
    assert_eq!(tagged_missing_u32(()), TaggedU32::Missing);
    assert_eq!(tagged_present_u32(6), TaggedU32::Present(6));
    assert_eq!(tagged_default_u32(TaggedU32::Missing, 7), 7);
    assert_eq!(tagged_default_u32(TaggedU32::Present(6), 7), 6);
}

#[test]
fn enum_declarations_and_payload_constructors_lower() {
    assert_eq!(step_stay(()), Step::Stay);
    assert_eq!(step_jump(12), Step::Jump(12));
}

#[test]
fn payload_enum_matches_bind_variant_fields() {
    assert_eq!(step_amount_or(Step::Stay, 99), 99);
    assert_eq!(step_amount_or(Step::Jump(12), 99), 12);
    assert_eq!(step_amount_plus_one_or(Step::Stay, 7), 7);
    assert_eq!(step_amount_plus_one_or(Step::Jump(u32::MAX), 7), 0);
    assert_eq!(general_step_match_u32(Step::Stay, 7), 7);
    assert_eq!(general_step_match_u32(Step::Jump(u32::MAX), 7), 0);
}

#[test]
fn general_pattern_and_recursion_lowering_work() {
    assert_eq!(pair_sum_match_u32(40, 2), 42);
    assert_eq!(list_length_u32(vec![]), 0);
    assert_eq!(list_length_u32(vec![1, 2, 3]), 3);
    assert_eq!(tail_sum_down_u32(0), 0);
    assert_eq!(tail_sum_down_u32(5), 15);
}

#[test]
fn first_order_function_calls_lower_to_rust_calls() {
    assert_eq!(inc_u32(41), 42);
    assert_eq!(inc_u32(u32::MAX), 0);
    assert_eq!(inc_twice_u32(40), 42);
    assert_eq!(inc_twice_u32(u32::MAX), 1);
    assert_eq!(helper_inc_fixed(41), 42);
    assert_eq!(helper_chain_u32(40), 42);
}

#[test]
fn dependent_shape_erasure_sprint_10_12() {
    assert_eq!(subtype_val_u32(42), 42);
    assert_eq!(subtype_inc_u32(u32::MAX), 0);
    assert_eq!(subtype_roundtrip_u32(7), 7);
    assert_eq!(fin_val10_u32(9), 9);
    assert_eq!(fin_checked10_u32(9), Some(9));
    assert_eq!(fin_checked10_u32(10), None);
    assert_eq!(fin_succ_checked10_u32(8), Some(9));
    assert_eq!(fin_succ_checked10_u32(9), None);
    assert_eq!(vector_echo3_u32(vec![1, 2, 3]), vec![1, 2, 3]);
    assert_eq!(vector_map_inc3_u32(vec![1, 2, u32::MAX]), vec![2, 3, 0]);
    assert_eq!(bounded_proof_make_u32(42), BoundedProof { value: 42 });
    assert_eq!(bounded_proof_value_u32(BoundedProof { value: 42 }), 42);
}

#[test]
fn proof_binders_are_erased_from_rust_signature() {
    assert_eq!(proof_erased_u32(9), 9);
}

fn plus_one_for_higher_order(x: u32) -> u32 {
    x.wrapping_add(1)
}

#[test]
fn limited_higher_order_fn_pointer_lowers() {
    assert_eq!(
        unsupported_higher_order_u32(plus_one_for_higher_order, 41),
        42
    );
    assert_eq!(
        unsupported_higher_order_u32(plus_one_for_higher_order, u32::MAX),
        0
    );
}

#[test]
fn expected_type_propagates_through_nested_constructors() {
    assert_eq!(nested_none_u32(()), Some(None));
    assert_eq!(result_ok_none_u32(()), Ok(None));
    assert_eq!(result_err_some_u32(44), Err(Some(44)));
}

#[test]
fn concrete_generic_instantiations_are_emitted() {
    assert_eq!(identity_u64(99), 99);
    assert_eq!(choose_generic_u32(true, 10, 20), 10);
    assert_eq!(choose_generic_u32(false, 10, 20), 20);
    assert_eq!(option_default_u64(None, 77), 77);
    assert_eq!(option_default_u64(Some(55), 77), 55);
    assert!(generic_beq_u32(7, 7));
    assert!(!generic_beq_u32(7, 8));
}

#[test]
fn automatic_monomorphization_emits_discovered_instances() {
    assert_eq!(generic_identity__u32(11), 11);
    assert_eq!(auto_identity_u32(12), 12);

    let left = Point { x: 1, y: 2 };
    let right = Point { x: 3, y: 4 };
    assert_eq!(
        generic_choose__point(true, left.clone(), right.clone()),
        left
    );
    assert_eq!(
        generic_choose__point(false, left.clone(), right.clone()),
        right
    );
    assert_eq!(auto_choose_point(true, left.clone(), right.clone()), left);
    assert_eq!(auto_choose_point(false, left.clone(), right.clone()), right);

    assert_eq!(generic_option_default__step(None, Step::Stay), Step::Stay);
    assert_eq!(
        generic_option_default__step(Some(Step::Jump(7)), Step::Stay),
        Step::Jump(7)
    );
    assert_eq!(auto_option_default_step(None, Step::Jump(5)), Step::Jump(5));
    assert_eq!(
        auto_option_default_step(Some(Step::Stay), Step::Jump(5)),
        Step::Stay
    );
}
