#!/usr/bin/env python3
"""Repository-local generated-artifact consistency checks.

This uses only Python's standard library so Sprint-1 sanity checks can run before
Rust/Cargo or Lean/Lake are available.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text()


def generated_symbols() -> tuple[list[str], list[str]]:
    source = read("rust/src/generated.rs")
    functions = re.findall(r"^pub fn ([A-Za-z_][A-Za-z0-9_]*)", source, re.MULTILINE)
    types = re.findall(r"^pub (?:struct|enum) ([A-Za-z_][A-Za-z0-9_]*)", source, re.MULTILINE)
    return functions, types


def load_json(path: str) -> object:
    try:
        return json.loads(read(path))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"{path} is not valid JSON: {exc}") from exc


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def check_json_artifacts(functions: list[str], types: list[str]) -> None:
    validation = load_json("rust/validation-report.json")
    compatibility = load_json("rust/compatibility-report.json")
    proof = load_json("rust/proof-report.json")
    metadata = load_json("rust/build-metadata.json")
    coverage = load_json("rust/coverage-dashboard.json")

    require(validation["generated_function_count"] == len(functions), "validation-report function count is stale")
    require(validation["generated_type_count"] == len(types), "validation-report type count is stale")
    require(validation["required_functions"] == functions, "validation-report required_functions differs from generated.rs order")
    require(validation["required_types"] == types, "validation-report required_types differs from generated.rs order")
    require(validation["target_validation_format"] == "lean-rust-core.target-validation.v2", "validation report target format is stale")
    require("feature_summary" in validation, "validation report is missing Sprint-2 feature_summary")
    require(coverage["target_validation_format"] == "lean-rust-core.target-validation.v2", "coverage dashboard target format is stale")

    supported = [d["rust_name"] for d in compatibility["diagnostics"] if d["code"] == "supported"]
    require(compatibility["generated_function_count"] == len(functions), "compatibility-report function count is stale")
    require(supported == functions, "compatibility-report supported diagnostics differ from generated.rs order")
    for diagnostic in compatibility["diagnostics"]:
        require("features" in diagnostic, f"compatibility diagnostic {diagnostic.get('rust_name')} lacks features")
        require("next_feature" in diagnostic, f"compatibility diagnostic {diagnostic.get('rust_name')} lacks next_feature")

    require("LeanRustCore.ExtractIR.functionFeatures" in proof["trusted_core"], "proof report missing ExtractIR trusted-core entry")
    require(proof["policy"].get("corpus_harness") is True, "proof report missing corpus_harness policy")
    require("rust/target-validation.txt" in metadata["generated_artifacts"], "build metadata missing target validation artifact")
    require("rust/coverage-dashboard.json" in metadata["generated_artifacts"], "build metadata missing coverage dashboard artifact")


def check_target_validation(functions: list[str], types: list[str]) -> None:
    lines = read("rust/target-validation.txt").splitlines()
    require(lines[:2] == ["FORMAT\tlean-rust-core.target-validation.v2", "ARCH\tdirect-lean-emits-rust"], "target-validation header is stale")
    require(sum(1 for line in lines if line.startswith("TYPE_COUNT\t")) == 1, "target-validation should contain one TYPE_COUNT")
    require(sum(1 for line in lines if line.startswith("FN_COUNT\t")) == 1, "target-validation should contain one FN_COUNT")
    type_count = int(next(line.split("\t", 1)[1] for line in lines if line.startswith("TYPE_COUNT\t")))
    fn_count = int(next(line.split("\t", 1)[1] for line in lines if line.startswith("FN_COUNT\t")))
    type_lines = [line for line in lines if line.startswith("TYPE\t")]
    fn_lines = [line for line in lines if line.startswith("FN\t")]
    require(type_count == len(types) == len(type_lines), "target-validation type count is stale")
    require(fn_count == len(functions) == len(fn_lines), "target-validation function count is stale")
    require([line.split("\t")[2] for line in type_lines] == types, "target-validation type order differs from generated.rs")
    require([line.split("\t")[1] for line in fn_lines] == functions, "target-validation function order differs from generated.rs")


def check_ffi() -> None:
    ffi = read("rust/src/ffi_generated.rs")
    wrappers = re.findall(r"^pub (?:unsafe )?extern \"C\" fn (lrc_[A-Za-z_][A-Za-z0-9_]*)", ffi, re.MULTILINE)
    validation = load_json("rust/validation-report.json")
    require(validation["ffi_boundary_export_count"] == len(wrappers), "validation-report FFI wrapper count is stale")
    for required in ["lrc_nat_sum_to_u32", "lrc_subtype_val_u32", "lrc_fin_val10_u32", "lrc_decidable_eq_u32", "lrc_closure_apply_capture_u32", "lrc_general_bool_match_u32", "lrc_pair_sum_match_u32", "lrc_tail_sum_down_u32"]:
        require(required in wrappers, f"missing FFI wrapper {required}")


def main() -> None:
    functions, types = generated_symbols()
    check_json_artifacts(functions, types)
    check_target_validation(functions, types)
    check_ffi()


if __name__ == "__main__":
    main()
