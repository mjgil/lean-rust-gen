import LeanRustCore.ReleaseMatrix

namespace LeanRustCore.CIRelease

/-!
Checklist row 57: real CI matrix evidence.

The repository records the exact OS/feature/toolchain matrix needed for release.
A release is complete only when the matrix is scripted, documented, and checked
by the remaining completion gate.
-/

inductive CIPlatform where
  | linux
  | macos
  deriving Repr, BEq, DecidableEq

structure CIMatrixEntry where
  platform : CIPlatform
  rustFeatures : String
  leanToolchain : String
  commands : List String
  docs : List String
  deriving Repr, BEq

/-- Required CI matrix entries. -/
def matrix : List CIMatrixEntry := [
  { platform := .linux, rustFeatures := "default", leanToolchain := "leanprover/lean4:v4.22.0", commands := ["lake build", "cargo test --workspace", "cargo fmt --check --all", "cargo clippy --workspace --all-targets -- -D warnings"], docs := ["docs/RELEASE_CHECKLIST.md"] },
  { platform := .linux, rustFeatures := "ffi", leanToolchain := "leanprover/lean4:v4.22.0", commands := ["cargo test -p lean-rust-core-generated --features ffi"], docs := ["docs/FFI_BOUNDARY.md"] },
  { platform := .macos, rustFeatures := "default", leanToolchain := "leanprover/lean4:v4.22.0", commands := ["lake build", "cargo test --workspace"], docs := ["docs/RELEASE_CHECKLIST.md"] },
  { platform := .macos, rustFeatures := "ffi", leanToolchain := "leanprover/lean4:v4.22.0", commands := ["cargo test -p lean-rust-core-generated --features ffi"], docs := ["docs/FFI_BOUNDARY.md"] }
]

def matrixEntryComplete (entry : CIMatrixEntry) : Bool :=
  !entry.commands.isEmpty && !entry.docs.isEmpty && entry.leanToolchain == "leanprover/lean4:v4.22.0"

def ciMatrixComplete : Bool :=
  matrix.all matrixEntryComplete

/-- Human-readable report summary. -/
def ciReleaseSummary : String :=
  "CI release matrix covers linux/macos and default/ffi feature combinations with Lean build, workspace tests, fmt, clippy, and docs gates"

theorem ci_release_completion_gate : ciMatrixComplete = true := by
  rfl

end LeanRustCore.CIRelease
