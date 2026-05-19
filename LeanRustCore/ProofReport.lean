import LeanRustCore.Examples
import LeanRustCore.ChimeraBoundary

namespace LeanRustCore.ProofReport

/-- A compact proof-sidecar model for generated Rust artifacts. -/
structure ProofFact where
  name : String
  statement : String
  deriving Repr, BEq

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
  { name := "fixed_width_type_extraction", statement := "rust_export extraction recognizes UInt32, UInt64, Int32, Int64, Unit, Option, Except, and simple closed enums" },
  { name := "match_lowering", statement := "Bool, Option, and closed enum matches, including payload variant binders, lower from elaborated recursor/casesOn forms" },
  { name := "struct_enum_declarations", statement := "SurfaceStruct and SurfaceEnum declarations are emitted before generated Rust functions" },
  { name := "expected_type_propagation", statement := "nested Option and Except constructors are checked with the Rust-facing expected type" },
  { name := "generic_monomorphization", statement := "rust_mono_export registers concrete type instantiations of generic Lean definitions and emits concrete Rust functions" },
  { name := "compatibility_reporting", statement := "unsupported tagged exports are skipped and recorded in a structured compatibility report" },
  { name := "payload_enum_branch_binders", statement := "payload enum pattern matching stores checked branch binders and emits Rust variant patterns" },
  { name := "first_order_function_calls", statement := "calls to other tagged first-order exports lower to checked SurfaceExpr.call nodes and Rust function calls" },
  { name := "rust_adapter_owned_rejected", statement := "owned Rust values cannot cross the raw FFI boundary" },
  { name := "result_u32_i32_lowering", statement := "Result<u32,i32> lowers to status plus two out parameters" }
]

private def jsonEscape (s : String) : String :=
  -- First pass: generated names/statements are ASCII and controlled.
  s

private def factToJson (f : ProofFact) : String :=
  "    { \"name\": \"" ++ jsonEscape f.name ++ "\", \"statement\": \"" ++ jsonEscape f.statement ++ "\" }"

private def joinWith (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

/-- JSON proof report emitted next to generated Rust. -/
def reportJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.proof-report.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"trusted_core\": [\"Lean kernel\", \"LeanRustCore.Extract.extractConst\", \"LeanRustCore.Extract.extractWithDiagnostics\", \"LeanRustCore.Surface.typeOfExpected\", \"LeanRustCore.EmitRust.emitSurfaceRustModule\", \"LeanRustCore.IR.eval\"],\n" ++
  "  \"policy\": {\n" ++
  "    \"generated_rust_unsafe\": false,\n" ++
  "    \"source_string_matching\": false,\n" ++
  "    \"ffi_result_lowering\": \"status-plus-out-params\",\n" ++
  "    \"native_rust_types_at_ffi\": false\n" ++
  "  },\n" ++
  "  \"facts\": [\n" ++
  joinWith ",\n" (facts.map factToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.ProofReport
