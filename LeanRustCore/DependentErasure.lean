import Lean
import LeanRustCore.EmitRust

namespace LeanRustCore.DependentErasure

/-!
Sprint 10–12 dependent-shape erasure policy.

The direct safe Rust lane still rejects general dependent computation.  This
module makes the accepted erasure slice explicit: proof-only constructor fields
are removed from runtime structs/enums, `Subtype` keeps only its carrier, `Fin`
keeps its numeric value, and `Vector` keeps its collection payload while length
proofs remain source-side obligations.
-/

/-- Proof-like heads whose values may be erased when they are not used computationally. -/
def proofHeadNameIsErased (n : Lean.Name) : Bool :=
  n == ``Eq ||
  n == ``True ||
  n == ``False ||
  n == ``And ||
  n == ``Or ||
  n == ``Not ||
  n == ``Iff ||
  n == ``Exists ||
  n == ``LT.lt ||
  n == ``LE.le ||
  n == ``Nat.lt ||
  n == ``Nat.le

/-- Runtime representation used by the current dependent-erasure lane. -/
def runtimeRepresentation : RType → String
  | .subtype t => "Subtype p erases to " ++ rustType t
  | .fin n => "Fin " ++ Nat.toString n ++ " erases to u32; the bound proof is static source evidence"
  | .vector t n => "Vector " ++ rustType t ++ " " ++ Nat.toString n ++ " erases to Vec<" ++ rustType t ++ ">; the length proof is static source evidence"
  | .struct name fields =>
      "structure " ++ name ++ " emits runtime fields " ++
      joinWith ", " (fields.map (fun f => f.1 ++ ": " ++ rustType f.2))
  | other => rustType other

/-- Dependent shapes intentionally admitted by Sprint 10–12. -/
def supportedDependentShapes : List String := [
  "Subtype.val and Subtype.mk erase proofs and keep the carrier value",
  "Fin.mk erases the bound proof and keeps the u32 value in the direct lane",
  "Vector.mk erases the length proof and keeps the Vec<T> payload",
  "single-constructor structures omit proof-only fields from generated Rust structs",
  "dependent matches whose erased index affects runtime branch shape remain rejected"
]

/-- Human-readable policy summary recorded in generated validation/proof reports. -/
def dependentErasureSummary : String :=
  "Sprint 10–12 dependent erasure supports Subtype/Fin/Vector runtime carriers and proof-only constructor-field erasure for Eq/True/False/And/Or/Not/Iff/Exists/LT/LE-shaped fields; non-erasable dependent computation remains rejected"

end LeanRustCore.DependentErasure
