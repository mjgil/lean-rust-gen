#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

generated="rust/src/generated.rs"
validation_report="rust/validation-report.json"
differential_tests="rust/tests/differential_generated.rs"
parser_validation_tests="rust/tests/parser_validation.rs"
build_metadata="rust/build-metadata.json"

required_files=("$generated" "$validation_report" "$differential_tests" "$parser_validation_tests" "$build_metadata")
for path in "${required_files[@]}"; do
  test -f "$path"
done

# The direct Lean-emits-Rust lane should emit ordinary safe Rust only. Raw FFI
# wrappers stay out of this path until an explicit boundary exporter is added.
! grep -n -E '(^|[^A-Za-z0-9_])unsafe([^A-Za-z0-9_]|$)|extern "C"|panic!|todo!|unimplemented!|/\* malformed|unsupported wrapping op' "$generated"

grep -q '"format": "lean-rust-core.rust-validation.v1"' "$validation_report"
grep -q '"architecture": "direct-lean-emits-rust"' "$validation_report"
grep -q '"name": "lean-evaluator-differential-tests"' "$validation_report"
grep -q '"name": "safe-rust-subset-gate"' "$validation_report"
grep -q '"name": "rust-identifier-hygiene"' "$validation_report"
grep -q '"name": "syn-parser-backed-validation"' "$validation_report"
grep -q '"name": "payload-enum-match-lowering"' "$validation_report"
grep -q '"name": "first-order-call-lowering"' "$validation_report"
grep -q '"name": "surface-evaluator-extracted-subset-tests"' "$validation_report"
grep -q '"name": "extractor-owned-surface-artifact"' "$validation_report"
grep -q '"name": "extractor-owned-surface-artifact"' "$validation_report"
grep -q '"name": "exact-toolchain-pins"' "$validation_report"
grep -q '"name": "release-fallback-ban"' "$validation_report"
grep -q '"name": "automatic-monomorphization"' "$validation_report"
grep -q '"name": "phase-1-recursion-policy"' "$validation_report"
grep -q '"name": "parameterized-data-lowering"' "$validation_report"
grep -q '"name": "standard-container-shapes"' "$validation_report"
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
grep -q 'helper_chain_u32(40)' "$differential_tests"
grep -q 'echo_prod_u32((5, 6))' "$differential_tests"
grep -q 'echo_sum_u32(Ok(7))' "$differential_tests"
grep -q 'boxed_u32(9)' "$differential_tests"
grep -q 'tagged_default_u32(TaggedU32::Present' "$differential_tests"

# Parser-backed validation is enforced by rust/tests/parser_validation.rs during cargo test.
grep -q 'syn::parse_file' "$parser_validation_tests"
grep -q 'parser_validates_generated_top_level_subset' "$parser_validation_tests"
grep -q 'parser_rejects_raw_boundary_or_panic_constructs' "$parser_validation_tests"

# Build metadata records exact pins and release fallback policy.
grep -q '"format": "lean-rust-core.build-metadata.v1"' "$build_metadata"
grep -q '"lean_toolchain": "leanprover/lean4:v4.22.0"' "$build_metadata"
grep -q '"rust_toolchain": "1.85.0"' "$build_metadata"
grep -q 'LEAN_RUST_CORE_ALLOW_FALLBACK' "$build_metadata"

# The Rust build script must not silently fallback in release/CI.
grep -q 'development_fallback_allowed' rust/build.rs
grep -q 'PROFILE' rust/build.rs
grep -q 'CI' rust/build.rs
grep -q 'LEAN_RUST_CORE_ALLOW_FALLBACK' rust/build.rs
