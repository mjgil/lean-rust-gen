import LeanRustCore.IR
import LeanRustCore.Surface
import LeanRustCore.Export
import LeanRustCore.EmitRust
import LeanRustCore.Extract
import LeanRustCore.Lowering
import LeanRustCore.ChimeraBoundary
import LeanRustCore.Examples
import LeanRustCore.ProofReport
import LeanRustCore.Differential
import LeanRustCore.RustValidation

/-!
# LeanRustCore

A self-contained direct **Lean emits Rust** workflow:

* ordinary Lean declarations are extracted from elaborated constant bodies,
* the extracted body lowers to a checked Rust-shaped surface IR,
* the emitter produces safe Rust source,
* the proof-carrying typed IR and checked surface evaluator provide semantic models for refinement tests,
* unsupported exports produce a structured compatibility report instead of aborting generation,
* Lean-generated differential tests compare evaluator results with emitted Rust,
* generated Rust validation reports and shell gates check the current safe subset,
* payload enum branches, first-order calls, structs, enums, Result, and monomorphized surface fixtures are covered by differential tests,
* a compact Chimera-inspired boundary model is retained only for later FFI edges.
-/
