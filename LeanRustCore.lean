import LeanRustCore.IR
import LeanRustCore.Surface
import LeanRustCore.Export
import LeanRustCore.RustHygiene
import LeanRustCore.ExtractIR
import LeanRustCore.ClosureConversion
import LeanRustCore.PureEffects
import LeanRustCore.StdLowering
import LeanRustCore.TypeclassPolicy
import LeanRustCore.Defunctionalization
import LeanRustCore.DependentErasure
import LeanRustCore.EmitRust
import LeanRustCore.Extract
import LeanRustCore.ParameterizedExamples
import LeanRustCore.Lowering
import LeanRustCore.ChimeraBoundary
import LeanRustCore.Examples
import LeanRustCore.TargetValidation
import LeanRustCore.BoundaryExport
import LeanRustCore.RecursionPolicy
import LeanRustCore.Pattern
import LeanRustCore.RecursionLowering
import LeanRustCore.RecursiveData
import LeanRustCore.ProofReport
import LeanRustCore.Differential
import LeanRustCore.RustValidation
import LeanRustCore.Toolchain
import LeanRustCore.ValidationV2
import LeanRustCore.PropertyCorpus
import LeanRustCore.CoverageDashboard
import LeanRustCore.Diagnostics
import LeanRustCore.SurfaceCoverage
import LeanRustCore.CrateDesign
import LeanRustCore.ReleaseMatrix
import LeanRustCore.TypeclassSpecialization
import LeanRustCore.DependentErasureChecker
import LeanRustCore.GenericPolicy
import LeanRustCore.ParameterizedData
import LeanRustCore.GenericEmission
import LeanRustCore.NumericSemantics
import LeanRustCore.RecursiveDiscovery
import LeanRustCore.OwnershipPolicy
import LeanRustCore.PatternMatrix
import LeanRustCore.RecursionAnalysis
import LeanRustCore.StdImplementation
import LeanRustCore.TypeclassDictionaries
import LeanRustCore.FirstClassClosures
import LeanRustCore.PureDoNotation
import LeanRustCore.IOBoundary
import LeanRustCore.CompleteSemantics
import LeanRustCore.Preservation
import LeanRustCore.PropertyGenerators
import LeanRustCore.CoverageCompletion
import LeanRustCore.CIRelease
import LeanRustCore.Publishing
import LeanRustCore.RemainingCompletion

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
* phase-3 target validation compares Lean surface fingerprints with parsed Rust AST fingerprints,
* phase-4 raw ABI wrappers are emitted only in a feature-gated boundary module,
* payload enum branches, first-order calls, structs, enums, Result, parameterized data, containers, and monomorphized extracted surface artifacts are covered by differential tests,
* Lean `Nat` to Rust `u32` requires explicit wrapping opt-in at exported boundaries,
* first-order helper extraction, conservative proof erasure, unary Rust `fn` pointer arguments, explicit closure-converted environments, finite defunctionalized function cases, completed numeric semantics, parameterized-data monomorphization, dependent-shape erasure, recursive Box/Rc/arena layout policy, ownership/borrowing policy, pattern-matrix and recursion-analysis metadata, full Std lowering metadata, generated dictionaries, first-class closure objects, pure do-notation, controlled IO boundary, complete target semantics, preservation skeleton, real property generators, feature-complete coverage, CI release matrix, publishing metadata, validation-v2 coverage metadata, deterministic property seeds, stable diagnostics, workspace crate design, and release-matrix metadata support the phase-2 large-subset slice,
* a compact Chimera-inspired boundary model and feature-gated raw ABI exporter cover the optional boundary lane.
-/
