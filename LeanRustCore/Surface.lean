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
  | litChar : Char → SurfaceExpr
  | litString : String → SurfaceExpr
  | letIn : String → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | ite : SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | matchBool : SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | matchOption : SurfaceExpr → SurfaceExpr → String → SurfaceExpr → SurfaceExpr
  | matchEnum : RType → SurfaceExpr → List (String × (List String × SurfaceExpr)) → SurfaceExpr
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
  | call : String → List RType → RType → List SurfaceExpr → SurfaceExpr
  | callValue : SurfaceExpr → RType → RType → SurfaceExpr → SurfaceExpr
  | listMap : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listFoldl : String → String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | natFold : String → String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
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
  | .char => "Char"
  | .string => "String"
  | .option t => "Option<" ++ rTypeLabel t ++ ">"
  | .result ok err => "Result<" ++ rTypeLabel ok ++ "," ++ rTypeLabel err ++ ">"
  | .list t => "List<" ++ rTypeLabel t ++ ">"
  | .array t => "Array<" ++ rTypeLabel t ++ ">"
  | .prod a b => "Prod<" ++ rTypeLabel a ++ "," ++ rTypeLabel b ++ ">"
  | .sum a b => "Sum<" ++ rTypeLabel a ++ "," ++ rTypeLabel b ++ ">"
  | .func a b => "Fn<" ++ rTypeLabel a ++ "," ++ rTypeLabel b ++ ">"
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
  | .char => true
  | .string => true
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
  | .litChar _ => applyExpected expected .char
  | .litString _ => applyExpected expected .string
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
          let variantNames := enumVariantNames variants
          let seen := branches.map (fun b => b.1)
          if seen.eraseDups.length != seen.length then
            throw (report .unsupportedExpression "enum match contains a duplicate variant branch")
          for branch in branches do
            match lookupVariant variants branch.1 with
            | some _ => pure ()
            | none => throw (report .unsupportedExpression ("enum match contains unknown variant `" ++ branch.1 ++ "`"))
          if variantNames.all (fun variant => containsString seen variant) then
            typeEnumBranchesWithExpected ctx variants branches expected
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
  | .call name argTypes ret args => do
      if argTypes.length == args.length then
        for pair in argTypes.zip args do
          discard <| typeOfExpected ctx pair.2 (some pair.1)
        applyExpected expected ret
      else
        throw (report .unsupportedExpression ("function call `" ++ name ++ "` received the wrong number of arguments"))
  | .callValue fn argTy retTy arg => do
      discard <| typeOfExpected ctx fn (some (.func argTy retTy))
      discard <| typeOfExpected ctx arg (some argTy)
      applyExpected expected retTy
  | .listMap binder elemTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) body (some outTy)
      applyExpected expected (.list outTy)
  | .listFoldl accName elemName accTy elemTy init target body => do
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((elemName, elemTy) :: (accName, accTy) :: ctx) body (some accTy)
      applyExpected expected accTy
  | .natFold idxName accName accTy init n body => do
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ctx n (some .u32)
      discard <| typeOfExpected ((idxName, .u32) :: (accName, accTy) :: ctx) body (some accTy)
      applyExpected expected accTy
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

  branchCtx (ctx : List RArg) (payloadTypes : List RType) (binders : List String) : Except CompatibilityReport (List RArg) := do
    if payloadTypes.length == binders.length then
      pure (binders.zip payloadTypes ++ ctx)
    else
      throw (report .unsupportedExpression "enum match branch has the wrong number of payload binders")

  typeEnumBranchWithExpected (ctx : List RArg) (variants : List (String × List RType)) (branch : (String × (List String × SurfaceExpr))) (expected : Option RType) : Except CompatibilityReport RType := do
    match lookupVariant variants branch.1 with
    | none => throw (report .unsupportedExpression ("enum match contains unknown variant `" ++ branch.1 ++ "`"))
    | some payloadTypes => do
        let ctx' ← branchCtx ctx payloadTypes branch.2.1
        typeOfExpected ctx' branch.2.2 expected

  typeEnumBranchesWithExpected (ctx : List RArg) (variants : List (String × List RType)) (branches : List (String × (List String × SurfaceExpr))) (expected : Option RType) : Except CompatibilityReport RType := do
    match branches with
    | [] => throw (report .unsupportedExpression "enum match has no branches")
    | first :: rest =>
        match expected with
        | some wanted =>
            discard <| typeEnumBranchWithExpected ctx variants first (some wanted)
            for branch in rest do
              discard <| typeEnumBranchWithExpected ctx variants branch (some wanted)
            pure wanted
        | none => do
            let firstTy ← typeEnumBranchWithExpected ctx variants first none
            for branch in rest do
              discard <| typeEnumBranchWithExpected ctx variants branch (some firstTy)
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

/-!
## Surface evaluator

This evaluator is the step-3 semantic model for the extracted `SurfaceExpr`
subset.  It deliberately interprets the same first-order Rust-shaped nodes that
the string emitter consumes, including structs, enums with payload binders,
`Option`, `Result`, and first-order calls between exported functions.

The evaluator is dynamic rather than dependently typed because `SurfaceExpr` is
the checked-but-not-intrinsically-typed layer.  `checkSurfaceFun` remains the
front-door typing gate, and the evaluator repeats enough shape checks to produce
stable diagnostics for differential fixtures.
-/

/-- Runtime values for the checked extracted surface subset. -/
inductive SurfaceValue where
  | unit : SurfaceValue
  | bool : Bool → SurfaceValue
  | u32 : Nat → SurfaceValue
  | u64 : Nat → SurfaceValue
  | i32 : Int → SurfaceValue
  | i64 : Int → SurfaceValue
  | char : Char → SurfaceValue
  | string : String → SurfaceValue
  | list : List SurfaceValue → SurfaceValue
  | array : List SurfaceValue → SurfaceValue
  | prodVal : SurfaceValue → SurfaceValue → SurfaceValue
  | sumInl : SurfaceValue → SurfaceValue
  | sumInr : SurfaceValue → SurfaceValue
  | optionNone : RType → SurfaceValue
  | optionSome : SurfaceValue → SurfaceValue
  | resultOk : SurfaceValue → SurfaceValue
  | resultErr : SurfaceValue → SurfaceValue
  | structVal : String → List (String × SurfaceValue) → SurfaceValue
  | enumVal : String → String → List SurfaceValue → SurfaceValue
  deriving Repr, BEq

/-- A dynamic surface evaluator environment. -/
abbrev SurfaceEnv := List (String × SurfaceValue)

private def lookupValue (ctx : SurfaceEnv) (name : String) : Option SurfaceValue :=
  match ctx with
  | [] => none
  | (candidate, value) :: rest => if candidate == name then some value else lookupValue rest name

private def lookupFieldValue (fields : List (String × SurfaceValue)) (name : String) : Option SurfaceValue :=
  match fields with
  | [] => none
  | (candidate, value) :: rest => if candidate == name then some value else lookupFieldValue rest name

/-- Lookup a generated surface function by its Rust-facing name. -/
def lookupSurfaceFun? (fns : List SurfaceFun) (name : String) : Option SurfaceFun :=
  match fns with
  | [] => none
  | f :: rest => if f.name == name then some f else lookupSurfaceFun? rest name

private def evalError (code : CompatibilityCode) (detail : String) : Except CompatibilityReport α :=
  throw { code := code, detail := detail }

private def checkedBool : SurfaceValue → Except CompatibilityReport Bool
  | .bool b => pure b
  | _ => evalError .unsupportedType "expected Bool during surface evaluation"

private def checkedU32 : SurfaceValue → Except CompatibilityReport Nat
  | .u32 n => pure (u32Wrap n)
  | _ => evalError .unsupportedType "expected UInt32 during surface evaluation"

private def checkedU64 : SurfaceValue → Except CompatibilityReport Nat
  | .u64 n => pure (u64Wrap n)
  | _ => evalError .unsupportedType "expected UInt64 during surface evaluation"

private def checkedI32 : SurfaceValue → Except CompatibilityReport Int
  | .i32 n => pure n
  | _ => evalError .unsupportedType "expected Int32 during surface evaluation"

private def checkedI64 : SurfaceValue → Except CompatibilityReport Int
  | .i64 n => pure n
  | _ => evalError .unsupportedType "expected Int64 during surface evaluation"

private def signedWrap (bits : Nat) (n : Int) : Int :=
  let modulus : Int := Int.ofNat (2 ^ bits)
  let half : Int := Int.ofNat (2 ^ (bits - 1))
  let r := n % modulus
  if r < half then r else r - modulus

def i32Wrap (n : Int) : Int := signedWrap 32 n

def i64Wrap (n : Int) : Int := signedWrap 64 n

mutual
  /-- Dynamic runtime-type check for evaluated surface values. -/
  partial def valueHasType : SurfaceValue → RType → Bool
    | .unit, .unit => true
    | .bool _, .bool => true
    | .u32 _, .u32 => true
    | .u64 _, .u64 => true
    | .i32 _, .i32 => true
    | .i64 _, .i64 => true
    | .char _, .char => true
    | .string _, .string => true
    | .list values, .list expected => values.all (fun value => valueHasType value expected)
    | .array values, .array expected => values.all (fun value => valueHasType value expected)
    | .prodVal a b, .prod expectedA expectedB => valueHasType a expectedA && valueHasType b expectedB
    | .sumInl value, .sum expectedA _ => valueHasType value expectedA
    | .sumInr value, .sum _ expectedB => valueHasType value expectedB
    | .optionNone inner, .option expected => inner == expected
    | .optionSome value, .option expected => valueHasType value expected
    | .resultOk value, .result okTy _ => valueHasType value okTy
    | .resultErr value, .result _ errTy => valueHasType value errTy
    | .structVal name fields, .struct expectedName expectedFields =>
        name == expectedName && valueHasTypeFields fields expectedFields
    | .enumVal name variant payload, .enum expectedName variants =>
        name == expectedName &&
        match lookupVariant variants variant with
        | some payloadTypes => valueHasTypeList payload payloadTypes
        | none => false
    | _, _ => false

  partial def valueHasTypeFields : List (String × SurfaceValue) → List RArg → Bool
    | [], [] => true
    | (name, value) :: values, (fieldName, fieldTy) :: fields =>
        name == fieldName && valueHasType value fieldTy && valueHasTypeFields values fields
    | _, _ => false

  partial def valueHasTypeList : List SurfaceValue → List RType → Bool
    | [], [] => true
    | value :: values, ty :: tys => valueHasType value ty && valueHasTypeList values tys
    | _, _ => false
end

private def assertValueType (value : SurfaceValue) (ty : RType) : Except CompatibilityReport Unit :=
  if valueHasType value ty then
    pure ()
  else
    evalError .unsupportedType ("surface value does not match expected type " ++ rTypeLabel ty)

private def bindSurfaceArgs (args : List RArg) (values : List SurfaceValue) : Except CompatibilityReport SurfaceEnv := do
  if args.length == values.length then
    let mut out : SurfaceEnv := []
    for pair in args.zip values do
      assertValueType pair.2 pair.1.2
      out := out ++ [(pair.1.1, pair.2)]
    pure out
  else
    evalError .unsupportedExpression "surface function called with the wrong number of arguments"

private def evalEq (ty : RType) (a b : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  assertValueType a ty
  assertValueType b ty
  pure (.bool (a == b))

private def evalOrdered (op : String) (ty : RType) (a b : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  match ty with
  | .u32 =>
      let av ← checkedU32 a
      let bv ← checkedU32 b
      pure (.bool (match op with
        | "<" => decide (av < bv)
        | "<=" => decide (av ≤ bv)
        | ">" => decide (av > bv)
        | ">=" => decide (av ≥ bv)
        | _ => false))
  | .u64 =>
      let av ← checkedU64 a
      let bv ← checkedU64 b
      pure (.bool (match op with
        | "<" => decide (av < bv)
        | "<=" => decide (av ≤ bv)
        | ">" => decide (av > bv)
        | ">=" => decide (av ≥ bv)
        | _ => false))
  | .i32 =>
      let av ← checkedI32 a
      let bv ← checkedI32 b
      pure (.bool (match op with
        | "<" => decide (av < bv)
        | "<=" => decide (av ≤ bv)
        | ">" => decide (av > bv)
        | ">=" => decide (av ≥ bv)
        | _ => false))
  | .i64 =>
      let av ← checkedI64 a
      let bv ← checkedI64 b
      pure (.bool (match op with
        | "<" => decide (av < bv)
        | "<=" => decide (av ≤ bv)
        | ">" => decide (av > bv)
        | ">=" => decide (av ≥ bv)
        | _ => false))
  | _ => evalError .unsupportedType ("ordered comparison is not enabled for " ++ rTypeLabel ty)

private def evalWrapping (op : String) (ty : RType) (a b : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  match ty with
  | .u32 =>
      let av ← checkedU32 a
      let bv ← checkedU32 b
      pure (.u32 (match op with
        | "add" => u32Wrap (av + bv)
        | "sub" => u32WrappingSub av bv
        | "mul" => u32Wrap (av * bv)
        | _ => av))
  | .u64 =>
      let av ← checkedU64 a
      let bv ← checkedU64 b
      pure (.u64 (match op with
        | "add" => u64Wrap (av + bv)
        | "sub" => u64WrappingSub av bv
        | "mul" => u64Wrap (av * bv)
        | _ => av))
  | .i32 =>
      let av ← checkedI32 a
      let bv ← checkedI32 b
      pure (.i32 (match op with
        | "add" => i32Wrap (av + bv)
        | "sub" => i32Wrap (av - bv)
        | "mul" => i32Wrap (av * bv)
        | _ => av))
  | .i64 =>
      let av ← checkedI64 a
      let bv ← checkedI64 b
      pure (.i64 (match op with
        | "add" => i64Wrap (av + bv)
        | "sub" => i64Wrap (av - bv)
        | "mul" => i64Wrap (av * bv)
        | _ => av))
  | _ => evalError .unsupportedType ("wrapping arithmetic is not enabled for " ++ rTypeLabel ty)

private def evalMinMax (chooseMax : Bool) (ty : RType) (a b : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  match ty with
  | .u32 =>
      let av ← checkedU32 a
      let bv ← checkedU32 b
      pure (.u32 (if chooseMax then (if av < bv then bv else av) else (if av < bv then av else bv)))
  | .u64 =>
      let av ← checkedU64 a
      let bv ← checkedU64 b
      pure (.u64 (if chooseMax then (if av < bv then bv else av) else (if av < bv then av else bv)))
  | .i32 =>
      let av ← checkedI32 a
      let bv ← checkedI32 b
      pure (.i32 (if chooseMax then (if av < bv then bv else av) else (if av < bv then av else bv)))
  | .i64 =>
      let av ← checkedI64 a
      let bv ← checkedI64 b
      pure (.i64 (if chooseMax then (if av < bv then bv else av) else (if av < bv then av else bv)))
  | _ => evalError .unsupportedType ("min/max is not enabled for " ++ rTypeLabel ty)

private def evalField (target : SurfaceValue) (fieldName : String) : Except CompatibilityReport SurfaceValue :=
  match target with
  | .structVal _ fields =>
      match lookupFieldValue fields fieldName with
      | some value => pure value
      | none => evalError .unsupportedExpression ("unknown evaluated struct field `" ++ fieldName ++ "`")
  | _ => evalError .unsupportedType "field projection target is not a struct value"

private def checkedStructFields (declared : List RArg) (provided : List (String × SurfaceValue)) : Except CompatibilityReport (List (String × SurfaceValue)) := do
  let mut out : List (String × SurfaceValue) := []
  for field in declared do
    match lookupFieldValue provided field.1 with
    | some value =>
        assertValueType value field.2
        out := out ++ [(field.1, value)]
    | none => evalError .unsupportedExpression ("surface struct literal is missing field `" ++ field.1 ++ "`")
  pure out

private def checkedPayloadValues (payloadTypes : List RType) (payload : List SurfaceValue) : Except CompatibilityReport (List SurfaceValue) := do
  if payloadTypes.length == payload.length then
    for pair in payloadTypes.zip payload do
      assertValueType pair.2 pair.1
    pure payload
  else
    evalError .unsupportedExpression "surface enum payload has the wrong number of values"

mutual
  /-- Evaluate a checked surface expression with bounded call fuel. -/
  partial def evalSurfaceExprWithFuel (fuel : Nat) (functions : List SurfaceFun) (env : SurfaceEnv) : SurfaceExpr → Except CompatibilityReport SurfaceValue
    | .var name =>
        match lookupValue env name with
        | some value => pure value
        | none => evalError .unsupportedExpression ("unbound surface evaluator variable `" ++ name ++ "`")
    | .litUnit => pure .unit
    | .litBool b => pure (.bool b)
    | .litU32 n => pure (.u32 (u32Wrap n))
    | .litU64 n => pure (.u64 (u64Wrap n))
    | .litI32 n => pure (.i32 (i32Wrap n))
    | .litI64 n => pure (.i64 (i64Wrap n))
    | .litChar c => pure (.char c)
    | .litString value => pure (.string value)
    | .letIn name value body => do
        let value' ← evalSurfaceExprWithFuel fuel functions env value
        evalSurfaceExprWithFuel fuel functions ((name, value') :: env) body
    | .ite c a b => do
        let cond ← checkedBool (← evalSurfaceExprWithFuel fuel functions env c)
        evalSurfaceExprWithFuel fuel functions env (if cond then a else b)
    | .matchBool c whenTrue whenFalse => do
        let cond ← checkedBool (← evalSurfaceExprWithFuel fuel functions env c)
        evalSurfaceExprWithFuel fuel functions env (if cond then whenTrue else whenFalse)
    | .matchOption target noneCase someName someCase => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .optionNone _ => evalSurfaceExprWithFuel fuel functions env noneCase
        | .optionSome value => evalSurfaceExprWithFuel fuel functions ((someName, value) :: env) someCase
        | _ => evalError .unsupportedType "Option match target is not an Option value"
    | .matchEnum enumTy target branches => do
        let targetValue ← evalSurfaceExprWithFuel fuel functions env target
        match enumTy, targetValue with
        | .enum enumName variants, .enumVal valueEnumName variant payload =>
            if enumName == valueEnumName then
              match lookupVariant variants variant, branches.find? (fun branch => branch.1 == variant) with
              | some payloadTypes, some branch => do
                  let payload' ← checkedPayloadValues payloadTypes payload
                  if payload'.length == branch.2.1.length then
                    let branchEnv := branch.2.1.zip payload' ++ env
                    evalSurfaceExprWithFuel fuel functions branchEnv branch.2.2
                  else
                    evalError .unsupportedExpression "surface enum match branch binder count does not match payload"
              | _, none => evalError .unsupportedExpression ("surface enum match has no branch for `" ++ variant ++ "`")
              | none, _ => evalError .unsupportedExpression ("surface enum value carries unknown variant `" ++ variant ++ "`")
            else
              evalError .unsupportedType ("surface enum value has type " ++ valueEnumName ++ " but match expected " ++ enumName)
        | _, _ => evalError .unsupportedType "enum match target is not an enum value"
    | .not a => pure (.bool (!(← checkedBool (← evalSurfaceExprWithFuel fuel functions env a))))
    | .and a b => do
        let av ← checkedBool (← evalSurfaceExprWithFuel fuel functions env a)
        if av then
          pure (.bool (← checkedBool (← evalSurfaceExprWithFuel fuel functions env b)))
        else
          pure (.bool false)
    | .or a b => do
        let av ← checkedBool (← evalSurfaceExprWithFuel fuel functions env a)
        if av then pure (.bool true) else pure (.bool (← checkedBool (← evalSurfaceExprWithFuel fuel functions env b)))
    | .eq ty a b => evalEq ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .lt ty a b => evalOrdered "<" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .le ty a b => evalOrdered "<=" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .gt ty a b => evalOrdered ">" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .ge ty a b => evalOrdered ">=" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .add ty a b => evalWrapping "add" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .sub ty a b => evalWrapping "sub" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .mul ty a b => evalWrapping "mul" ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .min ty a b => evalMinMax false ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .max ty a b => evalMinMax true ty (← evalSurfaceExprWithFuel fuel functions env a) (← evalSurfaceExprWithFuel fuel functions env b)
    | .optionNone inner => pure (.optionNone inner)
    | .optionSome a => pure (.optionSome (← evalSurfaceExprWithFuel fuel functions env a))
    | .resultOk _ a => pure (.resultOk (← evalSurfaceExprWithFuel fuel functions env a))
    | .resultErr _ e => pure (.resultErr (← evalSurfaceExprWithFuel fuel functions env e))
    | .structLit ty fields => do
        match ty with
        | .struct name declared =>
            let evaluated ← fields.mapM (fun field => do
              let value ← evalSurfaceExprWithFuel fuel functions env field.2
              pure (field.1, value))
            pure (.structVal name (← checkedStructFields declared evaluated))
        | _ => evalError .unsupportedType "surface struct literal does not carry a struct type"
    | .field target fieldName => evalField (← evalSurfaceExprWithFuel fuel functions env target) fieldName
    | .enumVariant ty variant payload => do
        match ty with
        | .enum name variants =>
            match lookupVariant variants variant with
            | some payloadTypes => do
                let evaluated ← payload.mapM (evalSurfaceExprWithFuel fuel functions env)
                pure (.enumVal name variant (← checkedPayloadValues payloadTypes evaluated))
            | none => evalError .unsupportedExpression ("surface enum constructor has unknown variant `" ++ variant ++ "`")
        | _ => evalError .unsupportedType "surface enum constructor does not carry an enum type"
    | .call name argTypes ret args => do
        match fuel with
        | 0 => evalError .unsupportedExpression ("surface evaluator call-fuel exhausted at `" ++ name ++ "`")
        | fuel' + 1 =>
            match lookupSurfaceFun? functions name with
            | none => evalError .unsupportedExpression ("surface evaluator cannot find function `" ++ name ++ "`")
            | some f => do
                let evaluatedArgs ← args.mapM (evalSurfaceExprWithFuel fuel functions env)
                let declaredArgTypes := f.args.map (fun arg => arg.2)
                if declaredArgTypes == argTypes && f.ret == ret then
                  evalSurfaceFunWithFuel fuel' functions f evaluatedArgs
                else
                  evalError .unsupportedType ("surface call signature for `" ++ name ++ "` does not match the function environment")
    | .callValue _ _ _ _ =>
        evalError .unsupportedExpression "surface evaluator does not interpret higher-order function values in differential tests"
    | .listMap binder elemTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            let mut out : List SurfaceValue := []
            for value in values do
              assertValueType value elemTy
              let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
              assertValueType mapped outTy
              out := out ++ [mapped]
            pure (.list out)
        | _ => evalError .unsupportedType "List.map target is not a List value"
    | .listFoldl accName elemName accTy elemTy init target body => do
        let initial ← evalSurfaceExprWithFuel fuel functions env init
        let mut acc := initial
        assertValueType acc accTy
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            for value in values do
              assertValueType value elemTy
              let next ← evalSurfaceExprWithFuel fuel functions ((elemName, value) :: (accName, acc) :: env) body
              assertValueType next accTy
              acc := next
            pure acc
        | _ => evalError .unsupportedType "List.foldl target is not a List value"
    | .natFold idxName accName accTy init n body => do
        let iterations ← checkedU32 (← evalSurfaceExprWithFuel fuel functions env n)
        if iterations > fuel then
          evalError .unsupportedExpression "surface evaluator structural-loop fuel exhausted during Nat.rec lowering"
        else
          let initial ← evalSurfaceExprWithFuel fuel functions env init
          let mut acc := initial
          assertValueType acc accTy
          for idx in List.range iterations do
            let next ← evalSurfaceExprWithFuel fuel functions ((idxName, .u32 idx) :: (accName, acc) :: env) body
            assertValueType next accTy
            acc := next
          pure acc

  /-- Evaluate a surface function from already-evaluated argument values. -/
  partial def evalSurfaceFunWithFuel (fuel : Nat) (functions : List SurfaceFun) (f : SurfaceFun) (values : List SurfaceValue) : Except CompatibilityReport SurfaceValue := do
    let env ← bindSurfaceArgs f.args values
    let value ← evalSurfaceExprWithFuel fuel functions env f.body
    assertValueType value f.ret
    pure value
end

/-- Default call-fuel budget for first-order calls, including generated recursive call cycles. -/
def defaultSurfaceEvalFuel (functions : List SurfaceFun) : Nat :=
  64 + functions.length * 8

/-- Evaluate a checked surface expression under the default call-fuel budget. -/
def evalSurfaceExpr (functions : List SurfaceFun) (env : SurfaceEnv) (expr : SurfaceExpr) : Except CompatibilityReport SurfaceValue :=
  evalSurfaceExprWithFuel (defaultSurfaceEvalFuel functions) functions env expr

/-- Evaluate a checked surface function under the default call-fuel budget. -/
def evalSurfaceFun (functions : List SurfaceFun) (f : SurfaceFun) (values : List SurfaceValue) : Except CompatibilityReport SurfaceValue :=
  evalSurfaceFunWithFuel (defaultSurfaceEvalFuel functions) functions f values

end LeanRustCore
