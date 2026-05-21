import Lean
import LeanRustCore.EmitRust
import LeanRustCore.Export

import LeanRustCore.ClosureConversion
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
initialize autoHelperExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []

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

private def localAt (locals : LocalCtx) (idx : Nat) : Except String Local :=
  match locals.get? idx with
  | some (some local) => Except.ok local
  | some none => Except.error s!"de-Bruijn variable #{idx} is erased or type-level, not a Rust value"
  | none => Except.error s!"unbound de-Bruijn variable #{idx} during extraction"

private def localNameAt (locals : LocalCtx) (idx : Nat) : Except String String := do
  pure (← localAt locals idx).name

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

/-- Conservative proof-erasure predicate for exported binders. -/
private def isProofTypeShape (ty0 : Expr) : Bool :=
  let ty := stripMData ty0
  match ty.getAppFn with
  | .const n _ => n == ``Eq || n == ``True || n == ``False
  | _ => false

private partial def exprContainsConst (needle : Name) (e0 : Expr) : Bool :=
  let e := stripMData e0
  match e with
  | .const n _ => n == needle
  | .app f a => exprContainsConst needle f || exprContainsConst needle a
  | .lam _ ty body _ => exprContainsConst needle ty || exprContainsConst needle body
  | .forallE _ ty body _ => exprContainsConst needle ty || exprContainsConst needle body
  | .letE _ ty value body _ =>
      exprContainsConst needle ty || exprContainsConst needle value || exprContainsConst needle body
  | .proj _ _ target => exprContainsConst needle target
  | .mdata _ inner => exprContainsConst needle inner
  | _ => false

private def runtimeSignatureUsesNat (binders : List (Name × Expr)) (retTy : Expr) : Bool :=
  let binderUsesNat := binders.any (fun binder =>
    !isTypeParamBinder binder.2 && !isProofTypeShape binder.2 && exprContainsConst ``Nat binder.2)
  binderUsesNat || exprContainsConst ``Nat retTy

private def enforceNatBoundaryPolicy (declName : Name) (binders : List (Name × Expr)) (retTy : Expr) : CoreM Unit := do
  let env ← getEnv
  if runtimeSignatureUsesNat binders retTy && !LeanRustCore.Export.natWrappingU32Allowed env declName then
    throwError "export `{declName}` uses Nat in a Rust-facing parameter or return type; add @[rust_nat_wrapping_u32] to opt into wrapping u32 semantics"

private def unsupported (e : Expr) : CoreM α :=
  throwError "unsupported Lean expression in rust_export extraction: {e}"

private def lookupRField (fields : List RArg) (fieldName : String) : Option RType :=
  match fields with
  | [] => none
  | (name, ty) :: rest => if name == fieldName then some ty else lookupRField rest fieldName

private def typeCtxFromParams (params : List RType) : TypeCtx :=
  params.foldl (fun ctx ty => some ty :: ctx) []

private def lowerRuntimeTypeChar : Char → Char
  | 'A' => 'a' | 'B' => 'b' | 'C' => 'c' | 'D' => 'd' | 'E' => 'e' | 'F' => 'f'
  | 'G' => 'g' | 'H' => 'h' | 'I' => 'i' | 'J' => 'j' | 'K' => 'k' | 'L' => 'l'
  | 'M' => 'm' | 'N' => 'n' | 'O' => 'o' | 'P' => 'p' | 'Q' => 'q' | 'R' => 'r'
  | 'S' => 's' | 'T' => 't' | 'U' => 'u' | 'V' => 'v' | 'W' => 'w' | 'X' => 'x'
  | 'Y' => 'y' | 'Z' => 'z'
  | c => c

private def lowerRuntimeTypeString (s : String) : String :=
  String.mk (s.toList.map lowerRuntimeTypeChar)

private partial def rTypeRuntimeSuffix : RType → String
  | .unit => "unit"
  | .bool => "bool"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .char => "char"
  | .string => "string"
  | .option t => "option_" ++ rTypeRuntimeSuffix t
  | .result ok err => "result_" ++ rTypeRuntimeSuffix ok ++ "_" ++ rTypeRuntimeSuffix err
  | .list t => "list_" ++ rTypeRuntimeSuffix t
  | .array t => "array_" ++ rTypeRuntimeSuffix t
  | .prod a b => "prod_" ++ rTypeRuntimeSuffix a ++ "_" ++ rTypeRuntimeSuffix b
  | .sum a b => "sum_" ++ rTypeRuntimeSuffix a ++ "_" ++ rTypeRuntimeSuffix b
  | .func a b => "fn_" ++ rTypeRuntimeSuffix a ++ "_" ++ rTypeRuntimeSuffix b
  | .subtype t => "subtype_" ++ rTypeRuntimeSuffix t
  | .fin n => "fin_" ++ Nat.toString n
  | .vector t n => "vector_" ++ rTypeRuntimeSuffix t ++ "_" ++ Nat.toString n
  | .struct name _ => sanitizeRustIdent "struct" (lowerRuntimeTypeString name)
  | .enum name _ => sanitizeRustIdent "enum" (lowerRuntimeTypeString name)

private def monomorphizedInductiveName (inductName : Name) (typeArgs : List RType) : String :=
  if typeArgs.isEmpty then
    nameLeaf inductName
  else
    nameLeaf inductName ++ "__" ++ joinWith "_" (typeArgs.map rTypeRuntimeSuffix)

private def indexedPayloadFieldsAux (idx : Nat) : List RType → List RArg
  | [] => []
  | ty :: rest => ("field" ++ Nat.toString idx, ty) :: indexedPayloadFieldsAux (idx + 1) rest

private def indexedPayloadFields (payload : List RType) : List RArg :=
  indexedPayloadFieldsAux 0 payload

mutual
  partial def typeOfLeanWithCtx (typeCtx : TypeCtx) (ty0 : Expr) : CoreM RType := do
    let ty := stripMData ty0
    match ty with
    | .bvar idx => typeParamAt typeCtx idx
    | .forallE _ domain body _ => do
        let argTy ← typeOfLeanWithCtx typeCtx domain
        let retTy ← typeOfLeanWithCtx (none :: typeCtx) body
        pure (.func argTy retTy)
    | _ =>
        if ty.isConstOf ``Nat then
          return .u32
  | .ordering => "ordering"
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
        else if ty.isConstOf ``Char then
          return .char
        else if ty.isConstOf ``String then
          return .string
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
              else if n == ``List then
                match args with
                | [inner] => return .list (← typeOfLeanWithCtx typeCtx inner)
                | _ => throwError "unsupported List type shape in rust_export extraction"
              else if n == ``Array then
                match args with
                | [inner] => return .array (← typeOfLeanWithCtx typeCtx inner)
                | _ => throwError "unsupported Array type shape in rust_export extraction"
              else if n == ``Prod then
                match args with
                | [a, b] => return .prod (← typeOfLeanWithCtx typeCtx a) (← typeOfLeanWithCtx typeCtx b)
                | _ => throwError "unsupported Prod type shape in rust_export extraction"
              else if n == ``Sum then
                match args with
                | [a, b] => return .sum (← typeOfLeanWithCtx typeCtx a) (← typeOfLeanWithCtx typeCtx b)
                | _ => throwError "unsupported Sum type shape in rust_export extraction"
              else if n == ``Subtype then
                match args with
                | [inner, _pred] => return .subtype (← typeOfLeanWithCtx typeCtx inner)
                | _ => throwError "unsupported Subtype shape in rust_export extraction"
        else if ty.isConstOf ``Ordering then
          return .ordering
              else if n == ``Fin then
                match args with
                | [boundExpr] =>
                    match natLiteral? boundExpr with
                    | some bound => return .fin bound
                    | none => throwError "Fin bounds must be numeral literals in the current rust_export subset"
                | _ => throwError "unsupported Fin type shape in rust_export extraction"
              else if n == ``Vector then
                match args with
                | [inner, boundExpr] =>
                    match natLiteral? boundExpr with
                    | some bound => return .vector (← typeOfLeanWithCtx typeCtx inner) bound
                    | none => throwError "Vector length indices must be numeral literals in the current rust_export subset"
                | _ => throwError "unsupported Vector type shape in rust_export extraction"
              else
                match (← getEnv).find? n with
                | some (.inductInfo info) => do
                    let paramExprs := args.take info.numParams
                    if paramExprs.length == info.numParams then
                      let concreteParams ← paramExprs.mapM (typeOfLeanWithCtx typeCtx)
                      typeOfInductiveWithArgs n concreteParams
                    else
                      throwError "inductive type `{n}` expected {info.numParams} parameters but got {paramExprs.length}"
                | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"
          | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"

  partial def typeOfLeanM (ty0 : Expr) : CoreM RType :=
    typeOfLeanWithCtx [] ty0

  partial def typeOfInductive (inductName : Name) : CoreM RType :=
    typeOfInductiveWithArgs inductName []

  partial def typeOfInductiveWithArgs (inductName : Name) (typeArgs : List RType) : CoreM RType := do
    let env ← getEnv
    match env.find? inductName with
    | some (.inductInfo info) =>
        if info.numIndices == 0 && info.numParams == typeArgs.length then
          let runtimeName := monomorphizedInductiveName inductName typeArgs
          match info.ctors with
          | [ctorName] =>
              let fields ← ctorPayloadFieldsWithParams ctorName typeArgs
              if fields.isEmpty then
                pure (.enum runtimeName [(nameLeaf ctorName, [])])
              else
                pure (.struct runtimeName fields)
          | ctors => do
              let variants ← ctors.mapM (fun ctorName => do
                let fields ← ctorPayloadFieldsWithParams ctorName typeArgs
                pure (nameLeaf ctorName, fields.map (fun field => field.2)))
              pure (.enum runtimeName variants)
        else
          throwError "rust_export type lowering supports parameterized, index-free inductives only; got {inductName} with {info.numParams} params, {info.numIndices} indices, and {typeArgs.length} concrete args"
    | _ => throwError "expected inductive declaration for {inductName}"

  partial def ctorPayloadFields (ctorName : Name) : CoreM (List RArg) :=
    ctorPayloadFieldsWithParams ctorName []

  partial def ctorPayloadFieldsWithParams (ctorName : Name) (typeArgs : List RType) : CoreM (List RArg) := do
    let env ← getEnv
    match env.find? ctorName with
    | some (.ctorInfo info) =>
        if info.numParams == typeArgs.length then
          let (binders, _) := peelForalls info.type
          let fieldBinders := (binders.drop info.numParams).take info.numFields
          let mut out : List RArg := []
          let mut fieldCtx := typeCtxFromParams typeArgs
          let mut idx : Nat := 0
          for field in fieldBinders do
            let fallback := "field" ++ Nat.toString idx
            let fieldName := sanitizeRustIdent fallback (nameLeaf field.1)
            let fieldTy ← typeOfLeanWithCtx fieldCtx field.2
            out := out ++ [(fieldName, fieldTy)]
            fieldCtx := none :: fieldCtx
            idx := idx + 1
          pure out
        else
          throwError "constructor `{ctorName}` expected {info.numParams} type parameters but got {typeArgs.length}"
    | _ => throwError "expected constructor declaration for {ctorName}"
end

private def firstOrderSignature? (declName : Name) : CoreM (Option (List RType × RType)) := do
  let info ← getConstInfo declName
  match info with
  | .defnInfo defInfo =>
      let (binders, retTyExpr) := peelForalls defInfo.type
      let mut argTypes : List RType := []
      let mut typeCtx : TypeCtx := []
      for binder in binders do
        if isTypeParamBinder binder.2 then
          return none
        else if isProofTypeShape binder.2 then
          typeCtx := none :: typeCtx
        else
          let rty ← typeOfLeanWithCtx typeCtx binder.2
          argTypes := argTypes ++ [rty]
          typeCtx := none :: typeCtx
      let retTy ← typeOfLeanWithCtx typeCtx retTyExpr
      pure (some (argTypes, retTy))
  | _ => pure none

/-- Signature lookup for calls to other tagged non-generic Lean declarations. Generic calls are handled by automatic/explicit monomorphization below. -/
private def callSignature? (declName : Name) : CoreM (Option (List RType × RType)) := do
  let env ← getEnv
  if !containsName (LeanRustCore.Export.exportedNames env) declName then
    return none
  firstOrderSignature? declName

private partial def firstTypeArg? (typeCtx : TypeCtx) : List Expr → CoreM (Option RType)
  | [] => pure none
  | x :: xs => do
      try
        return some (← typeOfLeanWithCtx typeCtx x)
      catch _ =>
        firstTypeArg? typeCtx xs

private partial def typeArgsFrom? (typeCtx : TypeCtx) : List Expr → CoreM (List RType)
  | [] => pure []
  | x :: xs => do
      let rest ← typeArgsFrom? typeCtx xs
      try
        pure ((← typeOfLeanWithCtx typeCtx x) :: rest)
      catch _ =>
        pure rest

private def firstTwoTypeArgs? (typeCtx : TypeCtx) (args : List Expr) : CoreM (Option (RType × RType)) := do
  match (← typeArgsFrom? typeCtx args) with
  | a :: b :: _ => pure (some (a, b))
  | _ => pure none


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
  | .ordering => "ordering"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .char => "char"
  | .string => "string"
  | .option t => "option_" ++ rTypeMonoSuffix t
  | .result ok err => "result_" ++ rTypeMonoSuffix ok ++ "_" ++ rTypeMonoSuffix err
  | .list t => "list_" ++ rTypeMonoSuffix t
  | .array t => "array_" ++ rTypeMonoSuffix t
  | .prod a b => "prod_" ++ rTypeMonoSuffix a ++ "_" ++ rTypeMonoSuffix b
  | .sum a b => "sum_" ++ rTypeMonoSuffix a ++ "_" ++ rTypeMonoSuffix b
  | .func a b => "fn_" ++ rTypeMonoSuffix a ++ "_" ++ rTypeMonoSuffix b
  | .subtype t => "subtype_" ++ rTypeMonoSuffix t
  | .fin n => "fin_" ++ Nat.toString n
  | .vector t n => "vector_" ++ rTypeMonoSuffix t ++ "_" ++ Nat.toString n
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

private def helperRustName (source : Name) : String :=
  sanitizeRustIdent "generated" (nameLeaf source)

private def registerAutoHelperSpec (source : Name) : CoreM String := do
  let explicitSpecs ← liftIO monoExportSpecsRef.get
  match findMonoSpecByKey source [] explicitSpecs with
  | some spec => pure spec.rustName
  | none => do
      let autoSpecs ← liftIO autoHelperExportSpecsRef.get
      match findMonoSpecByKey source [] autoSpecs with
      | some spec => pure spec.rustName
      | none => do
          let rustName := helperRustName source
          let spec : MonoExportSpec := { source := source, rustName := rustName, typeArgs := [] }
          liftIO <| autoHelperExportSpecsRef.modify (fun specs => specs ++ [spec])
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
  | .closureApply binder _ _ arg body => surfaceExprUsesVar needle arg || (binder != needle && surfaceExprUsesVar needle body)
  | .defaultValue _ => false
  | .toStringValue _ value => surfaceExprUsesVar needle value
  | .reprValue _ value => surfaceExprUsesVar needle value
  | .proj structName fieldIdx target =>
      if nameLeaf structName == "Subtype" && fieldIdx == 0 then
        match expected with
        | some inner => return .subtypeVal inner (← translateExpr typeCtx locals (some (.subtype inner)) target)
        | none => throwError "Subtype.val projection needs an expected erased runtime type"
      else if nameLeaf structName == "Fin" && fieldIdx == 0 then
        match stripMData target with
        | .bvar idx =>
            match localAt locals idx with
            | .ok local =>
                match local.ty with
                | .fin bound => return .finVal bound (← translateExpr typeCtx locals (some (.fin bound)) target)
                | _ => throwError "Fin.val target was not typed as Fin in the local context"
            | .error msg => throwError msg
        | _ => throwError "Fin.val projection currently supports local Fin variables only"
      else
        unsupported e
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

  translateLambdaApplication (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (fnExpr : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match stripMData fnExpr, args with
    | .lam n ty body _, [argExpr] => do
        let argTy ← typeOfLeanWithCtx typeCtx ty
        let retTy ← match expected with
          | some ty => pure ty
          | none => throwError "closure conversion for direct lambda application needs an expected return type"
        let binder := sanitizeRustIdent "item" (nameLeaf n)
        let loweredArg ← translateExpr typeCtx locals (some argTy) argExpr
        let loweredBody ← translateExpr (none :: typeCtx) (some { name := binder, ty := argTy } :: locals) (some retTy) body
        pure (.closureApply binder argTy retTy loweredArg loweredBody)
    | _, _ => unsupported fnExpr

  translateLetLambdaApplication? (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (_letName : Name) (letTy value body : Expr) : CoreM (Option SurfaceExpr) := do
    match stripMData value, stripMData body with
    | .lam n lamTy lamBody _, bodyExpr =>
        match (← typeOfLeanWithCtx typeCtx letTy) with
        | .func argTy retTy =>
            let appFn := bodyExpr.getAppFn
            let appArgs := bodyExpr.getAppArgs.toList
            match stripMData appFn, appArgs with
            | .bvar 0, [callArg] => do
                match expected with
                | some wanted => if wanted == retTy then pure () else throwError "let-bound closure return type did not match expected result type"
                | none => pure ()
                let actualLamTy ← typeOfLeanWithCtx typeCtx lamTy
                if actualLamTy == argTy then
                  pure ()
                else
                  throwError "let-bound closure argument type did not match its function type"
                let binder := sanitizeRustIdent "item" (nameLeaf n)
                let loweredArg ← translateExpr (none :: typeCtx) (none :: locals) (some argTy) callArg
                let loweredBody ← translateExpr (none :: typeCtx) (some { name := binder, ty := argTy } :: locals) (some retTy) lamBody
                pure (some (.closureApply binder argTy retTy loweredArg loweredBody))
            | _, _ => pure none
        | _ => pure none
    | _, _ => pure none

  translateUnaryLambdaBody (typeCtx : TypeCtx) (locals : LocalCtx) (elemTy outTy : RType) (fnExpr : Expr) : CoreM (String × SurfaceExpr) := do
    match stripMData fnExpr with
    | .lam n ty body _ => do
        let actualTy ← typeOfLeanWithCtx typeCtx ty
        if actualTy == elemTy then
          let binder := sanitizeRustIdent "item" (nameLeaf n)
          let bodyExpr ← translateExpr (none :: typeCtx) (some { name := binder, ty := elemTy } :: locals) (some outTy) body
          pure (binder, bodyExpr)
        else
          throwError "List.map lambda argument type did not match the list element type"
    | _ => unsupported fnExpr

  translateFoldlLambdaBody (typeCtx : TypeCtx) (locals : LocalCtx) (accTy elemTy : RType) (fnExpr : Expr) : CoreM (String × String × SurfaceExpr) := do
    match stripMData fnExpr with
    | .lam accName accTyExpr rest _ =>
        match stripMData rest with
        | .lam elemName elemTyExpr body _ => do
            let actualAccTy ← typeOfLeanWithCtx typeCtx accTyExpr
            let actualElemTy ← typeOfLeanWithCtx (none :: typeCtx) elemTyExpr
            if actualAccTy == accTy && actualElemTy == elemTy then
              let accBinder := sanitizeRustIdent "acc" (nameLeaf accName)
              let elemBinder := sanitizeRustIdent "item" (nameLeaf elemName)
              let bodyExpr ← translateExpr (none :: none :: typeCtx)
                (some { name := elemBinder, ty := elemTy } :: some { name := accBinder, ty := accTy } :: locals)
                (some accTy) body
              pure (accBinder, elemBinder, bodyExpr)
            else
              throwError "List.foldl lambda argument types did not match the accumulator/list element types"
        | _ => unsupported fnExpr
    | _ => unsupported fnExpr

  translateFoldrLambdaBody (typeCtx : TypeCtx) (locals : LocalCtx) (elemTy accTy : RType) (fnExpr : Expr) : CoreM (String × String × SurfaceExpr) := do
    match stripMData fnExpr with
    | .lam elemName elemTyExpr rest _ =>
        match stripMData rest with
        | .lam accName accTyExpr body _ => do
            let actualElemTy ← typeOfLeanWithCtx typeCtx elemTyExpr
            let actualAccTy ← typeOfLeanWithCtx (none :: typeCtx) accTyExpr
            if actualElemTy == elemTy && actualAccTy == accTy then
              let elemBinder := sanitizeRustIdent "item" (nameLeaf elemName)
              let accBinder := sanitizeRustIdent "acc" (nameLeaf accName)
              let bodyExpr ← translateExpr (none :: none :: typeCtx)
                (some { name := accBinder, ty := accTy } :: some { name := elemBinder, ty := elemTy } :: locals)
                (some accTy) body
              pure (elemBinder, accBinder, bodyExpr)
            else
              throwError "List.foldr lambda argument types did not match the element/accumulator types"
        | _ => unsupported fnExpr
    | _ => unsupported fnExpr

  translateListFilter (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: predExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        let (binder, predicate) ← translateUnaryLambdaBody typeCtx locals elemTy .bool predExpr
        return .listFilter binder elemTy target predicate
    | alpha :: predExpr :: _decider :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        let (binder, predicate) ← translateUnaryLambdaBody typeCtx locals elemTy .bool predExpr
        return .listFilter binder elemTy target predicate
    | _ => unsupported e

  translateListFoldr (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: initExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let accTy ← typeOfLeanWithCtx typeCtx beta
        match expected with
        | some wanted => if wanted == accTy then pure () else throwError "List.foldr result type did not match the expected type"
        | none => pure ()
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        let init ← translateExpr typeCtx locals (some accTy) initExpr
        let (elemName, accName, body) ← translateFoldrLambdaBody typeCtx locals elemTy accTy fnExpr
        return .listFoldr elemName accName elemTy accTy target init body
    | _ => unsupported e

  translateListAnyAll (wantAll : Bool) (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    let finish (alpha predExpr targetExpr : Expr) : CoreM SurfaceExpr := do
      let elemTy ← typeOfLeanWithCtx typeCtx alpha
      let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
      let (binder, predicate) ← translateUnaryLambdaBody typeCtx locals elemTy .bool predExpr
      if wantAll then return .listAll binder elemTy target predicate else return .listAny binder elemTy target predicate
    match args with
    | alpha :: predExpr :: targetExpr :: [] => finish alpha predExpr targetExpr
    | alpha :: targetExpr :: predExpr :: [] => finish alpha predExpr targetExpr
    | _ => unsupported e

  translateArrayMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        let target ← translateExpr typeCtx locals (some (.array elemTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy outTy fnExpr
        return .arrayMap binder elemTy outTy target body
    | alpha :: beta :: targetExpr :: fnExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        let target ← translateExpr typeCtx locals (some (.array elemTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy outTy fnExpr
        return .arrayMap binder elemTy outTy target body
    | _ => unsupported e

  translateArrayFoldl (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: initExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let accTy ← typeOfLeanWithCtx typeCtx beta
        match expected with
        | some wanted => if wanted == accTy then pure () else throwError "Array.foldl result type did not match the expected type"
        | none => pure ()
        let init ← translateExpr typeCtx locals (some accTy) initExpr
        let target ← translateExpr typeCtx locals (some (.array elemTy)) targetExpr
        let (accName, elemName, body) ← translateFoldlLambdaBody typeCtx locals accTy elemTy fnExpr
        return .arrayFoldl accName elemName accTy elemTy init target body
    | _ => unsupported e

  translateOptionMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: targetExpr :: [] => do
        let innerTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        let target ← translateExpr typeCtx locals (some (.option innerTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals innerTy outTy fnExpr
        return .optionMap binder innerTy outTy target body
    | _ => unsupported e

  translateOptionBind (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: targetExpr :: fnExpr :: [] => do
        let innerTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        match expected with
        | some (.option wanted) => if wanted == outTy then pure () else throwError "Option.bind result type did not match the expected Option type"
        | some _ => throwError "Option.bind expected type was not Option"
        | none => pure ()
        let target ← translateExpr typeCtx locals (some (.option innerTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals innerTy (.option outTy) fnExpr
        return .optionBind binder innerTy outTy target body
    | _ => unsupported e

  translateExceptMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | errExpr :: okExpr :: outExpr :: fnExpr :: targetExpr :: [] => do
        let errTy ← typeOfLeanWithCtx typeCtx errExpr
        let okTy ← typeOfLeanWithCtx typeCtx okExpr
        let outTy ← typeOfLeanWithCtx typeCtx outExpr
        let target ← translateExpr typeCtx locals (some (.result okTy errTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals okTy outTy fnExpr
        return .resultMapOk binder errTy okTy outTy target body
    | _ => unsupported e

  translateExceptBind (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | errExpr :: okExpr :: outExpr :: targetExpr :: fnExpr :: [] => do
        let errTy ← typeOfLeanWithCtx typeCtx errExpr
        let okTy ← typeOfLeanWithCtx typeCtx okExpr
        let outTy ← typeOfLeanWithCtx typeCtx outExpr
        match expected with
        | some (.result wantedOk wantedErr) =>
            if wantedOk == outTy && wantedErr == errTy then pure () else throwError "Except.bind result type did not match the expected Result type"
        | some _ => throwError "Except.bind expected type was not Result"
        | none => pure ()
        let target ← translateExpr typeCtx locals (some (.result okTy errTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals okTy (.result outTy errTy) fnExpr
        return .resultBind binder errTy okTy outTy target body
    | _ => unsupported e

  translateNatStepLambdaBody (typeCtx : TypeCtx) (locals : LocalCtx) (accTy : RType) (stepExpr : Expr) : CoreM (String × String × SurfaceExpr) := do
    match stripMData stepExpr with
    | .lam idxName idxTyExpr rest _ =>
        match stripMData rest with
        | .lam accName accTyExpr body _ => do
            let actualIdxTy ← typeOfLeanWithCtx typeCtx idxTyExpr
            let actualAccTy ← typeOfLeanWithCtx (none :: typeCtx) accTyExpr
            if actualIdxTy == .u32 && actualAccTy == accTy then
              let idxBinder := sanitizeRustIdent "idx" (nameLeaf idxName)
              let accBinder := sanitizeRustIdent "acc" (nameLeaf accName)
              let bodyExpr ← translateExpr (none :: none :: typeCtx)
                (some { name := accBinder, ty := accTy } :: some { name := idxBinder, ty := .u32 } :: locals)
                (some accTy) body
              pure (idxBinder, accBinder, bodyExpr)
            else
              throwError "Nat.rec step lambda must have shape Nat → accumulator → accumulator"
        | _ => unsupported stepExpr
    | _ => unsupported stepExpr

  translateListMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy outTy fnExpr
        return .listMap binder elemTy outTy target body
    | _ => unsupported e

  translateListFoldl (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: fnExpr :: initExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let accTy ← typeOfLeanWithCtx typeCtx beta
        match expected with
        | some wanted =>
            if wanted == accTy then pure () else throwError "List.foldl result type did not match the expected type"
        | none => pure ()
        let init ← translateExpr typeCtx locals (some accTy) initExpr
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        let (accName, elemName, body) ← translateFoldlLambdaBody typeCtx locals accTy elemTy fnExpr
        return .listFoldl accName elemName accTy elemTy init target body
    | _ => unsupported e

  translateNatRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match expected with
    | none => throwError "Nat.rec lowering needs an expected accumulator type"
    | some accTy =>
        match args with
        | _motive :: zeroExpr :: stepExpr :: discrExpr :: [] => do
            let init ← translateExpr typeCtx locals (some accTy) zeroExpr
            let n ← translateExpr typeCtx locals (some .u32) discrExpr
            let (idxName, accName, body) ← translateNatStepLambdaBody typeCtx locals accTy stepExpr
            return .natFold idxName accName accTy init n body
        | _ => unsupported e

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

  inductiveTypeFromArgs (typeCtx : TypeCtx) (inductName : Name) (args : List Expr) : CoreM (RType × List Expr) := do
    let env ← getEnv
    match env.find? inductName with
    | some (.inductInfo info) =>
        let paramExprs := args.take info.numParams
        if paramExprs.length == info.numParams then
          let concreteParams ← paramExprs.mapM (typeOfLeanWithCtx typeCtx)
          let ty ← typeOfInductiveWithArgs inductName concreteParams
          pure (ty, args.drop info.numParams)
        else
          throwError "inductive `{inductName}` expected {info.numParams} type parameters but got {paramExprs.length}"
    | _ => throwError "expected inductive declaration for {inductName}"

  translateEnumCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (recursor : Name) (args : List Expr) : CoreM SurfaceExpr := do
    let inductName := nameParent recursor
    let (enumTy, argsWithoutParams) ← inductiveTypeFromArgs typeCtx inductName args
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if argsWithoutParams.length == branchCount + 2 then
          match argsWithoutParams with
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
    let (enumTy, argsWithoutParams) ← inductiveTypeFromArgs typeCtx inductName args
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if argsWithoutParams.length == branchCount + 2 then
          match argsWithoutParams.reverse with
          | discr :: _ =>
              let rest := (argsWithoutParams.drop 1).take branchCount
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
        let paramExprs := args.take info.numParams
        let fallbackFromExpected : CoreM (Option (RType × List RArg)) :=
          match expected with
          | some ty@(.struct _ fields) => pure (some (ty, fields))
          | some ty@(.enum _ variants) =>
              match lookupVariant variants (nameLeaf ctorName) with
              | some payload =>
                  let fields := indexedPayloadFields payload
                  pure (some (ty, fields))
              | none => pure none
          | _ => pure none
        let inferred ←
          if paramExprs.length == info.numParams then
            try
              let concreteParams ← paramExprs.mapM (typeOfLeanWithCtx typeCtx)
              let ty ← typeOfInductiveWithArgs info.induct concreteParams
              let fields ← ctorPayloadFieldsWithParams ctorName concreteParams
              pure (some (ty, fields))
            catch _ =>
              fallbackFromExpected
          else
            fallbackFromExpected
        match inferred with
        | none => return none
        | some (ty, fields) =>
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
      let env ← getEnv
      match env.find? parent with
      | some (.inductInfo info) =>
          let paramExprs := args.take info.numParams
          if paramExprs.length != info.numParams then
            return none
          let concreteParams ← paramExprs.mapM (typeOfLeanWithCtx typeCtx)
          let ty ← typeOfInductiveWithArgs parent concreteParams
          match ty with
          | .struct _ fields =>
              let fieldName := nameLeaf projName
              match lookupRField fields fieldName, last? args with
              | some _fieldTy, some target =>
                  let targetExpr ← translateExpr typeCtx locals (some ty) target
                  return some (.field targetExpr fieldName)
              | _, _ => return none
          | _ => return none
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
        | none =>
            match (← firstOrderSignature? calledName) with
            | some (argTypes, retTy) =>
                if args.length == argTypes.length then
                  let rustName ← registerAutoHelperSpec calledName
                  let translatedArgs ← (argTypes.zip args).mapM (fun pair => translateExpr typeCtx locals (some pair.1) pair.2)
                  return some (.call rustName argTypes retTy translatedArgs)
                else
                  return none
            | none => return none


  isDefaultConst (n : Name) : Bool :=
    nameLeaf n == "default"

  isToStringConst (n : Name) : Bool :=
    nameLeaf n == "toString"

  isReprConst (n : Name) : Bool :=
    nameLeaf n == "reprStr" || nameLeaf n == "repr"

  isPureConst (n : Name) : Bool :=
    nameLeaf n == "pure"

  isBindConst (n : Name) : Bool :=
    nameLeaf n == "bind" && !(nameParent n == ``Option) && !(nameParent n == ``Except)

  isCompareConst (n : Name) : Bool :=
    nameLeaf n == "compare"

  translateDefaultValue (typeCtx : TypeCtx) (expected : Option RType) (args : List Expr) : CoreM SurfaceExpr := do
    let ty ← match expected with
      | some ty => pure ty
      | none =>
          match (← firstTypeArg? typeCtx args) with
          | some ty => pure ty
          | none => throwError "default/Inhabited lowering needs an expected type"
    pure (.defaultValue ty)

  translatePureValue (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match expected, last? args with
    | some (.option inner), some valueExpr =>
        pure (.optionSome (← translateExpr typeCtx locals (some inner) valueExpr))
    | some (.result ok err), some valueExpr =>
        pure (.resultOk err (← translateExpr typeCtx locals (some ok) valueExpr))
    | _, _ => unsupported e

  surfaceCtxFromLocals : LocalCtx → List RArg
    | [] => []
    | some local :: rest => (local.name, local.ty) :: surfaceCtxFromLocals rest
    | none :: rest => surfaceCtxFromLocals rest

  translatedSurfaceType (locals : LocalCtx) (expr : SurfaceExpr) : CoreM RType := do
    match typeOfExpected (surfaceCtxFromLocals locals) expr none with
    | .ok ty => pure ty
    | .error report => throwError "could not infer translated surface type during typeclass bind lowering: {report.detail}"

  translateTypeclassBind (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match lastTwo args with
    | some (targetExpr, fnExpr) => do
        let target ← translateExpr typeCtx locals none targetExpr
        let targetTy ← translatedSurfaceType locals target
        match targetTy, expected with
        | .option elemTy, some (.option outTy) =>
            let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy (.option outTy) fnExpr
            pure (.optionBind binder elemTy outTy target body)
        | .result okTy errTy, some (.result outTy expectedErr) =>
            if errTy == expectedErr then
              let (binder, body) ← translateUnaryLambdaBody typeCtx locals okTy (.result outTy errTy) fnExpr
              pure (.resultBind binder errTy okTy outTy target body)
            else
              unsupported e
        | _, _ => unsupported e
    | none => unsupported e

  translateStringLike (ctor : RType → SurfaceExpr → SurfaceExpr)
      (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match last? args with
    | some valueExpr => do
        let ty ← expectedOrTypeArg typeCtx none args .u32
        let value ← translateExpr typeCtx locals (some ty) valueExpr
        pure (ctor ty value)
    | none => unsupported e

  translateCompare (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    let domain ← expectedOrTypeArg typeCtx none args .u32
    match lastTwo args with
    | some (a, b) =>
        pure (.compare domain
          (← translateExpr typeCtx locals (some domain) a)
          (← translateExpr typeCtx locals (some domain) b))
    | none => unsupported e

  translateDirectLambdaApply (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (fnExpr : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match stripMData fnExpr, args with
    | .lam n ty body _, [argExpr] => do
        let argTy ← typeOfLeanWithCtx typeCtx ty
        let retTy ← match expected with
          | some retTy => pure retTy
          | none => throwError "direct captured-lambda application needs an expected result type"
        let binder := sanitizeRustIdent "arg" (nameLeaf n)
        let arg ← translateExpr typeCtx locals (some argTy) argExpr
        let bodyExpr ← translateExpr (none :: typeCtx) (some { name := binder, ty := argTy } :: locals) (some retTy) body
        pure (.closureApply binder argTy retTy arg bodyExpr)
    | _, _ => unsupported fnExpr

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
        else if isDefaultConst n then
          translateDefaultValue typeCtx expected args
        else if isPureConst n then
          translatePureValue typeCtx locals expected e args
        else if isToStringConst n then
          translateStringLike (fun ty value => .toStringValue ty value) typeCtx locals e args
        else if isReprConst n then
          translateStringLike (fun ty value => .reprValue ty value) typeCtx locals e args
        else if isBindConst n then
          translateTypeclassBind typeCtx locals expected e args
        else if isCompareConst n then
          translateCompare typeCtx locals e args
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
        else if n == ``List.map then
          translateListMap typeCtx locals e args
        else if n == ``List.filter then
          translateListFilter typeCtx locals e args
        else if n == ``List.foldl then
          translateListFoldl typeCtx locals expected e args
        else if n == ``List.foldr then
          translateListFoldr typeCtx locals expected e args
        else if n == ``List.any then
          translateListAnyAll false typeCtx locals e args
        else if n == ``List.all then
          translateListAnyAll true typeCtx locals e args
        else if n == ``Array.map then
          translateArrayMap typeCtx locals e args
        else if n == ``Array.foldl then
          translateArrayFoldl typeCtx locals expected e args
        else if n == ``Option.map then
          translateOptionMap typeCtx locals e args
        else if n == ``Option.bind then
          translateOptionBind typeCtx locals expected e args
        else if n == ``Except.map then
          translateExceptMap typeCtx locals e args
        else if n == ``Except.bind then
          translateExceptBind typeCtx locals expected e args
        else if n == ``Subtype.val then
          match expected with
          | some inner =>
              match last? args with
              | some target => return .subtypeVal inner (← translateExpr typeCtx locals (some (.subtype inner)) target)
              | none => unsupported e
          | none => throwError "Subtype.val extraction needs an expected runtime type"
        else if n == ``Fin.val then
          match last? args with
          | some target =>
              match stripMData target with
              | .bvar idx =>
                  match localAt locals idx with
                  | .ok local =>
                      match local.ty with
        else if isBindConst n then
          translateTypeclassBind typeCtx locals expected e args
                      | .fin bound => return .finVal bound (← translateExpr typeCtx locals (some (.fin bound)) target)
                      | _ => throwError "Fin.val target was not typed as Fin in the local context"
                  | .error msg => throwError msg
              | _ => throwError "Fin.val extraction currently supports local Fin variables only"
          | none => unsupported e
        else if isNamedRecursor n "casesOn" && nameParent n == ``Bool then
          translateBoolCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Bool then
          translateBoolRec typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" && nameParent n == ``Option then
          translateOptionCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Option then
          translateOptionRec typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Nat then
          translateNatRec typeCtx locals expected e args
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
    | .lam _ _ _ _ =>
        translateDirectLambdaApply typeCtx locals expected fn args
    | .bvar idx =>
        match localAt locals idx with
        | .ok local =>
            match local.ty, args with
            | .func argTy retTy, [arg] =>
                return .callValue (.var local.name) argTy retTy (← translateExpr typeCtx locals (some argTy) arg)
            | .func _ _, _ =>
                throwError "higher-order function value `{local.name}` was applied with an unsupported arity"
            | _, _ => unsupported e
        | .error msg => throwError msg
    | _ => unsupported e

private def rTypeSyntaxIdent (stx : Syntax) : Except String RType :=
  let n := stx.getId
  match nameLeaf n with
  | "Nat" => .ok .u32
  | "Bool" => .ok .bool
  | "Ordering" => .ok .ordering
  | "Unit" => .ok .unit
  | "UInt32" => .ok .u32
  | "UInt64" => .ok .u64
  | "Int32" => .ok .i32
  | "Int64" => .ok .i64
  | "Char" => .ok .char
  | "String" => .ok .string
  | _ => .error s!"rust_mono_export type argument `{n}` is not in the current concrete type subset"

private def rTypeReportLabel : RType → String
  | .unit => "Unit"
  | .bool => "Bool"
  | .ordering => "Ordering"
  | .u32 => "UInt32"
  | .u64 => "UInt64"
  | .i32 => "Int32"
  | .i64 => "Int64"
  | .char => "Char"
  | .string => "String"
  | .option t => "Option " ++ rTypeReportLabel t
  | .result ok err => "Except " ++ rTypeReportLabel err ++ " " ++ rTypeReportLabel ok
  | .list t => "List " ++ rTypeReportLabel t
  | .array t => "Array " ++ rTypeReportLabel t
  | .prod a b => "Prod " ++ rTypeReportLabel a ++ " " ++ rTypeReportLabel b
  | .sum a b => "Sum " ++ rTypeReportLabel a ++ " " ++ rTypeReportLabel b
  | .func a b => "Function " ++ rTypeReportLabel a ++ " -> " ++ rTypeReportLabel b
  | .subtype t => "Subtype " ++ rTypeReportLabel t
  | .fin n => "Fin " ++ Nat.toString n
  | .vector t n => "Vector " ++ rTypeReportLabel t ++ " " ++ Nat.toString n
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
    else if isProofTypeShape binderTy then
      typeCtx := none :: typeCtx
      locals := none :: locals
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
  enforceNatBoundaryPolicy declName typeBinders retTyExpr
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

/-!
## Extracted surface artifact emission

The differential suite should consume the exact `SurfaceFun`s produced by the
extractor, not hand-mirrored fixtures.  The helpers below quote checked surface
values back into Lean syntax so `rust_emit_exports_with_report_and_surface` can
define a first-class `List SurfaceFun` next to the generated Rust and report.
-/

private def stringTerm (s : String) : TSyntax `term :=
  ⟨Syntax.mkStrLit s⟩

private def natTerm (n : Nat) : TSyntax `term :=
  ⟨Syntax.mkNumLit (Nat.toString n)⟩

private def intTerm (n : Int) : CommandElabM (TSyntax `term) := do
  let magnitude := if n < 0 then Int.toNat (-n) else Int.toNat n
  let magnitudeTerm := natTerm magnitude
  if n < 0 then
    `(- (Int.ofNat $magnitudeTerm))
  else
    `(Int.ofNat $magnitudeTerm)

private partial def listTerm (items : List (TSyntax `term)) : CommandElabM (TSyntax `term) := do
  match items with
  | [] => `([])
  | item :: rest => do
      let restTerm ← listTerm rest
      `($item :: $restTerm)

private partial def rTypeTerm : RType → CommandElabM (TSyntax `term)
  | .unit => `(LeanRustCore.RType.unit)
  | .bool => `(LeanRustCore.RType.bool)
  | .u32 => `(LeanRustCore.RType.u32)
  | .u64 => `(LeanRustCore.RType.u64)
  | .ordering => `(LeanRustCore.RType.ordering)
  | .i32 => `(LeanRustCore.RType.i32)
  | .i64 => `(LeanRustCore.RType.i64)
  | .char => `(LeanRustCore.RType.char)
  | .string => `(LeanRustCore.RType.string)
  | .option ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.RType.option $tyTerm)
  | .result ok err => do
      let okTerm ← rTypeTerm ok
      let errTerm ← rTypeTerm err
      `(LeanRustCore.RType.result $okTerm $errTerm)
  | .list ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.RType.list $tyTerm)
  | .array ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.RType.array $tyTerm)
  | .prod a b => do
      let aTerm ← rTypeTerm a
      let bTerm ← rTypeTerm b
      `(LeanRustCore.RType.prod $aTerm $bTerm)
  | .sum a b => do
      let aTerm ← rTypeTerm a
      let bTerm ← rTypeTerm b
      `(LeanRustCore.RType.sum $aTerm $bTerm)
  | .func a b => do
      let aTerm ← rTypeTerm a
      let bTerm ← rTypeTerm b
      `(LeanRustCore.RType.func $aTerm $bTerm)
  | .subtype ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.RType.subtype $tyTerm)
  | .fin n => do
      let nTerm := natTerm n
      `(LeanRustCore.RType.fin $nTerm)
  | .vector ty n => do
      let tyTerm ← rTypeTerm ty
      let nTerm := natTerm n
      `(LeanRustCore.RType.vector $tyTerm $nTerm)
  | .struct name fields => do
      let nameTerm := stringTerm name
      let fieldTerms ← fields.mapM rArgTerm
      let fieldsTerm ← listTerm fieldTerms
      `(LeanRustCore.RType.struct $nameTerm $fieldsTerm)
  | .enum name variants => do
      let nameTerm := stringTerm name
      let variantTerms ← variants.mapM enumVariantTerm
      let variantsTerm ← listTerm variantTerms
      `(LeanRustCore.RType.enum $nameTerm $variantsTerm)
where
  rArgTerm (arg : RArg) : CommandElabM (TSyntax `term) := do
    let nameTerm := stringTerm arg.1
    let tyTerm ← rTypeTerm arg.2
    `(($nameTerm, $tyTerm))

  enumVariantTerm (variant : String × List RType) : CommandElabM (TSyntax `term) := do
    let nameTerm := stringTerm variant.1
    let payloadTerms ← variant.2.mapM rTypeTerm
    let payloadTerm ← listTerm payloadTerms
    `(($nameTerm, $payloadTerm))

private partial def surfaceExprTerm : SurfaceExpr → CommandElabM (TSyntax `term)
  | .var name => do
      let nameTerm := stringTerm name
      `(LeanRustCore.SurfaceExpr.var $nameTerm)
  | .litUnit => `(LeanRustCore.SurfaceExpr.litUnit)
  | .litBool value => do
      if value then
        `(LeanRustCore.SurfaceExpr.litBool true)
      else
        `(LeanRustCore.SurfaceExpr.litBool false)
  | .litU32 value => do
      let valueTerm := natTerm value
      `(LeanRustCore.SurfaceExpr.litU32 $valueTerm)
  | .litU64 value => do
      let valueTerm := natTerm value
      `(LeanRustCore.SurfaceExpr.litU64 $valueTerm)
  | .litI32 value => do
      let valueTerm ← intTerm value
      `(LeanRustCore.SurfaceExpr.litI32 $valueTerm)
  | .litI64 value => do
      let valueTerm ← intTerm value
      `(LeanRustCore.SurfaceExpr.litI64 $valueTerm)
  | .litChar value => do
      let valueTerm := natTerm value.toNat
      `(LeanRustCore.SurfaceExpr.litChar (Char.ofNat $valueTerm))
  | .litString value => do
      let valueTerm := stringTerm value
      `(LeanRustCore.SurfaceExpr.litString $valueTerm)
  | .letIn name value body => do
      let nameTerm := stringTerm name
      let valueTerm ← surfaceExprTerm value
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.letIn $nameTerm $valueTerm $bodyTerm)
  | .ite c a b => do
      let cTerm ← surfaceExprTerm c
      let aTerm ← surfaceExprTerm a
      let bTerm ← surfaceExprTerm b
      `(LeanRustCore.SurfaceExpr.ite $cTerm $aTerm $bTerm)
  | .matchBool c a b => do
      let cTerm ← surfaceExprTerm c
      let aTerm ← surfaceExprTerm a
      let bTerm ← surfaceExprTerm b
      `(LeanRustCore.SurfaceExpr.matchBool $cTerm $aTerm $bTerm)
  | .matchOption target noneCase someName someCase => do
      let targetTerm ← surfaceExprTerm target
      let noneTerm ← surfaceExprTerm noneCase
      let nameTerm := stringTerm someName
      let someTerm ← surfaceExprTerm someCase
      `(LeanRustCore.SurfaceExpr.matchOption $targetTerm $noneTerm $nameTerm $someTerm)
  | .matchEnum ty target branches => do
      let tyTerm ← rTypeTerm ty
      let targetTerm ← surfaceExprTerm target
      let branchTerms ← branches.mapM enumBranchTerm
      let branchesTerm ← listTerm branchTerms
      `(LeanRustCore.SurfaceExpr.matchEnum $tyTerm $targetTerm $branchesTerm)
  | .not a => do
      let aTerm ← surfaceExprTerm a
      `(LeanRustCore.SurfaceExpr.not $aTerm)
  | .and a b => binaryExprTerm ``LeanRustCore.SurfaceExpr.and a b
  | .or a b => binaryExprTerm ``LeanRustCore.SurfaceExpr.or a b
  | .eq ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.eq ty a b
  | .lt ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.lt ty a b
  | .le ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.le ty a b
  | .gt ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.gt ty a b
  | .ge ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.ge ty a b
  | .add ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.add ty a b
  | .sub ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.sub ty a b
  | .mul ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.mul ty a b
  | .min ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.min ty a b
  | .max ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.max ty a b
  | .compare ty a b => typedBinaryExprTerm ``LeanRustCore.SurfaceExpr.compare ty a b
  | .optionNone ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.SurfaceExpr.optionNone $tyTerm)
  | .optionSome value => do
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.optionSome $valueTerm)
  | .resultOk errTy value => do
      let errTerm ← rTypeTerm errTy
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.resultOk $errTerm $valueTerm)
  | .resultErr okTy value => do
      let okTerm ← rTypeTerm okTy
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.resultErr $okTerm $valueTerm)
  | .structLit ty fields => do
      let tyTerm ← rTypeTerm ty
      let fieldTerms ← fields.mapM exprFieldTerm
      let fieldsTerm ← listTerm fieldTerms
      `(LeanRustCore.SurfaceExpr.structLit $tyTerm $fieldsTerm)
  | .field target fieldName => do
      let targetTerm ← surfaceExprTerm target
      let fieldTerm := stringTerm fieldName
      `(LeanRustCore.SurfaceExpr.field $targetTerm $fieldTerm)
  | .enumVariant ty variant payload => do
      let tyTerm ← rTypeTerm ty
      let variantTerm := stringTerm variant
      let payloadTerms ← payload.mapM surfaceExprTerm
      let payloadTerm ← listTerm payloadTerms
      `(LeanRustCore.SurfaceExpr.enumVariant $tyTerm $variantTerm $payloadTerm)
  | .call name argTypes ret args => do
      let nameTerm := stringTerm name
      let argTypeTerms ← argTypes.mapM rTypeTerm
      let argTypesTerm ← listTerm argTypeTerms
      let retTerm ← rTypeTerm ret
      let argTerms ← args.mapM surfaceExprTerm
      let argsTerm ← listTerm argTerms
      `(LeanRustCore.SurfaceExpr.call $nameTerm $argTypesTerm $retTerm $argsTerm)
  | .callValue fn argTy retTy arg => do
      let fnTerm ← surfaceExprTerm fn
      let argTyTerm ← rTypeTerm argTy
      let retTyTerm ← rTypeTerm retTy
      let argTerm ← surfaceExprTerm arg
      `(LeanRustCore.SurfaceExpr.callValue $fnTerm $argTyTerm $retTyTerm $argTerm)
  | .closureApply binder argTy retTy arg body => do
      let binderTerm := stringTerm binder
      let argTyTerm ← rTypeTerm argTy
      let retTyTerm ← rTypeTerm retTy
      let argTerm ← surfaceExprTerm arg
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.closureApply $binderTerm $argTyTerm $retTyTerm $argTerm $bodyTerm)
  | .defaultValue ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.SurfaceExpr.defaultValue $tyTerm)
  | .toStringValue ty value => do
      let tyTerm ← rTypeTerm ty
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.toStringValue $tyTerm $valueTerm)
  | .reprValue ty value => do
      let tyTerm ← rTypeTerm ty
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.reprValue $tyTerm $valueTerm)
  | .listMap binder elemTy outTy target body => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.listMap $binderTerm $elemTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .listFilter binder elemTy target predicate => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      let predicateTerm ← surfaceExprTerm predicate
      `(LeanRustCore.SurfaceExpr.listFilter $binderTerm $elemTyTerm $targetTerm $predicateTerm)
  | .listFoldl accName elemName accTy elemTy init target body => do
      let accNameTerm := stringTerm accName
      let elemNameTerm := stringTerm elemName
      let accTyTerm ← rTypeTerm accTy
      let elemTyTerm ← rTypeTerm elemTy
      let initTerm ← surfaceExprTerm init
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.listFoldl $accNameTerm $elemNameTerm $accTyTerm $elemTyTerm $initTerm $targetTerm $bodyTerm)
  | .listFoldr elemName accName elemTy accTy target init body => do
      let elemNameTerm := stringTerm elemName
      let accNameTerm := stringTerm accName
      let elemTyTerm ← rTypeTerm elemTy
      let accTyTerm ← rTypeTerm accTy
      let targetTerm ← surfaceExprTerm target
      let initTerm ← surfaceExprTerm init
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.listFoldr $elemNameTerm $accNameTerm $elemTyTerm $accTyTerm $targetTerm $initTerm $bodyTerm)
  | .listAny binder elemTy target predicate => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      let predicateTerm ← surfaceExprTerm predicate
      `(LeanRustCore.SurfaceExpr.listAny $binderTerm $elemTyTerm $targetTerm $predicateTerm)
  | .listAll binder elemTy target predicate => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      let predicateTerm ← surfaceExprTerm predicate
      `(LeanRustCore.SurfaceExpr.listAll $binderTerm $elemTyTerm $targetTerm $predicateTerm)
  | .arrayMap binder elemTy outTy target body => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.arrayMap $binderTerm $elemTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .arrayFoldl accName elemName accTy elemTy init target body => do
      let accNameTerm := stringTerm accName
      let elemNameTerm := stringTerm elemName
      let accTyTerm ← rTypeTerm accTy
      let elemTyTerm ← rTypeTerm elemTy
      let initTerm ← surfaceExprTerm init
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.arrayFoldl $accNameTerm $elemNameTerm $accTyTerm $elemTyTerm $initTerm $targetTerm $bodyTerm)
  | .optionMap binder innerTy outTy target body => do
      let binderTerm := stringTerm binder
      let innerTyTerm ← rTypeTerm innerTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.optionMap $binderTerm $innerTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .optionBind binder innerTy outTy target body => do
      let binderTerm := stringTerm binder
      let innerTyTerm ← rTypeTerm innerTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.optionBind $binderTerm $innerTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .resultMapOk binder errTy okTy outTy target body => do
      let binderTerm := stringTerm binder
      let errTyTerm ← rTypeTerm errTy
      let okTyTerm ← rTypeTerm okTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.resultMapOk $binderTerm $errTyTerm $okTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .resultBind binder errTy okTy outTy target body => do
      let binderTerm := stringTerm binder
      let errTyTerm ← rTypeTerm errTy
      let okTyTerm ← rTypeTerm okTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.resultBind $binderTerm $errTyTerm $okTyTerm $outTyTerm $targetTerm $bodyTerm)
  | .subtypeErase inner value => do
      let innerTerm ← rTypeTerm inner
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.subtypeErase $innerTerm $valueTerm)
  | .subtypeVal inner value => do
      let innerTerm ← rTypeTerm inner
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.subtypeVal $innerTerm $valueTerm)
  | .finCheck bound value => do
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.finCheck $boundTerm $valueTerm)
  | .finVal bound value => do
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.finVal $boundTerm $valueTerm)
  | .vectorCheck elemTy bound value => do
      let elemTyTerm ← rTypeTerm elemTy
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.vectorCheck $elemTyTerm $boundTerm $valueTerm)
  | .natFold idxName accName accTy init n body => do
      let idxNameTerm := stringTerm idxName
      let accNameTerm := stringTerm accName
      let accTyTerm ← rTypeTerm accTy
      let initTerm ← surfaceExprTerm init
      let nTerm ← surfaceExprTerm n
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.natFold $idxNameTerm $accNameTerm $accTyTerm $initTerm $nTerm $bodyTerm)
where
  enumBranchTerm (branch : String × (List String × SurfaceExpr)) : CommandElabM (TSyntax `term) := do
    let variantTerm := stringTerm branch.1
    let binderTerms := branch.2.1.map stringTerm
    let bindersTerm ← listTerm binderTerms
    let bodyTerm ← surfaceExprTerm branch.2.2
    `(($variantTerm, ($bindersTerm, $bodyTerm)))

  exprFieldTerm (field : String × SurfaceExpr) : CommandElabM (TSyntax `term) := do
    let fieldTerm := stringTerm field.1
    let valueTerm ← surfaceExprTerm field.2
    `(($fieldTerm, $valueTerm))

  binaryExprTerm (ctorName : Name) (a b : SurfaceExpr) : CommandElabM (TSyntax `term) := do
    let ctor := mkIdent ctorName
    let aTerm ← surfaceExprTerm a
    let bTerm ← surfaceExprTerm b
    `($ctor $aTerm $bTerm)

  typedBinaryExprTerm (ctorName : Name) (ty : RType) (a b : SurfaceExpr) : CommandElabM (TSyntax `term) := do
    let ctor := mkIdent ctorName
    let tyTerm ← rTypeTerm ty
    let aTerm ← surfaceExprTerm a
    let bTerm ← surfaceExprTerm b
    `($ctor $tyTerm $aTerm $bTerm)

private def surfaceFunTerm (f : SurfaceFun) : CommandElabM (TSyntax `term) := do
  let nameTerm := stringTerm f.name
  let argTerms ← f.args.mapM (fun arg => do
    let argName := stringTerm arg.1
    let argTy ← rTypeTerm arg.2
    `(($argName, $argTy)))
  let argsTerm ← listTerm argTerms
  let retTerm ← rTypeTerm f.ret
  let bodyTerm ← surfaceExprTerm f.body
  `(({ name := $nameTerm, args := $argsTerm, ret := $retTerm, body := $bodyTerm } : LeanRustCore.SurfaceFun))

private def surfaceFunListTerm (functions : List SurfaceFun) : CommandElabM (TSyntax `term) := do
  let functionTerms ← functions.mapM surfaceFunTerm
  listTerm functionTerms

private def supportedDiagnostic (source rustName : String) (detail : String := "exported") : ExportDiagnostic :=
  { source := source, rustName := rustName, code := .supported, detail := detail }

private def unsupportedDiagnostic (source rustName detail : String) : ExportDiagnostic :=
  { source := source, rustName := rustName, code := .unsupportedDeclaration, detail := detail }

private def typeclassSpecializationExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "decidable_eq_u32" ||
  leaf == "ord_compare_u32" ||
  leaf == "inhabited_default_u32" ||
  leaf == "to_string_u32" ||
  leaf == "repr_u32"

private def monadicSpecializationExport (declName : Name) : Bool :=
  nameLeaf declName == "option_do_inc_u32"

private def immediateClosureExport (declName : Name) : Bool :=
  nameLeaf declName == "closure_apply_capture_u32"

private def regularSupportedDetail (declName : Name) : CoreM String := do
  let env ← getEnv
  if LeanRustCore.Export.natWrappingU32Allowed env declName then
    pure "exported-nat-wrapping-u32"
  else
    pure "exported"

private def extractRegularWithDiagnostic (declName : Name) : CoreM (Option SurfaceFun × ExportDiagnostic) := do
  else if typeclassSpecializationExport declName then
    pure "exported-typeclass-specialization"
  else if monadicSpecializationExport declName then
    pure "exported-monadic-bind-specialization"
  else if immediateClosureExport declName then
    pure "exported-immediate-closure-conversion"
  let rustName := sanitizeRustIdent "generated" (nameLeaf declName)
  try
    let f ← extractConst declName
    let detail ← regularSupportedDetail declName
    pure (some f, supportedDiagnostic (toString declName) f.name detail)
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

partial def extractPendingAutoHelpers (seen : List MonoExportSpec) (functions : List SurfaceFun) (diagnostics : List ExportDiagnostic) (fuel : Nat) : CoreM ExtractionResult := do
  match fuel with
  | 0 => pure { functions := functions, diagnostics := diagnostics ++ [unsupportedDiagnostic "<auto-helper-extraction>" "<fuel>" "automatic helper extraction stopped after the fixpoint fuel was exhausted"] }
  | fuel' + 1 => do
      let autoSpecs ← liftIO autoHelperExportSpecsRef.get
      let pending := pendingAutoSpecs seen autoSpecs
      if pending.isEmpty then
        pure { functions := functions, diagnostics := diagnostics }
      else
        let mut functions' := functions
        let mut diagnostics' := diagnostics
        for spec in pending do
          let (maybeFun, diagnostic) ← extractMonoWithDiagnostic spec "auto-helper-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeFun with
          | some f => functions' := functions' ++ [f]
          | none => pure ()
        extractPendingAutoHelpers (seen ++ pending) functions' diagnostics' fuel'

private partial def extractPendingGeneratedSpecs (seenMonos seenHelpers : List MonoExportSpec) (functions : List SurfaceFun) (diagnostics : List ExportDiagnostic) (fuel : Nat) : CoreM ExtractionResult := do
  match fuel with
  | 0 => pure { functions := functions, diagnostics := diagnostics ++ [unsupportedDiagnostic "<auto-generated-specs>" "<fuel>" "automatic monomorphization/helper extraction stopped after the fixpoint fuel was exhausted"] }
  | fuel' + 1 => do
      let autoMonos ← liftIO autoMonoExportSpecsRef.get
      let autoHelpers ← liftIO autoHelperExportSpecsRef.get
      let pendingMonos := pendingAutoSpecs seenMonos autoMonos
      let pendingHelpers := pendingAutoSpecs seenHelpers autoHelpers
      if pendingMonos.isEmpty && pendingHelpers.isEmpty then
        pure { functions := functions, diagnostics := diagnostics }
      else
        let mut functions' := functions
        let mut diagnostics' := diagnostics
        for spec in pendingMonos do
          let (maybeFun, diagnostic) ← extractMonoWithDiagnostic spec "auto-monomorphized-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeFun with
          | some f => functions' := functions' ++ [f]
          | none => pure ()
        for spec in pendingHelpers do
          let (maybeFun, diagnostic) ← extractMonoWithDiagnostic spec "auto-helper-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeFun with
          | some f => functions' := functions' ++ [f]
          | none => pure ()
        extractPendingGeneratedSpecs (seenMonos ++ pendingMonos) (seenHelpers ++ pendingHelpers) functions' diagnostics' fuel'

private def extractPendingAutoMonos (seen : List MonoExportSpec) (functions : List SurfaceFun) (diagnostics : List ExportDiagnostic) (fuel : Nat) : CoreM ExtractionResult :=
  extractPendingGeneratedSpecs seen [] functions diagnostics fuel

/-- Tolerant extraction: successful declarations are emitted; unsupported declarations are reported. -/
def extractWithDiagnostics (decls : List Name) (monos : List MonoExportSpec) : CoreM ExtractionResult := do
  liftIO <| autoMonoExportSpecsRef.set []
  liftIO <| autoHelperExportSpecsRef.set []
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
  extractPendingGeneratedSpecs monos [] functions diagnostics (decls.length + monos.length + 64)

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

/-- Emit Rust, a structured compatibility report, and the checked extractor-owned `SurfaceFun` artifact. -/
syntax (name := rustEmitExportsWithReportAndSurface) "rust_emit_exports_with_report_and_surface " ident ident ident : command

elab_rules : command
  | `(rust_emit_exports_with_report_and_surface $out:ident $reportOut:ident $surfaceOut:ident) => do
      let result ← currentExtractionResult
      let rust ← match emitSurfaceRustModuleChecked result.functions with
        | .ok source => pure source
        | .error report => throwError "Rust identifier hygiene failed: {report.detail}"
      let report := emitCompatibilityReport result
      let surfaceTerm ← surfaceFunListTerm result.functions
      let rustLit := Syntax.mkStrLit rust
      let reportLit := Syntax.mkStrLit report
      elabCommand (← `(def $out : String := $rustLit))
      elabCommand (← `(def $reportOut : String := $reportLit))
      elabCommand (← `(def $surfaceOut : List LeanRustCore.SurfaceFun := $surfaceTerm))

end LeanRustCore.Extract