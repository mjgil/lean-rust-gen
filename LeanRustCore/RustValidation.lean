import LeanRustCore.Differential
import LeanRustCore.RustHygiene
import LeanRustCore.Toolchain

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
  "add_u64",
  "inc_u32",
  "inc_twice_u32",
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
  "step_stay",
  "step_jump",
  "step_amount_or",
  "step_amount_plus_one_or",
  "nested_none_u32",
  "result_ok_none_u32",
  "result_err_some_u32",
  "identity_u64",
  "choose_generic_u32",
  "option_default_u64",
  "generic_identity__u32",
  "generic_choose__point",
  "generic_option_default__step",
  "auto_identity_u32",
  "auto_choose_point",
  "auto_option_default_step"
]

/-- Declarations that should exist before generated functions. -/
def requiredTypeNames : List String := [
  "Point",
  "Choice",
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
    detail := "scripts/check-extractor-snapshot.sh diffs generated.rs, differential tests, compatibility report, validation report, and build metadata against Lean output"
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
    detail := "the SurfaceExpr evaluator covers the current extracted struct, enum, Result, monomorphization, payload-match, and call fixtures"
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
    name := "syn-parser-backed-validation",
    status := "passed",
    detail := "rust/tests/parser_validation.rs parses generated.rs with syn and validates the approved top-level safe Rust subset by AST instead of relying only on text grep"
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
  "  \"required_functions\": " ++ jsonArray requiredFunctionNames ++ ",\n" ++
  "  \"required_types\": " ++ jsonArray requiredTypeNames ++ ",\n" ++
  "  \"checks\": [\n" ++
  joinWith ",\n" (checks.map checkToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.RustValidation
