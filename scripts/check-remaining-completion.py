#!/usr/bin/env python3
"""Checklist rows 41-63 completion checks."""
from __future__ import annotations

import json
import os
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
        "LeanRustCore/TypeclassDictionaries.lean",
        "LeanRustCore/TypeclassDictionaryExamples.lean",
        "LeanRustCore/FirstClassClosures.lean",
        "LeanRustCore/ClosureLoweringExamples.lean",
        "LeanRustCore/PureDoNotation.lean",
        "LeanRustCore/IOBoundary.lean",
        "LeanRustCore/CompleteSemantics.lean",
        "LeanRustCore/Preservation.lean",
        "LeanRustCore/PropertyGenerators.lean",
        "LeanRustCore/CoverageCompletion.lean",
        "LeanRustCore/CIRelease.lean",
        "LeanRustCore/Publishing.lean",
        "LeanRustCore/RemainingCompletion.lean",
        "scripts/check-ci-e2e.sh",
        "docs/TYPECLASS_DICTIONARIES.md",
        "docs/FIRST_CLASS_CLOSURES.md",
        "docs/CLOSURE_CONVERSION.md",
        "docs/PURE_DO_NOTATION.md",
        "docs/IO_BOUNDARY.md",
        "docs/SEMANTICS.md",
        "docs/PRESERVATION.md",
        "docs/PROPERTY_GENERATORS.md",
        "docs/COVERAGE_COMPLETION.md",
        "docs/PUBLISHING.md",
        "CHANGELOG.md",
        "rust/tests/remaining_completion.rs",
        "rust/tests/closure_lowering.rs",
        "rust/tests/typeclass_dictionaries.rs",
        "rust/tests/target_interpreter.rs",
        "corpus/positive/generated_dict_beq.expected.json",
        "corpus/positive/generated_dict_compare.expected.json",
        "corpus/positive/generated_dict_add.expected.json",
        "corpus/positive/generated_dict_default.expected.json",
        "corpus/positive/generated_dict_to_string.expected.json",
        "corpus/positive/stored_closure_apply.expected.json",
        "corpus/positive/returned_closure_apply.expected.json",
        "corpus/positive/passed_closure_apply.expected.json",
        "corpus/positive/stored_multi_closure_apply.expected.json",
        "corpus/positive/returned_multi_closure_apply.expected.json",
        "corpus/positive/passed_multi_closure_apply.expected.json",
        "corpus/positive/option_seq_right.expected.json",
        "corpus/positive/option_seq_left.expected.json",
        "corpus/positive/except_seq_right.expected.json",
        "corpus/positive/except_seq_left.expected.json",
        "corpus/positive/reader_do_add.expected.json",
        "corpus/positive/reader_seq_right.expected.json",
        "corpus/positive/reader_seq_left.expected.json",
        "corpus/positive/state_do_tick.expected.json",
        "corpus/positive/state_seq_right.expected.json",
        "corpus/positive/state_seq_left.expected.json",
    ]
    for path in required:
        require((ROOT / path).exists(), f"missing remaining-completion artifact {path}")
    require(
        os.access(ROOT / "scripts/check-ci-e2e.sh", os.X_OK),
        "scripts/check-ci-e2e.sh must be executable",
    )


def check_lean_modules() -> None:
    expectations = {
        "LeanRustCore/TypeclassDictionaries.lean": [
            "dictionaryShapes",
            "generatedDictionaryHelpers",
            "generatedDictionaryExports",
            "AddDictU32",
            "allDictionariesComplete",
            "dictionary_completion_gate",
        ],
        "LeanRustCore/FirstClassClosures.lean": ["closureObjects", "StoredClosureU32", "allClosureObjectsComplete", "closure_object_completion_gate"],
        "LeanRustCore/PureDoNotation.lean": ["ExceptT(StateM)", "allPureDoLoweringsComplete", "pure_do_completion_gate"],
        "LeanRustCore/IOBoundary.lean": ["ControlledIOOp", "allIOPoliciesComplete", "io_boundary_completion_gate"],
        "LeanRustCore/CompleteSemantics.lean": ["TargetGrammarHead", "TargetValue", "TargetTerm", "evalTargetTerm", "representativeSemanticChecks", "semanticCoverageComplete", "complete_semantics_completion_gate"],
        "LeanRustCore/Preservation.lean": [
            "PreservationSeam",
            "preservationLemmasComplete",
            "preservationSkeletonComplete",
            "extraction_metadata_preserved",
            "dependent_erasure_runtime_carriers_preserved",
            "checked_surface_typing_preserved",
            "checked_surface_evaluation_preserved",
            "target_lowering_snapshot_preserved",
            "safe_subset_emission_preserved",
            "emitted_subset_target_semantics_preserved",
            "preservation_lemmas_completion_gate",
            "preservation_skeleton_completion_gate",
        ],
        "LeanRustCore/PropertyGenerators.lean": ["GeneratorFamily", "allGeneratorsComplete", "property_generators_completion_gate"],
        "LeanRustCore/CoverageCompletion.lean": ["CoverageDenominator", "coverageCompletionComplete", "coverage_completion_gate"],
        "LeanRustCore/CIRelease.lean": ["CIMatrixEntry", "macos", "ci_release_completion_gate"],
        "LeanRustCore/Publishing.lean": ["PublishCratePolicy", "cargo publish --dry-run", "publishing_completion_gate"],
        "LeanRustCore/RemainingCompletion.lean": ["rows", "allRemainingComplete", "remaining_completion_gate", "row := 63"],
    }
    for path, needles in expectations.items():
        text = read(path)
        for needle in needles:
            require(needle in text, f"{path} missing {needle}")

    imports = read("LeanRustCore.lean")
    for module in [
        "TypeclassDictionaries",
        "FirstClassClosures",
        "PureDoNotation",
        "IOBoundary",
        "CompleteSemantics",
        "Preservation",
        "PropertyGenerators",
        "CoverageCompletion",
        "CIRelease",
        "Publishing",
        "RemainingCompletion",
    ]:
        require(f"import LeanRustCore.{module}" in imports, f"LeanRustCore.lean missing import {module}")


def check_rust_runtime_and_validate() -> None:
    runtime = "\n".join(
        [
            read("crates/runtime/src/lib.rs"),
            read("crates/runtime/src/property_generators.rs"),
        ]
    )
    for needle in [
        "pub struct AddDictU32",
        "pub struct StoredClosureU32",
        "pub enum ControlledIoOp",
        "pub struct ControlledIoProgram",
        "pub enum RuntimeValueCase",
        "generate_runtime_value_cases",
        "shrink_runtime_value_case",
        "minimize_runtime_value_case",
        "option_result_do_runtime",
        "except_state_do_runtime",
        "scalar_property_values_u32",
        "generated_dictionary_structs_are_first_order",
        "first_class_closure_objects_can_be_returned_stored_and_composed",
        "pure_do_notation_runtime_covers_option_except_state_reader",
        "controlled_io_boundary_is_transcript_based",
        "property_generators_cover_scalars_and_containers",
    ]:
        require(needle in runtime, f"runtime crate missing {needle}")

    validate = "\n".join(
        [
            read("crates/validate/src/lib.rs"),
            read("crates/validate/src/target_semantics.rs"),
            read("crates/validate/src/property_generators.rs"),
        ]
    )
    for needle in [
        "pub enum TargetValue",
        "pub enum TargetTerm",
        "eval_target_term",
        "target_grammar_heads",
        "generate_target_term_cases",
        "shrink_target_term",
        "minimize_target_term",
        "generated_subset_semantics_interprets_core_terms",
        "generated_subset_semantics_interprets_representative_values",
        "target_grammar_heads_are_complete",
    ]:
        require(needle in validate, f"validate crate missing {needle}")

    remaining_test = read("rust/tests/remaining_completion.rs")
    dictionary_test = read("rust/tests/typeclass_dictionaries.rs")
    target_interpreter = read("rust/tests/target_interpreter.rs")
    for needle in [
        "remaining_rows_reports_and_dashboard_are_complete",
        "remaining_runtime_features_are_exercised",
        "remaining_pure_do_generated_examples_cover_bind_and_seq_shapes",
        "remaining_source_level_closure_lowerings_are_exercised",
        "remaining_validate_semantics_cover_representative_values",
        "remaining_property_generators_are_randomized_and_shrinkable",
        "dictionary_add_u32",
        "closure_apply_stored",
        "ControlledIoProgram",
    ]:
        require(needle in remaining_test, f"remaining completion test missing {needle}")
    for needle in [
        "generated_dictionary_exports_use_runtime_dictionary_values",
        "generated_rust_snapshot_mentions_dictionary_constants_and_helpers",
        "generated_dict_beq_u32",
        "generated_dict_compare_u32",
        "crate::runtime::BEQ_U32",
        "crate::runtime::TO_STRING_U32",
    ]:
        require(needle in dictionary_test, f"typeclass dictionary test missing {needle}")
    for needle in [
        "generated_subset_semantics_are_executable_for_every_emitted_function",
        "dispatch_compiled_function",
        "sample_args_for",
        "parse_snapshot_functions",
    ]:
        require(
            needle in target_interpreter,
            f"target interpreter exhaustive coverage missing {needle}",
        )

    closure_test = read("rust/tests/closure_lowering.rs")
    for needle in [
        "source_level_closure_lowerings_cover_stored_returned_passed_and_multiarg_cases",
        "stored_closure_apply_u32",
        "returned_closure_apply_u32",
        "passed_closure_apply_u32",
        "stored_multi_closure_apply_u32",
        "returned_multi_closure_apply_u32",
        "passed_multi_closure_apply_u32",
    ]:
        require(needle in closure_test, f"closure lowering test missing {needle}")

    abi = "\n".join(
        [
            read("crates/abi/src/lib.rs"),
            read("crates/abi/src/property_generators.rs"),
        ]
    )
    for needle in [
        "HandleTraceOp",
        "generate_handle_traces",
        "shrink_handle_trace",
        "minimize_handle_trace",
        "randomized_handle_generators_cover_lifecycle_traces",
        "handle_trace_minimizer_prefers_short_lifecycle_counterexamples",
    ]:
        require(needle in abi, f"abi crate missing {needle}")


def check_reports_and_dashboard() -> None:
    validation = json_file("rust/validation-report.json")
    proof = json_file("rust/proof-report.json")
    coverage = json_file("rust/coverage-dashboard.json")

    check_names = {check["name"] for check in validation.get("checks", [])}
    for name in [
        "remaining-typeclass-dictionaries",
        "remaining-first-class-closures",
        "remaining-pure-do-notation",
        "remaining-controlled-io-boundary",
        "remaining-complete-generated-semantics",
        "remaining-preservation-proved-lemmas",
        "remaining-property-generators",
        "remaining-feature-complete-coverage",
        "remaining-ci-release-matrix",
        "remaining-publishing-versioning",
        "remaining-completion-gate",
    ]:
        require(name in check_names, f"validation report missing {name}")

    policy = proof.get("policy", {})
    for key in [
        "generated_typeclass_dictionaries_complete",
        "first_class_closure_objects_complete",
        "pure_do_notation_complete",
        "controlled_io_boundary_complete",
        "complete_generated_subset_semantics",
        "preservation_skeleton_complete",
        "property_generators_complete",
        "feature_complete_coverage_dashboard",
        "ci_release_matrix_complete",
        "publishing_versioning_complete",
        "remaining_completion_rows_41_63",
    ]:
        require(policy.get(key) is True, f"proof policy missing {key}")

    fact_names = {fact["name"] for fact in proof.get("facts", [])}
    for name in [
        "extraction_metadata_preserved",
        "dependent_erasure_runtime_carriers_preserved",
        "checked_surface_typing_preserved",
        "checked_surface_evaluation_preserved",
        "target_lowering_snapshot_preserved",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
    ]:
        require(name in fact_names, f"proof report missing preservation fact {name}")

    metrics = {metric["denominator"]: metric for metric in coverage.get("metrics", [])}
    for denominator in [
        "checklist_rows_41_63",
        "generated_subset_semantics_heads",
        "preservation_obligations",
        "lean_feature_families",
        "rust_target_grammar_heads",
        "property_generators",
    ]:
        require(denominator in metrics, f"coverage dashboard missing {denominator}")
        require(metrics[denominator]["percent"] == 100, f"coverage denominator {denominator} is not 100 percent")

    entries = {entry["feature"] for entry in coverage.get("entries", [])}
    for feature in [
        "remaining-typeclass-dictionaries",
        "remaining-first-class-closures",
        "remaining-pure-do-notation",
        "remaining-controlled-io-boundary",
        "remaining-complete-semantics",
        "remaining-preservation-proved-lemmas",
        "remaining-property-generators",
        "remaining-feature-complete-dashboard",
        "remaining-ci-release-matrix",
        "remaining-publishing-versioning",
        "remaining-completion-rows-41-63",
    ]:
        require(feature in entries, f"coverage dashboard missing feature {feature}")


def check_dictionary_docs_and_corpus() -> None:
    docs = read("docs/TYPECLASS_DICTIONARIES.md")
    for needle in [
        "generated_dict_beq_u32",
        "generated_dict_compare_u32",
        "apply_beq_dict_u32",
        "closed monomorphic dictionary arguments",
    ]:
        require(needle in docs, f"docs/TYPECLASS_DICTIONARIES.md missing {needle}")

    helper_examples = read("LeanRustCore/TypeclassDictionaryExamples.lean")
    exported_examples = read("LeanRustCore/Examples.lean")
    for needle in [
        "apply_beq_dict_u32",
        "apply_compare_dict_u32",
        "apply_add_dict_u32",
        "apply_default_dict_u32",
        "apply_to_string_dict_u32",
    ]:
        require(needle in helper_examples, f"LeanRustCore/TypeclassDictionaryExamples.lean missing {needle}")

    for needle in [
        "generated_dict_beq_u32",
        "generated_dict_compare_u32",
        "generated_dict_add_u32",
        "generated_dict_default_u32",
        "generated_dict_to_string_u32",
    ]:
        require(needle in exported_examples, f"LeanRustCore/Examples.lean missing {needle}")

    for fixture_name in [
        "generated_dict_beq.expected.json",
        "generated_dict_compare.expected.json",
        "generated_dict_add.expected.json",
        "generated_dict_default.expected.json",
        "generated_dict_to_string.expected.json",
    ]:
        fixture = json_file(f"corpus/positive/{fixture_name}")
        require(fixture.get("expected_status") == "supported", f"{fixture_name} must be supported")
        require(
            "remaining-typeclass-dictionaries" in fixture.get("tests", []),
            f"{fixture_name} missing remaining-typeclass-dictionaries test tag",
        )
        require(
            "docs/TYPECLASS_DICTIONARIES.md" in fixture.get("documentation", []),
            f"{fixture_name} missing typeclass dictionary docs",
        )


def check_closure_docs_and_corpus() -> None:
    docs = read("docs/FIRST_CLASS_CLOSURES.md")
    conversion = read("docs/CLOSURE_CONVERSION.md")
    for needle in [
        "stored_closure_apply_u32",
        "returned_closure_apply_u32",
        "passed_closure_apply_u32",
        "stored_multi_closure_apply_u32",
        "returned_multi_closure_apply_u32",
        "passed_multi_closure_apply_u32",
    ]:
        require(needle in docs, f"docs/FIRST_CLASS_CLOSURES.md missing {needle}")
        require(needle in conversion, f"docs/CLOSURE_CONVERSION.md missing {needle}")

    exported_examples = read("LeanRustCore/Examples.lean")
    helper_examples = read("LeanRustCore/ClosureLoweringExamples.lean")
    for needle in [
        "stored_closure_apply_u32",
        "returned_closure_apply_u32",
        "passed_closure_apply_u32",
        "stored_multi_closure_apply_u32",
        "returned_multi_closure_apply_u32",
        "passed_multi_closure_apply_u32",
    ]:
        require(needle in exported_examples, f"LeanRustCore/Examples.lean missing {needle}")
    for needle in [
        "apply_closure_u32",
        "make_add_delta_u32",
        "apply_binary_closure_u32",
        "make_add_pair_u32",
    ]:
        require(needle in helper_examples, f"LeanRustCore/ClosureLoweringExamples.lean missing {needle}")

    for fixture_name in [
        "stored_closure_apply.expected.json",
        "returned_closure_apply.expected.json",
        "passed_closure_apply.expected.json",
        "stored_multi_closure_apply.expected.json",
        "returned_multi_closure_apply.expected.json",
        "passed_multi_closure_apply.expected.json",
    ]:
        fixture = json_file(f"corpus/positive/{fixture_name}")
        require(fixture.get("expected_status") == "supported", f"{fixture_name} must be supported")
        require(
            "scripts/check-remaining-completion.py" in fixture.get("tests", []),
            f"{fixture_name} missing remaining completion gate",
        )
        require(
            "docs/CLOSURE_CONVERSION.md" in fixture.get("documentation", []),
            f"{fixture_name} missing closure conversion docs",
        )


def check_pure_do_docs_and_corpus() -> None:
    docs = read("docs/PURE_DO_NOTATION.md")
    architecture = read("docs/ARCHITECTURE.md")
    exported_examples = read("LeanRustCore/Examples.lean")
    for needle in [
        "option_do_inc_u32",
        "except_do_inc_u32",
        "option_seq_right_u32",
        "option_seq_left_u32",
        "except_seq_right_u32",
        "except_seq_left_u32",
        "reader_do_add_u32",
        "reader_seq_right_u32",
        "reader_seq_left_u32",
        "state_do_tick_u32",
        "state_seq_right_u32",
        "state_seq_left_u32",
        "except_state_do_u32",
        "except_state_seq_right_u32",
        "except_state_seq_left_u32",
        "ReaderT",
        "StateM",
        "ExceptT(StateM)",
        "SeqRight.seqRight",
        "SeqLeft.seqLeft",
    ]:
        require(needle in docs or needle in architecture or needle in exported_examples, f"pure-do coverage missing {needle}")

    for fixture_name in [
        "option_seq_right.expected.json",
        "option_seq_left.expected.json",
        "except_seq_right.expected.json",
        "except_seq_left.expected.json",
        "reader_do_add.expected.json",
        "reader_seq_right.expected.json",
        "reader_seq_left.expected.json",
        "state_do_tick.expected.json",
        "state_seq_right.expected.json",
        "state_seq_left.expected.json",
        "except_state_do.expected.json",
        "except_state_seq_right.expected.json",
        "except_state_seq_left.expected.json",
    ]:
        fixture = json_file(f"corpus/positive/{fixture_name}")
        require(fixture.get("expected_status") == "supported", f"{fixture_name} must be supported")
        require(
            "scripts/check-remaining-completion.py" in fixture.get("tests", []),
            f"{fixture_name} missing remaining completion gate",
        )
        require(
            "docs/PURE_DO_NOTATION.md" in fixture.get("documentation", []),
            f"{fixture_name} missing pure-do docs",
        )


def check_docs_and_release() -> None:
    for path in [
        "docs/TYPECLASS_DICTIONARIES.md",
        "docs/FIRST_CLASS_CLOSURES.md",
        "docs/CLOSURE_CONVERSION.md",
        "docs/PURE_DO_NOTATION.md",
        "docs/IO_BOUNDARY.md",
        "docs/SEMANTICS.md",
        "docs/PRESERVATION.md",
        "docs/PROPERTY_GENERATORS.md",
        "docs/COVERAGE_COMPLETION.md",
        "docs/PUBLISHING.md",
    ]:
        text = read(path).lower()
        require("test" in text or "tests" in text, f"{path} must mention tests")
        require("complete" in text or "completion" in text, f"{path} must mention completion")

    semantics = read("docs/SEMANTICS.md")
    for needle in [
        "every emitted function",
        "supported executable value domain",
        "match_pattern",
        "BinaryTreeU32",
        "fn(u32) -> u32",
    ]:
        require(needle in semantics, f"docs/SEMANTICS.md missing {needle}")

    preservation = read("docs/PRESERVATION.md")
    for needle in [
        "extraction_metadata_preserved",
        "dependent_erasure_runtime_carriers_preserved",
        "checked_surface_typing_preserved",
        "checked_surface_evaluation_preserved",
        "target_lowering_snapshot_preserved",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
        "proved Lean theorems",
    ]:
        require(needle in preservation, f"docs/PRESERVATION.md missing {needle}")

    trusted_core = read("docs/TRUSTED_CORE.md")
    for needle in [
        "proved Lean theorems",
        "regression-tested facts",
        "safe_subset_emission_preserved",
        "emitted_subset_target_semantics_preserved",
    ]:
        require(needle in trusted_core, f"docs/TRUSTED_CORE.md missing {needle}")

    workflow = read(".github/workflows/ci.yml")
    ci_script = read("scripts/check-ci-e2e.sh")
    require("ubuntu-latest" in workflow and "macos-latest" in workflow, "CI workflow must cover linux and macos")
    require("rust_features" in workflow and "ffi" in workflow, "CI workflow must cover ffi feature")
    require(
        "./scripts/check-ci-e2e.sh ${{ matrix.rust_features }}" in workflow,
        "CI workflow missing scripted lane runner",
    )
    require("./scripts/check.sh" in ci_script, "CI lane helper must run the full release gate")
    require(
        "cargo test --workspace --features ffi" in ci_script,
        "CI lane helper must run the ffi workspace lane",
    )

    release = read("docs/RELEASE_CHECKLIST.md")
    require("check-remaining-completion.py" in release, "release docs missing remaining gate")
    require("cargo publish --dry-run -p lean-rust-core-generated" in release, "release docs missing publish dry-run")

    for path in [
        "rust/Cargo.toml",
        "crates/runtime/Cargo.toml",
        "crates/abi/Cargo.toml",
        "crates/validate/Cargo.toml",
        "crates/headers/Cargo.toml",
    ]:
        text = read(path)
        for needle in ["version = \"0.2.0\"", "rust-version = \"1.85\"", "readme = \"README.md\"", "documentation = "]:
            require(needle in text, f"{path} missing publishing metadata {needle}")

    require((ROOT / "CHANGELOG.md").exists(), "missing changelog")


def check_scripts() -> None:
    for path in ["scripts/check.sh", "scripts/check-rust-validation.sh", "scripts/check-extractor-snapshot.sh"]:
        text = read(path)
        require("scripts/check-remaining-completion.py" in text, f"{path} missing remaining completion gate")


def main() -> None:
    check_required_files()
    check_lean_modules()
    check_rust_runtime_and_validate()
    check_reports_and_dashboard()
    check_dictionary_docs_and_corpus()
    check_closure_docs_and_corpus()
    check_pure_do_docs_and_corpus()
    check_docs_and_release()
    check_scripts()


if __name__ == "__main__":
    main()
