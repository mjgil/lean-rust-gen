import LeanRustCore.IR

namespace LeanRustCore.OwnershipPolicy

/-!
Row 33 ownership and borrowing completion.

The safe direct lane starts from owned values, then applies audited borrow/clone
policies for read-only containers and strings.  The policy is deliberately
machine-readable so validation can reject ad-hoc references/lifetimes in emitted
Rust.
-/

inductive OwnershipMode where
  | owned
  | borrowedShared
  | cloned
  | moved
  | boxed
  deriving Repr, BEq, DecidableEq

structure OwnershipRule where
  typeShape : String
  inputMode : OwnershipMode
  outputMode : OwnershipMode
  rustShape : String
  condition : String
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def rules : List OwnershipRule := [
  { typeShape := "small Copy scalars", inputMode := .owned, outputMode := .owned, rustShape := "u32/u64/i32/i64/bool/char by value", condition := "Copy and no borrow needed", requiredTests := ["differential scalar functions"], requiredDocs := ["docs/OWNERSHIP.md"] },
  { typeShape := "Vec<T> consumed by transformation", inputMode := .owned, outputMode := .owned, rustShape := "Vec<T> into_iter/for loop", condition := "generated function owns the container", requiredTests := ["list_map/list_filter/list_fold tests"], requiredDocs := ["docs/OWNERSHIP.md"] },
  { typeShape := "Vec<T> read-only helper", inputMode := .borrowedShared, outputMode := .owned, rustShape := "&[T] for get/length helpers", condition := "no mutation and no escaping reference", requiredTests := ["array_get_u32 runtime test"], requiredDocs := ["docs/OWNERSHIP.md"] },
  { typeShape := "String append", inputMode := .owned, outputMode := .owned, rustShape := "owned String plus borrowed suffix", condition := "caller transfers left string", requiredTests := ["string_append runtime test"], requiredDocs := ["docs/OWNERSHIP.md"] },
  { typeShape := "recursive payload", inputMode := .boxed, outputMode := .boxed, rustShape := "Box<T>/Rc<T>/arena index", condition := "recursive SCC layout decision", requiredTests := ["recursive data property tests"], requiredDocs := ["docs/RECURSIVE_DATA.md", "docs/OWNERSHIP.md"] }
]

def approvedReferenceForms : List String := [
  "temporary shared operand borrows for exact BigUint/BigInt arithmetic and comparisons",
  "no reference types in emitted struct, enum, or function signatures",
  "no explicit lifetimes in emitted Rust"
]

def ownershipPolicySummary : String :=
  "ownership completion keeps owned values as default, allows audited shared borrows for read-only helpers, records clone/move/box decisions, and rejects ad-hoc lifetime/reference emission outside the policy table"

def ownershipPolicyEnforcementSummary : String :=
  "emitted Rust keeps owned values as default, permits only temporary shared operand borrows for exact BigUint/BigInt arithmetic/comparisons, and rejects reference types or explicit lifetimes in generated declarations"

end LeanRustCore.OwnershipPolicy
