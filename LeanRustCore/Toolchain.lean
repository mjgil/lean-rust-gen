import LeanRustCore.EmitRust

namespace LeanRustCore.Toolchain

/-!
Pinned toolchain metadata for the direct Lean → Rust workflow.

The extractor reads elaborated Lean expressions, so exact Lean version pinning is
part of the semantic contract.  Rust is pinned for reproducible rustfmt/clippy,
parser-validation, and generated-code snapshots.
-/

def leanToolchain : String := "leanprover/lean4:v4.22.0"

def rustToolchain : String := "1.85.0"

def fallbackEnvVar : String := "LEAN_RUST_CORE_ALLOW_FALLBACK"

def fallbackPolicy : String :=
  "checked-in generated.rs fallback is allowed only for explicit local development builds; CI and release builds must run the Lean generator"

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

/-- JSON build metadata emitted by `lake exe gen_build_metadata`. -/
def buildMetadataJson : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.build-metadata.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"lean_toolchain\": " ++ jsonString leanToolchain ++ ",\n" ++
  "  \"rust_toolchain\": " ++ jsonString rustToolchain ++ ",\n" ++
  "  \"fallback_env_var\": " ++ jsonString fallbackEnvVar ++ ",\n" ++
  "  \"fallback_policy\": " ++ jsonString fallbackPolicy ++ ",\n" ++
  "  \"generated_artifacts\": [\n" ++
  "    \"rust/src/generated.rs\",\n" ++
  "    \"rust/proof-report.json\",\n" ++
  "    \"rust/compatibility-report.json\",\n" ++
  "    \"rust/tests/differential_generated.rs\",\n" ++
  "    \"rust/validation-report.json\",\n" ++
  "    \"rust/target-validation.txt\",\n" ++
  "    \"rust/extract-ir.txt\",\n" ++
  "    \"rust/src/ffi_generated.rs\",\n" ++
  "    \"rust/build-metadata.json\",\n" ++
  "    \"rust/coverage-dashboard.json\"\n" ++
  "  ],\n" ++
  "  \"workspace_crates\": [\n" ++
  "    \"lean-rust-core-generated\",\n" ++
  "    \"lean-rust-core-runtime\",\n" ++
  "    \"lean-rust-core-abi\",\n" ++
  "    \"lean-rust-core-validate\",\n" ++
  "    \"lean-rust-core-headers\"\n" ++
  "  ]\n" ++
  "}\n"

end LeanRustCore.Toolchain
