import Lean

namespace LeanRustCore.ReleaseMatrix

/-!
Task 50 release acceptance matrix.

The release row is not complete unless every feature has implementation, tests,
documentation, generated artifact reproducibility, and safe-lane/FFI separation.
-/

structure ReleaseGate where
  name : String
  command : String
  requiredForRelease : Bool
  documentation : String
  deriving Repr, BEq

/-- Release gates required before claiming design-doc completion. -/
def gates : List ReleaseGate := [
  { name := "lean-build", command := "lake build", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#lean-build" },
  { name := "generated-snapshot", command := "scripts/check-extractor-snapshot.sh", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#generated-snapshot" },
  { name := "artifact-consistency", command := "scripts/check-artifact-consistency.py", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#artifact-consistency" },
  { name := "final-checklist", command := "scripts/check-final-16-completion.py", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#final-checklist" },
  { name := "cargo-workspace-test", command := "cargo test --workspace", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#cargo-workspace-test" },
  { name := "ffi-feature-test", command := "cargo test -p lean-rust-core-generated --features ffi", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#ffi-feature-test" },
  { name := "cargo-fmt", command := "cargo fmt --check --all", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#cargo-fmt" },
  { name := "cargo-clippy", command := "cargo clippy --workspace --all-targets -- -D warnings", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#cargo-clippy" },
  { name := "negative-corpus", command := "scripts/check-corpus-harness.sh", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#negative-corpus" },
  { name := "unsafe-default-lane", command := "scripts/check-rust-validation.sh", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#unsafe-default-lane" },
  { name := "toolchain-pins", command := "scripts/check-toolchain-pins.sh", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#toolchain-pins" },
  { name := "headers", command := "cargo test -p lean-rust-core-headers", requiredForRelease := true, documentation := "docs/RELEASE_CHECKLIST.md#headers" }
]

/-- Human-readable summary for validation/proof reports. -/
def releaseMatrixSummary : String :=
  "release acceptance matrix contains " ++ Nat.toString gates.length ++ " required gates covering Lean, generated artifacts, Rust workspace, FFI, diagnostics, docs, and headers"

end LeanRustCore.ReleaseMatrix
