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
