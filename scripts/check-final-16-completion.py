#!/usr/bin/env python3
"""Task-41 through task-56 final implementation checkpoint checks."""
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
    required = [
        "LeanRustCore/PropertyCorpus.lean",
        "LeanRustCore/CoverageDashboard.lean",
        "LeanRustCore/Diagnostics.lean",
        "LeanRustCore/CrateDesign.lean",
        "LeanRustCore/ReleaseMatrix.lean",
        "corpus/property/seeds.json",
        "corpus/fuzz/README.md",
        "docs/TESTING.md",
        "docs/COVERAGE.md",
        "docs/DIAGNOSTICS.md",
        "docs/CRATE_DESIGN.md",
        "docs/RELEASE_CHECKLIST.md",
        "rust/README.md",
        "rust/tests/final16_property_coverage.rs",
        "rust/tests/final16_diagnostics_and_crates.rs",
        "crates/runtime/Cargo.toml",
        "crates/runtime/src/lib.rs",
        "crates/runtime/README.md",
        "crates/abi/Cargo.toml",
        "crates/abi/src/lib.rs",
        "crates/abi/README.md",
        "crates/validate/Cargo.toml",
        "crates/validate/src/lib.rs",
        "crates/validate/README.md",
        "crates/headers/Cargo.toml",
        "crates/headers/src/lib.rs",
        "crates/headers/README.md",
    ]
    for path in required:
        require((ROOT / path).exists(), f"missing final-16 artifact {path}")


def check_lean_modules() -> None:
    expectations = {
        "LeanRustCore/PropertyCorpus.lean": ["PropertySeedFamily", "seedFamilies", "deterministicSeedCount", "propertyCorpusSummary"],
        "LeanRustCore/CoverageDashboard.lean": ["CoverageMetric", "metrics", "metricPercent", "quantitativeCoverageSummary"],
        "LeanRustCore/Diagnostics.lean": ["DiagnosticTemplate", "LRC001", "LRC002", "LRC003", "LRC004", "diagnosticSummary"],
        "LeanRustCore/CrateDesign.lean": ["WorkspaceCrate", "lean-rust-core-generated", "lean-rust-core-runtime", "lean-rust-core-abi", "lean-rust-core-validate", "lean-rust-core-headers", "crateDesignSummary"],
        "LeanRustCore/ReleaseMatrix.lean": ["ReleaseGate", "cargo test --workspace", "cargo clippy --workspace", "releaseMatrixSummary"],
    }
    for path, needles in expectations.items():
        text = read(path)
        for needle in needles:
            require(needle in text, f"{path} missing {needle}")
    imports = read("LeanRustCore.lean")
    for module in ["PropertyCorpus", "CoverageDashboard", "Diagnostics", "CrateDesign", "ReleaseMatrix"]:
        require(f"import LeanRustCore.{module}" in imports, f"LeanRustCore.lean missing import for {module}")


def check_workspace_crates() -> None:
    root_cargo = read("Cargo.toml")
    for member in ["rust", "crates/runtime", "crates/abi", "crates/validate", "crates/headers"]:
        require(member in root_cargo, f"workspace missing {member}")
    generated_cargo = read("rust/Cargo.toml")
    require('lean-rust-core-runtime = { path = "../crates/runtime" }' in generated_cargo, "generated crate missing runtime dependency")
    require('lean-rust-core-abi = { path = "../crates/abi", optional = true }' in generated_cargo, "generated crate missing optional ABI dependency")
    require('ffi = ["dep:lean-rust-core-abi"]' in generated_cargo, "generated crate ffi feature does not include ABI crate")
    generated_lib = read("rust/src/lib.rs")
    require("pub use lean_rust_core_runtime as runtime_crate;" in generated_lib, "generated crate does not reexport runtime crate")
    require("pub use lean_rust_core_abi as abi_crate;" in generated_lib, "generated crate does not reexport ABI crate under ffi")
    require("#![forbid(unsafe_code)]" in read("crates/runtime/src/lib.rs"), "runtime crate must forbid unsafe")
    require("#![forbid(unsafe_code)]" in read("crates/validate/src/lib.rs"), "validate crate must forbid unsafe")
    require("#![forbid(unsafe_code)]" in read("crates/headers/src/lib.rs"), "headers crate must forbid unsafe")
    abi = read("crates/abi/src/lib.rs")
    require("# Safety" in abi and "unsafe fn lower_result_u32_u32" in abi, "ABI crate unsafe function lacks safety docs")


def check_tests_and_docs() -> None:
    property = json_file("corpus/property/seeds.json")
    families = {case["name"] for case in property.get("families", [])}
    for family in ["numeric-edge-cases", "container-roundtrip", "closure-and-dictionary", "ffi-handle-lifecycle", "generated-subset-target-grammar"]:
        require(family in families, f"property seeds missing {family}")
    test_text = "\n".join(read(path) for path in [
        "rust/tests/final16_property_coverage.rs",
        "rust/tests/final16_diagnostics_and_crates.rs",
        "crates/runtime/src/lib.rs",
        "crates/abi/src/lib.rs",
        "crates/validate/src/lib.rs",
        "crates/headers/src/lib.rs",
    ])
    for needle in [
        "property_seed_families_are_present_and_exercised",
        "quantitative_coverage_dashboard_has_required_denominators",
        "diagnostics_and_docs_are_declared_for_unsupported_constructs",
        "rust_workspace_crate_split_is_visible_to_tests",
        "numeric_edge_cases_are_documented_by_tests",
        "vec_handle_lifecycle_rejects_double_drop",
        "parses_valid_json_and_rejects_malformed_json",
        "header_contains_ownership_and_destructors",
    ]:
        require(needle in test_text, f"final-16 tests missing {needle}")
    for path in ["docs/TESTING.md", "docs/COVERAGE.md", "docs/DIAGNOSTICS.md", "docs/CRATE_DESIGN.md", "docs/RELEASE_CHECKLIST.md"]:
        text = read(path).lower()
        require("test" in text or "tests" in text, f"{path} must describe tests")
        require("doc" in text or "documentation" in text, f"{path} must describe documentation")


def check_reports() -> None:
    validation = json_file("rust/validation-report.json")
    proof = json_file("rust/proof-report.json")
    coverage = json_file("rust/coverage-dashboard.json")
    checks = {item["name"] for item in validation.get("checks", [])}
    required_checks = [
        "property-fuzz-corpus",
        "quantitative-coverage-dashboard",
        "user-facing-diagnostics",
        "rust-workspace-crate-split",
        "generated-crate-final-api",
        "runtime-crate-final-api",
        "abi-crate-final-api",
        "validate-crate-final-api",
        "headers-crate-final-api",
        "release-acceptance-matrix",
    ]
    for check in required_checks:
        require(check in checks, f"validation-report missing {check}")
    features = {entry["feature"] for entry in coverage.get("entries", [])}
    for feature in [
        "property-fuzz-corpus",
        "quantitative-coverage-dashboard",
        "user-facing-diagnostics",
        "rust-workspace-crate-split",
        "release-acceptance-matrix",
    ]:
        require(feature in features, f"coverage-dashboard missing {feature}")
    metrics = {metric["denominator"] for metric in coverage.get("metrics", [])}
    for denominator in ["checklist_rows_41_56", "rust_workspace_crates", "final_docs", "property_seed_families", "release_acceptance_gates"]:
        require(denominator in metrics, f"coverage-dashboard metrics missing {denominator}")
    trusted = "\n".join(proof.get("trusted_core", []))
    for needle in [
        "LeanRustCore.PropertyCorpus.seedFamilies",
        "LeanRustCore.CoverageDashboard.metrics",
        "LeanRustCore.Diagnostics.templates",
        "LeanRustCore.CrateDesign.workspaceCrates",
        "LeanRustCore.ReleaseMatrix.gates",
    ]:
        require(needle in trusted, f"proof-report trusted_core missing {needle}")
    policy = proof.get("policy", {})
    for flag in ["property_fuzz_corpus", "quantitative_coverage_dashboard", "user_facing_diagnostics", "rust_workspace_crate_split", "release_acceptance_matrix"]:
        require(policy.get(flag) is True, f"proof-report policy missing {flag}")


def check_release_scripts() -> None:
    check_sh = read("scripts/check.sh")
    require("scripts/check-final-16-completion.py" in check_sh, "check.sh missing final-16 completion gate")
    require("cargo test --workspace" in check_sh, "check.sh missing workspace cargo test")
    require("cargo clippy --workspace" in check_sh, "check.sh missing workspace clippy")
    rust_validation = read("scripts/check-rust-validation.sh")
    require("scripts/check-final-16-completion.py" in rust_validation, "check-rust-validation missing final-16 completion gate")
    makefile = read("Makefile")
    require("workspace-test" in makefile, "Makefile missing workspace-test target")


def main() -> None:
    check_required_files()
    check_lean_modules()
    check_workspace_crates()
    check_tests_and_docs()
    check_reports()
    check_release_scripts()


if __name__ == "__main__":
    main()
