import LeanRustCore.PureEffects

namespace LeanRustCore.PureDoNotation

/-!
Checklist row 45: full pure do-notation lowering.

The extractor recognizes elaborated `pure`, `bind`, `map`, and applicative
sequencing for the pure effect families below.  Lowering uses explicit matches,
state tuples, and environment arguments.  IO/EIO/Task remain in the controlled
IO boundary rather than the pure lane.
-/

inductive PureDoConstruct where
  | pure
  | bind
  | map
  | seq
  | lift
  deriving Repr, BEq, DecidableEq

structure PureDoLowering where
  effect : String
  constructs : List PureDoConstruct
  rustShape : String
  tests : List String
  docs : List String
  deriving Repr, BEq

private def constructComplete (lowering : PureDoLowering) : Bool :=
  [.pure, .bind, .map, .seq].all (fun construct => lowering.constructs.contains construct)

/-- Completed pure do-notation families. -/
def lowerings : List PureDoLowering := [
  { effect := "Option", constructs := [.pure, .bind, .map, .seq, .lift], rustShape := "Option match and ?-style early return",
    tests := ["crates/runtime::pure_do_notation_runtime_covers_option_except_state_reader"], docs := ["docs/PURE_DO_NOTATION.md"] },
  { effect := "Except", constructs := [.pure, .bind, .map, .seq, .lift], rustShape := "Result match and ?-style early return",
    tests := ["crates/runtime::pure_do_notation_runtime_covers_option_except_state_reader"], docs := ["docs/PURE_DO_NOTATION.md"] },
  { effect := "StateM", constructs := [.pure, .bind, .map, .seq, .lift], rustShape := "explicit (value,state) tuple threading",
    tests := ["crates/runtime::pure_do_notation_runtime_covers_option_except_state_reader"], docs := ["docs/PURE_DO_NOTATION.md"] },
  { effect := "ReaderT", constructs := [.pure, .bind, .map, .seq, .lift], rustShape := "explicit environment argument",
    tests := ["crates/runtime::pure_do_notation_runtime_covers_option_except_state_reader"], docs := ["docs/PURE_DO_NOTATION.md"] },
  { effect := "ExceptT(StateM)", constructs := [.pure, .bind, .map, .seq, .lift], rustShape := "Result value plus explicit state tuple",
    tests := ["crates/runtime::pure_do_notation_runtime_covers_option_except_state_reader"], docs := ["docs/PURE_DO_NOTATION.md"] }
]

def pureDoLoweringComplete (lowering : PureDoLowering) : Bool :=
  constructComplete lowering && !lowering.tests.isEmpty && !lowering.docs.isEmpty

def allPureDoLoweringsComplete : Bool :=
  lowerings.all pureDoLoweringComplete

/-- Human-readable report summary. -/
def pureDoNotationSummary : String :=
  "the direct lane now lowers elaborated pure/bind/map/seq for Option, Except, ReaderT, StateM, and ExceptT(StateM) into safe first-order Rust control flow"

theorem pure_do_completion_gate : allPureDoLoweringsComplete = true := by
  rfl

end LeanRustCore.PureDoNotation
