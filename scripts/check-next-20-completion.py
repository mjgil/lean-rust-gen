#!/usr/bin/env python3
"""Checklist rows 21-40 completion gate."""
from __future__ import annotations

import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
TEMPLATE_RE = re.compile(
    r'\{\s*code := "(LRC\d{3})", severity := \.(\w+), construct := "([^"]+)", '
    r'nextFeature := "([^"]+)", documentation := "([^"]+)", requiresSpan := (true|false) \}'
)
EXTRACTOR_BRANCHES = {
    "extract-regular-unsupported-export",
    "extract-mono-unsupported-export",
    "auto-helper-fixpoint-fuel",
    "auto-generated-specs-fixpoint-fuel",
}


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


def parse_diagnostic_templates() -> dict[str, dict[str, object]]:
    templates: dict[str, dict[str, object]] = {}
    for match in TEMPLATE_RE.finditer(read("LeanRustCore/Diagnostics.lean")):
        code, severity, construct, next_feature, documentation, requires_span = match.groups()
        templates[code] = {
            "severity": severity,
            "construct": construct,
            "next_feature": next_feature,
            "documentation": documentation,
            "requires_span": requires_span == "true",
        }
    require(len(templates) == 14, "Diagnostics.lean must define exactly 14 LRC templates")
    return templates


def check_files() -> None:
    required = [
        "LeanRustCore/GenericEmission.lean",
        "LeanRustCore/ParameterizedData.lean",
        "LeanRustCore/ParameterizedExamples.lean",
        "LeanRustCore/GenericPolicy.lean",
        "LeanRustCore/NumericSemantics.lean",
        "LeanRustCore/NumericExamples.lean",
        "LeanRustCore/StdExamples.lean",
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
        "docs/DIAGNOSTICS.md",
        "docs/RECURSIVE_DATA.md",
        "docs/OWNERSHIP.md",
        "docs/PATTERN_COMPILER.md",
        "docs/RECURSION_LOWERING.md",
        "docs/STD_LOWERINGS.md",
        "docs/TYPECLASSES.md",
        "crates/validate/src/ownership_validation.rs",
        "rust/tests/next20_completion.rs",
        "rust/tests/pattern_matrix_completion.rs",
        "corpus/positive/parameterized_pair_box.expected.json",
        "corpus/positive/parameterized_nested_payload.expected.json",
        "corpus/positive/equality_cast_subtype.expected.json",
        "corpus/positive/sigma_runtime_pair.expected.json",
        "corpus/positive/flag_carrier_invariant.expected.json",
        "corpus/positive/flag_carrier_invariant_match.expected.json",
        "corpus/positive/nested_proof_wrapper.expected.json",
        "corpus/positive/recursive_binary_tree.expected.json",
        "corpus/positive/recursive_rose_tree.expected.json",
        "corpus/positive/recursive_even_odd.expected.json",
        "corpus/positive/pattern_list_head.expected.json",
        "corpus/positive/pattern_list_second.expected.json",
        "corpus/positive/pattern_nat_pred.expected.json",
        "corpus/positive/pattern_nat_two_step.expected.json",
        "corpus/positive/pattern_tree_sum.expected.json",
        "corpus/positive/std_result_map_ok.expected.json",
        "corpus/positive/std_list_reverse.expected.json",
        "corpus/positive/std_array_get.expected.json",
        "corpus/positive/std_string_append.expected.json",
        "corpus/positive/std_string_length.expected.json",
        "corpus/positive/std_string_contains_char.expected.json",
        "corpus/unsupported/dependent_generic_index.expected.json",
    ]
    for path in required:
        require((ROOT / path).exists(), f"missing next-20 artifact {path}")


def check_lean_modules() -> None:
    expectations = {
        "LeanRustCore/GenericEmission.lean": ["ParameterizedDataShape", "monomorphizeDataShape", "multiParameterEnumFixture", "nestedParameterizedFixture", "acceptedParameterizedFixtures", "rejectedDependentParameterizedShapes", "rustGenericEmissionAllowedByDefault", "genericEmissionSummary"],
        "LeanRustCore/ParameterizedData.lean": ["substituteTypeVars", "decideMonomorphicInstance", "acceptedParameterizedShapes", "rejectedDependentGenericShapes", "parameterizedDataSummary"],
        "LeanRustCore/ParameterizedExamples.lean": ["structure PairBox", "inductive PairChoice", "structure NestedPayload"],
        "LeanRustCore/GenericPolicy.lean": ["ExportGenericDecision", "finalRustGenericPolicySummary", "LRC009"],
        "LeanRustCore/NumericSemantics.lean": ["NumericMode", "NumericRule", "checkedAddU32", "preconditionedDivU32", "numericSemanticsSummary"],
        "LeanRustCore/NumericExamples.lean": ["def checked_add_u32", "def saturating_add_u32", "def preconditioned_div_u32", "def checked_cast_u64_to_u32"],
        "LeanRustCore/StdExamples.lean": ["def result_map_ok_inc_u32", "def list_reverse_first_or_u32", "def array_get_opt_u32", "def string_append_lean", "def string_length_chars_u32", "def string_contains_char_lean"],
        "LeanRustCore/DependentErasureChecker.lean": ["RuntimeRelevance", "ErasureDecision", "checkDependentErasure", "dependentErasureCheckerSummary"],
        "LeanRustCore/RecursiveDiscovery.lean": ["RecursiveEdgeKind", "RecursiveLayoutMode", "layoutDecisions", "recursiveDiscoverySummary"],
        "LeanRustCore/OwnershipPolicy.lean": ["OwnershipMode", "OwnershipRule", "borrowedShared", "approvedReferenceForms", "ownershipPolicySummary", "ownershipPolicyEnforcementSummary"],
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
        "GenericEmission", "ParameterizedData", "ParameterizedExamples", "GenericPolicy", "NumericSemantics", "DependentErasureChecker",
        "RecursiveDiscovery", "OwnershipPolicy", "PatternMatrix", "RecursionAnalysis", "StdImplementation", "StdExamples", "TypeclassSpecialization",
    ]:
        require(f"import LeanRustCore.{module}" in imports, f"LeanRustCore.lean missing {module}")


def check_runtime_and_tests() -> None:
    runtime = read("crates/runtime/src/lib.rs")
    for needle in [
        "u32_checked_div", "u32_checked_mod", "u64_checked_add", "i32_checked_add", "i64_checked_mul",
        "u32_saturating_mul", "int_to_i32_checked", "u64_to_u32_checked", "list_append_u32",
        "list_find_nonzero_u32", "list_head_clone", "list_tail_clone", "list_partition_nonzero_u32", "RcTreeU32", "ArenaTreeU32",
        "borrowed_vec_len_u32", "borrowed_string_is_empty", "clone_vec_for_shared_use", "exact_int_mul",
    ]:
        require(needle in runtime, f"runtime crate missing {needle}")
    test = read("rust/tests/next20_completion.rs")
    for needle in [
        "next20_reports_mark_rows_21_40_complete",
        "next20_diagnostic_corpus_covers_all_rejection_paths",
        "next20_parameterized_data_examples_cover_multi_parameter_and_nested_shapes",
        "next20_recursive_discovery_examples_cover_direct_nested_and_mutual_sccs",
        "next20_ownership_policy_enforces_non_escaping_borrows",
        "next20_runtime_helpers_cover_numeric_std_and_layouts",
        "u32_checked_div", "checked_add_u32", "preconditioned_div_u32", "RcTreeU32",
        "ArenaTreeU32", "list_append_u32", "list_partition_nonzero_u32",
        "next20_dependent_erasure_examples_cover_invariant_sigma_and_indexed_shapes",
    ]:
        require(needle in test, f"next20 test missing {needle}")
    pattern_test = read("rust/tests/pattern_matrix_completion.rs")
    for needle in [
        "pattern_matrix_examples_cover_list_nat_tree_and_nested_shapes",
        "list_head_or_zero_u32",
        "list_second_or_zero_u32",
        "nat_pred_or_zero_u32",
        "nat_two_step_or_zero_u32",
        "pattern_tree_sum.expected.json",
    ]:
        require(needle in pattern_test, f"pattern-matrix test missing {needle}")

    parser_validation = read("rust/tests/parser_validation.rs")
    for needle in [
        "parser_validates_generated_ownership_policy",
        "validate_generated_ownership",
        "approved_reference_exprs",
    ]:
        require(needle in parser_validation, f"parser validation missing {needle}")

    generated = read("rust/src/generated.rs")
    for needle in [
        "pub fn checked_add_u32",
        "pub fn saturating_add_u32",
        "pub fn preconditioned_div_u32",
        "pub fn checked_cast_u64_to_u32",
        "pub fn equality_cast_subtype_value_u32",
        "pub fn sigma_runtime_pair_echo_u32",
        "pub fn sigma_runtime_pair_sum_u32",
        "pub fn flag_carrier_true_roundtrip_u32",
        "pub fn flag_carrier_false_value_u32",
        "pub fn flag_carrier_match_invariant_u32",
        "pub fn nested_proof_wrapper_value_u32",
        "pub fn list_head_or_zero_u32",
        "pub fn list_second_or_zero_u32",
        "pub fn nat_pred_or_zero_u32",
        "pub fn nat_two_step_or_zero_u32",
        "pub struct RoseTreeU32",
        "pub enum EvenNode",
        "pub enum OddNode",
        "pub fn rose_branch_u32",
        "pub fn even_terminal_u32",
        "pub fn odd_terminal_u32",
        "pub fn even_step_u32",
        "pub fn odd_step_u32",
        "pub struct PairboxU32String",
        "pub struct PairboxStringU32",
        "pub enum PairchoiceU32String",
        "pub struct NestedpayloadU32String",
        "pub fn pair_box_make_u32_string",
        "pub fn pair_box_swap_u32_string",
        "pub fn pair_choice_default_u32_string",
        "pub fn nested_payload_value_or_u32_string",
        "pub fn result_map_ok_inc_u32",
        "pub fn list_reverse_first_or_u32",
        "pub fn array_get_opt_u32",
        "pub fn string_append_lean",
        "pub fn string_length_chars_u32",
        "pub fn string_contains_char_lean",
    ]:
        require(needle in generated, f"generated Rust missing {needle}")

    target_validation = read("rust/target-validation.txt")
    for needle in [
        "FN\tchecked_add_u32",
        "FN\tsaturating_add_u32",
        "FN\tpreconditioned_div_u32",
        "FN\tchecked_cast_u64_to_u32",
        "FN\tequality_cast_subtype_value_u32",
        "FN\tsigma_runtime_pair_echo_u32",
        "FN\tsigma_runtime_pair_sum_u32",
        "FN\tflag_carrier_true_roundtrip_u32",
        "FN\tflag_carrier_false_value_u32",
        "FN\tflag_carrier_match_invariant_u32",
        "FN\tnested_proof_wrapper_value_u32",
        "FN\tlist_head_or_zero_u32",
        "FN\tlist_second_or_zero_u32",
        "FN\tnat_pred_or_zero_u32",
        "FN\tnat_two_step_or_zero_u32",
        "TYPE\tstruct\tRoseTreeU32",
        "TYPE\tenum\tEvenNode",
        "TYPE\tenum\tOddNode",
        "FN\trose_branch_u32",
        "FN\teven_terminal_u32",
        "FN\todd_terminal_u32",
        "FN\teven_step_u32",
        "FN\todd_step_u32",
        "TYPE\tstruct\tPairboxU32String",
        "TYPE\tenum\tPairchoiceU32String",
        "TYPE\tstruct\tNestedpayloadU32String",
        "FN\tpair_box_make_u32_string",
        "FN\tpair_choice_default_u32_string",
        "FN\tnested_payload_value_or_u32_string",
        "FN\tresult_map_ok_inc_u32",
        "FN\tlist_reverse_first_or_u32",
        "FN\tarray_get_opt_u32",
        "FN\tstring_append_lean",
        "FN\tstring_length_chars_u32",
        "FN\tstring_contains_char_lean",
    ]:
        require(needle in target_validation, f"target-validation snapshot missing {needle}")


def check_diagnostic_corpus() -> None:
    templates = parse_diagnostic_templates()
    fixtures = list((ROOT / "corpus/negative").glob("*.expected.json")) + list(
        (ROOT / "corpus/unsupported").glob("*.expected.json")
    )
    require(fixtures, "diagnostic corpus must include negative or unsupported fixtures")
    seen_codes: set[str] = set()
    seen_branches: set[str] = set()
    for fixture in fixtures:
        rel = str(fixture.relative_to(ROOT))
        data = load_json(rel)
        code = data.get("diagnostic_code")
        require(code in templates, f"{rel} uses unknown diagnostic code {code}")
        template = templates[code]
        require(data.get("next_feature") == template["next_feature"], f"{rel} has wrong next_feature")
        require(
            data.get("source_span_required") is template["requires_span"],
            f"{rel} must match requiresSpan={template['requires_span']} for {code}",
        )
        expected_status = "error" if template["severity"] == "error" else "unsupported"
        require(data.get("expected_status") == expected_status, f"{rel} must use expected_status {expected_status}")
        require(
            template["documentation"] in data.get("documentation", []),
            f"{rel} must reference {template['documentation']}",
        )
        tests = set(data.get("tests", []))
        require("scripts/check-next-20-completion.py" in tests, f"{rel} must include next-20 script coverage")
        require("rust/tests/next20_completion.rs" in tests, f"{rel} must include next-20 Rust coverage")
        seen_codes.add(code)
        branch = data.get("extractor_branch")
        if branch is not None:
            require(branch in EXTRACTOR_BRANCHES, f"{rel} uses unknown extractor branch {branch}")
            seen_branches.add(branch)
    require(seen_codes == set(templates), f"diagnostic corpus must cover {sorted(templates)}; saw {sorted(seen_codes)}")
    require(
        seen_branches == EXTRACTOR_BRANCHES,
        f"diagnostic corpus must cover extractor branches {sorted(EXTRACTOR_BRANCHES)}; saw {sorted(seen_branches)}",
    )


def check_parameterized_data_corpus() -> None:
    pair_box = load_json("corpus/positive/parameterized_pair_box.expected.json")
    require(pair_box["kind"] == "positive", "pair-box corpus case must be positive")
    require(pair_box["source"] == "LeanRustCore.Examples.pair_box_make_u32_string", "pair-box corpus case must reference the exported example")
    require(pair_box["expected_status"] == "supported", "pair-box corpus case must be supported")
    require(
        set(pair_box["required_features"]) == {"generic-monomorphization", "struct-enum-shape"},
        "pair-box corpus case must record generic monomorphization + struct/enum coverage",
    )

    nested = load_json("corpus/positive/parameterized_nested_payload.expected.json")
    require(nested["kind"] == "positive", "nested-payload corpus case must be positive")
    require(nested["source"] == "LeanRustCore.Examples.nested_payload_value_or_u32_string", "nested-payload corpus case must reference the exported example")
    require(nested["expected_status"] == "supported", "nested-payload corpus case must be supported")
    require(
        set(nested["required_features"]) == {"generic-monomorphization", "struct-enum-shape", "container-shape"},
        "nested-payload corpus case must record nested container coverage",
    )

    dependent = load_json("corpus/unsupported/dependent_generic_index.expected.json")
    require(dependent["kind"] == "unsupported", "dependent-generic corpus case must be unsupported")
    require(dependent["diagnostic_code"] == "LRC008", "dependent-generic corpus case must use LRC008")
    require(
        dependent["next_feature"] == "dependent erasure proof classifier",
        "dependent-generic corpus case must point at dependent erasure follow-up work",
    )
    require(
        "docs/GENERICS.md" in dependent["documentation"],
        "dependent-generic corpus case must reference the generics doc",
    )


def check_dependent_erasure_positive_corpus() -> None:
    expected = {
        "corpus/positive/equality_cast_subtype.expected.json": (
            "LeanRustCore.Examples.equality_cast_subtype_value_u32",
            {"dependent-erasure", "proof-erasure"},
        ),
        "corpus/positive/sigma_runtime_pair.expected.json": (
            "LeanRustCore.Examples.sigma_runtime_pair_echo_u32",
            {"dependent-erasure", "container-shape"},
        ),
        "corpus/positive/flag_carrier_invariant.expected.json": (
            "LeanRustCore.Examples.flag_carrier_true_roundtrip_u32",
            {"dependent-erasure"},
        ),
        "corpus/positive/flag_carrier_invariant_match.expected.json": (
            "LeanRustCore.Examples.flag_carrier_match_invariant_u32",
            {"dependent-erasure", "general-pattern-match"},
        ),
        "corpus/positive/nested_proof_wrapper.expected.json": (
            "LeanRustCore.Examples.nested_proof_wrapper_value_u32",
            {"dependent-erasure", "proof-erasure"},
        ),
    }
    for path, (source, features) in expected.items():
        fixture = load_json(path)
        require(fixture["kind"] == "positive", f"{path} must be positive")
        require(fixture["source"] == source, f"{path} must reference {source}")
        require(fixture["expected_status"] == "supported", f"{path} must be supported")
        require(
            set(fixture["required_features"]) == features,
            f"{path} must record required features {sorted(features)}",
        )
        require(
            "docs/DEPENDENT_ERASURE.md" in fixture["documentation"],
            f"{path} must reference docs/DEPENDENT_ERASURE.md",
        )


def check_recursive_positive_corpus() -> None:
    expected = {
        "corpus/positive/recursive_binary_tree.expected.json": (
            "LeanRustCore.Examples.tree_node_u32",
            {"recursive-owned-box-data", "recursive-direct-scc"},
        ),
        "corpus/positive/recursive_rose_tree.expected.json": (
            "LeanRustCore.Examples.rose_branch_u32",
            {"container-shape", "recursive-nested-scc", "recursive-owned-box-data"},
        ),
        "corpus/positive/recursive_even_odd.expected.json": (
            "LeanRustCore.Examples.even_step_u32",
            {"general-pattern-match", "recursive-mutual-scc", "recursive-owned-box-data"},
        ),
    }
    for path, (source, features) in expected.items():
        fixture = load_json(path)
        require(fixture["kind"] == "positive", f"{path} must be positive")
        require(fixture["source"] == source, f"{path} must reference {source}")
        require(fixture["expected_status"] == "supported", f"{path} must be supported")
        require(
            set(fixture["required_features"]) == features,
            f"{path} must record required features {sorted(features)}",
        )
        require(
            "docs/RECURSIVE_DATA.md" in fixture["documentation"],
            f"{path} must reference docs/RECURSIVE_DATA.md",
        )


def check_pattern_positive_corpus() -> None:
    expected = {
        "corpus/positive/pattern_list_head.expected.json": (
            "LeanRustCore.Examples.list_head_or_zero_u32",
            {"container-shape", "general-pattern-match"},
        ),
        "corpus/positive/pattern_list_second.expected.json": (
            "LeanRustCore.Examples.list_second_or_zero_u32",
            {"container-shape", "general-pattern-match"},
        ),
        "corpus/positive/pattern_nat_pred.expected.json": (
            "LeanRustCore.Examples.nat_pred_or_zero_u32",
            {"general-pattern-match", "primitive"},
        ),
        "corpus/positive/pattern_nat_two_step.expected.json": (
            "LeanRustCore.Examples.nat_two_step_or_zero_u32",
            {"general-pattern-match", "primitive"},
        ),
        "corpus/positive/pattern_tree_sum.expected.json": (
            "LeanRustCore.Examples.tree_sum_u32",
            {"general-pattern-match", "recursive-direct-scc", "recursive-owned-box-data"},
        ),
    }
    for path, (source, features) in expected.items():
        fixture = load_json(path)
        require(fixture["kind"] == "positive", f"{path} must be positive")
        require(fixture["source"] == source, f"{path} must reference {source}")
        require(fixture["expected_status"] == "supported", f"{path} must be supported")
        require(
            set(fixture["required_features"]) == features,
            f"{path} must record required features {sorted(features)}",
        )
        require(
            "docs/PATTERN_COMPILER.md" in fixture["documentation"],
            f"{path} must reference docs/PATTERN_COMPILER.md",
        )


def check_std_positive_corpus() -> None:
    expected = {
        "corpus/positive/std_result_map_ok.expected.json": (
            "LeanRustCore.Examples.result_map_ok_inc_u32",
            {"std-lowering", "result-shape"},
        ),
        "corpus/positive/std_list_reverse.expected.json": (
            "LeanRustCore.Examples.list_reverse_first_or_u32",
            {"std-lowering", "structural-loop"},
        ),
        "corpus/positive/std_array_get.expected.json": (
            "LeanRustCore.Examples.array_get_opt_u32",
            {"std-lowering", "container-shape"},
        ),
        "corpus/positive/std_string_append.expected.json": (
            "LeanRustCore.Examples.string_append_lean",
            {"std-lowering", "string-shape"},
        ),
        "corpus/positive/std_string_length.expected.json": (
            "LeanRustCore.Examples.string_length_chars_u32",
            {"std-lowering", "string-shape"},
        ),
        "corpus/positive/std_string_contains_char.expected.json": (
            "LeanRustCore.Examples.string_contains_char_lean",
            {"std-lowering", "string-shape"},
        ),
    }
    for path, (source, features) in expected.items():
        fixture = load_json(path)
        require(fixture["kind"] == "positive", f"{path} must be positive")
        require(fixture["source"] == source, f"{path} must reference {source}")
        require(fixture["expected_status"] == "supported", f"{path} must be supported")
        require(
            set(fixture["required_features"]) == features,
            f"{path} must record required features {sorted(features)}",
        )
        require(
            "docs/STD_LOWERINGS.md" in fixture["documentation"],
            f"{path} must reference docs/STD_LOWERINGS.md",
        )


def check_docs() -> None:
    for path in [
        "docs/GENERICS.md", "docs/NUMERIC_SEMANTICS.md", "docs/DEPENDENT_ERASURE.md", "docs/RECURSIVE_DATA.md",
        "docs/OWNERSHIP.md", "docs/PATTERN_COMPILER.md", "docs/RECURSION_LOWERING.md", "docs/STD_LOWERINGS.md", "docs/TYPECLASSES.md",
    ]:
        text = read(path).lower()
        require("implementation requirements" in text, f"{path} must include implementation requirements")
        require("tests required" in text, f"{path} must include test requirements")
        require("documentation" in text or "document" in text, f"{path} must include documentation requirements")
    diagnostics = read("docs/DIAGNOSTICS.md")
    for idx in range(1, 15):
        code = f"LRC{idx:03d}"
        start = diagnostics.find(f"## {code}")
        require(start != -1, f"docs/DIAGNOSTICS.md missing section for {code}")
        next_start = diagnostics.find("\n## ", start + 1)
        section = diagnostics[start : next_start if next_start != -1 else len(diagnostics)]
        require("example" in section.lower(), f"docs/DIAGNOSTICS.md section for {code} needs an example")
        require("```lean" in section, f"docs/DIAGNOSTICS.md section for {code} needs a Lean example")
    for branch in EXTRACTOR_BRANCHES:
        require(branch in diagnostics, f"docs/DIAGNOSTICS.md must describe {branch}")
    generics = read("docs/GENERICS.md").lower()
    for phrase in ["multi-parameter", "nested", "dependent generic", "index-free", "lrc013"]:
        require(phrase in generics, f"docs/GENERICS.md missing phrase {phrase}")
    numerics = read("docs/NUMERIC_SEMANTICS.md")
    for phrase in ["checked_add_u32", "preconditioned_div_u32", "checked_cast_u64_to_u32"]:
        require(phrase in numerics, f"docs/NUMERIC_SEMANTICS.md missing phrase {phrase}")
    dependent = read("docs/DEPENDENT_ERASURE.md").lower()
    for phrase in ["equality cast", "sigma", "indexed family", "invariant runtime shape", "nested proof", "proof/index/runtime"]:
        require(phrase in dependent, f"docs/DEPENDENT_ERASURE.md missing phrase {phrase}")
    recursive = read("docs/RECURSIVE_DATA.md").lower()
    for phrase in ["direct recursion", "nested recursion", "mutual recursion", "cycle-breaking", "list/array/vec", "layout selection"]:
        require(phrase in recursive, f"docs/RECURSIVE_DATA.md missing phrase {phrase}")
    ownership = read("docs/OWNERSHIP.md").lower()
    for phrase in ["temporary shared operand borrows", "exact biguint/bigint arithmetic", "list_head_clone", "list_tail_clone", "no reference types", "no explicit lifetimes", "generated references do not escape"]:
        require(phrase in ownership, f"docs/OWNERSHIP.md missing phrase {phrase}")
    pattern = read("docs/PATTERN_COMPILER.md")
    for phrase in ["List.nil", "List.cons", "Nat.zero", "Nat.succ", "list_head_clone", "list_tail_clone", "as-pattern", "LRC006"]:
        require(phrase in pattern, f"docs/PATTERN_COMPILER.md missing phrase {phrase}")


def check_reports() -> None:
    validation = load_json("rust/validation-report.json")
    proof = load_json("rust/proof-report.json")
    coverage = load_json("rust/coverage-dashboard.json")
    checks = {check["name"] for check in validation.get("checks", [])}
    for check in [
        "next20-base-type-universe", "next20-parameterized-data", "next20-generic-policy",
        "next20-numeric-semantics", "next20-dependent-erasure", "next20-recursive-discovery",
        "next20-diagnostic-corpus", "ownership-reference-allowlist",
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
        "next20-diagnostic-corpus",
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
    facts = {fact["name"] for fact in proof.get("facts", [])}
    require(
        "ownership_policy_enforced_emission" in facts,
        "proof-report missing ownership_policy_enforced_emission fact",
    )


def check_scripts() -> None:
    for path in ["scripts/check.sh", "scripts/check-rust-validation.sh", "scripts/check-extractor-snapshot.sh"]:
        require("scripts/check-next-20-completion.py" in read(path), f"{path} missing next-20 gate")


def main() -> None:
    check_files()
    check_lean_modules()
    check_runtime_and_tests()
    check_diagnostic_corpus()
    check_parameterized_data_corpus()
    check_dependent_erasure_positive_corpus()
    check_recursive_positive_corpus()
    check_pattern_positive_corpus()
    check_std_positive_corpus()
    check_docs()
    check_reports()
    check_scripts()


if __name__ == "__main__":
    main()
