#![cfg_attr(not(feature = "ffi"), forbid(unsafe_code))]
#![allow(
    clippy::needless_bool,
    non_snake_case,
    clippy::redundant_field_names,
    clippy::unused_unit
)]

pub mod abi;
pub use lean_rust_core_runtime as runtime;
pub use lean_rust_core_runtime as runtime_crate;

include!(concat!(env!("OUT_DIR"), "/generated.rs"));

#[cfg(feature = "ffi")]
pub use lean_rust_core_abi as abi_crate;
#[cfg(feature = "ffi")]
pub mod ffi_generated;
