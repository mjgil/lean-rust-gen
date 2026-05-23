import LeanRustCore.IR

namespace LeanRustCore.NumericSemantics

/-!
Rows 26-27 numeric semantics completion.

Every numeric lowering is explicit: exact integers use mathematical Lean values
and `num_bigint` on the Rust side; fixed-width integers choose wrapping, checked,
saturating, or preconditioned operation modes.  Division/modulus-by-zero and casts
are never silently emitted without a mode.
-/

inductive NumericMode where
  | exact
  | wrapping
  | checked
  | saturating
  | preconditioned
  deriving Repr, BEq, DecidableEq

inductive NumericOp where
  | add | sub | mul | div | mod | cast | compare
  deriving Repr, BEq, DecidableEq

structure NumericRule where
  sourceType : RType
  targetType : String
  operation : NumericOp
  mode : NumericMode
  rustShape : String
  requiredTests : List String
  requiredDocs : List String
  deriving Repr, BEq

def checkedAddU32 (a b : Nat) : Option Nat :=
  let sum := a + b
  if h : sum < u32Modulus then some sum else none

def checkedSubU32 (a b : Nat) : Option Nat :=
  if h : b ≤ a then some (a - b) else none

def checkedMulU32 (a b : Nat) : Option Nat :=
  let product := a * b
  if h : product < u32Modulus then some product else none

def saturatingAddU32 (a b : Nat) : Nat :=
  let sum := a + b
  if sum < u32Modulus then sum else u32Modulus - 1

def saturatingSubU32 (a b : Nat) : Nat :=
  if b ≤ a then a - b else 0

def preconditionedDivU32 (a b : Nat) : Except String Nat :=
  if b == 0 then .error "division-by-zero" else .ok (a / b)

def preconditionedModU32 (a b : Nat) : Except String Nat :=
  if b == 0 then .error "modulus-by-zero" else .ok (a % b)

def castNatToU32Checked (n : Nat) : Option Nat :=
  if n < u32Modulus then some n else none

def rules : List NumericRule := [
  { sourceType := .nat, targetType := "num_bigint::BigUint", operation := .add, mode := .exact, rustShape := "BigUint + BigUint", requiredTests := ["exact_nat_add differential", "runtime exact_nat_add"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .int, targetType := "num_bigint::BigInt", operation := .mul, mode := .exact, rustShape := "BigInt * BigInt", requiredTests := ["exact_int_mul differential", "runtime exact_int_add/mul"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .u32, targetType := "u32", operation := .add, mode := .wrapping, rustShape := "u32::wrapping_add", requiredTests := ["u32::MAX + 1 wraps"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .u32, targetType := "Option<u32>", operation := .add, mode := .checked, rustShape := "u32::checked_add", requiredTests := ["checked overflow returns None"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .u32, targetType := "u32", operation := .add, mode := .saturating, rustShape := "u32::saturating_add", requiredTests := ["saturating overflow clamps to MAX"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .u32, targetType := "Result<u32, NumericError>", operation := .div, mode := .preconditioned, rustShape := "explicit division-by-zero check", requiredTests := ["division by zero rejected"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] },
  { sourceType := .nat, targetType := "Option<u32>", operation := .cast, mode := .checked, rustShape := "TryFrom/checked bound", requiredTests := ["cast overflow returns None"], requiredDocs := ["docs/NUMERIC_SEMANTICS.md"] }
]


partial def lookupRule (sourceType : RType) (operation : NumericOp) (mode : NumericMode) : Option NumericRule :=
  rules.find? (fun r => r.sourceType == sourceType && r.operation == operation && r.mode == mode)

/-- Validate that an operation has an explicit numeric rule. -/
def requireRule (sourceType : RType) (operation : NumericOp) (mode : NumericMode) : Except String NumericRule :=
  match lookupRule sourceType operation mode with
  | some rule => Except.ok rule
  | none => Except.error "numeric operation has no explicit semantics rule"

def numericSemanticsSummary : String :=
  "numeric completion defines exact, wrapping, checked, saturating, and preconditioned modes for Nat/Int/fixed-width operations; division/modulus-by-zero and cast overflow require explicit checked/preconditioned semantics"

end LeanRustCore.NumericSemantics
