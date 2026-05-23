const COMPATIBILITY_REPORT: &str = include_str!("../compatibility-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const ROOT_CARGO: &str = include_str!("../../Cargo.toml");
const GENERATED_CARGO: &str = include_str!("../Cargo.toml");

#[test]
fn diagnostics_and_docs_are_declared_for_unsupported_constructs() {
    for code in ["LRC001", "LRC002", "LRC003", "LRC004", "LRC005"] {
        assert!(
            PROOF_REPORT.contains(code),
            "proof report missing diagnostic code {code}"
        );
    }
    assert!(COMPATIBILITY_REPORT.contains("features"));
    assert!(COMPATIBILITY_REPORT.contains("next_feature"));
}

#[test]
fn rust_workspace_crate_split_is_visible_to_tests() {
    for member in [
        "rust",
        "crates/runtime",
        "crates/abi",
        "crates/validate",
        "crates/headers",
    ] {
        assert!(
            ROOT_CARGO.contains(member),
            "workspace missing member {member}"
        );
    }

    assert!(GENERATED_CARGO.contains("lean-rust-core-runtime"));
    assert!(GENERATED_CARGO.contains("lean-rust-core-abi"));
    assert!(GENERATED_CARGO.contains("ffi = [\"dep:lean-rust-core-abi\"]"));
}
