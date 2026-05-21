#[test]
fn validation_report_records_current_subset_gates() {
    let report = include_str!("../validation-report.json");

    assert!(report.contains("lean-rust-core.rust-validation.v1"));
    assert!(report.contains("direct-lean-emits-rust"));
    assert!(report.contains("lean-evaluator-differential-tests"));
    assert!(report.contains("safe-rust-subset-gate"));
    assert!(report.contains("payload-enum-match-lowering"));
    assert!(report.contains("first-order-call-lowering"));
    assert!(report.contains("surface-evaluator-extracted-subset-tests"));
    assert!(report.contains("extractor-owned-surface-artifact"));
    assert!(report.contains("rust-identifier-hygiene"));
    assert!(report.contains("syn-parser-backed-validation"));
    assert!(report.contains("exact-toolchain-pins"));
    assert!(report.contains("release-fallback-ban"));
    assert!(report.contains("automatic-monomorphization"));
    assert!(report.contains("phase-1-recursion-policy"));
    assert!(report.contains("parameterized-data-lowering"));
    assert!(report.contains("standard-container-shapes"));
    assert!(report.contains("transitive-helper-extraction"));
    assert!(report.contains("proof-erased-binders"));
    assert!(report.contains("limited-higher-order-function-pointer"));
    assert!(report.contains("leanprover/lean4:v4.22.0"));
    assert!(report.contains("1.85.0"));
    assert!(!report.contains("\"status\": \"failed\""));
}

#[test]
fn generated_source_stays_inside_safe_subset_textually() {
    let source = include_str!("../src/generated.rs");

    for banned in [
        "unsafe",
        "extern \"C\"",
        "panic!",
        "todo!",
        "unimplemented!",
        "/* malformed",
        "unsupported wrapping op",
    ] {
        assert!(
            !source.contains(banned),
            "generated Rust contained banned fragment: {banned}"
        );
    }

    for required in [
        "pub struct Point",
        "pub struct BoxedU32",
        "pub enum Choice",
        "pub enum TaggedU32",
        "pub enum Step",
        "pub fn clamp_u32",
        "pub fn echo_string",
        "pub fn echo_list_u32",
        "pub fn echo_array_u32",
        "pub fn echo_prod_u32",
        "pub fn echo_sum_u32",
        "pub fn helper_chain_u32",
        "pub fn proof_erased_u32",
        "pub fn boxed_u32",
        "pub fn tagged_default_u32",
        "pub fn unsupported_higher_order_u32",
        "pub fn option_default_u64",
        "pub fn step_amount_or",
        "pub fn inc_twice_u32",
        "pub fn step_amount_plus_one_or",
        "pub fn generic_identity__u32",
        "pub fn generic_choose__point",
        "pub fn generic_option_default__step",
        "pub fn helper_inc_fixed",
        "pub fn auto_identity_u32",
        "pub fn auto_choose_point",
        "pub fn auto_option_default_step",
    ] {
        assert!(
            source.contains(required),
            "generated Rust did not contain required fragment: {required}"
        );
    }
}

#[test]
fn build_metadata_records_pins_and_fallback_policy() {
    let metadata = include_str!("../build-metadata.json");

    assert!(metadata.contains("lean-rust-core.build-metadata.v1"));
    assert!(metadata.contains("leanprover/lean4:v4.22.0"));
    assert!(metadata.contains("1.85.0"));
    assert!(metadata.contains("LEAN_RUST_CORE_ALLOW_FALLBACK"));
}
