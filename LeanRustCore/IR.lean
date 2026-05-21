import Lean

namespace LeanRustCore

/--
A deliberately small Rust-shaped type universe.

Integer operations whose Rust meaning depends on overflow are explicit. Unsigned
wrapping arithmetic is modeled with modular arithmetic; signed fixed-width values
are represented mathematically for the current extractor slice and are emitted
only through operations whose Rust behavior is explicit.
-/
inductive RType where
  | unit
  | bool
  | u32
  | u64
  | i32
  | i64
  | char
  | string
  | option : RType → RType
  | list : RType → RType
  | array : RType → RType
  | prod : RType → RType → RType
  | sum : RType → RType → RType
  | func : RType → RType → RType
  | result : RType → RType → RType
  | struct : String → List (String × RType) → RType
  | enum : String → List (String × List RType) → RType
  deriving Repr, BEq, DecidableEq

/-- Denotational meaning of an IR type inside Lean. -/
def Denote : RType → Type
  | .unit => Unit
  | .bool => Bool
  | .u32 => Nat
  | .u64 => Nat
  | .i32 => Int
  | .i64 => Int
  | .char => Char
  | .string => String
  | .option t => Option (Denote t)
  | .list t => List (Denote t)
  | .array t => Array (Denote t)
  | .prod a b => Denote a × Denote b
  | .sum a b => Sum (Denote a) (Denote b)
  | .func a b => Denote a → Denote b
  | .result ok err => Except (Denote err) (Denote ok)
  | .struct _ _ => Unit
  | .enum _ _ => Nat

/-- The modulus used by Rust `u32::wrapping_*` operations. -/
def u32Modulus : Nat := 4294967296

/-- The modulus used by Rust `u64::wrapping_*` operations. -/
def u64Modulus : Nat := 18446744073709551616

/-- Normalize a mathematical natural number to the `u32` wrapping domain. -/
def u32Wrap (n : Nat) : Nat := n % u32Modulus

/-- Normalize a mathematical natural number to the `u64` wrapping domain. -/
def u64Wrap (n : Nat) : Nat := n % u64Modulus

/-- Wrapping subtraction over the first-pass `u32` model. -/
def u32WrappingSub (a b : Nat) : Nat :=
  (u32Wrap a + u32Modulus - u32Wrap b) % u32Modulus

/-- Wrapping subtraction over the first-pass `u64` model. -/
def u64WrappingSub (a b : Nat) : Nat :=
  (u64Wrap a + u64Modulus - u64Wrap b) % u64Modulus

/--
A typed expression tree. Variables carry both a printed Rust name and a Lean
projection from the function argument context.
-/
inductive RExpr (ctx : Type) : RType → Type where
  | var {t : RType} : String → (ctx → Denote t) → RExpr ctx t
  | litUnit : RExpr ctx .unit
  | litBool : Bool → RExpr ctx .bool
  | litU32 : Nat → RExpr ctx .u32
  | litU64 : Nat → RExpr ctx .u64
  | litI32 : Int → RExpr ctx .i32
  | litI64 : Int → RExpr ctx .i64
  | letIn {a b : RType} : String → RExpr ctx a → RExpr (Denote a × ctx) b → RExpr ctx b
  | ite {t : RType} : RExpr ctx .bool → RExpr ctx t → RExpr ctx t → RExpr ctx t
  | matchBool {t : RType} : RExpr ctx .bool → RExpr ctx t → RExpr ctx t → RExpr ctx t
  | matchOption {a b : RType} : RExpr ctx (.option a) → RExpr ctx b → RExpr (Denote a × ctx) b → RExpr ctx b
  | not : RExpr ctx .bool → RExpr ctx .bool
  | and : RExpr ctx .bool → RExpr ctx .bool → RExpr ctx .bool
  | or : RExpr ctx .bool → RExpr ctx .bool → RExpr ctx .bool
  | eqU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | ltU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | leU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | gtU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | geU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | addU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | subU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | mulU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | minU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | maxU32 : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | optionNone {t : RType} : RExpr ctx (.option t)
  | optionSome {t : RType} : RExpr ctx t → RExpr ctx (.option t)
  | resultOk {ok err : RType} : RExpr ctx ok → RExpr ctx (.result ok err)
  | resultErr {ok err : RType} : RExpr ctx err → RExpr ctx (.result ok err)

/-- Interpret an IR expression in Lean. -/
def eval {ctx : Type} : {t : RType} → RExpr ctx t → ctx → Denote t
  | _, .var _ project, env => project env
  | _, .litUnit, _ => ()
  | _, .litBool b, _ => b
  | _, .litU32 n, _ => u32Wrap n
  | _, .litU64 n, _ => u64Wrap n
  | _, .litI32 n, _ => n
  | _, .litI64 n, _ => n
  | _, .letIn _ value body, env => eval body (eval value env, env)
  | _, .ite c a b, env => if eval c env then eval a env else eval b env
  | _, .matchBool c whenTrue whenFalse, env => if eval c env then eval whenTrue env else eval whenFalse env
  | _, .matchOption target noneCase someCase, env =>
      match eval target env with
      | none => eval noneCase env
      | some value => eval someCase (value, env)
  | _, .not a, env => !(eval a env)
  | _, .and a b, env => (eval a env) && (eval b env)
  | _, .or a b, env => (eval a env) || (eval b env)
  | _, .eqU32 a b, env => decide (eval a env = eval b env)
  | _, .ltU32 a b, env => decide (eval a env < eval b env)
  | _, .leU32 a b, env => decide (eval a env ≤ eval b env)
  | _, .gtU32 a b, env => decide (eval a env > eval b env)
  | _, .geU32 a b, env => decide (eval a env ≥ eval b env)
  | _, .addU32 a b, env => u32Wrap (eval a env + eval b env)
  | _, .subU32 a b, env => u32WrappingSub (eval a env) (eval b env)
  | _, .mulU32 a b, env => u32Wrap (eval a env * eval b env)
  | _, .minU32 a b, env => if decide (eval a env < eval b env) then eval a env else eval b env
  | _, .maxU32 a b, env => if decide (eval a env < eval b env) then eval b env else eval a env
  | _, .optionNone, _ => none
  | _, .optionSome a, env => some (eval a env)
  | _, .resultOk a, env => Except.ok (eval a env)
  | _, .resultErr e, env => Except.error (eval e env)

/-- A function argument declaration for Rust emission. -/
abbrev RArg := String × RType

/--
An exported function packages a private Lean context type, a typed body, and the
Rust-facing argument list. The context keeps proofs direct while the argument
list gives codegen stable names/types.
-/
structure RFun where
  Ctx : Type
  name : String
  args : List RArg
  ret : RType
  body : RExpr Ctx ret

/-- Evaluate a packaged function against its Lean context. -/
def RFun.eval (f : RFun) (env : f.Ctx) : Denote f.ret :=
  eval f.body env

/-- Simple compatibility summary used by the lowering/checking layer. -/
inductive CompatibilityCode where
  | supported
  | unsupportedType
  | unsupportedExpression
  | unsupportedBoundary
  | unsupportedDeclaration
  deriving Repr, BEq, DecidableEq

structure CompatibilityReport where
  code : CompatibilityCode
  detail : String
  deriving Repr, BEq

end LeanRustCore
