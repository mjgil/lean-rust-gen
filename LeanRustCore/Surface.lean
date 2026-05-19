import LeanRustCore.IR

namespace LeanRustCore

/-!
`SurfaceExpr` is the first-pass extracted form produced from elaborated Lean
constant bodies. It is intentionally first-order: variables are names, and a
small checker assigns `RType`s before Rust emission.
-/

/-- A Rust-facing struct declaration discovered during extraction. -/
structure SurfaceStruct where
  name : String
  fields : List RArg
  deriving Repr, BEq

/-- A Rust-facing enum declaration discovered during extraction. -/
structure SurfaceEnum where
  name : String
  variants : List (String × List RType)
  deriving Repr, BEq

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
  | structLit : RType → List (String × SurfaceExpr) → SurfaceExpr
  | field : SurfaceExpr → String → SurfaceExpr
  | enumVariant : RType → String → List SurfaceExpr → SurfaceExpr
  deriving Repr, BEq

/-- A checked extracted function, before packaging into proof-carrying `RFun`s. -/
structure SurfaceFun where
  name : String
  args : List RArg
  ret : RType
  body : SurfaceExpr
  deriving Repr, BEq

/-- A checked extracted module: declarations plus functions. -/
structure SurfaceModule where
  structs : List SurfaceStruct
  enums : List SurfaceEnum
  functions : List SurfaceFun
  deriving Repr, BEq

private def lookupType (ctx : List RArg) (name : String) : Option RType :=
  match ctx with
  | [] => none
  | (candidate, ty) :: rest => if candidate == name then some ty else lookupType rest name

private def lookupField (fields : List RArg) (name : String) : Option RType :=
  match fields with
  | [] => none
  | (candidate, ty) :: rest => if candidate == name then some ty else lookupField rest name

private def lookupVariant (variants : List (String × List RType)) (name : String) : Option (List RType) :=
  match variants with
  | [] => none
  | (candidate, payload) :: rest => if candidate == name then some payload else lookupVariant rest name

private def containsString : List String → String → Bool
  | [], _ => false
  | x :: xs, s => x == s || containsString xs s

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
  | .struct name _ => name
  | .enum name _ => name

private def applyExpected (expected : Option RType) (actual : RType) : Except CompatibilityReport RType :=
  match expected with
  | none => pure actual
  | some wanted =>
      if wanted == actual then
        pure actual
      else
        throw (report .unsupportedType ("expected " ++ rTypeLabel wanted ++ " but found " ++ rTypeLabel actual))

private def isEqType : RType → Bool
  | .unit => true
  | .bool => true
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | .enum _ variants => variants.all (fun v => v.2.isEmpty)
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

private def structFields? : RType → Option (List RArg)
  | .struct _ fields => some fields
  | _ => none

private def enumVariants? : RType → Option (List (String × List RType))
  | .enum _ variants => some variants
  | _ => none

private def enumVariantNames : List (String × List RType) → List String
  | [] => []
  | (name, _) :: rest => name :: enumVariantNames rest

private def allEnumVariantsAreNullary : List (String × List RType) → Bool
  | [] => true
  | (_, payload) :: rest => payload.isEmpty && allEnumVariantsAreNullary rest

/-- Type check the extracted first-order surface tree, using an expected type when it disambiguates constructors. -/
partial def typeOfExpected (ctx : List RArg) (expr : SurfaceExpr) (expected : Option RType) : Except CompatibilityReport RType :=
  match expr with
  | .var name =>
      match lookupType ctx name with
      | some ty => applyExpected expected ty
      | none => throw (report .unsupportedExpression ("unbound extracted variable `" ++ name ++ "`"))
  | .litUnit => applyExpected expected .unit
  | .litBool _ => applyExpected expected .bool
  | .litU32 _ => applyExpected expected .u32
  | .litU64 _ => applyExpected expected .u64
  | .litI32 _ => applyExpected expected .i32
  | .litI64 _ => applyExpected expected .i64
  | .letIn name value body => do
      let valueTy ← typeOfExpected ctx value none
      typeOfExpected ((name, valueTy) :: ctx) body expected
  | .ite c a b => do
      checkExpected ctx c .bool
      typeBranchesWithExpected ctx a b expected "if"
  | .matchBool c whenTrue whenFalse => do
      checkExpected ctx c .bool
      typeBranchesWithExpected ctx whenTrue whenFalse expected "Bool match"
  | .matchOption target noneCase someName someCase => do
      let targetTy ← typeOfExpected ctx target none
      match targetTy with
      | .option inner => do
          match expected with
          | some wanted =>
              discard <| typeOfExpected ctx noneCase (some wanted)
              discard <| typeOfExpected ((someName, inner) :: ctx) someCase (some wanted)
              pure wanted
          | none => do
              let noneTy ← typeOfExpected ctx noneCase none
              let someTy ← typeOfExpected ((someName, inner) :: ctx) someCase (some noneTy)
              if noneTy == someTy then pure noneTy else throw (report .unsupportedType "Option match branches have different extracted types")
      | other => throw (report .unsupportedType ("Option match target has type " ++ rTypeLabel other))
  | .matchEnum enumTy target branches => do
      checkExpected ctx target enumTy
      match enumVariants? enumTy with
      | none => throw (report .unsupportedType ("enum match target has type " ++ rTypeLabel enumTy))
      | some variants => do
          if !allEnumVariantsAreNullary variants then
            throw (report .unsupportedExpression "enum match over payload variants is not in the current extractor subset")
          let variantNames := enumVariantNames variants
          let seen := branches.map (fun b => b.1)
          if variantNames.all (fun variant => containsString seen variant) then
            typeBranchListWithExpected ctx branches expected
          else
            throw (report .unsupportedExpression "enum match is missing at least one variant branch")
  | .not a => checkExpected ctx a .bool *> applyExpected expected .bool
  | .and a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> applyExpected expected .bool
  | .or a b => checkExpected ctx a .bool *> checkExpected ctx b .bool *> applyExpected expected .bool
  | .eq t a b => do
      if isEqType t then expectPair ctx t a b *> applyExpected expected .bool else throw (report .unsupportedType ("equality is not enabled for " ++ rTypeLabel t))
  | .lt t a b => ordered ctx t a b "<" expected
  | .le t a b => ordered ctx t a b "<=" expected
  | .gt t a b => ordered ctx t a b ">" expected
  | .ge t a b => ordered ctx t a b ">=" expected
  | .add t a b => wrapping ctx t a b "addition" expected
  | .sub t a b => wrapping ctx t a b "subtraction" expected
  | .mul t a b => wrapping ctx t a b "multiplication" expected
  | .min t a b => do
      if isOrderedType t then expectPair ctx t a b *> applyExpected expected t else throw (report .unsupportedType ("min is not enabled for " ++ rTypeLabel t))
  | .max t a b => do
      if isOrderedType t then expectPair ctx t a b *> applyExpected expected t else throw (report .unsupportedType ("max is not enabled for " ++ rTypeLabel t))
  | .optionNone t => applyExpected expected (.option t)
  | .optionSome a => do
      match expected with
      | some (.option inner) =>
          discard <| typeOfExpected ctx a (some inner)
          pure (.option inner)
      | some other => throw (report .unsupportedType ("expected " ++ rTypeLabel other ++ " but found Option constructor"))
      | none => return .option (← typeOfExpected ctx a none)
  | .resultOk errTy a => do
      match expected with
      | some (.result okTy expectedErr) =>
          if expectedErr == errTy then
            discard <| typeOfExpected ctx a (some okTy)
            pure (.result okTy expectedErr)
          else
            throw (report .unsupportedType ("Result error type mismatch: expected " ++ rTypeLabel expectedErr ++ " but constructor carries " ++ rTypeLabel errTy))
      | some other => throw (report .unsupportedType ("expected " ++ rTypeLabel other ++ " but found Result.ok constructor"))
      | none => do
          let okTy ← typeOfExpected ctx a none
          pure (.result okTy errTy)
  | .resultErr okTy e => do
      match expected with
      | some (.result expectedOk errTy) =>
          if expectedOk == okTy then
            discard <| typeOfExpected ctx e (some errTy)
            pure (.result expectedOk errTy)
          else
            throw (report .unsupportedType ("Result ok type mismatch: expected " ++ rTypeLabel expectedOk ++ " but constructor carries " ++ rTypeLabel okTy))
      | some other => throw (report .unsupportedType ("expected " ++ rTypeLabel other ++ " but found Result.err constructor"))
      | none => do
          let errTy ← typeOfExpected ctx e none
          pure (.result okTy errTy)
  | .structLit ty fields => do
      match structFields? ty with
      | some declared =>
          checkStructFields ctx declared fields
          applyExpected expected ty
      | none => throw (report .unsupportedType "struct literal node does not carry a struct type")
  | .field target fieldName => do
      let targetTy ← typeOfExpected ctx target none
      match structFields? targetTy with
      | some fields =>
          match lookupField fields fieldName with
          | some fieldTy => applyExpected expected fieldTy
          | none => throw (report .unsupportedExpression ("unknown field `" ++ fieldName ++ "` on " ++ rTypeLabel targetTy))
      | none => throw (report .unsupportedType ("field projection target has type " ++ rTypeLabel targetTy))
  | .enumVariant ty variant payload => do
      match enumVariants? ty with
      | some variants =>
          match lookupVariant variants variant with
          | some expectedPayload =>
              checkPayload ctx variant expectedPayload payload
              applyExpected expected ty
          | none => throw (report .unsupportedExpression ("unknown enum variant `" ++ variant ++ "`"))
      | none => throw (report .unsupportedType "enum variant node does not carry an enum type")
where
  checkExpected (ctx : List RArg) (expr : SurfaceExpr) (wanted : RType) : Except CompatibilityReport Unit := do
    discard <| typeOfExpected ctx expr (some wanted)

  expectPair (ctx : List RArg) (wanted : RType) (a b : SurfaceExpr) : Except CompatibilityReport Unit :=
    checkExpected ctx a wanted *> checkExpected ctx b wanted

  ordered (ctx : List RArg) (wanted : RType) (a b : SurfaceExpr) (op : String) (expected : Option RType) : Except CompatibilityReport RType := do
    if isOrderedType wanted then
      expectPair ctx wanted a b *> applyExpected expected .bool
    else
      throw (report .unsupportedType ("operator `" ++ op ++ "` is not enabled for " ++ rTypeLabel wanted))

  wrapping (ctx : List RArg) (wanted : RType) (a b : SurfaceExpr) (label : String) (expected : Option RType) : Except CompatibilityReport RType := do
    if isWrappingNumericType wanted then
      expectPair ctx wanted a b *> applyExpected expected wanted
    else
      throw (report .unsupportedType (label ++ " is not enabled for " ++ rTypeLabel wanted))

  typeBranchesWithExpected (ctx : List RArg) (a b : SurfaceExpr) (expected : Option RType) (label : String) : Except CompatibilityReport RType := do
    match expected with
    | some wanted =>
        discard <| typeOfExpected ctx a (some wanted)
        discard <| typeOfExpected ctx b (some wanted)
        pure wanted
    | none => do
        let aTy ← typeOfExpected ctx a none
        let bTy ← typeOfExpected ctx b (some aTy)
        if aTy == bTy then pure aTy else throw (report .unsupportedType (label ++ " branches have different extracted types"))

  typeBranchListWithExpected (ctx : List RArg) (branches : List (String × SurfaceExpr)) (expected : Option RType) : Except CompatibilityReport RType := do
    match branches with
    | [] => throw (report .unsupportedExpression "enum match has no branches")
    | (_, first) :: rest =>
        match expected with
        | some wanted =>
            discard <| typeOfExpected ctx first (some wanted)
            for branch in rest do
              discard <| typeOfExpected ctx branch.2 (some wanted)
            pure wanted
        | none => do
            let firstTy ← typeOfExpected ctx first none
            for branch in rest do
              discard <| typeOfExpected ctx branch.2 (some firstTy)
            pure firstTy

  checkStructFields (ctx : List RArg) (declared : List RArg) (provided : List (String × SurfaceExpr)) : Except CompatibilityReport Unit := do
    let providedNames := provided.map (fun p => p.1)
    for field in declared do
      match provided.find? (fun p => p.1 == field.1) with
      | some providedField => discard <| typeOfExpected ctx providedField.2 (some field.2)
      | none => throw (report .unsupportedExpression ("struct literal is missing field `" ++ field.1 ++ "`"))
    for providedField in provided do
      match lookupField declared providedField.1 with
      | some _ => pure ()
      | none => throw (report .unsupportedExpression ("struct literal contains unknown field `" ++ providedField.1 ++ "`"))
    let uniqueProvided := providedNames.eraseDups
    if uniqueProvided.length == providedNames.length then
      pure ()
    else
      throw (report .unsupportedExpression "struct literal contains a duplicate field")

  checkPayload (ctx : List RArg) (variant : String) (expectedPayload : List RType) (payload : List SurfaceExpr) : Except CompatibilityReport Unit := do
    if expectedPayload.length == payload.length then
      for pair in expectedPayload.zip payload do
        discard <| typeOfExpected ctx pair.2 (some pair.1)
    else
      throw (report .unsupportedExpression ("enum variant `" ++ variant ++ "` received the wrong number of payload fields"))

/-- Type check without an externally supplied expected type. -/
def typeOf (ctx : List RArg) (expr : SurfaceExpr) : Except CompatibilityReport RType :=
  typeOfExpected ctx expr none

/-- Check a whole extracted function shape. -/
def checkSurfaceFun (f : SurfaceFun) : Except CompatibilityReport SurfaceFun := do
  let actual ← typeOfExpected f.args f.body (some f.ret)
  if actual == f.ret then
    pure f
  else
    throw (report .unsupportedType ("function `" ++ f.name ++ "` declared return " ++ rTypeLabel f.ret ++ " but body has " ++ rTypeLabel actual))

end LeanRustCore
