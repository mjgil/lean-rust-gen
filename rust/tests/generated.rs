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
fn arithmetic_uses_wrapping_u32_semantics() {
    assert_eq!(add_u32(u32::MAX, 1), 0);
    assert_eq!(add_u32(40, 2), 42);
    assert_eq!(mul_u32(u32::MAX, 2), u32::MAX.wrapping_mul(2));
}

#[test]
fn let_lowering_keeps_local_value() {
    assert_eq!(bounded_bump_u32(0), 1);
    assert_eq!(bounded_bump_u32(9), 10);
    assert_eq!(bounded_bump_u32(10), 10);
    assert_eq!(bounded_bump_u32(u32::MAX), 0);
}
