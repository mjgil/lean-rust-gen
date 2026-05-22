import LeanRustCore.Surface

namespace LeanRustCore.PureEffects

/-!
Sprint 9 pure-effect policy.

`do` notation elaborates to `pure`/`bind`; the extractor recognizes the
monomorphic pure effect shells below and lowers them to explicit safe Rust
control flow.  The default lane still rejects `IO`, `EIO`, tasks, mutation
through references, and arbitrary external effects.
-/

inductive PureEffect where
  | option
  | except
  | state
  | reader
  deriving Repr, BEq, DecidableEq

def supportedEffects : List PureEffect := [
  .option, .except, .state, .reader
]

def effectName : PureEffect → String
  | .option => "Option"
  | .except => "Except"
  | .state => "StateM"
  | .reader => "ReaderT"

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- Human-readable summary included in validation/proof reports. -/
def pureEffectsSummary : String :=
  "Sprint 9 lowers pure do-notation for " ++
  joinWithLocal ", " (supportedEffects.map effectName) ++
  " into matches, explicit state tuples, or explicit environment arguments; IO remains outside the safe direct lane"

end LeanRustCore.PureEffects
