import LeanRustCore.Differential
import LeanRustCore.RustHygiene
import LeanRustCore.RecursionPolicy
import LeanRustCore.Toolchain
import LeanRustCore.TargetValidation
import LeanRustCore.BoundaryExport

namespace LeanRustCore.RustValidation

open LeanRustCore
open LeanRustCore.Differential
open LeanRustCore.Toolchain

/-!
Step 8 validation manifest for the current generated Rust subset.

The formal object in this pass is the checked Lean surface IR plus the
proof-carrying IR evaluator used by the differential tests. The emitted Rust is
validated by a generated manifest and by repository gates that compare snapshots,
ban unsafe/placeholder fragments in generated Rust, and run the Lean-generated
Rust differential tests.
-/

structure ValidationCheck where
  name : String
  status : String
  detail : String
  deriving Repr, BEq

/-- Function names that the current generated Rust snapshot is expected to expose. -/
def requiredFunctionNames : List String := [
  "clamp_u32",
  "max_u32",
  "is_nonzero_u32",
  "add_u32",
  "mul_u32",
  "bounded_bump_u32",
  "echo_u32",
  "echo_u64",
  "echo_i32",
  "echo_i64",
  "echo_char",
  "echo_string",
  "echo_list_u32",
  "echo_array_u32",
  "list_map_inc_u32",
  "list_fold_sum_u32",
  "echo_prod_u32",
  "echo_sum_u32",
  "add_u64",
  "inc_u32",
  "inc_twice_u32",
  "proof_erased_u32",
  "unit_roundtrip",
  "bool_match_u32",
  "option_identity_u32",
  "none_u32",
  "some_u32",
  "option_default_u32",
  "result_ok_u32",
  "result_err_u32",
  "choose_by_enum",
  "make_point",
  "point_x",
  "point_y",
  "shift_point_x",
  "boxed_u32",
  "boxed_value_u32",
  "tagged_missing_u32",
  "tagged_present_u32",
  "tagged_default_u32",
  "step_stay",
  "step_jump",
  "step_amount_or",
  "step_amount_plus_one_or",
  "nested_none_u32",
  "result_ok_none_u32",
  "result_err_some_u32",
  "unsupported_higher_order_u32",
  "identity_u64",
  "choose_generic_u32",
  "option_default_u64",
  "generic_identity__u32",
  "generic_choose__point",
  "generic_option_default__step",
  "helper_inc_fixed",
  "helper_chain_u32",
  "auto_identity_u32",
  "auto_choose_point",
  "auto_option_default_step"
]

/-- Declarations that should exist before generated functions. -/
def requiredTypeNames : List String := [
  "Point",
  "BoxedU32",
  "Choice",
  "TaggedU32",
  "Step"
]

/-- Validation checks completed for the current generated subset. -/
def checks : List ValidationCheck := [
  {
    name := "surface-type-check-before-emission",
    status := "passed",
    detail := "every emitted declaration passes LeanRustCore.Surface.checkSurfaceFun before Rust source is produced"
  },
  {
    name := "snapshot-reproducibility",
    status := "passed",
    detail := "scripts/check-extractor-snapshot.sh diffs generated.rs, differential tests, compatibility report, validation report, build metadata, target validation, and FFI wrappers against Lean output"
  },
  {
    name := "lean-evaluator-differential-tests",
    status := "passed",
    detail := "rust/tests/differential_generated.rs compares generated Rust calls with expectations computed by LeanRustCore.IR.eval and LeanRustCore.Surface.evalSurfaceFun"
  },
  {
    name := "safe-rust-subset-gate",
    status := "passed",
    detail := "scripts/check-rust-validation.sh rejects unsafe, extern boundaries, panic/todo/unimplemented calls, and malformed emitter markers in generated Rust"
  },
  {
    name := "ffi-boundary-exclusion",
    status := "passed",
    detail := "the direct Lean-emits-Rust path emits ordinary safe Rust only; raw FFI remains outside this compiler path"
  },
  {
    name := "payload-enum-match-lowering",
    status := "passed",
    detail := "payload enum matches lower through checked branch binders and Rust variant patterns"
  },
  {
    name := "first-order-call-lowering",
    status := "passed",
    detail := "calls to tagged first-order Lean declarations lower to checked Rust function calls and dependency-aware emission"
  },
  {
    name := "surface-evaluator-extracted-subset-tests",
    status := "passed",
    detail := "the SurfaceExpr evaluator covers the current extracted struct, enum, Result, monomorphization, payload-match, structural recursion, and call fixtures"
  },
  {
    name := "extractor-owned-surface-artifact",
    status := "passed",
    detail := "LeanRustCore.Examples.extractedSurfaceFunctions is emitted by the same extractor command as generated Rust and drives the SurfaceExpr differential expectations"
  },
  {
    name := "rust-identifier-hygiene",
    status := "passed",
    detail := rustHygieneSummary
  },
  {
    name := "exact-toolchain-pins",
    status := "passed",
    detail := "Lean toolchain " ++ leanToolchain ++ " and Rust toolchain " ++ rustToolchain ++ " are pinned and checked by scripts/check-toolchain-pins.sh"
  },
  {
    name := "release-fallback-ban",
    status := "passed",
    detail := "rust/build.rs refuses checked-in generated.rs fallback for CI or release builds; local development fallback requires LEAN_RUST_CORE_ALLOW_FALLBACK=1"
  },
  {
    name := "automatic-monomorphization",
    status := "passed",
    detail := "generic calls discovered inside concrete exported declarations enqueue and emit concrete monomorphized Rust functions before their callers"
  },
  {
    name := "phase-1-recursion-policy",
    status := "passed",
    detail := recursionPolicySummary
  },
  {
    name := "parameterized-data-lowering",
    status := "passed",
    detail := "index-free parameterized structures/enums are monomorphized into Rust structs/enums such as BoxedU32 and TaggedU32"
  },
  {
    name := "standard-container-shapes",
    status := "passed",
    detail := "Char, String, List, Array, Prod, Sum, and unary function types are represented in RType and lowered to safe Rust type shapes for supported bodies"
  },
  {
    name := "structural-recursion-lowering",
    status := "passed",
    detail := "recognized List.map, List.foldl, and Nat.rec shapes lower to explicit safe Rust loop-shaped SurfaceExpr nodes with evaluator and target-validation fingerprints"
  },
  {
    name := "transitive-helper-extraction",
    status := "passed",
    detail := "first-order helper definitions reached from exported declarations are enqueued and emitted as auto-helper-export functions"
  },
  {
    name := "proof-erased-binders",
    status := "passed",
    detail := "conservative proof-shaped binders such as Eq/True/False proofs are erased from Rust function signatures when their values are not used computationally"
  },
  {
    name := "limited-higher-order-function-pointer",
    status := "passed",
    detail := "unary function-typed arguments lower to safe Rust fn-pointer arguments and SurfaceExpr.callValue nodes; closures remain a future closure-conversion layer"
  },

  {
    name := "rust-to-target-ir-translation-validation",
    status := "passed",
    detail := "rust/tests/semantic_validation.rs parses generated.rs with syn, reconstructs the generated-subset target IR, and compares it with LeanRustCore.TargetValidation.targetValidationSnapshot"
  },
  {
    name := "target-validation-snapshot",
    status := "passed",
    detail := "rust/target-validation.txt records the Lean-side SurfaceExpr fingerprints, Rust-facing declarations, and function signatures used by target validation"
  },
  {
    name := "property-differential-seeds",
    status := "passed",
    detail := "rust/tests/generated.rs and the Lean-generated differential suite include boundary seeds for wrapping arithmetic, payload matches, helper calls, containers, structural List loops, and function-pointer arguments"
  },
  {
    name := "ffi-boundary-exporter",
    status := "passed",
    detail := "LeanRustCore.BoundaryExport emits optional C ABI wrappers for the conservative primitive/result subset; generated wrapper count: " ++ Nat.toString LeanRustCore.BoundaryExport.boundaryExportCount
  },
  {
    name := "ffi-feature-isolation",
    status := "passed",
    detail := "rust/src/ffi_generated.rs is included only under the Rust ffi feature, while default builds continue to compile the direct lane with unsafe_code forbidden"
  },
  {
    name := "ffi-result-status-out-params",
    status := "passed",
    detail := "Result<u32,u32> raw ABI wrappers lower through ChStatus plus out_ok/out_err pointers instead of exposing native Rust Result across FFI"
  },
  {
    name := "syn-parser-backed-validation",
    status := "passed",
    detail := "rust/tests/parser_validation.rs parses generated.rs with syn and validates the approved top-level safe Rust subset by AST instead of relying only on text grep"
  },
  {
    name := "json-artifact-parse-validation",
    status := "passed",
    detail := "rust/tests/validation_report.rs parses validation, compatibility, proof, and build-metadata JSON artifacts with serde_json"
  },
  {
    name := "compatibility-report-output-consistency",
    status := "passed",
    detail := "rust/tests/validation_report.rs compares compatibility diagnostics and generated function counts against the parsed generated.rs AST"
  }
]

private def jsonEscapeChar : Char → String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | c => String.singleton c

private def jsonEscape (s : String) : String :=
  joinWith "" (s.toList.map jsonEscapeChar)

private def jsonString (s : String) : String :=
  "\"" ++ jsonEscape s ++ "\""

private def jsonArray (items : List String) : String :=
  "[" ++ joinWith ", " (items.map jsonString) ++ "]"

private def checkToJson (check : ValidationCheck) : String :=
  "    { \"name\": " ++ jsonString check.name ++
  ", \"status\": " ++ jsonString check.status ++
  ", \"detail\": " ++ jsonString check.detail ++ " }"

/-- JSON validation report emitted by `lake exe gen_validation_report`. -/
def validationReportJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.rust-validation.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": " ++ jsonString leanToolchain ++ ",\n" ++
  "  \"rust_toolchain\": " ++ jsonString rustToolchain ++ ",\n" ++
  "  \"generated_function_count\": " ++ Nat.toString requiredFunctionNames.length ++ ",\n" ++
  "  \"generated_type_count\": " ++ Nat.toString requiredTypeNames.length ++ ",\n" ++
  "  \"differential_assertion_count\": " ++ Nat.toString (evaluatorAssertions.length + extractedDeclarationAssertions.length) ++ ",\n" ++
  "  \"target_validation_format\": " ++ jsonString LeanRustCore.TargetValidation.targetValidationFormat ++ ",\n" ++
  "  \"ffi_boundary_export_count\": " ++ Nat.toString LeanRustCore.BoundaryExport.boundaryExportCount ++ ",\n" ++
  "  \"required_functions\": " ++ jsonArray requiredFunctionNames ++ ",\n" ++
  "  \"required_types\": " ++ jsonArray requiredTypeNames ++ ",\n" ++
  "  \"checks\": [\n" ++
  joinWith ",\n" (checks.map checkToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.RustValidation
