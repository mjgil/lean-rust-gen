#![cfg(feature = "ffi")]

use lean_rust_core_generated::abi::ChStatus;
use lean_rust_core_generated::ffi_generated::*;

#[test]
fn primitive_ffi_wrappers_call_generated_functions() {
    assert_eq!(lrc_add_u32(u32::MAX, 1), 0);
    assert_eq!(lrc_clamp_u32(10, 20, 25), 20);
    assert_eq!(lrc_bool_match_u32(1, 7, 9), 7);
    assert_eq!(lrc_bool_match_u32(0, 7, 9), 9);
    assert_eq!(lrc_helper_chain_u32(40), 42);
    assert_eq!(lrc_decidable_eq_u32(7, 7), 1);
    assert_eq!(lrc_decidable_eq_u32(7, 8), 0);
    assert_eq!(lrc_closure_apply_capture_u32(5, 37), 42);
    assert_eq!(lrc_closure_env_apply_add_delta_u32(5, 37), 42);
    assert_eq!(lrc_defun_compose_inc_double_u32(20), 42);
    assert_eq!(lrc_defun_apply_add5_u32(37), 42);
    assert_eq!(lrc_nat_sum_to_u32(5), 10);
    assert_eq!(lrc_subtype_val_u32(42), 42);
    assert_eq!(lrc_subtype_inc_u32(u32::MAX), 0);
    assert_eq!(lrc_fin_val10_u32(7), 7);
    assert_eq!(lrc_subtype_roundtrip_u32(13), 13);
    assert_eq!(lrc_general_bool_match_u32(1, 9, 20), 10);
    assert_eq!(lrc_general_bool_match_u32(0, 9, 20), 21);
    assert_eq!(lrc_pair_sum_match_u32(40, 2), 42);
    assert_eq!(lrc_tail_sum_down_u32(5), 15);
}

#[test]
fn result_ffi_wrappers_lower_to_status_and_out_params() {
    let mut ok = 0;
    let mut err = 0;

    let status = unsafe { lrc_result_ok_u32(12, &mut ok, &mut err) };
    assert_eq!(status, ChStatus::OK);
    assert_eq!(ok, 12);
    assert_eq!(err, 0);

    let status = unsafe { lrc_result_err_u32(34, &mut ok, &mut err) };
    assert_eq!(status, ChStatus::ERR);
    assert_eq!(ok, 12);
    assert_eq!(err, 34);
}
