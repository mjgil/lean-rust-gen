#!/usr/bin/env python3
"""Completion gate for checklist rows 1-20.

This gate is intentionally repository-local and uses only Python stdlib so it can
run before Lean/Cargo are available. It checks that every first-20 item has a
concrete implementation artifact, a test or corpus fixture, and documentation.
"""
from __future__ import annotations

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def json_file(path: str):
    try:
        return json.loads(read(path))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path} is not valid JSON: {exc}") from exc


def check_required_files() -> None:
    for path in [
        "LeanRustCore/ExtractIR.lean",
        "LeanRustCore/Diagnostics.lean",
        "LeanRustCore/IR.lean",
        "docs/EXTRACT_IR.md",
        "docs/RUNTIME_SEMANTICS.md",
        "docs/DIAGNOSTICS.md",
        "docs/TRUSTED_CORE.md",
        "corpus/positive/simple_u32.expected.json",
        "corpus/negative/unresolved_typeclass.expected.json",
        "corpus/unsupported/io_effect.expected.json",
        "rust/tests/first20_completion.rs",
    ]:
        require((ROOT / path).exists(), f"missing first-20 artifact {path}")


def check_extract_ir() -> None:
    text = read("LeanRustCore/ExtractIR.lean")
    for needle in [
        "inductive ExtractExpr",
        "lowerExpr?",
        "recognizedRecursor",
        "recognizedStdLowering",
        "dictionaryArgument",
        "structure DeclarationMetadata",
        "sourceSpan",
        "RecursorMetadata",
        "DictionaryMetadata",
        "functionFeatureTags",
        "extractIRSummary",
    ]:
        require(needle in text, f"ExtractIR missing {needle}")
    imports = read("LeanRustCore.lean")
    require("import LeanRustCore.ExtractIR" in imports, "LeanRustCore.lean missing ExtractIR import")


def check_runtime_denotation() -> None:
    text = read("LeanRustCore/IR.lean")
    for needle in ["inductive RuntimeValue", "runtimeValueHasType", "runtimeFieldsHaveTypes", "runtimePayloadHasTypes", "runtimeDenotationSummary"]:
        require(needle in text, f"IR.lean missing {needle}")
    forbidden = [
        "| .recursive _ => Unit",
        "| .struct _ _ => Unit",
        "| .enum _ _ => Nat",
    ]
    for needle in forbidden:
        require(needle not in text, f"placeholder denotation remains: {needle}")
    require(".struct name fields => { value : RuntimeValue" in text, "struct Denote must use RuntimeValue subtype")
    require(".enum name variants => { value : RuntimeValue" in text, "enum Denote must use RuntimeValue subtype")
    require(".recursive name => { value : RuntimeValue" in text, "recursive Denote must use RuntimeValue subtype")


def check_diagnostics() -> None:
    text = read("LeanRustCore/Diagnostics.lean")
    docs = read("docs/DIAGNOSTICS.md")
    for needle in ["structure SourceSpan", "DiagnosticInstance", "sourceSpanSummary", "requiresSpan"]:
        require(needle in text, f"Diagnostics missing {needle}")
    for idx in range(1, 15):
        code = f"LRC{idx:03d}"
        require(code in text, f"Diagnostics.lean missing {code}")
        require(code.lower() in docs.lower() or code in docs, f"docs/DIAGNOSTICS.md missing {code}")
    for phrase in ["source-span", "next feature", "documentation link"]:
        require(phrase in docs.lower(), f"diagnostics docs missing phrase {phrase}")


def check_corpus() -> None:
    kinds = {
        "corpus/positive": "positive",
        "corpus/negative": "negative",
        "corpus/unsupported": "unsupported",
    }
    for directory, kind in kinds.items():
        fixtures = list((ROOT / directory).glob("*.expected.json"))
        require(fixtures, f"{directory} must have at least one fixture")
        for fixture in fixtures:
            data = json.loads(fixture.read_text())
            require(data.get("format") == "lean-rust-core.corpus-case.v1", f"{fixture} has wrong format")
            require(data.get("kind") == kind, f"{fixture} has wrong kind")
            require(data.get("tests"), f"{fixture} lacks tests")
            require(data.get("documentation"), f"{fixture} lacks documentation")
            if kind != "positive":
                require(str(data.get("diagnostic_code", "")).startswith("LRC"), f"{fixture} lacks diagnostic code")
                require(data.get("source_span_required") is True, f"{fixture} must require source span")


def check_reports() -> None:
    validation = json_file("rust/validation-report.json")
    proof = json_file("rust/proof-report.json")
    coverage = json_file("rust/coverage-dashboard.json")

    checks = {item["name"] for item in validation.get("checks", [])}
    for check in [
        "extract-ir-pipeline",
        "runtime-value-denotation",
        "expanded-diagnostic-codes",
        "source-span-diagnostics",
        "first20-completion-gate",
    ]:
        require(check in checks, f"validation-report missing {check}")

    trusted = "\n".join(proof.get("trusted_core", []))
    for needle in [
        "LeanRustCore.ExtractIR.functionFeatures",
        "LeanRustCore.ExtractIR.lowerExpr?",
        "LeanRustCore.IR.runtimeValueHasType",
        "LeanRustCore.Diagnostics.SourceSpan",
    ]:
        require(needle in trusted, f"proof-report missing trusted core {needle}")
    policy = proof.get("policy", {})
    for flag in ["extract_ir_pipeline", "runtime_value_denotation", "source_span_diagnostics"]:
        require(policy.get(flag) is True, f"proof-report policy missing {flag}")
    require(policy.get("expanded_diagnostic_codes") == "LRC001-LRC014", "proof report must record expanded diagnostic range")

    features = {entry.get("feature") for entry in coverage.get("entries", [])}
    for feature in ["extract-ir-pipeline", "runtime-value-denotation", "expanded-diagnostics", "source-span-diagnostics", "first20-completion"]:
        require(feature in features, f"coverage-dashboard missing {feature}")


def check_scripts_and_ci() -> None:
    for path in ["scripts/check.sh", "scripts/check-rust-validation.sh", "scripts/check-extractor-snapshot.sh"]:
        text = read(path)
        require("scripts/check-first-20-completion.py" in text, f"{path} missing first-20 gate")
    workflow = read(".github/workflows/ci.yml")
    ci_script = read("scripts/check-ci-e2e.sh")
    require(
        "./scripts/check-ci-e2e.sh ${{ matrix.rust_features }}" in workflow,
        "CI workflow must run the scripted lane helper",
    )
    require("./scripts/check.sh" in ci_script, "CI lane helper must run scripts/check.sh")
    release_docs = read("docs/RELEASE_CHECKLIST.md")
    require("scripts/check-first-20-completion.py" in release_docs, "release checklist missing first-20 gate")


def check_tests_and_docs() -> None:
    test = read("rust/tests/first20_completion.rs")
    for needle in [
        "first20_reports_record_required_completion_metadata",
        "first20_diagnostics_are_expanded_and_source_spanned",
        "first20_extract_ir_and_runtime_semantics_are_documented",
        "LRC014",
        "runtimeValueHasType",
    ]:
        require(needle in test, f"first20 Rust test missing {needle}")

    validation_test = read("rust/tests/validation_report.rs")
    for needle in [
        "typed_report_schemas_are_strict_and_complete",
        "typed_report_counts_and_feature_flags_match_generated_artifacts",
        "parse_validation_report",
        "parse_coverage_dashboard",
    ]:
        require(needle in validation_test, f"validation report test missing {needle}")

    validate_lib = read("crates/validate/src/lib.rs")
    for needle in [
        "#[serde(deny_unknown_fields)]",
        "pub fn parse_validation_report",
        "pub fn parse_compatibility_report",
        "pub fn parse_proof_report",
        "pub fn parse_build_metadata_report",
        "pub fn parse_coverage_dashboard",
    ]:
        require(needle in validate_lib, f"validate crate missing typed report schema support {needle}")

    for path in ["docs/EXTRACT_IR.md", "docs/RUNTIME_SEMANTICS.md", "docs/DIAGNOSTICS.md"]:
        text = read(path).lower()
        require("test" in text or "testing" in text, f"{path} must document tests")
        require("complete" in text or "completion" in text, f"{path} must document completion")
    trusted = read("docs/TRUSTED_CORE.md").lower()
    for phrase in ["report schema validation", "deny_unknown_fields", "coverage-dashboard.json"]:
        require(phrase in trusted, f"docs/TRUSTED_CORE.md missing report-schema phrase {phrase}")


def main() -> None:
    check_required_files()
    check_extract_ir()
    check_runtime_denotation()
    check_diagnostics()
    check_corpus()
    check_reports()
    check_scripts_and_ci()
    check_tests_and_docs()


if __name__ == "__main__":
    main()
