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

/-- General pattern tree for the Sprint-3/4 constructor-pattern compiler.
Patterns are checked against a known scrutinee type before Rust emission. -/
inductive SurfacePattern where
  | wildcard : SurfacePattern
  | var : String → SurfacePattern
  | unit : SurfacePattern
  | bool : Bool → SurfacePattern
  | optionNone : SurfacePattern
  | optionSome : SurfacePattern → SurfacePattern
  | enumCtor : String → List SurfacePattern → SurfacePattern
  | prod : SurfacePattern → SurfacePattern → SurfacePattern
  deriving Repr, BEq

inductive SurfaceExpr where
  | var : String → SurfaceExpr
  | litUnit : SurfaceExpr
  | litBool : Bool → SurfaceExpr
  | litNat : Nat → SurfaceExpr
  | litInt : Int → SurfaceExpr
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
  | matchPattern : RType → SurfaceExpr → List (SurfacePattern × SurfaceExpr) → SurfaceExpr
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
  | compare : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | optionNone : RType → SurfaceExpr
  | optionSome : SurfaceExpr → SurfaceExpr
  | resultOk : RType → SurfaceExpr → SurfaceExpr
  | resultErr : RType → SurfaceExpr → SurfaceExpr
  | prodLit : SurfaceExpr → SurfaceExpr → SurfaceExpr
  | structLit : RType → List (String × SurfaceExpr) → SurfaceExpr
  | field : SurfaceExpr → String → SurfaceExpr
  | enumVariant : RType → String → List SurfaceExpr → SurfaceExpr
  | call : String → List RType → RType → List SurfaceExpr → SurfaceExpr
  | callValue : SurfaceExpr → RType → RType → SurfaceExpr → SurfaceExpr
  | boxNew : RType → SurfaceExpr → SurfaceExpr
  | boxDeref : RType → SurfaceExpr → SurfaceExpr
  | closureApply : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | defaultValue : RType → SurfaceExpr
  | toStringValue : RType → SurfaceExpr → SurfaceExpr
  | reprValue : RType → SurfaceExpr → SurfaceExpr
  | listMap : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listFilter : String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listFoldl : String → String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listFoldr : String → String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listAny : String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listAll : String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listAppend : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listFind : String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | arrayMap : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | arrayFoldl : String → String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | arrayPush : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | optionMap : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | optionBind : String → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | resultMapOk : String → RType → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | resultMapErr : String → RType → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | resultBind : String → RType → RType → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | subtypeErase : RType → SurfaceExpr → SurfaceExpr
  | subtypeVal : RType → SurfaceExpr → SurfaceExpr
  | finCheck : Nat → SurfaceExpr → SurfaceExpr
  | finMk : Nat → SurfaceExpr → SurfaceExpr
  | finVal : Nat → SurfaceExpr → SurfaceExpr
  | vectorCheck : RType → Nat → SurfaceExpr → SurfaceExpr
  | vectorErase : RType → Nat → SurfaceExpr → SurfaceExpr
  | vectorMap : String → RType → RType → Nat → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | listLength : RType → SurfaceExpr → SurfaceExpr
  | natFold : String → String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
  | tailRecNat : String → String → RType → SurfaceExpr → SurfaceExpr → SurfaceExpr → SurfaceExpr
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
  | .ordering => "Ordering"
  | .nat => "Nat"
  | .int => "Int"
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
  | .boxed t => "Box<" ++ rTypeLabel t ++ ">"
  | .recursive name => name
  | .subtype t => "Subtype<" ++ rTypeLabel t ++ ">"
  | .fin n => "Fin<" ++ toString n ++ ">"
  | .vector t n => "Vector<" ++ rTypeLabel t ++ "," ++ toString n ++ ">"
  | .struct name _ => name
  | .enum name _ => name

private partial def sameRuntimeType : RType → RType → Bool
  | .recursive a, .recursive b => a == b
  | .recursive a, .enum b _ => a == b
  | .enum a _, .recursive b => a == b
  | .boxed a, .boxed b => sameRuntimeType a b
  | .subtype a, b => sameRuntimeType a b
  | a, .subtype b => sameRuntimeType a b
  | a, b => a == b

private def applyExpected (expected : Option RType) (actual : RType) : Except CompatibilityReport RType :=
  match expected with
  | none => pure actual
  | some wanted =>
      if sameRuntimeType wanted actual then
        pure wanted
      else
        throw (report .unsupportedType ("expected " ++ rTypeLabel wanted ++ " but found " ++ rTypeLabel actual))

private def isEqType : RType → Bool
  | .unit => true
  | .bool => true
  | .ordering => true
  | .nat => true
  | .int => true
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | .char => true
  | .string => true
  | .subtype t => isEqType t
  | .fin _ => true
  | .vector t _ => isEqType t
  | .boxed t => isEqType t
  | .recursive _ => true
  | .enum _ variants => variants.all (fun v => v.2.isEmpty)
  | _ => false

private def isOrderedType : RType → Bool
  | .nat => true
  | .int => true
  | .u32 => true
  | .u64 => true
  | .i32 => true
  | .i64 => true
  | .subtype t => isOrderedType t
  | .fin _ => true
  | .recursive _ => true
  | _ => false

private def isWrappingNumericType : RType → Bool
  | .nat => true
  | .int => true
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

private partial def patternBinders (pat : SurfacePattern) (ty : RType) : Except CompatibilityReport (List RArg) :=
  match pat, ty with
  | .wildcard, _ => pure []
  | .var name, ty => pure [(name, ty)]
  | .unit, .unit => pure []
  | .bool _, .bool => pure []
  | .optionNone, .option _ => pure []
  | .optionSome innerPat, .option innerTy => patternBinders innerPat innerTy
  | .enumCtor variant payloadPats, .enum _ variants =>
      match lookupVariant variants variant with
      | none => throw (report .unsupportedExpression ("pattern refers to unknown enum variant `" ++ variant ++ "`"))
      | some payloadTypes => patternBinderList payloadPats payloadTypes
  | .prod aPat bPat, .prod aTy bTy => do
      let a ← patternBinders aPat aTy
      let b ← patternBinders bPat bTy
      pure (a ++ b)
  | _, ty => throw (report .unsupportedType ("pattern is not compatible with scrutinee type " ++ rTypeLabel ty))
where
  patternBinderList (pats : List SurfacePattern) (tys : List RType) : Except CompatibilityReport (List RArg) := do
    if pats.length == tys.length then
      let mut out : List RArg := []
      for pair in pats.zip tys do
        out := out ++ (← patternBinders pair.1 pair.2)
      pure out
    else
      throw (report .unsupportedExpression "constructor pattern has the wrong payload arity")

private def patternBinderNames : List RArg → List String :=
  List.map (fun arg => arg.1)

private def ensureNoDuplicatePatternBinders (binders : List RArg) : Except CompatibilityReport Unit :=
  let names := patternBinderNames binders
  if names.eraseDups.length == names.length then
    pure ()
  else
    throw (report .unsupportedExpression "pattern introduces a duplicate binder")

private partial def patternCoversAll : SurfacePattern → Bool
  | .wildcard | .var _ => true
  | _ => false

private partial def patternCoversBool (wanted : Bool) : SurfacePattern → Bool
  | .wildcard | .var _ => true
  | .bool b => b == wanted
  | _ => false

private partial def patternCoversOptionNone : SurfacePattern → Bool
  | .wildcard | .var _ => true
  | .optionNone => true
  | _ => false

private partial def patternCoversOptionSome : SurfacePattern → Bool
  | .wildcard | .var _ => true
  | .optionSome _ => true
  | _ => false

private partial def patternCoversEnumVariant (variant : String) : SurfacePattern → Bool
  | .wildcard | .var _ => true
  | .enumCtor name _ => name == variant
  | _ => false

private def patternsExhaustive (scrutTy : RType) (patterns : List SurfacePattern) : Bool :=
  if patterns.any patternCoversAll then
    true
  else
    match scrutTy with
    | .unit => patterns.any (fun p => p == .unit)
    | .bool => patterns.any (patternCoversBool true) && patterns.any (patternCoversBool false)
    | .option _ => patterns.any patternCoversOptionNone && patterns.any patternCoversOptionSome
    | .enum _ variants => variants.all (fun variant => patterns.any (patternCoversEnumVariant variant.1))
    | .prod _ _ => patterns.any (fun p => match p with | .prod _ _ => true | _ => false)
    | _ => false

/-- Type check the extracted first-order surface tree, using an expected type when it disambiguates constructors. -/
partial def typeOfExpected (ctx : List RArg) (expr : SurfaceExpr) (expected : Option RType) : Except CompatibilityReport RType :=
  match expr with
  | .var name =>
      match lookupType ctx name with
      | some ty => applyExpected expected ty
      | none => throw (report .unsupportedExpression ("unbound extracted variable `" ++ name ++ "`"))
  | .litUnit => applyExpected expected .unit
  | .litBool _ => applyExpected expected .bool
  | .litNat _ => applyExpected expected .nat
  | .litInt _ => applyExpected expected .int
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
  | .matchPattern scrutTy target arms => do
      checkExpected ctx target scrutTy
      typePatternBranchesWithExpected ctx scrutTy arms expected
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
  | .compare t a b => do
      if isOrderedType t then expectPair ctx t a b *> applyExpected expected .ordering else throw (report .unsupportedType ("Ord.compare is not enabled for " ++ rTypeLabel t))
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
  | .prodLit a b => do
      match expected with
      | some (.prod aTy bTy) =>
          discard <| typeOfExpected ctx a (some aTy)
          discard <| typeOfExpected ctx b (some bTy)
          pure (.prod aTy bTy)
      | some other => throw (report .unsupportedType ("expected " ++ rTypeLabel other ++ " but found product literal"))
      | none => do
          let aTy ← typeOfExpected ctx a none
          let bTy ← typeOfExpected ctx b none
          pure (.prod aTy bTy)
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
  | .boxNew inner value => do
      discard <| typeOfExpected ctx value (some inner)
      applyExpected expected (.boxed inner)
  | .boxDeref inner value => do
      discard <| typeOfExpected ctx value (some (.boxed inner))
      applyExpected expected inner
  | .closureApply binder argTy retTy arg body => do
      discard <| typeOfExpected ctx arg (some argTy)
      discard <| typeOfExpected ((binder, argTy) :: ctx) body (some retTy)
      applyExpected expected retTy
  | .defaultValue ty => applyExpected expected ty
  | .toStringValue ty value => do
      discard <| typeOfExpected ctx value (some ty)
      applyExpected expected .string
  | .reprValue ty value => do
      discard <| typeOfExpected ctx value (some ty)
      applyExpected expected .string
  | .listMap binder elemTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) body (some outTy)
      applyExpected expected (.list outTy)
  | .listFilter binder elemTy target predicate => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) predicate (some .bool)
      applyExpected expected (.list elemTy)
  | .listFoldl accName elemName accTy elemTy init target body => do
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((elemName, elemTy) :: (accName, accTy) :: ctx) body (some accTy)
      applyExpected expected accTy
  | .listFoldr elemName accName elemTy accTy target init body => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ((accName, accTy) :: (elemName, elemTy) :: ctx) body (some accTy)
      applyExpected expected accTy
  | .listAny binder elemTy target predicate => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) predicate (some .bool)
      applyExpected expected .bool
  | .listAll binder elemTy target predicate => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) predicate (some .bool)
      applyExpected expected .bool
  | .listAppend elemTy left right => do
      discard <| typeOfExpected ctx left (some (.list elemTy))
      discard <| typeOfExpected ctx right (some (.list elemTy))
      applyExpected expected (.list elemTy)
  | .listFind binder elemTy target predicate => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) predicate (some .bool)
      applyExpected expected (.option elemTy)
  | .arrayMap binder elemTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.array elemTy))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) body (some outTy)
      applyExpected expected (.array outTy)
  | .arrayFoldl accName elemName accTy elemTy init target body => do
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ctx target (some (.array elemTy))
      discard <| typeOfExpected ((elemName, elemTy) :: (accName, accTy) :: ctx) body (some accTy)
      applyExpected expected accTy
  | .arrayPush elemTy target value => do
      discard <| typeOfExpected ctx target (some (.array elemTy))
      discard <| typeOfExpected ctx value (some elemTy)
      applyExpected expected (.array elemTy)
  | .optionMap binder innerTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.option innerTy))
      discard <| typeOfExpected ((binder, innerTy) :: ctx) body (some outTy)
      applyExpected expected (.option outTy)
  | .optionBind binder innerTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.option innerTy))
      discard <| typeOfExpected ((binder, innerTy) :: ctx) body (some (.option outTy))
      applyExpected expected (.option outTy)
  | .resultMapOk binder errTy okTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.result okTy errTy))
      discard <| typeOfExpected ((binder, okTy) :: ctx) body (some outTy)
      applyExpected expected (.result outTy errTy)
  | .resultMapErr binder okTy errTy outErr target body => do
      discard <| typeOfExpected ctx target (some (.result okTy errTy))
      discard <| typeOfExpected ((binder, errTy) :: ctx) body (some outErr)
      applyExpected expected (.result okTy outErr)
  | .resultBind binder errTy okTy outTy target body => do
      discard <| typeOfExpected ctx target (some (.result okTy errTy))
      discard <| typeOfExpected ((binder, okTy) :: ctx) body (some (.result outTy errTy))
      applyExpected expected (.result outTy errTy)
  | .subtypeErase inner value => do
      discard <| typeOfExpected ctx value (some inner)
      applyExpected expected (.subtype inner)
  | .subtypeVal inner value => do
      discard <| typeOfExpected ctx value (some (.subtype inner))
      applyExpected expected inner
  | .finCheck bound value => do
      discard <| typeOfExpected ctx value (some .u32)
      applyExpected expected (.option (.fin bound))
  | .finMk bound value => do
      discard <| typeOfExpected ctx value (some .u32)
      applyExpected expected (.fin bound)
  | .finVal bound value => do
      discard <| typeOfExpected ctx value (some (.fin bound))
      applyExpected expected .u32
  | .vectorCheck elemTy bound value => do
      discard <| typeOfExpected ctx value (some (.list elemTy))
      applyExpected expected (.option (.vector elemTy bound))
  | .vectorErase elemTy bound value => do
      discard <| typeOfExpected ctx value (some (.list elemTy))
      applyExpected expected (.vector elemTy bound)
  | .vectorMap binder elemTy outTy bound target body => do
      discard <| typeOfExpected ctx target (some (.vector elemTy bound))
      discard <| typeOfExpected ((binder, elemTy) :: ctx) body (some outTy)
      applyExpected expected (.vector outTy bound)
  | .listLength elemTy target => do
      discard <| typeOfExpected ctx target (some (.list elemTy))
      applyExpected expected .u32
  | .natFold idxName accName accTy init n body => do
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ctx n (some .u32)
      discard <| typeOfExpected ((idxName, .u32) :: (accName, accTy) :: ctx) body (some accTy)
      applyExpected expected accTy
  | .tailRecNat counterName accName accTy counter init body => do
      discard <| typeOfExpected ctx counter (some .u32)
      discard <| typeOfExpected ctx init (some accTy)
      discard <| typeOfExpected ((counterName, .u32) :: (accName, accTy) :: ctx) body (some accTy)
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


  typePatternBranchesWithExpected (ctx : List RArg) (scrutTy : RType) (arms : List (SurfacePattern × SurfaceExpr)) (expected : Option RType) : Except CompatibilityReport RType := do
    if arms.isEmpty then
      throw (report .unsupportedExpression "general pattern match has no branches")
    if !patternsExhaustive scrutTy (arms.map (fun arm => arm.1)) then
      throw (report .unsupportedExpression "general pattern match is not exhaustive for the supported pattern fragment")
    match arms with
    | [] => throw (report .unsupportedExpression "general pattern match has no branches")
    | first :: rest =>
        let firstBinders ← patternBinders first.1 scrutTy
        ensureNoDuplicatePatternBinders firstBinders
        match expected with
        | some wanted =>
            discard <| typeOfExpected (firstBinders ++ ctx) first.2 (some wanted)
            for arm in rest do
              let binders ← patternBinders arm.1 scrutTy
              ensureNoDuplicatePatternBinders binders
              discard <| typeOfExpected (binders ++ ctx) arm.2 (some wanted)
            pure wanted
        | none =>
            let firstTy ← typeOfExpected (firstBinders ++ ctx) first.2 none
            for arm in rest do
              let binders ← patternBinders arm.1 scrutTy
              ensureNoDuplicatePatternBinders binders
              discard <| typeOfExpected (binders ++ ctx) arm.2 (some firstTy)
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
  | ordering : Ordering → SurfaceValue
  | nat : Nat → SurfaceValue
  | int : Int → SurfaceValue
  | u32 : Nat → SurfaceValue
  | u64 : Nat → SurfaceValue
  | i32 : Int → SurfaceValue
  | i64 : Int → SurfaceValue
  | char : Char → SurfaceValue
  | string : String → SurfaceValue
  | list : List SurfaceValue → SurfaceValue
  | array : List SurfaceValue → SurfaceValue
  | fin : Nat → Nat → SurfaceValue
  | vector : Nat → List SurfaceValue → SurfaceValue
  | prodVal : SurfaceValue → SurfaceValue → SurfaceValue
  | sumInl : SurfaceValue → SurfaceValue
  | sumInr : SurfaceValue → SurfaceValue
  | optionNone : RType → SurfaceValue
  | optionSome : SurfaceValue → SurfaceValue
  | resultOk : SurfaceValue → SurfaceValue
  | resultErr : SurfaceValue → SurfaceValue
  | structVal : String → List (String × SurfaceValue) → SurfaceValue
  | enumVal : String → String → List SurfaceValue → SurfaceValue
  | boxed : SurfaceValue → SurfaceValue
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

private def checkedNat : SurfaceValue → Except CompatibilityReport Nat
  | .nat n => pure n
  | _ => evalError .unsupportedType "expected exact Nat during surface evaluation"

private def checkedInt : SurfaceValue → Except CompatibilityReport Int
  | .int n => pure n
  | _ => evalError .unsupportedType "expected exact Int during surface evaluation"

private def checkedU32 : SurfaceValue → Except CompatibilityReport Nat
  | .u32 n => pure (u32Wrap n)
  | .fin _ n => pure (u32Wrap n)
  | _ => evalError .unsupportedType "expected UInt32 during surface evaluation"

private partial def evalTreeSumWorklist (root : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  let mut total := 0
  let mut worklist := [root]
  while !worklist.isEmpty do
    match worklist with
    | [] => pure ()
    | current :: rest =>
        worklist := rest
        match current with
        | .enumVal "BinaryTreeU32" "leaf" [] => pure ()
        | .enumVal "BinaryTreeU32" "node" [.boxed left, .u32 value, .boxed right] => do
            total := u32Wrap (total + value)
            worklist := left :: right :: worklist
        | _ =>
            evalError .unsupportedType "tree_sum_worklist_u32 expected BinaryTreeU32 runtime values"
  pure (.u32 total)

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
    | .ordering _, .ordering => true
    | .nat _, .nat => true
    | .int _, .int => true
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
    | .enumVal name _ _, .recursive expectedName => name == expectedName
    | .boxed value, .boxed expected => valueHasType value expected
    | value, .subtype expected => valueHasType value expected
    | .fin actualBound value, .fin expectedBound => actualBound == expectedBound && value < expectedBound
    | .u32 value, .fin bound => value < bound
    | .vector actualBound values, .vector expected bound =>
        actualBound == bound && values.length == bound && values.all (fun value => valueHasType value expected)
    | .list values, .vector expected bound => values.length == bound && values.all (fun value => valueHasType value expected)
    | .array values, .vector expected bound => values.length == bound && values.all (fun value => valueHasType value expected)
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

private partial def defaultSurfaceValue (ty : RType) : Except CompatibilityReport SurfaceValue :=
  match ty with
  | .unit => pure .unit
  | .bool => pure (.bool false)
  | .ordering => pure (.ordering Ordering.eq)
  | .nat => pure (.nat 0)
  | .int => pure (.int 0)
  | .u32 => pure (.u32 0)
  | .u64 => pure (.u64 0)
  | .i32 => pure (.i32 0)
  | .i64 => pure (.i64 0)
  | .char => pure (.char (Char.ofNat 0))
  | .string => pure (.string "")
  | .option inner => pure (.optionNone inner)
  | .list _ => pure (.list [])
  | .array _ => pure (.array [])
  | .vector elem len => do
      let value ← defaultSurfaceValue elem
      pure (.list (List.replicate len value))
  | .boxed inner => do
      pure (.boxed (← defaultSurfaceValue inner))
  | .recursive name => evalError .unsupportedType ("recursive type " ++ name ++ " has no synthesized default value")
  | .fin 0 => evalError .unsupportedType "Fin 0 has no inhabited runtime value"
  | .fin bound => pure (.u32 0)
  | .prod a b => do
      let av ← defaultSurfaceValue a
      let bv ← defaultSurfaceValue b
      pure (.prodVal av bv)
  | .sum a _ => do
      let av ← defaultSurfaceValue a
      pure (.sumInl av)
  | .result _ err => do
      let errValue ← defaultSurfaceValue err
      pure (.resultErr errValue)
  | .subtype inner => defaultSurfaceValue inner
  | .struct name fields => do
      let values ← fields.mapM (fun field => do
        let value ← defaultSurfaceValue field.2
        pure (field.1, value))
      pure (.structVal name values)
  | .enum name variants =>
      match variants with
      | [] => evalError .unsupportedType ("enum " ++ name ++ " has no default variant")
      | (variant, payloadTypes) :: _ => do
          let payload ← payloadTypes.mapM defaultSurfaceValue
          pure (.enumVal name variant payload)
  | .func _ _ => evalError .unsupportedType "function values do not have a generated default"

private def orderingString : Ordering → String
  | Ordering.lt => "Less"
  | Ordering.eq => "Equal"
  | Ordering.gt => "Greater"

private def boolString (b : Bool) : String :=
  if b then "true" else "false"

private partial def surfaceValueToString (ty : RType) (value : SurfaceValue) : Except CompatibilityReport String := do
  assertValueType value ty
  match ty, value with
  | .unit, .unit => pure "()"
  | .bool, .bool b => pure (boolString b)
  | .ordering, .ordering o => pure (orderingString o)
  | .nat, .nat n => pure (toString n)
  | .int, .int n => pure (toString n)
  | .u32, .u32 n => pure (toString (u32Wrap n))
  | .u64, .u64 n => pure (toString (u64Wrap n))
  | .i32, .i32 n => pure (toString (i32Wrap n))
  | .i64, .i64 n => pure (toString (i64Wrap n))
  | .char, .char c => pure (String.singleton c)
  | .string, .string s => pure s
  | .fin _, .u32 n => pure (toString n)
  | .subtype inner, _ => surfaceValueToString inner value
  | _, _ => evalError .unsupportedType ("ToString/Repr is not enabled for " ++ rTypeLabel ty)

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
  | .nat =>
      let av ← checkedNat a
      let bv ← checkedNat b
      pure (.nat (match op with
        | "add" => av + bv
        | "sub" => if av < bv then 0 else av - bv
        | "mul" => av * bv
        | _ => av))
  | .int =>
      let av ← checkedInt a
      let bv ← checkedInt b
      pure (.int (match op with
        | "add" => av + bv
        | "sub" => av - bv
        | "mul" => av * bv
        | _ => av))
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
  | _ => evalError .unsupportedType ("arithmetic is not enabled for " ++ rTypeLabel ty)

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


private def evalCompare (ty : RType) (a b : SurfaceValue) : Except CompatibilityReport SurfaceValue := do
  match ty with
  | .nat =>
      let av ← checkedNat a
      let bv ← checkedNat b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | .int =>
      let av ← checkedInt a
      let bv ← checkedInt b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | .u32 =>
      let av ← checkedU32 a
      let bv ← checkedU32 b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | .u64 =>
      let av ← checkedU64 a
      let bv ← checkedU64 b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | .i32 =>
      let av ← checkedI32 a
      let bv ← checkedI32 b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | .i64 =>
      let av ← checkedI64 a
      let bv ← checkedI64 b
      pure (.ordering (if av < bv then Ordering.lt else if av == bv then Ordering.eq else Ordering.gt))
  | _ => evalError .unsupportedType ("compare is not enabled for " ++ rTypeLabel ty)

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

private partial def matchPatternValue (pat : SurfacePattern) (value : SurfaceValue) : Option SurfaceEnv :=
  match pat, value with
  | .wildcard, _ => some []
  | .var name, value => some [(name, value)]
  | .unit, .unit => some []
  | .bool wanted, .bool actual => if wanted == actual then some [] else none
  | .optionNone, .optionNone _ => some []
  | .optionSome innerPat, .optionSome innerValue => matchPatternValue innerPat innerValue
  | .enumCtor wanted payloadPats, .enumVal _ actual payloadValues =>
      if wanted == actual && payloadPats.length == payloadValues.length then
        matchPatternList payloadPats payloadValues
      else
        none
  | .prod aPat bPat, .prodVal a b => do
      let aEnv ← matchPatternValue aPat a
      let bEnv ← matchPatternValue bPat b
      some (aEnv ++ bEnv)
  | _, _ => none
where
  matchPatternList (pats : List SurfacePattern) (values : List SurfaceValue) : Option SurfaceEnv :=
    match pats, values with
    | [], [] => some []
    | pat :: pats, value :: values => do
        let head ← matchPatternValue pat value
        let tail ← matchPatternList pats values
        some (head ++ tail)
    | _, _ => none

mutual
  /-- Evaluate a checked surface expression with bounded call fuel. -/
  partial def evalSurfaceExprWithFuel (fuel : Nat) (functions : List SurfaceFun) (env : SurfaceEnv) : SurfaceExpr → Except CompatibilityReport SurfaceValue
    | .var name =>
        match lookupValue env name with
        | some value => pure value
        | none => evalError .unsupportedExpression ("unbound surface evaluator variable `" ++ name ++ "`")
    | .litUnit => pure .unit
    | .litBool b => pure (.bool b)
    | .litNat n => pure (.nat n)
    | .litInt n => pure (.int n)
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
    | .matchPattern scrutTy target arms => do
        let targetValue ← evalSurfaceExprWithFuel fuel functions env target
        assertValueType targetValue scrutTy
        let rec evalArms : List (SurfacePattern × SurfaceExpr) → Except CompatibilityReport SurfaceValue
          | [] => evalError .unsupportedExpression "general pattern match reached a non-exhaustive runtime value"
          | arm :: rest =>
              match matchPatternValue arm.1 targetValue with
              | some bindings => evalSurfaceExprWithFuel fuel functions (bindings ++ env) arm.2
              | none => evalArms rest
        evalArms arms
    | .not a => do
        let value ← checkedBool (← evalSurfaceExprWithFuel fuel functions env a)
        pure (.bool (!value))
    | .and a b => do
        let av ← checkedBool (← evalSurfaceExprWithFuel fuel functions env a)
        if av then
          pure (.bool (← checkedBool (← evalSurfaceExprWithFuel fuel functions env b)))
        else
          pure (.bool false)
    | .or a b => do
        let av ← checkedBool (← evalSurfaceExprWithFuel fuel functions env a)
        if av then pure (.bool true) else pure (.bool (← checkedBool (← evalSurfaceExprWithFuel fuel functions env b)))
    | .eq ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalEq ty av bv
    | .lt ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalOrdered "<" ty av bv
    | .le ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalOrdered "<=" ty av bv
    | .gt ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalOrdered ">" ty av bv
    | .ge ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalOrdered ">=" ty av bv
    | .add ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalWrapping "add" ty av bv
    | .sub ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalWrapping "sub" ty av bv
    | .mul ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalWrapping "mul" ty av bv
    | .min ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalMinMax false ty av bv
    | .max ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalMinMax true ty av bv
    | .compare ty a b => do
        let av ← evalSurfaceExprWithFuel fuel functions env a
        let bv ← evalSurfaceExprWithFuel fuel functions env b
        evalCompare ty av bv
    | .optionNone inner => pure (.optionNone inner)
    | .optionSome a => do
        let value ← evalSurfaceExprWithFuel fuel functions env a
        pure (.optionSome value)
    | .resultOk _ a => do
        let value ← evalSurfaceExprWithFuel fuel functions env a
        pure (.resultOk value)
    | .resultErr _ e => do
        let value ← evalSurfaceExprWithFuel fuel functions env e
        pure (.resultErr value)
    | .prodLit a b => do
        let aValue ← evalSurfaceExprWithFuel fuel functions env a
        let bValue ← evalSurfaceExprWithFuel fuel functions env b
        pure (.prodVal aValue bValue)
    | .structLit ty fields => do
        match ty with
        | .struct name declared =>
            let evaluated ← fields.mapM (fun field => do
              let value ← evalSurfaceExprWithFuel fuel functions env field.2
              pure (field.1, value))
            pure (.structVal name (← checkedStructFields declared evaluated))
        | _ => evalError .unsupportedType "surface struct literal does not carry a struct type"
    | .field target fieldName => do
        let value ← evalSurfaceExprWithFuel fuel functions env target
        evalField value fieldName
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
            let evaluatedArgs ← args.mapM (evalSurfaceExprWithFuel fuel functions env)
            if name == "__runtime_list_prepend_u32" &&
                argTypes == [.u32, .list .u32] &&
                ret == .list .u32 then
              match evaluatedArgs with
              | [head, .list tail] => pure (.list (head :: tail))
              | _ => evalError .unsupportedType "list_prepend_u32 expected (u32, List<u32>)"
            else if name == "__runtime_list_head_or_default_u32" &&
                argTypes == [.list .u32, .u32] &&
                ret == .u32 then
              match evaluatedArgs with
              | [.list xs, .u32 fallback] =>
                  match xs with
                  | [] => pure (.u32 fallback)
                  | .u32 head :: _ => pure (.u32 head)
                  | _ => evalError .unsupportedType "list_head_or_default_u32 expected List<u32>"
              | _ => evalError .unsupportedType "list_head_or_default_u32 expected (List<u32>, u32)"
            else if name == "__runtime_list_second_or_default_u32" &&
                argTypes == [.list .u32, .u32] &&
                ret == .u32 then
              match evaluatedArgs with
              | [.list (.u32 _ :: .u32 second :: _), .u32 _] => pure (.u32 second)
              | [.list _, .u32 fallback] => pure (.u32 fallback)
              | _ => evalError .unsupportedType "list_second_or_default_u32 expected (List<u32>, u32)"
            else if name == "__runtime_tree_sum_worklist_u32" &&
                argTypes == [.enum "BinaryTreeU32" [
                  ("leaf", []),
                  ("node", [.boxed (.recursive "BinaryTreeU32"), .u32, .boxed (.recursive "BinaryTreeU32")])
                ]] &&
                ret == .u32 then
              match evaluatedArgs with
              | [tree] => evalTreeSumWorklist tree
              | _ => evalError .unsupportedType "tree_sum_worklist_u32 expected BinaryTreeU32"
            else
              match lookupSurfaceFun? functions name with
              | none => evalError .unsupportedExpression ("surface evaluator cannot find function `" ++ name ++ "`")
              | some f => do
                  let declaredArgTypes := f.args.map (fun arg => arg.2)
                  if declaredArgTypes == argTypes && f.ret == ret then
                    evalSurfaceFunWithFuel fuel' functions f evaluatedArgs
                  else
                    evalError .unsupportedType ("surface call signature for `" ++ name ++ "` does not match the function environment")
    | .callValue _ _ _ _ =>
        evalError .unsupportedExpression "surface evaluator does not interpret higher-order function values in differential tests"
    | .boxNew inner value => do
        let evaluated ← evalSurfaceExprWithFuel fuel functions env value
        assertValueType evaluated inner
        pure (.boxed evaluated)
    | .boxDeref inner value => do
        match (← evalSurfaceExprWithFuel fuel functions env value) with
        | .boxed innerValue => do
            assertValueType innerValue inner
            pure innerValue
        | _ => evalError .unsupportedType "Box dereference target is not a boxed surface value"
    | .closureApply binder argTy retTy arg body => do
        let value ← evalSurfaceExprWithFuel fuel functions env arg
        assertValueType value argTy
        let out ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
        assertValueType out retTy
        pure out
    | .defaultValue ty => defaultSurfaceValue ty
    | .toStringValue ty value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        pure (.string (← surfaceValueToString ty value))
    | .reprValue ty value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        pure (.string (← surfaceValueToString ty value))
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
    | .listFilter binder elemTy target predicate => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            let mut out : List SurfaceValue := []
            for value in values do
              assertValueType value elemTy
              let keep ← checkedBool (← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) predicate)
              if keep then out := out ++ [value] else pure ()
            pure (.list out)
        | _ => evalError .unsupportedType "List.filter target is not a List value"
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
    | .listFoldr elemName accName elemTy accTy target init body => do
        let initial ← evalSurfaceExprWithFuel fuel functions env init
        let mut acc := initial
        assertValueType acc accTy
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            for value in values.reverse do
              assertValueType value elemTy
              let next ← evalSurfaceExprWithFuel fuel functions ((accName, acc) :: (elemName, value) :: env) body
              assertValueType next accTy
              acc := next
            pure acc
        | _ => evalError .unsupportedType "List.foldr target is not a List value"
    | .listAny binder elemTy target predicate => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            let mut out := false
            for value in values do
              assertValueType value elemTy
              if (← checkedBool (← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) predicate)) then
                out := true
              else
                pure ()
            pure (.bool out)
        | _ => evalError .unsupportedType "List.any target is not a List value"
    | .listAll binder elemTy target predicate => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            let mut out := true
            for value in values do
              assertValueType value elemTy
              if !(← checkedBool (← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) predicate)) then
                out := false
              else
                pure ()
            pure (.bool out)
        | _ => evalError .unsupportedType "List.all target is not a List value"
    | .listAppend elemTy left right => do
        match (← evalSurfaceExprWithFuel fuel functions env left), (← evalSurfaceExprWithFuel fuel functions env right) with
        | .list leftValues, .list rightValues => do
            for value in leftValues do
              assertValueType value elemTy
            for value in rightValues do
              assertValueType value elemTy
            pure (.list (leftValues ++ rightValues))
        | _, _ => evalError .unsupportedType "List.append operands are not List values"
    | .listFind binder elemTy target predicate => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values => do
            for value in values do
              assertValueType value elemTy
              if (← checkedBool (← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) predicate)) then
                return .optionSome value
            pure (.optionNone elemTy)
        | _ => evalError .unsupportedType "List.find? target is not a List value"
    | .arrayMap binder elemTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .array values => do
            let mut out : List SurfaceValue := []
            for value in values do
              assertValueType value elemTy
              let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
              assertValueType mapped outTy
              out := out ++ [mapped]
            pure (.array out)
        | _ => evalError .unsupportedType "Array.map target is not an Array value"
    | .arrayFoldl accName elemName accTy elemTy init target body => do
        let initial ← evalSurfaceExprWithFuel fuel functions env init
        let mut acc := initial
        assertValueType acc accTy
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .array values => do
            for value in values do
              assertValueType value elemTy
              let next ← evalSurfaceExprWithFuel fuel functions ((elemName, value) :: (accName, acc) :: env) body
              assertValueType next accTy
              acc := next
            pure acc
        | _ => evalError .unsupportedType "Array.foldl target is not an Array value"
    | .arrayPush elemTy target value => do
        let pushed ← evalSurfaceExprWithFuel fuel functions env value
        assertValueType pushed elemTy
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .array values => do
            for entry in values do
              assertValueType entry elemTy
            pure (.array (values ++ [pushed]))
        | _ => evalError .unsupportedType "Array.push target is not an Array value"
    | .optionMap binder innerTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .optionNone _ => pure (.optionNone outTy)
        | .optionSome value => do
            assertValueType value innerTy
            let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
            assertValueType mapped outTy
            pure (.optionSome mapped)
        | _ => evalError .unsupportedType "Option.map target is not an Option value"
    | .optionBind binder innerTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .optionNone _ => pure (.optionNone outTy)
        | .optionSome value => do
            assertValueType value innerTy
            evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
        | _ => evalError .unsupportedType "Option.bind target is not an Option value"
    | .resultMapOk binder errTy okTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .resultErr value => do
            assertValueType value errTy
            pure (.resultErr value)
        | .resultOk value => do
            assertValueType value okTy
            let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
            assertValueType mapped outTy
            pure (.resultOk mapped)
        | _ => evalError .unsupportedType "Except.map target is not an Except/Result value"
    | .resultMapErr binder okTy errTy outErr target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .resultErr value => do
            assertValueType value errTy
            let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
            assertValueType mapped outErr
            pure (.resultErr mapped)
        | .resultOk value => do
            assertValueType value okTy
            pure (.resultOk value)
        | _ => evalError .unsupportedType "Except.mapError target is not an Except/Result value"
    | .resultBind binder errTy okTy outTy target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .resultErr value => do
            assertValueType value errTy
            pure (.resultErr value)
        | .resultOk value => do
            assertValueType value okTy
            evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
        | _ => evalError .unsupportedType "Except.bind target is not an Except/Result value"
    | .subtypeErase inner value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        assertValueType value inner
        pure value
    | .subtypeVal inner value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        assertValueType value (.subtype inner)
        pure value
    | .finCheck bound value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        let n ← checkedU32 value
        if n < bound then pure (.optionSome (.fin bound n)) else pure (.optionNone (.fin bound))
    | .finMk bound value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        let n ← checkedU32 value
        if n < bound then pure (.fin bound n) else evalError .unsupportedExpression "Fin.mk proof erasure saw a value outside its erased bound"
    | .finVal bound value => do
        let value ← evalSurfaceExprWithFuel fuel functions env value
        assertValueType value (.fin bound)
        match value with
        | .fin _ n => pure (.u32 n)
        | .u32 n => pure (.u32 n)
        | _ => evalError .unsupportedType "Fin.val expected a Fin-compatible carrier during surface evaluation"
    | .vectorCheck elemTy bound value => do
        match (← evalSurfaceExprWithFuel fuel functions env value) with
        | .list values =>
            if values.length == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.optionSome (.vector bound values))
            else
              pure (.optionNone (.vector elemTy bound))
        | .array values =>
            if values.length == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.optionSome (.vector bound values))
            else
              pure (.optionNone (.vector elemTy bound))
        | .vector valueBound values =>
            if valueBound == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.optionSome (.vector bound values))
            else
              pure (.optionNone (.vector elemTy bound))
        | _ => evalError .unsupportedType "Vector checked constructor needs a List/Array/Vector value"
    | .vectorErase elemTy bound value => do
        match (← evalSurfaceExprWithFuel fuel functions env value) with
        | .list values =>
            if values.length == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.vector bound values)
            else
              evalError .unsupportedType "Vector.mk proof erasure saw a payload whose runtime length/type does not match the erased Vector index"
        | .array values =>
            if values.length == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.vector bound values)
            else
              evalError .unsupportedType "Vector.mk proof erasure saw an Array payload whose runtime length/type does not match the erased Vector index"
        | .vector valueBound values =>
            if valueBound == bound && values.all (fun item => valueHasType item elemTy) then
              pure (.vector bound values)
            else
              evalError .unsupportedType "Vector.mk proof erasure saw a Vector payload with a mismatched erased index"
        | _ => evalError .unsupportedType "Vector.mk proof erasure needs a List/Array/Vector payload"
    | .vectorMap binder elemTy outTy bound target body => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .vector valueBound values => do
            if valueBound != bound then
              evalError .unsupportedType "Vector.map source length index did not match the expected bound"
            else
              let mut out : List SurfaceValue := []
              for value in values do
                assertValueType value elemTy
                let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
                assertValueType mapped outTy
                out := out ++ [mapped]
              pure (.vector bound out)
        | .list values => do
            if values.length != bound then
              evalError .unsupportedType "Vector.map erased carrier length did not match the expected bound"
            else
              let mut out : List SurfaceValue := []
              for value in values do
                assertValueType value elemTy
                let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
                assertValueType mapped outTy
                out := out ++ [mapped]
              pure (.vector bound out)
        | .array values => do
            if values.length != bound then
              evalError .unsupportedType "Vector.map erased array carrier length did not match the expected bound"
            else
              let mut out : List SurfaceValue := []
              for value in values do
                assertValueType value elemTy
                let mapped ← evalSurfaceExprWithFuel fuel functions ((binder, value) :: env) body
                assertValueType mapped outTy
                out := out ++ [mapped]
              pure (.vector bound out)
        | _ => evalError .unsupportedType "Vector.map target is not a Vector value"
    | .listLength elemTy target => do
        match (← evalSurfaceExprWithFuel fuel functions env target) with
        | .list values =>
            if values.all (fun item => valueHasType item elemTy) then
              pure (.u32 values.length)
            else
              evalError .unsupportedType "List.length target contains an element outside the expected type"
        | _ => evalError .unsupportedType "List.length target is not a List value"
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
    | .tailRecNat counterName accName accTy counter init body => do
        let iterations ← checkedU32 (← evalSurfaceExprWithFuel fuel functions env counter)
        if iterations > fuel then
          evalError .unsupportedExpression "surface evaluator tail-recursion fuel exhausted during Nat loop lowering"
        else
          let initialAcc ← evalSurfaceExprWithFuel fuel functions env init
          let mut acc := initialAcc
          let mut remaining := iterations
          assertValueType acc accTy
          for _ in List.range iterations do
            let next ← evalSurfaceExprWithFuel fuel functions ((counterName, .u32 remaining) :: (accName, acc) :: env) body
            assertValueType next accTy
            acc := next
            remaining := u32WrappingSub remaining 1
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
