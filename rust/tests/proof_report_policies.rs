use serde_json::Value;

const PROOF_REPORT: &str = include_str!("../proof-report.json");

fn parse_json_artifact(path: &str, contents: &str) -> Value {
    serde_json::from_str(contents).unwrap_or_else(|err| panic!("{path} is not valid JSON: {err}"))
}

#[test]
fn proof_report_records_closure_and_defunctionalization_policies() {
    let report = parse_json_artifact("proof-report.json", PROOF_REPORT);

    assert_eq!(
        report["policy"]["closure_conversion"].as_str(),
        Some("helper-normalized-let-chains-and-explicit-environment-structs")
    );
    assert_eq!(
        report["policy"]["defunctionalization"].as_str(),
        Some("finite-enum-cases")
    );
    assert_eq!(
        report["policy"]["recursive_data_layout"].as_str(),
        Some("owned-box")
    );
    assert_eq!(
        report["policy"]["coverage_dashboard"].as_str(),
        Some("rust/coverage-dashboard.json")
    );
}
