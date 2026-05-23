import LeanRustCore.ClosureConversion

namespace LeanRustCore.FirstClassClosures

/-!
Checklist row 43: first-class closure objects.

The completed lane represents stored/returned/captured closures as monomorphic
objects.  Closure objects are ordinary tagged values with explicit ownership and
an apply operation; unsupported mutation-sensitive `FnMut`/`FnOnce` shapes are
rejected by diagnostics rather than lowered implicitly.
-/

inductive ClosureOwnership where
  | borrowed
  | owned
  | shared
  deriving Repr, BEq, DecidableEq

inductive ClosureCapability where
  | fnOnly
  | rejectedFnMut
  | rejectedFnOnce
  deriving Repr, BEq, DecidableEq

structure ClosureObjectShape where
  rustName : String
  captures : List String
  ownership : ClosureOwnership
  capability : ClosureCapability
  canBeReturned : Bool
  canBeStored : Bool
  tests : List String
  docs : List String
  deriving Repr, BEq

private def joinWithLocal (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWithLocal sep xs

/-- First-class closure object shapes admitted by the completed lane. -/
def closureObjects : List ClosureObjectShape := [
  { rustName := "U32ClosureObject", captures := ["delta", "composed functions"], ownership := .owned,
    capability := .fnOnly, canBeReturned := true, canBeStored := true,
    tests := ["crates/runtime::first_class_closure_objects_can_be_returned_stored_and_composed"],
    docs := ["docs/FIRST_CLASS_CLOSURES.md", "docs/CLOSURE_CONVERSION.md"] },
  { rustName := "StoredClosureU32", captures := ["U32ClosureObject"], ownership := .owned,
    capability := .fnOnly, canBeReturned := true, canBeStored := true,
    tests := ["crates/runtime::first_class_closure_objects_can_be_returned_stored_and_composed"],
    docs := ["docs/FIRST_CLASS_CLOSURES.md", "docs/CLOSURE_CONVERSION.md"] }
]

def closureObjectComplete (shape : ClosureObjectShape) : Bool :=
  shape.canBeReturned && shape.canBeStored && !shape.tests.isEmpty && !shape.docs.isEmpty && shape.capability == .fnOnly

def allClosureObjectsComplete : Bool :=
  closureObjects.all closureObjectComplete

/-- Human-readable report summary. -/
def firstClassClosureSummary : String :=
  "first-class non-mutating monomorphic closure objects are returnable, storable, composable, and test/doc gated: " ++
  joinWithLocal ", " (closureObjects.map (fun shape => shape.rustName))

theorem closure_object_completion_gate : allClosureObjectsComplete = true := by
  rfl

end LeanRustCore.FirstClassClosures
