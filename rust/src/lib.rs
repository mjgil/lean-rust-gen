#![cfg_attr(not(feature = "ffi"), forbid(unsafe_code))]

pub mod abi;
pub use lean_rust_core_runtime as runtime;
pub use lean_rust_core_runtime as runtime_crate;
pub mod recursion_helpers;

mod generated {
    #![allow(
        clippy::collapsible_else_if,
        clippy::comparison_chain,
        clippy::manual_map,
        clippy::match_single_binding,
        clippy::needless_bool,
        clippy::nonminimal_bool,
        clippy::redundant_field_names,
        clippy::unused_unit,
        non_snake_case,
        unused_variables
    )]

    include!(concat!(env!("OUT_DIR"), "/generated.rs"));
}

pub use generated::*;

#[cfg(feature = "ffi")]
pub use lean_rust_core_abi as abi_crate;
#[cfg(feature = "ffi")]
pub mod ffi_generated;
