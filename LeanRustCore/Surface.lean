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
  | litI32 : Int → SurfaceExpr
  | litI64 : Int → SurfaceExpr
  | letIn : String → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | ite : SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | matchBool : SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | matchOption : SurfaceExpr → SurfaceExpr → String → SurfaceExpr → SurfaceExpr
  | matchEnum : RType → SurfaceExpr → List (String × SurfaceExpr) → SurfaceExpr
  | not : SurfaceExpr → SurfaceExpr
  | and : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | or : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | eq : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | lt : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | le : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | gt : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | ge : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | add : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | sub : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | mul : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | min : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | max : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | optionNone : RType → SurfaceExpr
  | optionSome : SurfaceExpr → SurfaceExpr
  | resultOk : RType → SurfaceExpr → SurfaceExpr
  | resultErr : RType → SurfaceExpr → SurfaceExpr
  | enumVariant : RType → String → SurfaceExpr
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

private def report (code : CompatibilityCode) (detail : String) : CompatibilityReport :=
  { code := code, detail := detail }

private def rTypeLabel : RType → String
  | .unit => "unit"
  | .bool => "bool"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .option t => "Option<" ++ rTypeLabel t ++ ">"
  | .result ok err => "Result<" ++ rTypeLabel ok ++ "," ++ rTypeLabel err ++ ">"
  | .enum name _ => name

private def isEqType : RType → Bool
  | .unit => true
  | .bool => true
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | .enum _ _ => true
  | _ => false

private def isOrderedType : RType → Bool
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | _ => false

private def isWrappingNumericType : RType → Bool
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | _ => false

private def enumVariants? : RType → Option (List String)
  | .enum _ variants => some variants
  | _ => none

/-- Type check the extracted first-order surface tree. -/
partial def typeOf (ctx : List RArg) : SurfaceExpr → Except CompatibilityReport RType
  | .var name =>
      match lookupType ctx name with
      | some ty => pure ty
      | none => throw (report .unsupportedExpression ("unbound extracted variable `" ++ name ++ "`"))
  | .litUnit => pure .unit
  | .litBool _ => pure .bool
  | .litU32 _ => pure .u32
  | .litU64 _ => pure .u64
  | .litI32 _ => pure .i32
  | .litI64 _ => pure .i64
  | .letIn name value body => do
      let valueTy ← typeOf ctx value
      typeOf ((name, valueTy) :: ctx) body
  | .ite c a b => do
      checkExpected ctx c .bool
      checkSameBranches ctx a b "if"
  | .matchBool c whenTrue whenFalse => do
      checkExpected ctx c .bool
      checkSameBranches ctx whenTrue whenFalse "Bool match"
  | .matchOption target noneCase someName someCase => do
      let targetTy ← typeOf ctx target
      match targetTy with
      | .option inner => do
          let noneTy ← typeOf ctx noneCase
          let someTy ← typeOf ((someName, inner) :: ctx) someCase
          if noneTy == someTy then pure noneTy else throw (report .unsupportedType "Option match branches have different extracted types")
      | other => throw (report .unsupportedType ("Option match target has type " ++ rTypeLabel other))
  | .matchEnum enumTy target branches => do
      checkExpected ctx target enumTy
      match enumVariants? enumTy with
      | none => throw (report .unsupportedType ("enum match target has type " ++ rTypeLabel enumTy))
      | some variants => do
          let seen := branches.map (fun b => b.1)
          if variants.all (fun variant => seen.contains variant) then
            typeBranches ctx branches
          else
            throw (report .unsupportedExpression "enum match is missing at least one variant branch")
  | .not a => checkExpected ctx a .bool *> pure .bool
  | .and a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> pure .bool
  | .or a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> pure .bool
  | .eq t a b => do
      if isEqType t then expectPair ctx t a b *> pure .bool else throw (report .unsupportedType ("equality is not enabled for " ++ rTypeLabel t))
  | .lt t a b => ordered ctx t a b "<"
  | .le t a b => ordered ctx t a b "<="
  | .gt t a b => ordered ctx t a b ">"
  | .ge t a b => ordered ctx t a b ">="
  | .add t a b => wrapping ctx t a b "addition"
  | .sub t a b => wrapping ctx t a b "subtraction"
  | .mul t a b => wrapping ctx t a b "multiplication"
  | .min t a b => do
      if isOrderedType t then expectPair ctx t a b *> pure t else throw (report .unsupportedType ("min is not enabled for " ++ rTypeLabel t))
  | .max t a b => do
      if isOrderedType t then expectPair ctx t a b *> pure t else throw (report .unsupportedType ("max is not enabled for " ++ rTypeLabel t))
  | .optionNone t => pure (.option t)
  | .optionSome a => return .option (← typeOf ctx a)
  | .resultOk errTy a => do
      let okTy ← typeOf ctx a
      pure (.result okTy errTy)
  | .resultErr okTy e => do
      let errTy ← typeOf ctx e
      pure (.result okTy errTy)
  | .enumVariant ty variant => do
      match enumVariants? ty with
      | some variants =>
          if variants.contains variant then pure ty else throw (report .unsupportedExpression ("unknown enum variant `" ++ variant ++ "`"))
      | none => throw (report .unsupportedType "enum variant node does not carry an enum type")
where
  checkExpected (ctx : List RArg) (expr : SurfaceExpr) (expected : RType) : Except CompatibilityReport Unit := do
    let actual ← typeOf ctx expr
    if actual == expected then
      pure ()
    else
      throw (report .unsupportedType ("expected " ++ rTypeLabel expected ++ " but found " ++ rTypeLabel actual))

  expectPair (ctx : List RArg) (expected : RType) (a b : SurfaceExpr) : Except CompatibilityReport Unit :=
    checkExpected ctx a expected *> checkExpected ctx b expected

  ordered (ctx : List RArg) (expected : RType) (a b : SurfaceExpr) (op : String) : Except CompatibilityReport RType := do
    if isOrderedType expected then
      expectPair ctx expected a b *> pure .bool
    else
      throw (report .unsupportedType ("operator `" ++ op ++ "` is not enabled for " ++ rTypeLabel expected))

  wrapping (ctx : List RArg) (expected : RType) (a b : SurfaceExpr) (label : String) : Except CompatibilityReport RType := do
    if isWrappingNumericType expected then
      expectPair ctx expected a b *> pure expected
    else
      throw (report .unsupportedType (label ++ " is not enabled for " ++ rTypeLabel expected))

  checkSameBranches (ctx : List RArg) (a b : SurfaceExpr) (label : String) : Except CompatibilityReport RType := do
    let aTy ← typeOf ctx a
    let bTy ← typeOf ctx b
    if aTy == bTy then pure aTy else throw (report .unsupportedType (label ++ " branches have different extracted types"))

  typeBranches (ctx : List RArg) : List (String × SurfaceExpr) → Except CompatibilityReport RType
    | [] => throw (report .unsupportedExpression "enum match has no branches")
    | (_, first) :: rest => do
        let firstTy ← typeOf ctx first
        for branch in rest do
          let branchTy ← typeOf ctx branch.2
          if branchTy == firstTy then
            pure ()
          else
            throw (report .unsupportedType "enum match branches have different extracted types")
        pure firstTy

/-- Check a whole extracted function shape. -/
def checkSurfaceFun (f : SurfaceFun) : Except CompatibilityReport SurfaceFun := do
  let actual ← typeOf f.args f.body
  if actual == f.ret then
    pure f
  else
    throw (report .unsupportedType ("function `" ++ f.name ++ "` declared return " ++ rTypeLabel f.ret ++ " but body has " ++ rTypeLabel actual))

end LeanRustCore
