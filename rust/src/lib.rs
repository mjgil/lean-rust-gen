#![forbid(unsafe_code)]

pub mod abi;

include!(concat!(env!("OUT_DIR"), "/generated.rs"));
