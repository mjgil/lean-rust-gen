#[test]
fn validation_report_records_current_subset_gates() {
    let report = include_str!("../validation-report.json");

    assert!(report.contains("lean-rust-core.rust-validation.v1"));
    assert!(report.contains("direct-lean-emits-rust"));
    assert!(report.contains("lean-evaluator-differential-tests"));
    assert!(report.contains("safe-rust-subset-gate"));
    assert!(report.contains("payload-enum-match-lowering"));
    assert!(report.contains("first-order-call-lowering"));
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
        "pub enum Choice",
        "pub enum Step",
        "pub fn clamp_u32",
        "pub fn option_default_u64",
        "pub fn step_amount_or",
        "pub fn inc_twice_u32",
    ] {
        assert!(
            source.contains(required),
            "generated Rust did not contain required fragment: {required}"
        );
    }
}
