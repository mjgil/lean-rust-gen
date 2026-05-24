const COMPATIBILITY_REPORT: &str = include_str!("../compatibility-report.json");
const PROOF_REPORT: &str = include_str!("../proof-report.json");
const ROOT_CARGO: &str = include_str!("../../Cargo.toml");
const GENERATED_CARGO: &str = include_str!("../Cargo.toml");
const BUILD_RS: &str = include_str!("../build.rs");
const RUNTIME_CARGO: &str = include_str!("../../crates/runtime/Cargo.toml");
const ABI_CARGO: &str = include_str!("../../crates/abi/Cargo.toml");
const VALIDATE_CARGO: &str = include_str!("../../crates/validate/Cargo.toml");
const HEADERS_CARGO: &str = include_str!("../../crates/headers/Cargo.toml");
const GENERATED_README: &str = include_str!("../README.md");
const RUNTIME_README: &str = include_str!("../../crates/runtime/README.md");
const ABI_README: &str = include_str!("../../crates/abi/README.md");
const VALIDATE_README: &str = include_str!("../../crates/validate/README.md");
const HEADERS_README: &str = include_str!("../../crates/headers/README.md");
const PUBLISHING_DOC: &str = include_str!("../../docs/PUBLISHING.md");
const CHANGELOG: &str = include_str!("../../CHANGELOG.md");

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

#[test]
fn publishing_metadata_and_semver_policy_are_visible_to_tests() {
    for manifest in [
        GENERATED_CARGO,
        RUNTIME_CARGO,
        ABI_CARGO,
        VALIDATE_CARGO,
        HEADERS_CARGO,
    ] {
        for needle in [
            "version = \"0.2.0\"",
            "rust-version = \"1.85\"",
            "license = \"MIT OR Apache-2.0\"",
            "repository = \"https://github.com/mjgil/lean-rust-gen\"",
            "homepage = \"https://github.com/mjgil/lean-rust-gen\"",
            "documentation = \"https://docs.rs/",
            "keywords = [",
            "categories = [",
            "[package.metadata.docs.rs]",
        ] {
            assert!(
                manifest.contains(needle),
                "manifest metadata missing {needle}"
            );
        }
    }

    for needle in [
        "lean-rust-core-runtime = { path = \"../crates/runtime\", version = \"0.2.0\" }",
        "lean-rust-core-abi = { path = \"../crates/abi\", version = \"0.2.0\", optional = true }",
        "lean-rust-core-validate = { path = \"../crates/validate\", version = \"0.2.0\" }",
    ] {
        assert!(
            GENERATED_CARGO.contains(needle),
            "generated manifest missing publishable workspace dependency {needle}"
        );
    }

    for text in [
        GENERATED_README,
        RUNTIME_README,
        ABI_README,
        VALIDATE_README,
        HEADERS_README,
    ] {
        assert!(text.contains("semver"));
        assert!(text.contains("scripts/check-publishing.sh"));
        assert!(text.contains("docs.rs"));
    }

    for needle in [
        "python3 scripts/check-publishing.py",
        "./scripts/check-publishing.sh",
        "cargo doc --workspace --no-deps",
        "cargo tree --workspace",
        "cargo publish --dry-run -p lean-rust-core-generated",
        "repository",
        "homepage",
        "keywords",
        "categories",
        "Unreleased",
    ] {
        assert!(
            PUBLISHING_DOC.contains(needle) || CHANGELOG.contains(needle),
            "publishing policy evidence missing {needle}"
        );
    }

    assert!(BUILD_RS.contains("Lean workspace not packaged with crate"));
    assert!(BUILD_RS.contains("using checked-in src/generated.rs"));
}
