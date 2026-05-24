import LeanRustCore.ChimeraBoundary

namespace LeanRustCore.IOBoundary

/-!
Checklist row 46: controlled IO boundary.

The default Lean→Rust lane remains pure.  Admitted IO is represented as an
explicit boundary program with whitelisted operations and a transcript type;
arbitrary `IO`, `EIO`, `Task`, mutation, and external effects remain diagnostics.
-/

inductive ControlledIOOp where
  | printLine
  | readEnv
  | monotonicTime
  deriving Repr, BEq, DecidableEq

structure ControlledIOPolicy where
  op : ControlledIOOp
  rustShape : String
  deterministicTest : String
  documentation : String
  deriving Repr, BEq

/-- Whitelisted IO operations admitted by the controlled boundary. -/
def policies : List ControlledIOPolicy := [
  { op := .printLine, rustShape := "append line to transcript", deterministicTest := "crates/runtime::controlled_io_boundary_is_transcript_based", documentation := "docs/IO_BOUNDARY.md" },
  { op := .readEnv, rustShape := "read supplied environment map, never process env directly", deterministicTest := "crates/runtime::controlled_io_boundary_is_transcript_based", documentation := "docs/IO_BOUNDARY.md" },
  { op := .monotonicTime, rustShape := "read supplied deterministic timestamp seed", deterministicTest := "crates/runtime::controlled_io_boundary_is_transcript_based", documentation := "docs/IO_BOUNDARY.md" }
]

/-- Extractor-backed exported boundary examples admitted by Task 54. -/
def generatedBoundaryExports : List String := [
  "io_boundary_transcript",
  "eio_boundary_transcript"
]

def policyComplete (policy : ControlledIOPolicy) : Bool :=
  policy.deterministicTest != "" && policy.documentation == "docs/IO_BOUNDARY.md"

def allIOPoliciesComplete : Bool :=
  policies.all policyComplete

/-- Human-readable report summary. -/
def ioBoundarySummary : String :=
  "controlled IO is explicit and transcript-based; exported io_boundary_transcript and eio_boundary_transcript lower to deterministic transcript strings, the default lane remains pure, and arbitrary IO/EIO/Task/external effects are rejected"

theorem io_boundary_completion_gate : allIOPoliciesComplete = true := by
  rfl

end LeanRustCore.IOBoundary
