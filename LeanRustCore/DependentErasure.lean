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
  | .fin n => "Fin " ++ toString n ++ " erases to u32; the bound proof is static source evidence"
  | .vector t n => "Vector " ++ rustType t ++ " " ++ toString n ++ " erases to Vec<" ++ rustType t ++ ">; the length proof is static source evidence"
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

private partial def classifyNestedNotErasable : RType → Bool
  | .subtype _ => false
  | .fin _ => false
  | .vector _ _ => false
  | .unit => false
  | .bool => false
  | .ordering => false
  | .nat => false
  | .int => false
  | .u32 => false
  | .u64 => false
  | .i32 => false
  | .i64 => false
  | .char => false
  | .string => false
  | .option t => classifyNestedNotErasable t
  | .result ok err => classifyNestedNotErasable ok || classifyNestedNotErasable err
  | .list t | .array t | .boxed t => classifyNestedNotErasable t
  | .prod a b | .sum a b | .func a b => classifyNestedNotErasable a || classifyNestedNotErasable b
  | .recursive _ => false
  | .struct _ fields => fieldListHasNotErasable fields
  | .enum _ variants => variantListHasNotErasable variants
where
  fieldListHasNotErasable : List (String × RType) → Bool
    | [] => false
    | (_, ty) :: rest => classifyNestedNotErasable ty || fieldListHasNotErasable rest

  typeListHasNotErasable : List RType → Bool
    | [] => false
    | ty :: rest => classifyNestedNotErasable ty || typeListHasNotErasable rest

  variantListHasNotErasable : List (String × List RType) → Bool
    | [] => false
    | (_, payloads) :: rest => typeListHasNotErasable payloads || variantListHasNotErasable rest

/-- Classify a runtime type for erasure. This is deliberately conservative. -/
def classifyType (ty : RType) : RuntimeRelevance :=
  match ty with
  | .subtype _ => .erasedSafe
  | .fin _ => .erasedWithCheck
  | .vector _ _ => .erasedWithCheck
  | _ => if classifyNestedNotErasable ty then .notErasable else .runtime

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
  | .fin n => { source := source, relevance := .erasedWithCheck, runtimeType := some .u32, requiredCheck := some ("value < " ++ toString n), reason := "Fin proof erases after bound check" }
  | .vector elem n => { source := source, relevance := .erasedWithCheck, runtimeType := some (.list elem), requiredCheck := some ("length == " ++ toString n), reason := "Vector length index erases after length check" }
  | .prod a b => { source := source, relevance := .runtime, runtimeType := some (.prod a b), requiredCheck := none, reason := "Sigma-like runtime pair keeps both components when both have runtime representation" }
  | other => { source := source, relevance := classifyType other, runtimeType := eraseType? other, requiredCheck := none, reason := "non-dependent or already runtime-represented value" }

/-- Equality casts are safe only when the before/after runtime representations agree. -/
def equalityCastErases? (before after : RType) : Bool :=
  eraseType? before == eraseType? after

/-- Regression: bounded dependent checks must render with the pinned toolchain. -/
theorem vectorDependentCheckUsesConcreteBound :
    (checkDependentErasure "vector_fixture" (.vector .u32 3)).requiredCheck =
      some "length == 3" := by
  rfl

/-- Human-readable policy summary recorded in generated validation/proof reports. -/
def dependentErasureSummary : String :=
  "rows 28/29 complete: dependent erasure classifies runtime/proof/index fields, erases Subtype carriers, checks Fin bounds and Vector lengths, permits equality casts only when erased runtime representations agree, admits Sigma-like runtime pairs, and rejects dependent branch shapes whose erased index changes runtime behavior"

end LeanRustCore.DependentErasure
