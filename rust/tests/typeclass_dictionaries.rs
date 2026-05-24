use std::fs;
use std::path::PathBuf;

use lean_rust_core_generated::{
    generated_dict_add_u32, generated_dict_beq_u32, generated_dict_compare_u32,
    generated_dict_default_u32, generated_dict_to_string_u32, Ordering,
};

fn repo_root() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("workspace root")
        .to_path_buf()
}

#[test]
fn generated_dictionary_exports_use_runtime_dictionary_values() {
    assert!(generated_dict_beq_u32(7, 7));
    assert!(!generated_dict_beq_u32(7, 8));
    assert_eq!(generated_dict_compare_u32(1, 2), Ordering::Lt);
    assert_eq!(generated_dict_compare_u32(2, 2), Ordering::Eq);
    assert_eq!(generated_dict_compare_u32(3, 2), Ordering::Gt);
    assert_eq!(generated_dict_add_u32(u32::MAX, 1), 0);
    assert_eq!(generated_dict_default_u32(()), 0);
    assert_eq!(generated_dict_to_string_u32(42), String::from("42"));
}

#[test]
fn generated_rust_snapshot_mentions_dictionary_constants_and_helpers() {
    let generated =
        fs::read_to_string(repo_root().join("rust/src/generated.rs")).expect("generated Rust");
    for needle in [
        "pub fn generated_dict_beq_u32",
        "pub fn generated_dict_compare_u32",
        "pub fn generated_dict_add_u32",
        "pub fn generated_dict_default_u32",
        "pub fn generated_dict_to_string_u32",
        "crate::runtime::dictionary_beq_u32(crate::runtime::BEQ_U32",
        "crate::runtime::dictionary_compare_u32(crate::runtime::ORD_U32",
        "crate::runtime::dictionary_add_u32(crate::runtime::ADD_U32",
        "crate::runtime::dictionary_default_u32(crate::runtime::DEFAULT_U32)",
        "crate::runtime::dictionary_to_string_u32(crate::runtime::TO_STRING_U32",
    ] {
        assert!(
            generated.contains(needle),
            "missing generated dictionary item {needle}"
        );
    }
}
