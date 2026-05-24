use lean_rust_core_generated::*;

#[test]
fn source_level_closure_lowerings_cover_stored_returned_passed_and_multiarg_cases() {
    assert_eq!(closure_apply_capture_u32(5, 37), 42);
    assert_eq!(stored_closure_apply_u32(5, 37), 42);
    assert_eq!(returned_closure_apply_u32(5, 37), 42);
    assert_eq!(passed_closure_apply_u32(5, 37), 42);
    assert_eq!(stored_multi_closure_apply_u32(1, 4, 30, 7), 42);
    assert_eq!(returned_multi_closure_apply_u32(1, 4, 30, 7), 42);
    assert_eq!(passed_multi_closure_apply_u32(1, 4, 30, 7), 42);
    assert_eq!(closure_env_apply_add_delta_u32(5, 37), 42);
    assert_eq!(
        closure_env_map_add_delta_u32(5, vec![1, u32::MAX]),
        vec![6, 4]
    );
}
