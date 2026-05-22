import LeanRustCore.Examples
import LeanRustCore.ChimeraBoundary
import LeanRustCore.Toolchain
import LeanRustCore.TargetValidation
import LeanRustCore.BoundaryExport
import LeanRustCore.Pattern
import LeanRustCore.RecursionLowering

import LeanRustCore.ClosureConversion
namespace LeanRustCore.ProofReport

/-- A compact proof-sidecar model for generated Rust artifacts. -/
structure ProofFact where
  name : String
  statement : String
  deriving Repr, BEq

private def joinWith (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

/-- Facts that are checked by importing/building the Lean modules. -/
def facts : List ProofFact := [
  { name := "extractor_reads_elaborated_definitions", statement := "rust_emit_exports collects @[rust_export] declarations and uses Lean constant bodies, not source-string matching" },
  { name := "surface_type_check", statement := "extracted SurfaceFun bodies are type-checked before Rust emission" },
  { name := "clamp_refines_spec", statement := "eval clampBody = clampSpec" },
  { name := "max_refines_spec", statement := "eval maxBody = maxSpec" },
  { name := "nonzero_refines_spec", statement := "eval nonzeroBody = nonzeroSpec" },
  { name := "add_refines_wrapping_spec", statement := "eval addBody = u32 wrapping-add spec" },
  { name := "bounded_bump_refines_spec", statement := "eval boundedBumpBody = let/arithmetic spec" },
  { name := "option_default_refines_spec", statement := "eval optionDefaultBody = Option-match spec" },
  { name := "fixed_width_type_extraction", statement := "rust_export extraction recognizes UInt32, UInt64, Int32, Int64, Unit, Option, Except, and simple closed enums; Nat-to-u32 lowering requires explicit rust_nat_wrapping_u32 opt-in" },
  { name := "match_lowering", statement := "Bool, Option, and closed enum matches, including payload variant binders, lower from elaborated recursor/casesOn forms" },
  { name := "struct_enum_declarations", statement := "SurfaceStruct and SurfaceEnum declarations are emitted before generated Rust functions" },
  { name := "expected_type_propagation", statement := "nested Option and Except constructors are checked with the Rust-facing expected type" },
  { name := "generic_monomorphization", statement := "rust_mono_export registers concrete type instantiations of generic Lean definitions and emits concrete Rust functions" },
  { name := "automatic_monomorphization", statement := "generic calls discovered inside concrete exported declarations enqueue and emit concrete monomorphized Rust functions" },
  { name := "phase_1_recursion_policy", statement := "the default direct Rust lane permits first-order generated call cycles; the surface evaluator bounds recursive calls with fuel" },
  { name := "parameterized_data_monomorphization", statement := "index-free parameterized structures and enums lower to concrete Rust declarations after substituting concrete type arguments" },
  { name := "standard_container_shapes", statement := "RType represents Char, String, List, Array, Prod, Sum, and unary function types with safe Rust type spellings" },
  { name := "standard_combinator_lowering", statement := "List, Array, Option, and Except combinators lower to checked loop or match SurfaceExpr nodes" },
  { name := "structural_recursion_loop_lowering", statement := "Nat.rec accumulator shapes and list folds lower to explicit safe Rust loops" },
  { name := "general_pattern_compiler", statement := "SurfacePattern and SurfaceExpr.matchPattern represent a checked general constructor-pattern fragment for Bool, Option, Prod, and closed enums" },
  { name := "tail_recursion_loop_lowering", statement := "recognized Nat accumulator tail recursion lowers to SurfaceExpr.tailRecNat and safe Rust while loops" },
  { name := "list_length_structural_lowering", statement := "List.length lowers to SurfaceExpr.listLength and Rust Vec::len in the owned List representation" },
  { name := "dependent_shape_erasure", statement := "Subtype, Fin, and Vector runtime shapes erase to safe Rust values with checked Fin/Vector constructor nodes" },
  { name := "structural_recursion_lowering", statement := "recognized List.map, List.foldl, and Nat.rec shapes lower to explicit safe Rust loop-shaped SurfaceExpr nodes" },
  { name := "exact_integer_modes", statement := "@[rust_nat_exact] and @[rust_int_exact] lower Lean Nat/Int boundaries to exact num_bigint BigUint/BigInt Rust values" },
  { name := "captured_closure_conversion", statement := "captured lambdas inside recognized structural combinators lower to loop bodies that close over ordinary Rust locals" },
  { name := "typeclass_dictionary_erasure", statement := LeanRustCore.TypeclassPolicy.typeclassPolicySummary },
  { name := "closure_conversion_policy", statement := LeanRustCore.ClosureConversion.closureConversionSummary },
  { name := "extract_ir_feature_tags", statement := LeanRustCore.ExtractIR.extractIRSummary },
  { name := "transitive_helper_extraction", statement := "first-order helper definitions reached from exported bodies are enqueued and emitted as auto-helper-export functions" },
  { name := "proof_erased_binders", statement := "conservative proof-shaped binders are erased from Rust signatures when their values are not used computationally" },
  { name := "limited_higher_order_function_pointer", statement := "unary function-typed arguments lower to Rust fn-pointer arguments and SurfaceExpr.callValue nodes" },

  { name := "std_library_lowering_table", statement := LeanRustCore.StdLowering.stdLoweringSummary },
  { name := "typeclass_specialization_policy", statement := LeanRustCore.TypeclassPolicy.typeclassPolicySummary },
  { name := "pure_monadic_do_lowering", statement := LeanRustCore.PureEffects.pureEffectsSummary },
  { name := "toolchain_pins", statement := "Lean and Rust toolchains are pinned exactly and checked before CI/release validation" },
  { name := "release_fallback_ban", statement := "checked-in generated.rs fallback is disabled for CI and release builds" },
  { name := "compatibility_reporting", statement := "unsupported tagged exports are skipped and recorded in a structured compatibility report" },
  { name := "payload_enum_branch_binders", statement := "payload enum pattern matching stores checked branch binders and emits Rust variant patterns" },
  { name := "first_order_function_calls", statement := "calls to other tagged first-order exports lower to checked SurfaceExpr.call nodes and Rust function calls" },
  { name := "surface_expr_evaluator", statement := "evalSurfaceFun interprets the checked SurfaceExpr subset used by the direct Lean-to-Rust emitter" },
  { name := "extracted_surface_artifact", statement := "rust_emit_exports_with_report_and_surface emits the same checked SurfaceFun list that generated Rust uses, and the differential suite consumes that artifact instead of hand-mirrored fixtures" },
  { name := "expanded_surface_differential", statement := "Lean-generated differential tests compute extracted struct, enum, Result, call, and monomorphization expectations with evalSurfaceFun" },
  { name := "rust_identifier_hygiene", statement := "validateSurfaceModuleHygiene rejects generated modules whose sanitized Rust identifiers collide" },
  { name := "syn_parser_backed_validation", statement := "rust/tests/parser_validation.rs parses generated.rs with syn and validates the approved top-level safe Rust subset" },
  { name := "json_artifact_parse_validation", statement := "rust/tests/validation_report.rs parses generated JSON artifacts and checks report counts against parsed generated Rust" },
  { name := "rust_to_target_ir_validation", statement := "rust/tests/semantic_validation.rs parses generated.rs, reconstructs target fingerprints, and compares them to LeanRustCore.TargetValidation.targetValidationSnapshot" },
  { name := "target_validation_snapshot", statement := "LeanRustCore.TargetValidation.targetValidationSnapshot is generated from the extractor-owned SurfaceFun artifact" },
  { name := "ffi_boundary_exporter", statement := "LeanRustCore.BoundaryExport.generatedBoundaryRust emits optional feature-gated raw ABI wrappers for primitive and Result<u32,u32> exports" },
  { name := "ffi_feature_isolation", statement := "raw ABI wrappers are isolated under the Rust ffi feature and are not emitted into rust/src/generated.rs" },
  { name := "rust_adapter_owned_rejected", statement := "owned Rust values cannot cross the raw FFI boundary" },
  { name := "result_u32_i32_lowering", statement := "Result<u32,i32> lowers to status plus two out parameters" }
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

private def factToJson (f : ProofFact) : String :=
  "    { \"name\": \"" ++ jsonEscape f.name ++ "\", \"statement\": \"" ++ jsonEscape f.statement ++ "\" }"

/-- JSON proof report emitted next to generated Rust. -/
def reportJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.proof-report.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": \"" ++ LeanRustCore.Toolchain.leanToolchain ++ "\",\n" ++
  "  \"rust_toolchain\": \"" ++ LeanRustCore.Toolchain.rustToolchain ++ "\",\n" ++
  "  \"trusted_core\": [\"Lean kernel\", \"LeanRustCore.Extract.extractConst\", \"LeanRustCore.Extract.extractWithDiagnostics\", \"LeanRustCore.Extract.extractPendingAutoHelpers\", \"LeanRustCore.Examples.extractedSurfaceFunctions\", \"LeanRustCore.Surface.typeOfExpected\", \"LeanRustCore.Surface.evalSurfaceFun\", \"LeanRustCore.RustHygiene.validateSurfaceModuleHygiene\", \"LeanRustCore.EmitRust.emitSurfaceRustModule\", \"LeanRustCore.TargetValidation.targetValidationSnapshot\", \"LeanRustCore.BoundaryExport.generatedBoundaryRust\", \"rust/tests/parser_validation.rs\", \"rust/tests/semantic_validation.rs\", \"rust/tests/target_interpreter.rs\", \"LeanRustCore.TypeclassPolicy.isSupportedErasedDictionaryType\", \"LeanRustCore.IR.eval\"],\n" ++
  "  \"policy\": {\n" ++
  "    \"generated_rust_unsafe\": false,\n" ++
  "    \"source_string_matching\": false,\n" ++
  "    \"ffi_result_lowering\": \"status-plus-out-params\",\n" ++
  "    \"native_rust_types_at_ffi\": false,\n" ++
  "    \"release_fallback_allowed\": false,\n" ++
  "    \"nat_to_u32_requires_opt_in\": true,\n" ++
  "    \"first_order_recursion_allowed\": true,\n" ++
  "    \"target_validation_snapshot\": \"" ++ LeanRustCore.TargetValidation.targetValidationFormat ++ "\",\n" ++
  "    \"ffi_wrappers_feature_gated\": true,\n" ++
  "    \"closure_conversion\": \"future-phase\"\n" ++
  "  },\n" ++
  "  \"facts\": [\n" ++
  joinWith ",\n" (facts.map factToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.ProofReport
