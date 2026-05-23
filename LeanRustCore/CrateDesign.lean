import Lean

namespace LeanRustCore.CrateDesign

/-!
Tasks 44-49 and 51-56 concrete Rust workspace design.

The generated safe API remains a crate named `lean-rust-core-generated`; shared
helpers, raw ABI, validation tooling, and header generation are split into
separate crates so unsafe boundary code and developer tooling cannot leak into
the default generated lane.
-/

inductive CrateKind where
  | generated
  | runtime
  | abi
  | validate
  | headers
  deriving Repr, BEq, DecidableEq

structure WorkspaceCrate where
  package : String
  path : String
  kind : CrateKind
  allowsUnsafe : Bool
  publicApi : String
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

/-- Final Rust workspace crate split required for design-doc completion. -/
def workspaceCrates : List WorkspaceCrate := [
  { package := "lean-rust-core-generated", path := "rust", kind := .generated, allowsUnsafe := false,
    publicApi := "generated safe Rust functions/types plus minimal runtime reexports",
    requiredTests := ["parser_validation", "semantic_validation", "differential_generated", "property_validation"],
    requiredDocs := ["rust/README.md", "docs/CRATE_DESIGN.md"] },
  { package := "lean-rust-core-runtime", path := "crates/runtime", kind := .runtime, allowsUnsafe := false,
    publicApi := "exact/numeric/container/closure/dictionary helper semantics",
    requiredTests := ["runtime unit tests", "runtime property seeds"],
    requiredDocs := ["crates/runtime/README.md", "docs/CRATE_DESIGN.md"] },
  { package := "lean-rust-core-abi", path := "crates/abi", kind := .abi, allowsUnsafe := true,
    publicApi := "ChStatus, opaque handles, destructor policy, raw ABI helpers",
    requiredTests := ["ffi handle lifecycle", "null out-param", "double-drop"],
    requiredDocs := ["crates/abi/README.md", "docs/FFI_BOUNDARY.md"] },
  { package := "lean-rust-core-validate", path := "crates/validate", kind := .validate, allowsUnsafe := false,
    publicApi := "report parsing, syn validation helpers, target snapshot validation",
    requiredTests := ["valid report", "malformed report", "target mismatch"],
    requiredDocs := ["crates/validate/README.md", "docs/SEMANTIC_VALIDATION.md"] },
  { package := "lean-rust-core-headers", path := "crates/headers", kind := .headers, allowsUnsafe := false,
    publicApi := "C header generation with ownership annotations",
    requiredTests := ["header contains ABI symbols", "ownership comments"],
    requiredDocs := ["crates/headers/README.md", "docs/FFI_BOUNDARY.md"] }
]

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Human-readable summary for validation/proof reports. -/
def crateDesignSummary : String :=
  "Rust workspace split: " ++ joinWithLocal ", " (workspaceCrates.map (fun c => c.package ++ "@" ++ c.path))

end LeanRustCore.CrateDesign
