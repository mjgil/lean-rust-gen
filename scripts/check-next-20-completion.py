#!/usr/bin/env python3
"""Checklist rows 21-40 completion gate."""
from __future__ import annotations

import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def load_json(path: str):
    try:
        return json.loads(read(path))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path} is not valid JSON: {exc}") from exc


def check_files() -> None:
    required = [
        "LeanRustCore/GenericEmission.lean",
        "LeanRustCore/ParameterizedData.lean",
        "LeanRustCore/GenericPolicy.lean",
        "LeanRustCore/NumericSemantics.lean",
        "LeanRustCore/DependentErasureChecker.lean",
        "LeanRustCore/RecursiveDiscovery.lean",
        "LeanRustCore/OwnershipPolicy.lean",
        "LeanRustCore/PatternMatrix.lean",
        "LeanRustCore/RecursionAnalysis.lean",
        "LeanRustCore/StdImplementation.lean",
        "LeanRustCore/TypeclassSpecialization.lean",
        "docs/GENERICS.md",
        "docs/NUMERIC_SEMANTICS.md",
        "docs/DEPENDENT_ERASURE.md",
        "docs/RECURSIVE_DATA.md",
        "docs/OWNERSHIP.md",
        "docs/PATTERN_COMPILER.md",
        "docs/RECURSION_LOWERING.md",
        "docs/STD_LOWERINGS.md",
        "docs/TYPECLASSES.md",
        "rust/tests/next20_completion.rs",
    ]
    for path in required:
        require((ROOT / path).exists(), f"missing next-20 artifact {path}")


def check_lean_modules() -> None:
    expectations = {
        "LeanRustCore/GenericEmission.lean": ["ParameterizedDataShape", "monomorphizeDataShape", "rustGenericEmissionAllowedByDefault", "genericEmissionSummary"],
        "LeanRustCore/ParameterizedData.lean": ["substituteTypeVars", "decideMonomorphicInstance", "parameterizedDataSummary"],
        "LeanRustCore/GenericPolicy.lean": ["ExportGenericDecision", "finalRustGenericPolicySummary", "LRC009"],
        "LeanRustCore/NumericSemantics.lean": ["NumericMode", "NumericRule", "checkedAddU32", "preconditionedDivU32", "numericSemanticsSummary"],
        "LeanRustCore/DependentErasureChecker.lean": ["RuntimeRelevance", "ErasureDecision", "checkDependentErasure", "dependentErasureCheckerSummary"],
        "LeanRustCore/RecursiveDiscovery.lean": ["RecursiveEdgeKind", "RecursiveLayoutMode", "layoutDecisions", "recursiveDiscoverySummary"],
        "LeanRustCore/OwnershipPolicy.lean": ["OwnershipMode", "OwnershipRule", "borrowedShared", "ownershipPolicySummary"],
        "LeanRustCore/PatternMatrix.lean": ["PatternClass", "completedPatternFeatures", "patternMatrixSummary"],
        "LeanRustCore/RecursionAnalysis.lean": ["RecursionKind", "StackPolicy", "decisions", "recursionAnalysisSummary"],
        "LeanRustCore/StdImplementation.lean": ["ImplementedLowering", "implementedLoweringCount", "stdImplementationSummary"],
        "LeanRustCore/TypeclassSpecialization.lean": ["SpecializedClass", "classes", "typeclassSpecializationCompletionSummary"],
    }
    for path, needles in expectations.items():
        text = read(path)
        for needle in needles:
            require(needle in text, f"{path} missing {needle}")
    imports = read("LeanRustCore.lean")
    for module in [
        "GenericEmission", "ParameterizedData", "GenericPolicy", "NumericSemantics", "DependentErasureChecker",
        "RecursiveDiscovery", "OwnershipPolicy", "PatternMatrix", "RecursionAnalysis", "StdImplementation", "TypeclassSpecialization",
    ]:
        require(f"import LeanRustCore.{module}" in imports, f"LeanRustCore.lean missing {module}")


def check_runtime_and_tests() -> None:
    runtime = read("crates/runtime/src/lib.rs")
    for needle in [
        "u32_checked_div", "u32_checked_mod", "u64_checked_add", "i32_checked_add", "i64_checked_mul",
        "u32_saturating_mul", "int_to_i32_checked", "u64_to_u32_checked", "list_append_u32",
        "list_find_nonzero_u32", "list_partition_nonzero_u32", "RcTreeU32", "ArenaTreeU32",
        "borrowed_vec_len_u32", "borrowed_string_is_empty", "clone_vec_for_shared_use", "exact_int_mul",
    ]:
        require(needle in runtime, f"runtime crate missing {needle}")
    test = read("rust/tests/next20_completion.rs")
    for needle in [
        "next20_reports_mark_rows_21_40_complete",
        "next20_runtime_helpers_cover_numeric_std_and_layouts",
        "u32_checked_div", "RcTreeU32", "ArenaTreeU32", "list_append_u32", "list_partition_nonzero_u32",
    ]:
        require(needle in test, f"next20 test missing {needle}")


def check_docs() -> None:
    for path in [
        "docs/GENERICS.md", "docs/NUMERIC_SEMANTICS.md", "docs/DEPENDENT_ERASURE.md", "docs/RECURSIVE_DATA.md",
        "docs/OWNERSHIP.md", "docs/PATTERN_COMPILER.md", "docs/RECURSION_LOWERING.md", "docs/STD_LOWERINGS.md", "docs/TYPECLASSES.md",
    ]:
        text = read(path).lower()
        require("implementation requirements" in text, f"{path} must include implementation requirements")
        require("tests required" in text, f"{path} must include test requirements")
        require("documentation" in text or "document" in text, f"{path} must include documentation requirements")


def check_reports() -> None:
    validation = load_json("rust/validation-report.json")
    proof = load_json("rust/proof-report.json")
    coverage = load_json("rust/coverage-dashboard.json")
    checks = {check["name"] for check in validation.get("checks", [])}
    for check in [
        "next20-base-type-universe", "next20-parameterized-data", "next20-generic-policy",
        "next20-numeric-semantics", "next20-dependent-erasure", "next20-recursive-discovery",
        "next20-ownership-policy", "next20-pattern-matrix", "next20-recursion-analysis",
        "next20-std-implementation", "next20-typeclass-specialization",
    ]:
        require(check in checks, f"validation-report missing {check}")
    policy = proof.get("policy", {})
    for flag in [
        "next20_completion", "parameterized_data_monomorphization", "rust_generic_emission_policy_final",
        "numeric_semantics_complete", "dependent_erasure_complete", "recursive_discovery_complete",
        "ownership_policy_complete", "pattern_matrix_complete", "recursion_analysis_complete",
        "std_lowering_implementation_complete", "typeclass_specialization_complete",
    ]:
        require(policy.get(flag) is True, f"proof-report policy missing {flag}")
    entries = {entry["feature"] for entry in coverage.get("entries", [])}
    for entry in [
        "next20-completion", "parameterized-data-monomorphization", "rust-generic-policy",
        "complete-numeric-semantics", "complete-dependent-erasure", "recursive-discovery-layouts",
        "ownership-borrowing-policy", "pattern-matrix-compiler", "recursion-analysis-lowering",
        "std-lowering-implementation", "typeclass-specialization-complete",
    ]:
        require(entry in entries, f"coverage dashboard missing {entry}")
    metrics = {metric["denominator"] for metric in coverage.get("metrics", [])}
    require("checklist_rows_21_40" in metrics, "coverage metrics missing checklist_rows_21_40")
    trusted = "\n".join(proof.get("trusted_core", []))
    for needle in [
        "LeanRustCore.NumericSemantics.rules", "LeanRustCore.PatternMatrix.completedPatternFeatures",
        "LeanRustCore.RecursionAnalysis.decisions", "LeanRustCore.StdImplementation.lowerings",
        "LeanRustCore.TypeclassSpecialization.classes",
    ]:
        require(needle in trusted, f"proof-report trusted core missing {needle}")


def check_scripts() -> None:
    for path in ["scripts/check.sh", "scripts/check-rust-validation.sh", "scripts/check-extractor-snapshot.sh"]:
        require("scripts/check-next-20-completion.py" in read(path), f"{path} missing next-20 gate")


def main() -> None:
    check_files()
    check_lean_modules()
    check_runtime_and_tests()
    check_docs()
    check_reports()
    check_scripts()


if __name__ == "__main__":
    main()
