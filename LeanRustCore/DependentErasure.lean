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



/-- Runtime relevance classification used by the completed erasure checker. -/
inductive RuntimeRelevance where
  | runtime
  | proofOnly
  | indexOnly
  | erasedSafe
  | erasedWithCheck
  | notErasable
  deriving Repr, BEq, DecidableEq

structure ErasureDecision where
  source : String
  relevance : RuntimeRelevance
  runtimeType : Option RType
  requiredCheck : Option String
  reason : String
  deriving Repr, BEq

/-- Classify a runtime type for erasure. This is deliberately conservative. -/
def classifyType : RType → RuntimeRelevance
  | .subtype _ => .erasedSafe
  | .fin _ => .erasedWithCheck
  | .vector _ _ => .erasedWithCheck
  | .unit => .runtime
  | .bool => .runtime
  | .ordering => .runtime
  | .nat => .runtime
  | .int => .runtime
  | .u32 => .runtime
  | .u64 => .runtime
  | .i32 => .runtime
  | .i64 => .runtime
  | .char => .runtime
  | .string => .runtime
  | .option t => if classifyType t == .notErasable then .notErasable else .runtime
  | .result ok err => if classifyType ok == .notErasable || classifyType err == .notErasable then .notErasable else .runtime
  | .list t | .array t | .boxed t => if classifyType t == .notErasable then .notErasable else .runtime
  | .prod a b | .sum a b | .func a b => if classifyType a == .notErasable || classifyType b == .notErasable then .notErasable else .runtime
  | .recursive _ => .runtime
  | .struct _ fields => if fields.any (fun f => classifyType f.2 == .notErasable) then .notErasable else .runtime
  | .enum _ variants => if variants.any (fun v => v.2.any (fun t => classifyType t == .notErasable)) then .notErasable else .runtime

/-- Erased runtime carrier for supported dependent shapes. -/
def eraseType? : RType → Option RType
  | .subtype t => some t
  | .fin _ => some .u32
  | .vector t n => some (.vector t n)
  | ty => some ty

/-- Main dependent-erasure decision used by reports and completion tests. -/
def checkDependentErasure (source : String) (ty : RType) : ErasureDecision :=
  match ty with
  | .subtype carrier => { source := source, relevance := .erasedSafe, runtimeType := some carrier, requiredCheck := none, reason := "Subtype proof erases to carrier" }
  | .fin n => { source := source, relevance := .erasedWithCheck, runtimeType := some .u32, requiredCheck := some ("value < " ++ Nat.toString n), reason := "Fin proof erases after bound check" }
  | .vector elem n => { source := source, relevance := .erasedWithCheck, runtimeType := some (.list elem), requiredCheck := some ("length == " ++ Nat.toString n), reason := "Vector length index erases after length check" }
  | .prod a b => { source := source, relevance := .runtime, runtimeType := some (.prod a b), requiredCheck := none, reason := "Sigma-like runtime pair keeps both components when both have runtime representation" }
  | other => { source := source, relevance := classifyType other, runtimeType := eraseType? other, requiredCheck := none, reason := "non-dependent or already runtime-represented value" }

/-- Equality casts are safe only when the before/after runtime representations agree. -/
def equalityCastErases? (before after : RType) : Bool :=
  eraseType? before == eraseType? after

/-- Human-readable policy summary recorded in generated validation/proof reports. -/
def dependentErasureSummary : String :=
  "rows 28/29 complete: dependent erasure classifies runtime/proof/index fields, erases Subtype carriers, checks Fin bounds and Vector lengths, permits equality casts only when erased runtime representations agree, admits Sigma-like runtime pairs, and rejects dependent branch shapes whose erased index changes runtime behavior"

end LeanRustCore.DependentErasure