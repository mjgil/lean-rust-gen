use std::collections::BTreeSet;

const PROOF_REPORT: &str = include_str!("../proof-report.json");
const VALIDATION_REPORT: &str = include_str!("../validation-report.json");
const COVERAGE_DASHBOARD: &str = include_str!("../coverage-dashboard.json");
const EXTRACT_IR: &str = include_str!("../../LeanRustCore/ExtractIR.lean");
const IR: &str = include_str!("../../LeanRustCore/IR.lean");
const DIAGNOSTICS: &str = include_str!("../../LeanRustCore/Diagnostics.lean");
const DIAGNOSTICS_DOC: &str = include_str!("../../docs/DIAGNOSTICS.md");
const EXTRACT_IR_DOC: &str = include_str!("../../docs/EXTRACT_IR.md");
const RUNTIME_DOC: &str = include_str!("../../docs/RUNTIME_SEMANTICS.md");
const POSITIVE_FIXTURE: &str = include_str!("../../corpus/positive/simple_u32.expected.json");
const NEGATIVE_FIXTURE: &str =
    include_str!("../../corpus/negative/unresolved_typeclass.expected.json");
const UNSUPPORTED_FIXTURE: &str = include_str!("../../corpus/unsupported/io_effect.expected.json");

#[test]
fn first20_reports_record_required_completion_metadata() {
    let proof: serde_json::Value = serde_json::from_str(PROOF_REPORT).unwrap();
    let validation: serde_json::Value = serde_json::from_str(VALIDATION_REPORT).unwrap();
    let coverage: serde_json::Value = serde_json::from_str(COVERAGE_DASHBOARD).unwrap();

    let trusted = proof["trusted_core"].as_array().unwrap();
    for required in [
        "LeanRustCore.ExtractIR.functionFeatures",
        "LeanRustCore.ExtractIR.lowerExpr?",
        "LeanRustCore.IR.runtimeValueHasType",
        "LeanRustCore.Diagnostics.SourceSpan",
    ] {
        assert!(
            trusted.iter().any(|item| item.as_str() == Some(required)),
            "proof report missing {required}"
        );
    }

    let policy = proof["policy"].as_object().unwrap();
    assert_eq!(policy["extract_ir_pipeline"], true);
    assert_eq!(policy["runtime_value_denotation"], true);
    assert_eq!(policy["expanded_diagnostic_codes"], "LRC001-LRC014");
    assert_eq!(policy["source_span_diagnostics"], true);

    let checks = validation["checks"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|check| check["name"].as_str())
        .collect::<BTreeSet<_>>();
    for required in [
        "extract-ir-pipeline",
        "runtime-value-denotation",
        "expanded-diagnostic-codes",
        "source-span-diagnostics",
        "first20-completion-gate",
    ] {
        assert!(checks.contains(required), "validation missing {required}");
    }

    let features = coverage["entries"]
        .as_array()
        .unwrap()
        .iter()
        .filter_map(|entry| entry["feature"].as_str())
        .collect::<BTreeSet<_>>();
    for required in [
        "extract-ir-pipeline",
        "runtime-value-denotation",
        "expanded-diagnostics",
        "source-span-diagnostics",
        "first20-completion",
    ] {
        assert!(features.contains(required), "coverage missing {required}");
    }
}

#[test]
fn first20_diagnostics_are_expanded_and_source_spanned() {
    assert!(DIAGNOSTICS.contains("structure SourceSpan"));
    assert!(DIAGNOSTICS.contains("DiagnosticInstance"));
    assert!(DIAGNOSTICS.contains("sourceSpanSummary"));
    for idx in 1..=14 {
        let code = format!("LRC{idx:03}");
        assert!(
            DIAGNOSTICS.contains(&code),
            "Diagnostics.lean missing {code}"
        );
        assert!(
            DIAGNOSTICS_DOC.contains(&code),
            "diagnostics docs missing {code}"
        );
    }
}

#[test]
fn first20_extract_ir_and_runtime_semantics_are_documented() {
    for needle in [
        "inductive ExtractExpr",
        "lowerExpr?",
        "recognizedRecursor",
        "dictionaryArgument",
        "DeclarationMetadata",
        "sourceSpan",
    ] {
        assert!(EXTRACT_IR.contains(needle), "ExtractIR missing {needle}");
    }
    assert!(EXTRACT_IR_DOC.contains("Only `ExtractExpr.surface` may enter the Rust emitter"));

    for needle in [
        "inductive RuntimeValue",
        "runtimeValueHasType",
        "runtimeFieldsHaveTypes",
        "runtimeDenotationSummary",
    ] {
        assert!(IR.contains(needle), "IR.lean missing {needle}");
    }
    assert!(!IR.contains("| .struct _ _ => Unit"));
    assert!(!IR.contains("| .enum _ _ => Nat"));
    assert!(!IR.contains("| .recursive _ => Unit"));
    assert!(RUNTIME_DOC.contains("RuntimeValue subtype witnesses"));
}

#[test]
fn first20_corpus_fixtures_require_tests_and_docs() {
    for fixture in [POSITIVE_FIXTURE, NEGATIVE_FIXTURE, UNSUPPORTED_FIXTURE] {
        let value: serde_json::Value = serde_json::from_str(fixture).unwrap();
        assert_eq!(value["format"], "lean-rust-core.corpus-case.v1");
        assert!(value["tests"].as_array().unwrap().len() >= 1);
        assert!(value["documentation"].as_array().unwrap().len() >= 1);
    }
    let negative: serde_json::Value = serde_json::from_str(NEGATIVE_FIXTURE).unwrap();
    assert_eq!(negative["diagnostic_code"], "LRC001");
    assert_eq!(negative["source_span_required"], true);

    let unsupported: serde_json::Value = serde_json::from_str(UNSUPPORTED_FIXTURE).unwrap();
    assert_eq!(unsupported["diagnostic_code"], "LRC004");
    assert_eq!(unsupported["source_span_required"], true);
}

#[test]
fn first_twenty_completion_metadata_is_present() {
    // Compatibility name for shell validation gates.
    first20_reports_record_required_completion_metadata();
}

#[test]
fn expanded_diagnostics_and_corpus_are_complete() {
    // Compatibility name for shell validation gates.
    first20_diagnostics_are_expanded_and_source_spanned();
    first20_corpus_fixtures_require_tests_and_docs();
}
