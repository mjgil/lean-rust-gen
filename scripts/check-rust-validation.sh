#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

generated="rust/src/generated.rs"
validation_report="rust/validation-report.json"
differential_tests="rust/tests/differential_generated.rs"
parser_validation_tests="rust/tests/parser_validation.rs"
build_metadata="rust/build-metadata.json"
target_validation="rust/target-validation.txt"
semantic_validation_tests="rust/tests/semantic_validation.rs"
target_interpreter_tests="rust/tests/target_interpreter.rs"
ffi_generated="rust/src/ffi_generated.rs"
ffi_boundary_tests="rust/tests/ffi_boundary.rs"

required_files=("$generated" "$validation_report" "$differential_tests" "$parser_validation_tests" "$semantic_validation_tests" "$target_interpreter_tests" "$target_validation" "$ffi_generated" "$ffi_boundary_tests" "$build_metadata")
for path in "${required_files[@]}"; do
  test -f "$path"
done

./scripts/check-corpus-harness.sh
./scripts/check-artifact-consistency.py

python3 - <<'PY'
import json
import pathlib

for path in [
    "rust/validation-report.json",
    "rust/compatibility-report.json",
    "rust/proof-report.json",
    "rust/build-metadata.json",
]:
    json.loads(pathlib.Path(path).read_text())
PY

# The direct Lean-emits-Rust lane should emit ordinary safe Rust only. Raw FFI
# wrappers are generated separately under rust/src/ffi_generated.rs and stay out of this path.
! grep -n -E '(^|[^A-Za-z0-9_])unsafe([^A-Za-z0-9_]|$)|extern "C"|panic!|todo!|unimplemented!|/\* malformed|unsupported wrapping op' "$generated"

grep -q '"format": "lean-rust-core.rust-validation.v1"' "$validation_report"
grep -q 'lean-rust-core.feature-tags.v1' rust/compatibility-report.json
grep -q '"features"' rust/compatibility-report.json
grep -q '"next_feature"' rust/compatibility-report.json
grep -q '"architecture": "direct-lean-emits-rust"' "$validation_report"
grep -q '"name": "lean-evaluator-differential-tests"' "$validation_report"
grep -q '"name": "safe-rust-subset-gate"' "$validation_report"
grep -q '"name": "rust-identifier-hygiene"' "$validation_report"
grep -q '"name": "syn-parser-backed-validation"' "$validation_report"
grep -q '"name": "json-artifact-parse-validation"' "$validation_report"
grep -q '"name": "compatibility-report-output-consistency"' "$validation_report"
grep -q '"name": "payload-enum-match-lowering"' "$validation_report"
grep -q '"name": "general-pattern-compiler"' "$validation_report"
grep -q '"name": "constructor-pattern-rust-emission"' "$validation_report"
grep -q '"name": "first-order-call-lowering"' "$validation_report"
grep -q '"name": "surface-evaluator-extracted-subset-tests"' "$validation_report"
grep -q '"name": "extractor-owned-surface-artifact"' "$validation_report"
grep -q '"name": "exact-toolchain-pins"' "$validation_report"
grep -q '"name": "release-fallback-ban"' "$validation_report"
grep -q '"name": "automatic-monomorphization"' "$validation_report"
grep -q '"name": "rust-to-target-ir-translation-validation"' "$validation_report"
grep -q '"name": "target-validation-snapshot"' "$validation_report"
grep -q '"name": "property-differential-seeds"' "$validation_report"
grep -q '"name": "ffi-boundary-exporter"' "$validation_report"
grep -q '"name": "ffi-feature-isolation"' "$validation_report"
grep -q '"name": "ffi-result-status-out-params"' "$validation_report"
grep -q '"name": "phase-1-recursion-policy"' "$validation_report"
grep -q '"name": "parameterized-data-lowering"' "$validation_report"
grep -q '"name": "standard-container-shapes"' "$validation_report"
grep -q '"name": "standard-combinator-lowering"' "$validation_report"
grep -q '"name": "structural-recursion-lowering"' "$validation_report"
grep -q '"name": "tail-recursion-loop-lowering"' "$validation_report"
grep -q '"name": "list-length-structural-lowering"' "$validation_report"
grep -q '"name": "dependent-shape-erasure"' "$validation_report"
grep -q '"name": "exact-integer-modes"' "$validation_report"
grep -q '"name": "captured-closure-conversion"' "$validation_report"
grep -q '"name": "typeclass-dictionary-erasure"' "$validation_report"
grep -q '"name": "target-fingerprint-interpreter"' "$validation_report"
grep -q '"name": "transitive-helper-extraction"' "$validation_report"
grep -q '"name": "proof-erased-binders"' "$validation_report"
grep -q '"name": "limited-higher-order-function-pointer"' "$validation_report"
grep -q '"lean_toolchain": "leanprover/lean4:v4.22.0"' "$validation_report"
grep -q '"rust_toolchain": "1.85.0"' "$validation_report"
! grep -q '"status": "failed"' "$validation_report"

grep -q 'LeanRustCore.Differential' "$differential_tests"
grep -q 'lean_ir_evaluator_matches_generated_rust' "$differential_tests"
grep -q 'surface_evaluator_matches_extracted_rust' "$differential_tests"
grep -q 'add_u32(u32::MAX, 1)' "$differential_tests"
grep -q 'step_amount_or(Step::Jump(12), 9)' "$differential_tests"
grep -q 'inc_twice_u32(u32::MAX)' "$differential_tests"
grep -q 'auto_identity_u32(12)' "$differential_tests"
grep -q 'auto_choose_point(false' "$differential_tests"
grep -q 'auto_option_default_step(Some(Step::Stay)' "$differential_tests"
grep -q 'make_point(3, 4)' "$differential_tests"
grep -q 'result_err_some_u32(44)' "$differential_tests"
grep -q 'echo_string(String::from' "$differential_tests"
grep -q 'list_map_inc_u32(vec!' "$differential_tests"
grep -q 'list_fold_sum_u32(vec!' "$differential_tests"
grep -q 'helper_chain_u32(40)' "$differential_tests"
grep -q 'echo_prod_u32((5, 6))' "$differential_tests"
grep -q 'echo_sum_u32(Ok(7))' "$differential_tests"
grep -q 'boxed_u32(9)' "$differential_tests"
grep -q 'tagged_default_u32(TaggedU32::Present' "$differential_tests"
grep -q 'general_bool_match_u32(true' "$differential_tests"
grep -q 'general_option_match_u32(Some' "$differential_tests"
grep -q 'general_step_match_u32(Step::Jump' "$differential_tests"
grep -q 'pair_sum_match_u32(40, 2)' "$differential_tests"
grep -q 'list_length_u32(vec!' "$differential_tests"
grep -q 'tail_sum_down_u32(5)' "$differential_tests"

# Target translation validation compares the Lean-side snapshot to a parsed Rust AST fingerprint.
grep -q 'FORMAT[[:space:]]lean-rust-core.target-validation.v2' "$target_validation"
grep -q '^TYPE[[:space:]]struct[[:space:]]BoxedU32' "$target_validation"
grep -q '^FN[[:space:]]unsupported_higher_order_u32' "$target_validation"
grep -q 'call_value(var(f),var(x))' "$target_validation"
grep -q '^FN[[:space:]]list_map_inc_u32' "$target_validation"
grep -q 'list_map(x,var(xs),add(var(x),lit(1)))' "$target_validation"
grep -q '^FN[[:space:]]list_fold_sum_u32' "$target_validation"
grep -q 'list_foldl(acc,x,lit(0),var(xs),add(var(acc),var(x)))' "$target_validation"
grep -q '^FN[[:space:]]general_bool_match_u32' "$target_validation"
grep -q 'match_pattern(var(flag),true=>add(var(when_true),lit(1))|false=>add(var(when_false),lit(1)))' "$target_validation"
grep -q '^FN[[:space:]]list_length_u32' "$target_validation"
grep -q 'list_length(var(xs))' "$target_validation"
grep -q '^FN[[:space:]]tail_sum_down_u32' "$target_validation"
grep -q 'tail_rec_nat(k,acc,var(n),lit(0),add(var(acc),var(k)))' "$target_validation"
grep -q 'target_validation_snapshot_matches_generated_rust_ast' "$semantic_validation_tests"
grep -q 'syn::parse_file' "$semantic_validation_tests"

# Parser-backed validation is enforced by rust/tests/parser_validation.rs during cargo test.
grep -q 'decidable_eq_u32(7, 7)' "$differential_tests"
grep -q 'ord_compare_u32(1, 2)' "$differential_tests"
grep -q 'option_do_inc_u32(Some(41))' "$differential_tests"
grep -q 'closure_apply_capture_u32(5, 37)' "$differential_tests"
grep -q 'syn::parse_file' "$parser_validation_tests"
grep -q 'parser_validates_generated_top_level_subset' "$parser_validation_tests"
grep -q 'parser_rejects_raw_boundary_or_panic_constructs' "$parser_validation_tests"

# Optional raw ABI wrappers are present but isolated from the default safe direct-emission lane.
grep -q '#\[cfg(feature = "ffi")\]' rust/src/lib.rs
grep -q 'ffi = \[\]' rust/Cargo.toml
grep -q 'extern "C" fn lrc_add_u32' "$ffi_generated"
grep -q 'unsafe extern "C" fn lrc_result_ok_u32' "$ffi_generated"
grep -q 'lower_result_u32_u32' rust/src/abi.rs
grep -q 'lrc_result_err_u32' "$ffi_boundary_tests"
grep -q 'lrc_nat_sum_to_u32' "$ffi_generated"
grep -q 'lrc_fin_val10_u32' "$ffi_generated"
grep -q 'lrc_general_bool_match_u32' "$ffi_generated"
grep -q 'lrc_pair_sum_match_u32' "$ffi_generated"
grep -q 'lrc_tail_sum_down_u32' "$ffi_generated"

# Build metadata records exact pins and release fallback policy.
grep -q '"format": "lean-rust-core.build-metadata.v1"' "$build_metadata"
grep -q '"lean_toolchain": "leanprover/lean4:v4.22.0"' "$build_metadata"
grep -q '"rust_toolchain": "1.85.0"' "$build_metadata"
grep -q 'LEAN_RUST_CORE_ALLOW_FALLBACK' "$build_metadata"
grep -q 'rust/target-validation.txt' "$build_metadata"
grep -q 'rust/src/ffi_generated.rs' "$build_metadata"

# The Rust build script must not silently fallback in release/CI.
grep -q 'development_fallback_allowed' rust/build.rs
grep -q 'PROFILE' rust/build.rs
grep -q 'CI' rust/build.rs
grep -q 'LEAN_RUST_CORE_ALLOW_FALLBACK' rust/build.rs
grep -q 'extern "C" fn lrc_decidable_eq_u32' "$ffi_generated"
grep -q 'extern "C" fn lrc_closure_apply_capture_u32' "$ffi_generated"
