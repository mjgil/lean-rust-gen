#![forbid(unsafe_code)]
#![allow(
    clippy::needless_bool,
    clippy::redundant_field_names,
    clippy::unused_unit,
    non_snake_case
)]

pub mod abi;

include!(concat!(env!("OUT_DIR"), "/generated.rs"));
