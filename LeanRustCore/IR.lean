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
  | ordering
  | nat
  | int
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
  | boxed : RType → RType
  | recursive : String → RType
  | subtype : RType → RType
  | fin : Nat → RType
  | vector : RType → Nat → RType
  | result : RType → RType → RType
  | struct : String → List (String × RType) → RType
  | enum : String → List (String × List RType) → RType
  deriving Repr, BEq

/-- The modulus used by Rust `u32::wrapping_*` operations. -/
def u32Modulus : Nat := 4294967296

/-- The modulus used by Rust `u64::wrapping_*` operations. -/
def u64Modulus : Nat := 18446744073709551616

/--
Runtime values used to give all Rust-shaped aggregate types a non-placeholder
semantic carrier.  Primitive and container `Denote` cases still use ordinary
Lean values; generated structs, enums, and recursive names use a subtype of
`RuntimeValue` with `runtimeValueHasType = true`, so they no longer collapse to
`Unit` or arbitrary `Nat` placeholders.
-/
inductive RuntimeValue where
  | unit
  | bool : Bool → RuntimeValue
  | ordering : Ordering → RuntimeValue
  | nat : Nat → RuntimeValue
  | int : Int → RuntimeValue
  | u32 : Nat → RuntimeValue
  | u64 : Nat → RuntimeValue
  | i32 : Int → RuntimeValue
  | i64 : Int → RuntimeValue
  | char : Char → RuntimeValue
  | string : String → RuntimeValue
  | optionNone : RuntimeValue
  | optionSome : RuntimeValue → RuntimeValue
  | list : List RuntimeValue → RuntimeValue
  | array : List RuntimeValue → RuntimeValue
  | prod : RuntimeValue → RuntimeValue → RuntimeValue
  | sumInl : RuntimeValue → RuntimeValue
  | sumInr : RuntimeValue → RuntimeValue
  | functionOpaque : String → RuntimeValue
  | boxed : RuntimeValue → RuntimeValue
  | recursive : String → RuntimeValue → RuntimeValue
  | resultOk : RuntimeValue → RuntimeValue
  | resultErr : RuntimeValue → RuntimeValue
  | struct : String → List (String × RuntimeValue) → RuntimeValue
  | enum : String → String → List RuntimeValue → RuntimeValue
  deriving Repr, BEq

private def lookupRuntimeField (fields : List (String × RuntimeValue)) (name : String) : Option RuntimeValue :=
  match fields with
  | [] => none
  | (candidate, value) :: rest => if candidate == name then some value else lookupRuntimeField rest name

private def lookupVariantTypes (variants : List (String × List RType)) (name : String) : Option (List RType) :=
  match variants with
  | [] => none
  | (candidate, payload) :: rest => if candidate == name then some payload else lookupVariantTypes rest name

mutual
  /-- Check that runtime values match runtime types field-by-field and payload-by-payload. -/
  partial def runtimeValueHasType : RuntimeValue → RType → Bool
    | .unit, .unit => true
    | .bool _, .bool => true
    | .ordering _, .ordering => true
    | .nat _, .nat => true
    | .int _, .int => true
    | .u32 n, .u32 => decide (n < u32Modulus)
    | .u64 n, .u64 => decide (n < u64Modulus)
    | .i32 _, .i32 => true
    | .i64 _, .i64 => true
    | .char _, .char => true
    | .string _, .string => true
    | .optionNone, .option _ => true
    | .optionSome value, .option t => runtimeValueHasType value t
    | .list values, .list t => runtimeListHasType values t
    | .array values, .array t => runtimeListHasType values t
    | .prod a b, .prod aTy bTy => runtimeValueHasType a aTy && runtimeValueHasType b bTy
    | .sumInl value, .sum aTy _ => runtimeValueHasType value aTy
    | .sumInr value, .sum _ bTy => runtimeValueHasType value bTy
    | .functionOpaque _, .func _ _ => true
    | .boxed value, .boxed t => runtimeValueHasType value t
    | .recursive name _, .recursive expected => name == expected
    | value, .subtype t => runtimeValueHasType value t
    | .u32 n, .fin bound => decide (n < bound)
    | .list values, .vector t n => (values.length == n) && runtimeListHasType values t
    | .array values, .vector t n => (values.length == n) && runtimeListHasType values t
    | .resultOk value, .result ok _ => runtimeValueHasType value ok
    | .resultErr value, .result _ err => runtimeValueHasType value err
    | .struct name fields, .struct expected declFields =>
        name == expected && runtimeFieldsHaveTypes fields declFields
    | .enum name variant payload, .enum expected variants =>
        name == expected &&
        match lookupVariantTypes variants variant with
        | some payloadTypes => runtimePayloadHasTypes payload payloadTypes
        | none => false
    | _, _ => false

  partial def runtimeListHasType : List RuntimeValue → RType → Bool
    | [], _ => true
    | value :: rest, t => runtimeValueHasType value t && runtimeListHasType rest t

  partial def runtimePayloadHasTypes : List RuntimeValue → List RType → Bool
    | [], [] => true
    | value :: restValues, ty :: restTypes =>
        runtimeValueHasType value ty && runtimePayloadHasTypes restValues restTypes
    | _, _ => false

  partial def runtimeFieldsHaveTypes : List (String × RuntimeValue) → List (String × RType) → Bool
    | [], [] => true
    | _, [] => false
    | fields, (name, ty) :: restDecls =>
        match lookupRuntimeField fields name with
        | some value => runtimeValueHasType value ty && runtimeFieldsHaveTypes fields restDecls
        | none => false
end

/-- Denotational meaning of an IR type inside Lean. -/
def Denote : RType → Type
  | .unit => Unit
  | .bool => Bool
  | .ordering => Ordering
  | .nat => Nat
  | .int => Int
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
  | .boxed t => Denote t
  | .recursive name => { value : RuntimeValue // runtimeValueHasType value (.recursive name) = true }
  | .subtype t => Denote t
  | .fin _ => Nat
  | .vector t _ => List (Denote t)
  | .result ok err => Except (Denote err) (Denote ok)
  | .struct name fields => { value : RuntimeValue // runtimeValueHasType value (.struct name fields) = true }
  | .enum name variants => { value : RuntimeValue // runtimeValueHasType value (.enum name variants) = true }

/-- Human-readable summary for proof/validation reports. -/
def runtimeDenotationSummary : String :=
  "RType.Denote uses precise Lean values for primitives/containers/functions and RuntimeValue subtype witnesses for generated structs, enums, and named recursive payloads; placeholder Unit/Nat aggregate semantics are no longer used"

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
inductive RExpr : Type → RType → Type 2 where
  | var {ctx : Type} {t : RType} : String → (ctx → Denote t) → RExpr ctx t
  | litUnit {ctx : Type} : RExpr ctx .unit
  | litBool {ctx : Type} : Bool → RExpr ctx .bool
  | litU32 {ctx : Type} : Nat → RExpr ctx .u32
  | litU64 {ctx : Type} : Nat → RExpr ctx .u64
  | litI32 {ctx : Type} : Int → RExpr ctx .i32
  | litI64 {ctx : Type} : Int → RExpr ctx .i64
  | letIn {ctx : Type} {a b : RType} : String → RExpr ctx a → RExpr (Denote a × ctx) b → RExpr ctx b
  | ite {ctx : Type} {t : RType} : RExpr ctx .bool → RExpr ctx t → RExpr ctx t → RExpr ctx t
  | matchBool {ctx : Type} {t : RType} : RExpr ctx .bool → RExpr ctx t → RExpr ctx t → RExpr ctx t
  | matchOption {ctx : Type} {a b : RType} : RExpr ctx (.option a) → RExpr ctx b → RExpr (Denote a × ctx) b → RExpr ctx b
  | not {ctx : Type} : RExpr ctx .bool → RExpr ctx .bool
  | and {ctx : Type} : RExpr ctx .bool → RExpr ctx .bool → RExpr ctx .bool
  | or {ctx : Type} : RExpr ctx .bool → RExpr ctx .bool → RExpr ctx .bool
  | eqU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | ltU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | leU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | gtU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | geU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .bool
  | addU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | subU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | mulU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | minU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | maxU32 {ctx : Type} : RExpr ctx .u32 → RExpr ctx .u32 → RExpr ctx .u32
  | optionNone {ctx : Type} {t : RType} : RExpr ctx (.option t)
  | optionSome {ctx : Type} {t : RType} : RExpr ctx t → RExpr ctx (.option t)
  | resultOk {ctx : Type} {ok err : RType} : RExpr ctx ok → RExpr ctx (.result ok err)
  | resultErr {ctx : Type} {ok err : RType} : RExpr ctx err → RExpr ctx (.result ok err)

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
  | _, .ite c a b, env =>
      let cond : Bool := eval c env
      match cond with
      | true => eval a env
      | false => eval b env
  | _, .matchBool c whenTrue whenFalse, env =>
      let cond : Bool := eval c env
      match cond with
      | true => eval whenTrue env
      | false => eval whenFalse env
  | _, .matchOption target noneCase someCase, env =>
      match eval target env with
      | none => eval noneCase env
      | some value => eval someCase (value, env)
  | _, .not a, env =>
      let value : Bool := eval a env
      !value
  | _, .and a b, env =>
      let av : Bool := eval a env
      let bv : Bool := eval b env
      av && bv
  | _, .or a b, env =>
      let av : Bool := eval a env
      let bv : Bool := eval b env
      av || bv
  | _, .eqU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      decide (av = bv)
  | _, .ltU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      decide (av < bv)
  | _, .leU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      decide (av ≤ bv)
  | _, .gtU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      decide (av > bv)
  | _, .geU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      decide (av ≥ bv)
  | _, .addU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      u32Wrap (av + bv)
  | _, .subU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      u32WrappingSub av bv
  | _, .mulU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      u32Wrap (av * bv)
  | _, .minU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      if decide (av < bv) then av else bv
  | _, .maxU32 a b, env =>
      let av : Nat := eval a env
      let bv : Nat := eval b env
      if decide (av < bv) then bv else av
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
  LeanRustCore.eval f.body env

/-- Simple compatibility summary used by the lowering/checking layer. -/
inductive CompatibilityCode where
  | supported
  | unsupportedType
  | unsupportedExpression
  | unsupportedBoundary
  | unsupportedDeclaration
  deriving Repr, BEq, DecidableEq, Inhabited

structure CompatibilityReport where
  code : CompatibilityCode
  detail : String
  deriving Repr, BEq, Inhabited

end LeanRustCore
