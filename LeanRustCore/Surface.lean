import LeanRustCore.IR

namespace LeanRustCore

/-!
`SurfaceExpr` is the first-pass extracted form produced from elaborated Lean
constant bodies. It is intentionally first-order: variables are names, and a
small checker assigns `RType`s before Rust emission.
-/

inductive SurfaceExpr where
  | var : String → SurfaceExpr
  | litUnit : SurfaceExpr
  | litBool : Bool → SurfaceExpr
  | litU32 : Nat → SurfaceExpr
  | litU64 : Nat → SurfaceExpr
  | letIn : String → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | ite : SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | not : SurfaceExpr → SurfaceExpr
  | and : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | or : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | eqU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | ltU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | leU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | gtU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | geU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | addU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | subU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | mulU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | minU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | maxU32 : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | optionNone : RType → SurfaceExpr
  | optionSome : SurfaceExpr → SurfaceExpr
  | resultOk : SurfaceExpr → SurfaceExpr
  | resultErr : SurfaceExpr → SurfaceExpr
  deriving Repr, BEq

/-- A checked extracted function, before packaging into proof-carrying `RFun`s. -/
structure SurfaceFun where
  name : String
  args : List RArg
  ret : RType
  body : SurfaceExpr
  deriving Repr, BEq

private def lookupType (ctx : List RArg) (name : String) : Option RType :=
  match ctx with
  | [] => none
  | (candidate, ty) :: rest => if candidate == name then some ty else lookupType rest name

private def boolReport (detail : String) : CompatibilityReport :=
  { code := .unsupportedExpression, detail := detail }

private def rTypeLabel : RType → String
  | .unit => "unit"
  | .bool => "bool"
  | .u32 => "u32"
  | .u64 => "u64"
  | .option t => "Option<" ++ rTypeLabel t ++ ">"
  | .result ok err => "Result<" ++ rTypeLabel ok ++ "," ++ rTypeLabel err ++ ">"

/-- Type check the extracted first-order surface tree. -/
partial def typeOf (ctx : List RArg) : SurfaceExpr → Except CompatibilityReport RType
  | .var name =>
      match lookupType ctx name with
      | some ty => pure ty
      | none => throw { code := .unsupportedExpression, detail := "unbound extracted variable `" ++ name ++ "`" }
  | .litUnit => pure .unit
  | .litBool _ => pure .bool
  | .litU32 _ => pure .u32
  | .litU64 _ => pure .u64
  | .letIn name value body => do
      let valueTy ← typeOf ctx value
      typeOf ((name, valueTy) :: ctx) body
  | .ite c a b => do
      checkExpected ctx c .bool
      let aTy ← typeOf ctx a
      let bTy ← typeOf ctx b
      if aTy == bTy then pure aTy else throw { code := .unsupportedType, detail := "if branches have different extracted types" }
  | .not a => checkExpected ctx a .bool *> pure .bool
  | .and a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> pure .bool
  | .or a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> pure .bool
  | .eqU32 a b => expectU32Pair ctx a b *> pure .bool
  | .ltU32 a b => expectU32Pair ctx a b *> pure .bool
  | .leU32 a b => expectU32Pair ctx a b *> pure .bool
  | .gtU32 a b => expectU32Pair ctx a b *> pure .bool
  | .geU32 a b => expectU32Pair ctx a b *> pure .bool
  | .addU32 a b => expectU32Pair ctx a b *> pure .u32
  | .subU32 a b => expectU32Pair ctx a b *> pure .u32
  | .mulU32 a b => expectU32Pair ctx a b *> pure .u32
  | .minU32 a b => expectU32Pair ctx a b *> pure .u32
  | .maxU32 a b => expectU32Pair ctx a b *> pure .u32
  | .optionNone t => pure (.option t)
  | .optionSome a => return .option (← typeOf ctx a)
  | .resultOk _ => throw (boolReport "Result::Ok extraction needs an expected result type in this pass")
  | .resultErr _ => throw (boolReport "Result::Err extraction needs an expected result type in this pass")
where
  checkExpected (ctx : List RArg) (expr : SurfaceExpr) (expected : RType) : Except CompatibilityReport Unit := do
    let actual ← typeOf ctx expr
    if actual == expected then
      pure ()
    else
      throw { code := .unsupportedType, detail := "expected " ++ rTypeLabel expected ++ " but found " ++ rTypeLabel actual }

  expectU32Pair (ctx : List RArg) (a b : SurfaceExpr) : Except CompatibilityReport Unit :=
    checkExpected ctx a .u32 *> checkExpected ctx b .u32

/-- Check a whole extracted function shape. -/
def checkSurfaceFun (f : SurfaceFun) : Except CompatibilityReport SurfaceFun := do
  let actual ← typeOf f.args f.body
  if actual == f.ret then
    pure f
  else
    throw { code := .unsupportedType, detail := "function `" ++ f.name ++ "` declared return " ++ rTypeLabel f.ret ++ " but body has " ++ rTypeLabel actual }

end LeanRustCore
