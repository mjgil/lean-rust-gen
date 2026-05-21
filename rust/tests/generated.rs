use lean_rust_core_generated::*;

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
    assert_eq!(echo_prod_u32((1, 2)), (1, 2));
    assert_eq!(echo_sum_u32(Ok(3)), Ok(3));
    assert_eq!(echo_sum_u32(Err(4)), Err(4));
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
