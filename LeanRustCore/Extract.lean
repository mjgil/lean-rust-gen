import Lean
import LeanRustCore.EmitRust
import LeanRustCore.Export

namespace LeanRustCore.Extract

open Lean Elab Command
open LeanRustCore

structure Local where
  name : String
  ty : RType
  deriving Repr

/-- Type-parameter entries in de-Bruijn order. `none` means a term binder. -/
abbrev TypeCtx := List (Option RType)

/-- Term-local entries in de-Bruijn order. `none` means a type binder. -/
abbrev LocalCtx := List (Option Local)

/-- A requested concrete export of a generic Lean definition. -/
structure MonoExportSpec where
  source : Name
  rustName : String
  typeArgs : List RType
  deriving Repr, BEq

/-- Result item from the tolerant extractor used by compatibility reports. -/
structure ExportDiagnostic where
  source : String
  rustName : String
  code : CompatibilityCode
  detail : String
  deriving Repr, BEq

/-- Supported functions plus structured diagnostics for skipped/unsupported exports. -/
structure ExtractionResult where
  functions : List SurfaceFun
  diagnostics : List ExportDiagnostic
  deriving Repr, BEq

initialize monoExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []
initialize autoMonoExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []

private def nameLeaf : Name → String
  | .anonymous => "_"
  | .str _ s => s
  | .num p n => nameLeaf p ++ Nat.toString n

private def nameParent : Name → Name
  | .anonymous => .anonymous
  | .str p _ => p
  | .num p _ => p

private def sanitizeRustIdent (fallback : String) (s : String) : String :=
  LeanRustCore.sanitizeRustIdent fallback s

private def containsName : List Name → Name → Bool
  | [], _ => false
  | x :: xs, target => x == target || containsName xs target

private def localNameAt (locals : LocalCtx) (idx : Nat) : Except String String :=
  match locals.get? idx with
  | some (some local) => Except.ok local.name
  | some none => Except.error s!"de-Bruijn variable #{idx} is a type parameter, not a Rust value"
  | none => Except.error s!"unbound de-Bruijn variable #{idx} during extraction"

private def typeParamAt (typeCtx : TypeCtx) (idx : Nat) : CoreM RType := do
  match typeCtx.get? idx with
  | some (some ty) => pure ty
  | some none => throwError "dependent term variables in types are outside the current rust_export subset"
  | none => throwError "unbound type parameter #{idx} during monomorphization"

private partial def stripMData : Expr → Expr
  | .mdata _ inner => stripMData inner
  | other => other

private partial def peelForalls : Expr → List (Name × Expr) × Expr
  | .forallE n ty body _ =>
      let (rest, ret) := peelForalls body
      ((n, ty) :: rest, ret)
  | other => ([], other)

private partial def peelLambdas : Expr → List (Name × Expr) × Expr
  | .lam n ty body _ =>
      let (rest, finalBody) := peelLambdas body
      ((n, ty) :: rest, finalBody)
  | other => ([], other)

private def lastTwo {α : Type} : List α → Option (α × α)
  | [] => none
  | [_] => none
  | [a, b] => some (a, b)
  | _ :: xs => lastTwo xs

private def last? {α : Type} : List α → Option α
  | [] => none
  | [x] => some x
  | _ :: xs => last? xs

private def takeLast {α : Type} (n : Nat) (xs : List α) : List α :=
  xs.drop (xs.length - n)

private def natLiteral? (e : Expr) : Option Nat :=
  let e := stripMData e
  match e with
  | .lit (.natVal n) => some n
  | _ =>
      let fn := e.getAppFn
      let args := e.getAppArgs.toList
      match fn with
      | .const n _ =>
          if n == ``OfNat.ofNat then
            match args with
            | _ty :: (.lit (.natVal n)) :: _ => some n
            | _ => none
          else
            none
      | _ => none

private def boolLiteral? (e : Expr) : Option Bool :=
  let e := stripMData e
  match e with
  | .const n _ =>
      if n == ``Bool.true then some true
      else if n == ``Bool.false then some false
      else none
  | _ => none

private def unitLiteral? (e : Expr) : Bool :=
  let e := stripMData e
  match e with
  | .const n _ => toString n == "Unit.unit" || toString n == "PUnit.unit"
  | _ => false

private def isTypeParamBinder (ty : Expr) : Bool :=
  match stripMData ty with
  | .sort _ => true
  | _ => false

private def unsupported (e : Expr) : CoreM α :=
  throwError "unsupported Lean expression in rust_export extraction: {e}"

private def lookupRField (fields : List RArg) (fieldName : String) : Option RType :=
  match fields with
  | [] => none
  | (name, ty) :: rest => if name == fieldName then some ty else lookupRField rest fieldName

mutual
  partial def typeOfLeanWithCtx (typeCtx : TypeCtx) (ty0 : Expr) : CoreM RType := do
    let ty := stripMData ty0
    match ty with
    | .bvar idx => typeParamAt typeCtx idx
    | _ =>
        if ty.isConstOf ``Nat then
          return .u32
        else if ty.isConstOf ``Bool then
          return .bool
        else if ty.isConstOf ``Unit then
          return .unit
        else if ty.isConstOf ``UInt32 then
          return .u32
        else if ty.isConstOf ``UInt64 then
          return .u64
        else if ty.isConstOf ``Int32 then
          return .i32
        else if ty.isConstOf ``Int64 then
          return .i64
        else
          let fn := ty.getAppFn
          let args := ty.getAppArgs.toList
          match fn with
          | .const n _ =>
              if n == ``Option then
                match args with
                | [inner] => return .option (← typeOfLeanWithCtx typeCtx inner)
                | _ => throwError "unsupported Option type shape in rust_export extraction"
              else if n == ``Except then
                match args with
                | [errTy, okTy] => return .result (← typeOfLeanWithCtx typeCtx okTy) (← typeOfLeanWithCtx typeCtx errTy)
                | _ => throwError "unsupported Except type shape in rust_export extraction"
              else
                match (← getEnv).find? n with
                | some (.inductInfo _) => typeOfInductive n
                | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"
          | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"

  partial def typeOfLeanM (ty0 : Expr) : CoreM RType :=
    typeOfLeanWithCtx [] ty0

  partial def typeOfInductive (inductName : Name) : CoreM RType := do
    let env ← getEnv
    match env.find? inductName with
    | some (.inductInfo info) =>
        if info.numParams == 0 && info.numIndices == 0 then
          match info.ctors with
          | [ctorName] =>
              let fields ← ctorPayloadFields ctorName
              if fields.isEmpty then
                pure (.enum (nameLeaf inductName) [(nameLeaf ctorName, [])])
              else
                pure (.struct (nameLeaf inductName) fields)
          | ctors => do
              let variants ← ctors.mapM (fun ctorName => do
                let fields ← ctorPayloadFields ctorName
                pure (nameLeaf ctorName, fields.map (fun field => field.2)))
              pure (.enum (nameLeaf inductName) variants)
        else
          throwError "rust_export type lowering currently supports only closed, parameter-free inductives and structures; got {inductName}"
    | _ => throwError "expected inductive declaration for {inductName}"

  partial def ctorPayloadFields (ctorName : Name) : CoreM (List RArg) := do
    let env ← getEnv
    match env.find? ctorName with
    | some (.ctorInfo info) =>
        let (binders, _) := peelForalls info.type
        let fieldBinders := (binders.drop info.numParams).take info.numFields
        let mut out : List RArg := []
        let mut idx : Nat := 0
        for field in fieldBinders do
          let fallback := "field" ++ Nat.toString idx
          let fieldName := sanitizeRustIdent fallback (nameLeaf field.1)
          let fieldTy ← typeOfLeanM field.2
          out := out ++ [(fieldName, fieldTy)]
          idx := idx + 1
        pure out
    | _ => throwError "expected constructor declaration for {ctorName}"
end

/-- Signature lookup for first-order calls to other tagged non-generic Lean declarations. Generic calls are handled by automatic/explicit monomorphization below. -/
private def callSignature? (declName : Name) : CoreM (Option (List RType × RType)) := do
  let env ← getEnv
  if !containsName (LeanRustCore.Export.exportedNames env) declName then
    return none
  let info ← getConstInfo declName
  match info with
  | .defnInfo defInfo =>
      let (binders, retTyExpr) := peelForalls defInfo.type
      let mut argTypes : List RType := []
      let mut typeCtx : TypeCtx := []
      for binder in binders do
        if isTypeParamBinder binder.2 then
          return none
        let rty ← typeOfLeanWithCtx typeCtx binder.2
        argTypes := argTypes ++ [rty]
        typeCtx := none :: typeCtx
      let retTy ← typeOfLeanWithCtx typeCtx retTyExpr
      pure (some (argTypes, retTy))
  | _ => pure none

private partial def firstTypeArg? (typeCtx : TypeCtx) : List Expr → CoreM (Option RType)
  | [] => pure none
  | x :: xs => do
      try
        return some (← typeOfLeanWithCtx typeCtx x)
      catch _ =>
        firstTypeArg? typeCtx xs


private def lowerMonoChar : Char → Char
  | 'A' => 'a' | 'B' => 'b' | 'C' => 'c' | 'D' => 'd' | 'E' => 'e' | 'F' => 'f'
  | 'G' => 'g' | 'H' => 'h' | 'I' => 'i' | 'J' => 'j' | 'K' => 'k' | 'L' => 'l'
  | 'M' => 'm' | 'N' => 'n' | 'O' => 'o' | 'P' => 'p' | 'Q' => 'q' | 'R' => 'r'
  | 'S' => 's' | 'T' => 't' | 'U' => 'u' | 'V' => 'v' | 'W' => 'w' | 'X' => 'x'
  | 'Y' => 'y' | 'Z' => 'z'
  | c => c

private def lowerMonoString (s : String) : String :=
  String.mk (s.toList.map lowerMonoChar)

private partial def rTypeMonoSuffix : RType → String
  | .unit => "unit"
  | .bool => "bool"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .option t => "option_" ++ rTypeMonoSuffix t
  | .result ok err => "result_" ++ rTypeMonoSuffix ok ++ "_" ++ rTypeMonoSuffix err
  | .struct name _ => sanitizeRustIdent "struct" (lowerMonoString name)
  | .enum name _ => sanitizeRustIdent "enum" (lowerMonoString name)

private def autoMonoRustName (source : Name) (typeArgs : List RType) : String :=
  sanitizeRustIdent "generated" (nameLeaf source ++ "__" ++ joinWith "_" (typeArgs.map rTypeMonoSuffix))

private def sameMonoKey (source : Name) (typeArgs : List RType) (spec : MonoExportSpec) : Bool :=
  spec.source == source && spec.typeArgs == typeArgs

private def findMonoSpecByKey (source : Name) (typeArgs : List RType) : List MonoExportSpec → Option MonoExportSpec
  | [] => none
  | spec :: rest => if sameMonoKey source typeArgs spec then some spec else findMonoSpecByKey source typeArgs rest

private def registerAutoMonoSpec (source : Name) (typeArgs : List RType) : CoreM String := do
  let explicitSpecs ← liftIO monoExportSpecsRef.get
  match findMonoSpecByKey source typeArgs explicitSpecs with
  | some spec => pure spec.rustName
  | none => do
      let autoSpecs ← liftIO autoMonoExportSpecsRef.get
      match findMonoSpecByKey source typeArgs autoSpecs with
      | some spec => pure spec.rustName
      | none => do
          let rustName := autoMonoRustName source typeArgs
          let spec : MonoExportSpec := { source := source, rustName := rustName, typeArgs := typeArgs }
          liftIO <| autoMonoExportSpecsRef.modify (fun specs => specs ++ [spec])
          pure rustName

private def expectedOrTypeArg (typeCtx : TypeCtx) (expected : Option RType) (args : List Expr) (fallback : RType) : CoreM RType := do
  match expected with
  | some ty => pure ty
  | none =>
      match (← firstTypeArg? typeCtx args) with
      | some ty => pure ty
      | none => pure fallback

private def literalForExpected (expected : Option RType) (n : Nat) : SurfaceExpr :=
  match expected with
  | some .u64 => .litU64 n
  | some .i32 => .litI32 (Int.ofNat n)
  | some .i64 => .litI64 (Int.ofNat n)
  | _ => .litU32 n

private def isNamedRecursor (n : Name) (leaf : String) : Bool :=
  nameLeaf n == leaf

private partial def translateExpr (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e0 : Expr) : CoreM SurfaceExpr := do
  let e := stripMData e0
  if unitLiteral? e then
    return .litUnit
  if let some b := boolLiteral? e then
    return .litBool b
  if let some n := natLiteral? e then
    return literalForExpected expected n
  match e with
  | .bvar idx =>
      match localNameAt locals idx with
      | .ok name => return .var name
      | .error msg => throwError msg
  | .const n _ =>
      match (← translateConstructorApp? typeCtx locals expected n []) with
      | some expr => return expr
      | none => unsupported e
  | .letE n ty value body _ =>
      let rustName := sanitizeRustIdent "tmp" (nameLeaf n)
      let valueTy ← typeOfLeanWithCtx typeCtx ty
      let valueExpr ← translateExpr typeCtx locals (some valueTy) value
      let bodyExpr ← translateExpr (none :: typeCtx) (some { name := rustName, ty := valueTy } :: locals) expected body
      return .letIn rustName valueExpr bodyExpr
  | .app .. => translateApp typeCtx locals expected e
  | .mdata _ inner => translateExpr typeCtx locals expected inner
  | _ => unsupported e
where
  translateBinaryLastTwo (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (fallback : RType)
      (ctor : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr) : CoreM SurfaceExpr := do
    let args := e.getAppArgs.toList
    let domain ← expectedOrTypeArg typeCtx expected args fallback
    match lastTwo args with
    | some (a, b) => return ctor domain (← translateExpr typeCtx locals (some domain) a) (← translateExpr typeCtx locals (some domain) b)
    | none => unsupported e

  translateBoolCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: discr :: falseCase :: trueCase :: [] =>
        return .matchBool (← translateExpr typeCtx locals (some .bool) discr)
          (← translateExpr typeCtx locals expected trueCase)
          (← translateExpr typeCtx locals expected falseCase)
    | _ => unsupported e

  translateBoolRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: falseCase :: trueCase :: discr :: [] =>
        return .matchBool (← translateExpr typeCtx locals (some .bool) discr)
          (← translateExpr typeCtx locals expected trueCase)
          (← translateExpr typeCtx locals expected falseCase)
    | _ => unsupported e

  translateOptionSomeBranch (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (someCase : Expr) : CoreM (String × SurfaceExpr) := do
    let someCase := stripMData someCase
    match someCase with
    | .lam n ty body _ =>
        let innerTy ← typeOfLeanWithCtx typeCtx ty
        let binder := sanitizeRustIdent "value" (nameLeaf n)
        let bodyExpr ← translateExpr (none :: typeCtx) (some { name := binder, ty := innerTy } :: locals) expected body
        return (binder, bodyExpr)
    | _ => unsupported someCase

  translateOptionCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _α :: _motive :: discr :: noneCase :: someCase :: [] =>
        let target ← translateExpr typeCtx locals none discr
        let noneExpr ← translateExpr typeCtx locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch typeCtx locals expected someCase
        return .matchOption target noneExpr binder someExpr
    | _ => unsupported e

  translateOptionRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _α :: _motive :: noneCase :: someCase :: discr :: [] =>
        let target ← translateExpr typeCtx locals none discr
        let noneExpr ← translateExpr typeCtx locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch typeCtx locals expected someCase
        return .matchOption target noneExpr binder someExpr
    | _ => unsupported e

  translateEnumBranch (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (variant : String × List RType) (branchExpr : Expr) : CoreM (String × (List String × SurfaceExpr)) := do
    let rec peel (idx : Nat) (typeCtx : TypeCtx) (locals : LocalCtx) (binders : List String) (payloadTypes : List RType) (expr : Expr) : CoreM (List String × SurfaceExpr) := do
      match payloadTypes with
      | [] => do
          let bodyExpr ← translateExpr typeCtx locals expected expr
          pure (binders, bodyExpr)
      | payloadTy :: rest =>
          match stripMData expr with
          | .lam n ty body _ => do
              let actualTy ← typeOfLeanWithCtx typeCtx ty
              if actualTy == payloadTy then
                let binder := sanitizeRustIdent ("field" ++ Nat.toString idx) (nameLeaf n)
                peel (idx + 1) (none :: typeCtx) (some { name := binder, ty := payloadTy } :: locals) (binders ++ [binder]) rest body
              else
                throwError "enum branch payload type mismatch while lowering variant `{variant.1}`"
          | _ => unsupported expr
    let (binders, body) ← peel 0 typeCtx locals [] variant.2 branchExpr
    pure (variant.1, (binders, body))

  translateEnumCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (recursor : Name) (args : List Expr) : CoreM SurfaceExpr := do
    let inductName := nameParent recursor
    let enumTy ← typeOfInductive inductName
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if args.length == branchCount + 2 then
          match args with
          | _motive :: discr :: rest =>
              let branches := variants.zip rest
              return .matchEnum enumTy (← translateExpr typeCtx locals (some enumTy) discr)
                (← branches.mapM (fun branch => translateEnumBranch typeCtx locals expected branch.1 branch.2))
          | _ => unsupported e
        else
          unsupported e
    | _ => unsupported e

  translateEnumRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (recursor : Name) (args : List Expr) : CoreM SurfaceExpr := do
    let inductName := nameParent recursor
    let enumTy ← typeOfInductive inductName
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if args.length == branchCount + 2 then
          match args.reverse with
          | discr :: _ =>
              let rest := (args.drop 1).take branchCount
              let branches := variants.zip rest
              return .matchEnum enumTy (← translateExpr typeCtx locals (some enumTy) discr)
                (← branches.mapM (fun branch => translateEnumBranch typeCtx locals expected branch.1 branch.2))
          | [] => unsupported e
        else
          unsupported e
    | _ => unsupported e

  translateConstructorApp? (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (ctorName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match (← getEnv).find? ctorName with
    | some (.ctorInfo info) =>
        let ty ← typeOfInductive info.induct
        let fields ← ctorPayloadFields ctorName
        let valueArgs := takeLast info.numFields args
        match ty with
        | .struct _ declared =>
            if declared.length == fields.length && valueArgs.length == fields.length then
              let mut provided : List (String × SurfaceExpr) := []
              for pair in fields.zip valueArgs do
                provided := provided ++ [(pair.1.1, (← translateExpr typeCtx locals (some pair.1.2) pair.2))]
              return some (.structLit ty provided)
            else
              return none
        | .enum _ _ =>
            if valueArgs.length == fields.length then
              let mut payload : List SurfaceExpr := []
              for pair in fields.zip valueArgs do
                payload := payload ++ [(← translateExpr typeCtx locals (some pair.1.2) pair.2)]
              return some (.enumVariant ty (nameLeaf ctorName) payload)
            else
              return none
        | _ => return none
    | _ => return none

  translateProjectionApp? (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (projName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    let parent := nameParent projName
    try
      let ty ← typeOfInductive parent
      match ty with
      | .struct _ fields =>
          let fieldName := nameLeaf projName
          match lookupRField fields fieldName, last? args with
          | some _fieldTy, some target =>
              let targetExpr ← translateExpr typeCtx locals (some ty) target
              return some (.field targetExpr fieldName)
          | _, _ => return none
      | _ => return none
    catch _ =>
      return none

  instantiateGenericCall? (callerTypeCtx : TypeCtx) (calledName : Name) (args : List Expr) : CoreM (Option (String × List RType × RType × List Expr)) := do
    let info ← getConstInfo calledName
    match info with
    | .defnInfo defInfo =>
        let (binders, retTyExpr) := peelForalls defInfo.type
        let mut remaining := args
        let mut calledTypeCtx : TypeCtx := []
        let mut concreteTypeArgs : List RType := []
        let mut argTypes : List RType := []
        let mut valueArgs : List Expr := []
        let mut sawTypeBinder := false
        for binder in binders do
          if isTypeParamBinder binder.2 then
            sawTypeBinder := true
            match remaining with
            | typeArgExpr :: rest =>
                let concreteTy ← typeOfLeanWithCtx callerTypeCtx typeArgExpr
                concreteTypeArgs := concreteTypeArgs ++ [concreteTy]
                calledTypeCtx := some concreteTy :: calledTypeCtx
                remaining := rest
            | [] => return none
          else
            let argTy ← typeOfLeanWithCtx calledTypeCtx binder.2
            match remaining with
            | valueExpr :: rest =>
                argTypes := argTypes ++ [argTy]
                valueArgs := valueArgs ++ [valueExpr]
                calledTypeCtx := none :: calledTypeCtx
                remaining := rest
            | [] => return none
        if sawTypeBinder && remaining.isEmpty then
          let retTy ← typeOfLeanWithCtx calledTypeCtx retTyExpr
          let rustName ← registerAutoMonoSpec calledName concreteTypeArgs
          pure (some (rustName, argTypes, retTy, valueArgs))
        else
          pure none
    | _ => pure none

  translateFunctionCall? (typeCtx : TypeCtx) (locals : LocalCtx) (calledName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match (← callSignature? calledName) with
    | some (argTypes, retTy) =>
        if args.length == argTypes.length then
          let translatedArgs ← (argTypes.zip args).mapM (fun pair => translateExpr typeCtx locals (some pair.1) pair.2)
          return some (.call (sanitizeRustIdent "generated" (nameLeaf calledName)) argTypes retTy translatedArgs)
        else
          return none
    | none =>
        match (← instantiateGenericCall? typeCtx calledName args) with
        | some (rustName, argTypes, retTy, valueArgs) =>
            let translatedArgs ← (argTypes.zip valueArgs).mapM (fun pair => translateExpr typeCtx locals (some pair.1) pair.2)
            return some (.call rustName argTypes retTy translatedArgs)
        | none => return none

  translateApp (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) : CoreM SurfaceExpr := do
    let fn := e.getAppFn
    let args := e.getAppArgs.toList
    match fn with
    | .const n _ =>
        if n == ``ite then
          match args with
          | _ty :: cond :: _dec :: thenExpr :: elseExpr :: [] =>
              return .ite (← translateExpr typeCtx locals (some .bool) cond) (← translateExpr typeCtx locals expected thenExpr) (← translateExpr typeCtx locals expected elseExpr)
          | _ => unsupported e
        else if n == ``Eq then
          let domain ← expectedOrTypeArg typeCtx none args .u32
          translateBinaryLastTwo typeCtx locals (some domain) e domain .eq
        else if n == ``LT.lt || n == ``Nat.lt then
          translateBinaryLastTwo typeCtx locals none e .u32 .lt
        else if n == ``LE.le || n == ``Nat.le then
          translateBinaryLastTwo typeCtx locals none e .u32 .le
        else if n == ``Nat.add || n == ``HAdd.hAdd then
          translateBinaryLastTwo typeCtx locals expected e .u32 .add
        else if n == ``Nat.sub || n == ``HSub.hSub then
          translateBinaryLastTwo typeCtx locals expected e .u32 .sub
        else if n == ``Nat.mul || n == ``HMul.hMul then
          translateBinaryLastTwo typeCtx locals expected e .u32 .mul
        else if n == ``Bool.not then
          match args with
          | [a] => return .not (← translateExpr typeCtx locals (some .bool) a)
          | _ => unsupported e
        else if n == ``Bool.and then
          translateBinaryLastTwo typeCtx locals (some .bool) e .bool .and
        else if n == ``Bool.or then
          translateBinaryLastTwo typeCtx locals (some .bool) e .bool .or
        else if n == ``Option.none then
          match expected with
          | some (.option inner) => return .optionNone inner
          | _ =>
              match (← firstTypeArg? typeCtx args) with
              | some inner => return .optionNone inner
              | none => throwError "Option.none extraction needs an expected Option type"
        else if n == ``Option.some then
          let inner ← match expected with
            | some (.option inner) => pure inner
            | _ => expectedOrTypeArg typeCtx none args .u32
          match lastTwo args with
          | some (_, value) => return .optionSome (← translateExpr typeCtx locals (some inner) value)
          | none => unsupported e
        else if n == ``Except.ok then
          let (errTy, okTy) ← match expected with
            | some (.result ok err) => pure (err, ok)
            | _ =>
                match args with
                | errExpr :: okExpr :: _ => do
                    let errTy ← typeOfLeanWithCtx typeCtx errExpr
                    let okTy ← typeOfLeanWithCtx typeCtx okExpr
                    pure (errTy, okTy)
                | _ => throwError "Except.ok extraction needs an expected Result type"
          match lastTwo args with
          | some (_, value) => return .resultOk errTy (← translateExpr typeCtx locals (some okTy) value)
          | none => unsupported e
        else if n == ``Except.error then
          let (errTy, okTy) ← match expected with
            | some (.result ok err) => pure (err, ok)
            | _ =>
                match args with
                | errExpr :: okExpr :: _ => do
                    let errTy ← typeOfLeanWithCtx typeCtx errExpr
                    let okTy ← typeOfLeanWithCtx typeCtx okExpr
                    pure (errTy, okTy)
                | _ => throwError "Except.error extraction needs an expected Result type"
          match lastTwo args with
          | some (_, value) => return .resultErr okTy (← translateExpr typeCtx locals (some errTy) value)
          | none => unsupported e
        else if isNamedRecursor n "casesOn" && nameParent n == ``Bool then
          translateBoolCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Bool then
          translateBoolRec typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" && nameParent n == ``Option then
          translateOptionCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Option then
          translateOptionRec typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" then
          translateEnumCasesOn typeCtx locals expected e n args
        else if isNamedRecursor n "rec" then
          translateEnumRec typeCtx locals expected e n args
        else
          match (← translateFunctionCall? typeCtx locals n args) with
          | some expr => return expr
          | none =>
              match (← translateProjectionApp? typeCtx locals expected n args) with
              | some expr => return expr
              | none =>
                  match (← translateConstructorApp? typeCtx locals expected n args) with
                  | some expr => return expr
                  | none => unsupported e
    | _ => unsupported e

private def rTypeSyntaxIdent (stx : Syntax) : Except String RType :=
  let n := stx.getId
  match nameLeaf n with
  | "Nat" => .ok .u32
  | "Bool" => .ok .bool
  | "Unit" => .ok .unit
  | "UInt32" => .ok .u32
  | "UInt64" => .ok .u64
  | "Int32" => .ok .i32
  | "Int64" => .ok .i64
  | _ => .error s!"rust_mono_export type argument `{n}` is not in the current concrete type subset"

private def rTypeReportLabel : RType → String
  | .unit => "Unit"
  | .bool => "Bool"
  | .u32 => "UInt32"
  | .u64 => "UInt64"
  | .i32 => "Int32"
  | .i64 => "Int64"
  | .option t => "Option " ++ rTypeReportLabel t
  | .result ok err => "Except " ++ rTypeReportLabel err ++ " " ++ rTypeReportLabel ok
  | .struct name _ => name
  | .enum name _ => name

private def monoSpecLabel (spec : MonoExportSpec) : String :=
  toString spec.source ++ "[" ++ joinWith "," (spec.typeArgs.map rTypeReportLabel) ++ "]"

private def buildExtractionContexts (binders : List (Name × Expr)) (typeArgs : List RType) : CoreM (List RArg × TypeCtx × LocalCtx) := do
  let mut args : List RArg := []
  let mut typeCtx : TypeCtx := []
  let mut locals : LocalCtx := []
  let mut typeArgIndex : Nat := 0
  let mut valueIndex : Nat := 0
  for binder in binders do
    let (binderName, binderTy) := binder
    if isTypeParamBinder binderTy then
      match typeArgs.get? typeArgIndex with
      | some concreteTy =>
          typeCtx := some concreteTy :: typeCtx
          locals := none :: locals
          typeArgIndex := typeArgIndex + 1
      | none =>
          throwError "generic rust_export `{binderName}` requires rust_mono_export with a concrete type argument"
    else
      let rustName := sanitizeRustIdent s!"arg{valueIndex}" (nameLeaf binderName)
      let rty ← typeOfLeanWithCtx typeCtx binderTy
      args := args ++ [(rustName, rty)]
      typeCtx := none :: typeCtx
      locals := some { name := rustName, ty := rty } :: locals
      valueIndex := valueIndex + 1
  if typeArgIndex == typeArgs.length then
    pure (args, typeCtx, locals)
  else
    throwError "rust_mono_export provided too many concrete type arguments"

/-- Extract one ordinary Lean definition into the first-pass Rust surface IR. -/
def extractConstAs (declName : Name) (rustFunName : String) (typeArgs : List RType) : CoreM SurfaceFun := do
  let info ← getConstInfo declName
  let defInfo ← match info with
    | .defnInfo d => pure d
    | _ => throwError "rust_export extraction only supports ordinary definitions; got {declName}"
  let (typeBinders, retTyExpr) := peelForalls defInfo.type
  let (valueBinders, body) := peelLambdas defInfo.value
  if valueBinders.length != typeBinders.length then
    throwError "rust_export extraction currently requires eta-expanded definitions; `{declName}` has {typeBinders.length} type binders but {valueBinders.length} value binders"
  let (args, typeCtx, locals) ← buildExtractionContexts typeBinders typeArgs
  let ret ← typeOfLeanWithCtx typeCtx retTyExpr
  let bodyExpr ← translateExpr typeCtx locals (some ret) body
  let surfaceFun : SurfaceFun := { name := rustFunName, args := args, ret := ret, body := bodyExpr }
  match checkSurfaceFun surfaceFun with
  | .ok checked => pure checked
  | .error report => throwError "extracted declaration failed surface type check: {report.detail}"

/-- Extract one non-generic Lean definition. -/
def extractConst (declName : Name) : CoreM SurfaceFun :=
  extractConstAs declName (sanitizeRustIdent "generated" (nameLeaf declName)) []

/-- Extract a concrete monomorphization of a generic Lean definition. -/
def extractMonoConst (spec : MonoExportSpec) : CoreM SurfaceFun :=
  extractConstAs spec.source spec.rustName spec.typeArgs

/-- Extract many Lean definitions, preserving declaration order. -/
def extractConsts (decls : List Name) : CoreM (List SurfaceFun) :=
  decls.mapM extractConst

private def compatibilityCodeString : CompatibilityCode → String
  | .supported => "supported"
  | .unsupportedType => "unsupported-type"
  | .unsupportedExpression => "unsupported-expression"
  | .unsupportedBoundary => "unsupported-boundary"
  | .unsupportedDeclaration => "unsupported-declaration"

private def jsonEscapeChar : Char → String
  | '"' => "\\\""
  | '\\' => "\\\\"
  | '\n' => "\\n"
  | '\r' => "\\r"
  | '\t' => "\\t"
  | c => String.singleton c

private def jsonEscape (s : String) : String :=
  joinWith "" (s.toList.map jsonEscapeChar)

private def diagnosticToJson (d : ExportDiagnostic) : String :=
  "    { \"source\": \"" ++ jsonEscape d.source ++ "\", \"rust_name\": \"" ++ jsonEscape d.rustName ++
  "\", \"code\": \"" ++ compatibilityCodeString d.code ++ "\", \"detail\": \"" ++ jsonEscape d.detail ++ "\" }"

/-- Emit a structured compatibility report for supported and skipped exports. -/
def emitCompatibilityReport (result : ExtractionResult) : String :=
  "{\n" ++
  "  \"format\": \"lean-rust-core.compatibility-report.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"generated_function_count\": " ++ Nat.toString result.functions.length ++ ",\n" ++
  "  \"diagnostics\": [\n" ++
  joinWith ",\n" (result.diagnostics.map diagnosticToJson) ++ "\n" ++
  "  ]\n" ++
  "}\n"

private def supportedDiagnostic (source rustName : String) (detail : String := "exported") : ExportDiagnostic :=
  { source := source, rustName := rustName, code := .supported, detail := detail }

private def unsupportedDiagnostic (source rustName detail : String) : ExportDiagnostic :=
  { source := source, rustName := rustName, code := .unsupportedDeclaration, detail := detail }

private def extractRegularWithDiagnostic (declName : Name) : CoreM (Option SurfaceFun × ExportDiagnostic) := do
  let rustName := sanitizeRustIdent "generated" (nameLeaf declName)
  try
    let f ← extractConst declName
    pure (some f, supportedDiagnostic (toString declName) f.name "exported")
  catch _ =>
    pure (none, unsupportedDiagnostic (toString declName) rustName "unsupported export skipped by the direct Lean-to-Rust extractor")

private def extractMonoWithDiagnostic (spec : MonoExportSpec) (detail : String) : CoreM (Option SurfaceFun × ExportDiagnostic) := do
  try
    let f ← extractMonoConst spec
    pure (some f, supportedDiagnostic (monoSpecLabel spec) f.name detail)
  catch _ =>
    pure (none, unsupportedDiagnostic (monoSpecLabel spec) spec.rustName "monomorphized export could not be lowered by the current extractor subset")

private def monoSpecIn (spec : MonoExportSpec) : List MonoExportSpec → Bool
  | [] => false
  | candidate :: rest => sameMonoKey spec.source spec.typeArgs candidate || monoSpecIn spec rest

private def pendingAutoSpecs (seen : List MonoExportSpec) (all : List MonoExportSpec) : List MonoExportSpec :=
  all.filter (fun spec => !monoSpecIn spec seen)

private partial def extractPendingAutoMonos (seen : List MonoExportSpec) (functions : List SurfaceFun) (diagnostics : List ExportDiagnostic) (fuel : Nat) : CoreM ExtractionResult := do
  match fuel with
  | 0 => pure { functions := functions, diagnostics := diagnostics ++ [unsupportedDiagnostic "<auto-monomorphization>" "<fuel>" "automatic monomorphization stopped after the fixpoint fuel was exhausted"] }
  | fuel' + 1 => do
      let autoSpecs ← liftIO autoMonoExportSpecsRef.get
      let pending := pendingAutoSpecs seen autoSpecs
      if pending.isEmpty then
        pure { functions := functions, diagnostics := diagnostics }
      else
        let mut functions' := functions
        let mut diagnostics' := diagnostics
        for spec in pending do
          let (maybeFun, diagnostic) ← extractMonoWithDiagnostic spec "auto-monomorphized-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeFun with
          | some f => functions' := functions' ++ [f]
          | none => pure ()
        extractPendingAutoMonos (seen ++ pending) functions' diagnostics' fuel'

/-- Tolerant extraction: successful declarations are emitted; unsupported declarations are reported. -/
def extractWithDiagnostics (decls : List Name) (monos : List MonoExportSpec) : CoreM ExtractionResult := do
  liftIO <| autoMonoExportSpecsRef.set []
  let mut functions : List SurfaceFun := []
  let mut diagnostics : List ExportDiagnostic := []
  for decl in decls do
    let (maybeFun, diagnostic) ← extractRegularWithDiagnostic decl
    diagnostics := diagnostics ++ [diagnostic]
    match maybeFun with
    | some f => functions := functions ++ [f]
    | none => pure ()
  for spec in monos do
    let (maybeFun, diagnostic) ← extractMonoWithDiagnostic spec "explicit-monomorphized-export"
    diagnostics := diagnostics ++ [diagnostic]
    match maybeFun with
    | some f => functions := functions ++ [f]
    | none => pure ()
  extractPendingAutoMonos monos functions diagnostics (decls.length + monos.length + 16)

/-- Register a concrete Rust export for a generic Lean definition. -/
syntax (name := rustMonoExport) "rust_mono_export " ident " as " ident " [" ident,* "]" : command

elab_rules : command
  | `(rust_mono_export $src:ident as $out:ident [$tys,*]) => do
      let mut typeArgs : List RType := []
      for tyStx in tys.getElems do
        match rTypeSyntaxIdent tyStx with
        | .ok ty => typeArgs := typeArgs ++ [ty]
        | .error msg => throwError msg
      let sourceName ← realizeGlobalConstNoOverloadWithInfo src
      let spec : MonoExportSpec := {
        source := sourceName,
        rustName := sanitizeRustIdent "generated" (nameLeaf out.getId),
        typeArgs := typeArgs
      }
      liftIO <| monoExportSpecsRef.modify (fun specs => specs ++ [spec])

/--
Compile-time command for an explicit declaration list. The tagged `rust_emit_exports`
command below is the default workflow; this helper is retained for tests.
-/
syntax (name := rustEmitDefs) "rust_emit_defs " ident " [" ident,* "]" : command

elab_rules : command
  | `(rust_emit_defs $out:ident [$ids,*]) => do
      let declNames := ids.getElems.toList.map (fun stx => stx.getId)
      let funs ← liftCoreM <| extractConsts declNames
      let rust ← match emitSurfaceRustModuleChecked funs with
        | .ok source => pure source
        | .error report => throwError "Rust identifier hygiene failed: {report.detail}"
      let lit := Syntax.mkStrLit rust
      elabCommand (← `(def $out : String := $lit))

private def currentExtractionResult : CommandElabM ExtractionResult := do
  let env ← getEnv
  let declNames := LeanRustCore.Export.exportedNames env
  let monoSpecs ← liftIO monoExportSpecsRef.get
  liftCoreM <| extractWithDiagnostics declNames monoSpecs

/-- Emit Rust for every supported declaration tagged with `@[rust_export]`. Unsupported exports are skipped and can be inspected with `rust_emit_exports_with_report`. -/
syntax (name := rustEmitExports) "rust_emit_exports " ident : command

elab_rules : command
  | `(rust_emit_exports $out:ident) => do
      let result ← currentExtractionResult
      let rust ← match emitSurfaceRustModuleChecked result.functions with
        | .ok source => pure source
        | .error report => throwError "Rust identifier hygiene failed: {report.detail}"
      let lit := Syntax.mkStrLit rust
      elabCommand (← `(def $out : String := $lit))

/-- Emit Rust and a structured compatibility report for tagged and monomorphized exports. -/
syntax (name := rustEmitExportsWithReport) "rust_emit_exports_with_report " ident ident : command

elab_rules : command
  | `(rust_emit_exports_with_report $out:ident $reportOut:ident) => do
      let result ← currentExtractionResult
      let rust ← match emitSurfaceRustModuleChecked result.functions with
        | .ok source => pure source
        | .error report => throwError "Rust identifier hygiene failed: {report.detail}"
      let report := emitCompatibilityReport result
      let rustLit := Syntax.mkStrLit rust
      let reportLit := Syntax.mkStrLit report
      elabCommand (← `(def $out : String := $rustLit))
      elabCommand (← `(def $reportOut : String := $reportLit))

end LeanRustCore.Extract
