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
    unit_roundtrip(());
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
fn enum_declarations_and_payload_constructors_lower() {
    assert_eq!(step_stay(()), Step::Stay);
    assert_eq!(step_jump(12), Step::Jump(12));
}

#[test]
fn expected_type_propagates_through_nested_constructors() {
    assert_eq!(nested_none_u32(()), Some(None));
    assert_eq!(result_ok_none_u32(()), Ok(None));
    assert_eq!(result_err_some_u32(44), Err(Some(44)));
}
