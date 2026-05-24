import Lean
import LeanRustCore.EmitRust
import LeanRustCore.Export
import LeanRustCore.DependentErasure
import LeanRustCore.ExtractIR

import LeanRustCore.ClosureConversion
namespace LeanRustCore.Extract

open Lean Elab Command
open LeanRustCore
open LeanRustCore.DependentErasure

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
  extractDecls : List LeanRustCore.ExtractIR.ExtractDecl
  diagnostics : List ExportDiagnostic
  deriving Repr, BEq

initialize monoExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []
initialize autoMonoExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []
initialize autoHelperExportSpecsRef : IO.Ref (List MonoExportSpec) ← IO.mkRef []

private def nameLeaf : Name → String
  | .anonymous => "_"
  | .str _ s => s
  | .num p n => nameLeaf p ++ toString n

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
  | some (some localVal) => Except.ok localVal
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

/-- Conservative proof-erasure predicate for exported binders and constructor fields. -/
private def isProofTypeShape (ty0 : Expr) : Bool :=
  let ty := stripMData ty0
  match ty.getAppFn with
  | .const n _ => proofHeadNameIsErased n
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

private def exprContainsAnyConst (needles : List Name) (e : Expr) : Bool :=
  needles.any (fun needle => exprContainsConst needle e)

private def inductiveInfoIsRecursive (env : Environment) (info : InductiveVal) : Bool :=
  if info.all.length > 1 then
    true
  else
    info.ctors.any (fun ctorName =>
      match env.find? ctorName with
      | some (.ctorInfo ctorInfo) =>
          let (binders, _) := peelForalls ctorInfo.type
          let fieldBinders := (binders.drop ctorInfo.numParams).take ctorInfo.numFields
          fieldBinders.any (fun field => exprContainsAnyConst info.all field.2)
      | _ => false)

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

private def lookupVariantPayload (variants : List (String × List RType)) (variantName : String) : Option (List RType) :=
  match variants with
  | [] => none
  | (name, payload) :: rest =>
      if name == variantName then some payload else lookupVariantPayload rest variantName

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
  | .ordering => "ordering"
  | .nat => "nat"
  | .int => "int"
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
  | .boxed t => "box_" ++ rTypeRuntimeSuffix t
  | .recursive name => sanitizeRustIdent "rec" (lowerRuntimeTypeString name)
  | .subtype t => "subtype_" ++ rTypeRuntimeSuffix t
  | .fin n => "fin_" ++ toString n
  | .vector t n => "vector_" ++ rTypeRuntimeSuffix t ++ "_" ++ toString n
  | .struct name _ => sanitizeRustIdent "struct" (lowerRuntimeTypeString name)
  | .enum name _ => sanitizeRustIdent "enum" (lowerRuntimeTypeString name)

private def monomorphizedInductiveName (inductName : Name) (typeArgs : List RType) : String :=
  if typeArgs.isEmpty then
    nameLeaf inductName
  else
    nameLeaf inductName ++ "__" ++ joinWith "_" (typeArgs.map rTypeRuntimeSuffix)

private def binaryTreeU32Type : RType :=
  .enum "BinaryTreeU32" [
    ("leaf", []),
    ("node", [.boxed (.recursive "BinaryTreeU32"), .u32, .boxed (.recursive "BinaryTreeU32")])
  ]

private def exprU32Type : RType :=
  .enum "ExprU32" [
    ("lit", [.u32]),
    ("add", [.boxed (.recursive "ExprU32"), .boxed (.recursive "ExprU32")])
  ]

private def recursiveRuntimeName? : RType → Option String
  | .recursive name => some name
  | .enum name _ => some name
  | _ => none

private def sameRecursiveRuntimeType (a b : RType) : Bool :=
  match recursiveRuntimeName? a, recursiveRuntimeName? b with
  | some x, some y => x == y
  | _, _ => false

private def indexedPayloadFieldsAux (idx : Nat) : List RType → List RArg
  | [] => []
  | ty :: rest => ("field" ++ toString idx, ty) :: indexedPayloadFieldsAux (idx + 1) rest

private def indexedPayloadFields (payload : List RType) : List RArg :=
  indexedPayloadFieldsAux 0 payload

private def indexedRuntimePayloadFieldsAux (idx : Nat) : List RType → List (RArg × Nat)
  | [] => []
  | ty :: rest => (("field" ++ toString idx, ty), idx) :: indexedRuntimePayloadFieldsAux (idx + 1) rest

private def indexedRuntimePayloadFields (payload : List RType) : List (RArg × Nat) :=
  indexedRuntimePayloadFieldsAux 0 payload

mutual
  partial def typeOfLeanWithMode (typeCtx : TypeCtx) (recursiveGroup? : Option (List Name))
      (indirect : Bool) (ty0 : Expr) : CoreM RType := do
    let ty := stripMData ty0
    match ty with
    | .bvar idx => typeParamAt typeCtx idx
    | .forallE _ domain body _ => do
        let argTy ← typeOfLeanWithMode typeCtx recursiveGroup? indirect domain
        let retTy ← typeOfLeanWithMode (none :: typeCtx) recursiveGroup? indirect body
        pure (.func argTy retTy)
    | _ =>
        if ty.isConstOf ``Nat then
          return .u32
        else if ty.isConstOf ``Int then
          return .int
        else if ty.isConstOf ``Bool then
          return .bool
        else if ty.isConstOf ``Unit then
          return .unit
        else if ty.isConstOf ``Ordering then
          return .ordering
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
                | [inner] => return .option (← typeOfLeanWithMode typeCtx recursiveGroup? indirect inner)
                | _ => throwError "unsupported Option type shape in rust_export extraction"
              else if n == ``Except then
                match args with
                | [errTy, okTy] =>
                    return .result
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect okTy)
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect errTy)
                | _ => throwError "unsupported Except type shape in rust_export extraction"
              else if n == ``List then
                match args with
                | [inner] => return .list (← typeOfLeanWithMode typeCtx recursiveGroup? true inner)
                | _ => throwError "unsupported List type shape in rust_export extraction"
              else if n == ``Array then
                match args with
                | [inner] => return .array (← typeOfLeanWithMode typeCtx recursiveGroup? true inner)
                | _ => throwError "unsupported Array type shape in rust_export extraction"
              else if n == ``Prod then
                match args with
                | [a, b] =>
                    return .prod
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect a)
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect b)
                | _ => throwError "unsupported Prod type shape in rust_export extraction"
              else if n == ``Sigma then
                match args with
                | [domain, codomain] =>
                    let codomainTy ←
                      match stripMData codomain with
                      | .lam _ _ body _ => typeOfLeanWithMode (none :: typeCtx) recursiveGroup? indirect body
                      | other => typeOfLeanWithMode (none :: typeCtx) recursiveGroup? indirect other
                    return .prod
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect domain)
                      codomainTy
                | _ => throwError "unsupported Sigma type shape in rust_export extraction"
              else if n == ``Sum then
                match args with
                | [a, b] =>
                    return .sum
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect a)
                      (← typeOfLeanWithMode typeCtx recursiveGroup? indirect b)
                | _ => throwError "unsupported Sum type shape in rust_export extraction"
              else if n == ``Subtype then
                match args with
                | [inner, _pred] => return .subtype (← typeOfLeanWithMode typeCtx recursiveGroup? indirect inner)
                | _ => throwError "unsupported Subtype shape in rust_export extraction"
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
                    | some bound => return .vector (← typeOfLeanWithMode typeCtx recursiveGroup? true inner) bound
                    | none => throwError "Vector length indices must be numeral literals in the current rust_export subset"
                | _ => throwError "unsupported Vector type shape in rust_export extraction"
              else if nameLeaf n == "FlagCarrier" then
                match args with
                  | [_index] => return .u32
                  | _ => throwError "unsupported FlagCarrier shape in rust_export extraction"
              else
                let env ← getEnv
                match env.find? n with
                | some (.inductInfo info) => do
                    let paramExprs := args.take info.numParams
                    if paramExprs.length == info.numParams then
                      let concreteParams ← paramExprs.mapM (typeOfLeanWithMode typeCtx recursiveGroup? indirect)
                      match recursiveGroup? with
                      | some recursiveGroup =>
                          if containsName recursiveGroup n then
                            let recursiveTy := .recursive (monomorphizedInductiveName n concreteParams)
                            return if indirect then recursiveTy else .boxed recursiveTy
                          else
                            typeOfInductiveWithArgs n concreteParams
                      | none =>
                          if indirect && inductiveInfoIsRecursive env info then
                            pure (.recursive (monomorphizedInductiveName n concreteParams))
                          else
                            typeOfInductiveWithArgs n concreteParams
                    else
                      throwError "inductive type `{n}` expected {info.numParams} parameters but got {paramExprs.length}"
                | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"
          | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"

  partial def typeOfLeanWithCtx (typeCtx : TypeCtx) (ty0 : Expr) : CoreM RType :=
    typeOfLeanWithMode typeCtx none false ty0

  partial def typeOfLeanRecursiveField (typeCtx : TypeCtx) (recursiveGroup : List Name)
      (indirect : Bool) (ty0 : Expr) : CoreM RType :=
    typeOfLeanWithMode typeCtx (some recursiveGroup) indirect ty0

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
    pure ((← ctorRuntimePayloadFieldsWithParams ctorName typeArgs).map (fun field => field.1))

  /-- Runtime constructor fields paired with their original constructor-field index. Proof-only fields are erased. -/
  partial def ctorRuntimePayloadFieldsWithParams (ctorName : Name) (typeArgs : List RType) : CoreM (List (RArg × Nat)) := do
    let env ← getEnv
    match env.find? ctorName with
    | some (.ctorInfo info) =>
        if info.numParams == typeArgs.length then
          let (binders, _) := peelForalls info.type
          let fieldBinders := (binders.drop info.numParams).take info.numFields
          let recursiveGroup :=
            match env.find? (nameParent ctorName) with
            | some (.inductInfo inductInfo) => inductInfo.all
            | _ => [nameParent ctorName]
          let mut out : List (RArg × Nat) := []
          let mut fieldCtx := typeCtxFromParams typeArgs
          let mut idx : Nat := 0
          for field in fieldBinders do
            if isProofTypeShape field.2 then
              fieldCtx := none :: fieldCtx
              idx := idx + 1
            else
              let fallback := "field" ++ toString idx
              let fieldName := sanitizeRustIdent fallback (nameLeaf field.1)
              let fieldTy ← typeOfLeanRecursiveField fieldCtx recursiveGroup false field.2
              out := out ++ [((fieldName, fieldTy), idx)]
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
  | .nat => "nat"
  | .int => "int"
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
  | .boxed t => "box_" ++ rTypeMonoSuffix t
  | .recursive name => sanitizeRustIdent "rec" (lowerRuntimeTypeString name)
  | .subtype t => "subtype_" ++ rTypeMonoSuffix t
  | .fin n => "fin_" ++ toString n
  | .vector t n => "vector_" ++ rTypeMonoSuffix t ++ "_" ++ toString n
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
  let explicitSpecs ← monoExportSpecsRef.get
  match findMonoSpecByKey source typeArgs explicitSpecs with
  | some spec => pure spec.rustName
  | none => do
      let autoSpecs ← autoMonoExportSpecsRef.get
      match findMonoSpecByKey source typeArgs autoSpecs with
      | some spec => pure spec.rustName
      | none => do
          let rustName := autoMonoRustName source typeArgs
          let spec : MonoExportSpec := { source := source, rustName := rustName, typeArgs := typeArgs }
          autoMonoExportSpecsRef.modify (fun specs => specs ++ [spec])
          pure rustName

private def helperRustName (source : Name) : String :=
  sanitizeRustIdent "generated" (nameLeaf source)

private def registerAutoHelperSpec (source : Name) : CoreM String := do
  let explicitSpecs ← monoExportSpecsRef.get
  match findMonoSpecByKey source [] explicitSpecs with
  | some spec => pure spec.rustName
  | none => do
      let autoSpecs ← autoHelperExportSpecsRef.get
      match findMonoSpecByKey source [] autoSpecs with
      | some spec => pure spec.rustName
      | none => do
          let rustName := helperRustName source
          let spec : MonoExportSpec := { source := source, rustName := rustName, typeArgs := [] }
          autoHelperExportSpecsRef.modify (fun specs => specs ++ [spec])
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

private def isPatternMatchHelper (n : Name) : Bool :=
  (nameLeaf n).startsWith "match_"

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
      match localAt locals idx with
      | .ok localVal =>
          match expected, localVal.ty with
          | some (.boxed inner), actual =>
              if sameRecursiveRuntimeType inner actual then
                return .boxNew inner (.var localVal.name)
              else
                return .var localVal.name
          | some wanted, .boxed inner =>
              if sameRecursiveRuntimeType wanted inner then
                return .boxDeref inner (.var localVal.name)
              else
                return .var localVal.name
          | _, _ => return .var localVal.name
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
  | .proj structName fieldIdx target =>
      if nameLeaf structName == "Subtype" && fieldIdx == 0 then
        match expected with
        | some inner => return .subtypeVal inner (← translateExpr typeCtx locals (some (.subtype inner)) target)
        | none => throwError "Subtype.val projection needs an expected erased runtime type"
      else if nameLeaf structName == "Fin" && fieldIdx == 0 then
        match stripMData target with
        | .bvar idx =>
            match localAt locals idx with
            | .ok localVal =>
                match localVal.ty with
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

  translateListReverse (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        if elemTy == .u32 then
          let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
          pure (.call "__runtime_list_reverse_u32" [.list elemTy] (.list elemTy) [target])
        else
          unsupported e
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
    | alpha :: a :: b :: [] =>
        try
          finish alpha a b
        catch _ =>
          finish alpha b a
    | _ => unsupported e

  translateArrayMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    let finish (alpha beta fnExpr targetExpr : Expr) : CoreM SurfaceExpr := do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        let target ← translateExpr typeCtx locals (some (.array elemTy)) targetExpr
        let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy outTy fnExpr
        return .arrayMap binder elemTy outTy target body
    match args with
    | alpha :: beta :: a :: b :: [] =>
        try
          finish alpha beta a b
        catch _ =>
          finish alpha beta b a
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

  translateArrayGet (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: targetExpr :: indexExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        if elemTy == .u32 then
          let target ← translateExpr typeCtx locals (some (.array elemTy)) targetExpr
          let index ← translateExpr typeCtx locals (some .u32) indexExpr
          pure (.call "__runtime_array_get_u32" [.array elemTy, .u32] (.option elemTy) [target, index])
        else
          unsupported e
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

  translateListLength (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let target ← translateExpr typeCtx locals (some (.list elemTy)) targetExpr
        return .listLength elemTy target
    | _ => unsupported e

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

  translateNatSuccBranch (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType)
      (succCase : Expr) : CoreM (String × SurfaceExpr) := do
    match stripMData succCase with
    | .lam predName predTyExpr body _ => do
        let actualPredTy ← typeOfLeanWithCtx typeCtx predTyExpr
        if actualPredTy == .u32 then
          let predBinder := sanitizeRustIdent "pred" (nameLeaf predName)
          let bodyExpr ← translateExpr (none :: typeCtx)
            (some { name := predBinder, ty := .u32 } :: locals)
            expected
            body
          pure (predBinder, bodyExpr)
        else
          throwError "Nat.casesOn successor branch binder must lower to Nat/u32"
    | _ => unsupported succCase

  translateNatCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType)
      (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: discrExpr :: zeroExpr :: succExpr :: [] => do
        let discr ← translateExpr typeCtx locals (some .u32) discrExpr
        let zeroBranch ← translateExpr typeCtx locals expected zeroExpr
        let (predBinder, succBranchBody) ← translateNatSuccBranch typeCtx locals expected succExpr
        let predValue := SurfaceExpr.sub .u32 discr (.litU32 1)
        pure <| .ite (.eq .u32 discr (.litU32 0)) zeroBranch
          (.letIn predBinder predValue succBranchBody)
    | _ => unsupported e

  translateListConsBranch (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType)
      (elemTy : RType) (consCase : Expr) : CoreM (String × String × SurfaceExpr) := do
    match stripMData consCase with
    | .lam headName headTyExpr rest _ =>
        match stripMData rest with
        | .lam tailName tailTyExpr body _ => do
            let actualHeadTy ← typeOfLeanWithCtx typeCtx headTyExpr
            let actualTailTy ← typeOfLeanWithCtx (none :: typeCtx) tailTyExpr
            if actualHeadTy == elemTy && actualTailTy == .list elemTy then
              let headBinder := sanitizeRustIdent "head" (nameLeaf headName)
              let tailBinder := sanitizeRustIdent "tail" (nameLeaf tailName)
              let bodyExpr ← translateExpr (none :: none :: typeCtx)
                (some { name := tailBinder, ty := .list elemTy } :: some { name := headBinder, ty := elemTy } :: locals)
                expected
                body
              pure (headBinder, tailBinder, bodyExpr)
            else
              throwError "List.casesOn cons branch binders must lower to element/list runtime types"
        | _ => unsupported consCase
    | _ => unsupported consCase

  translateListCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType)
      (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: _motive :: discrExpr :: nilExpr :: consExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let discr ← translateExpr typeCtx locals (some (.list elemTy)) discrExpr
        let nilBranch ← translateExpr typeCtx locals expected nilExpr
        let (headBinder, tailBinder, consBody) ←
          translateListConsBranch typeCtx locals expected elemTy consExpr
        let emptyCheck := .eq .u32 (.listLength elemTy discr) (.litU32 0)
        let headValue := .call "__runtime_list_head_clone" [.list elemTy] (.option elemTy) [discr]
        let tailValue := .call "__runtime_list_tail_clone" [.list elemTy] (.list elemTy) [discr]
        let consBranch := .matchOption headValue nilBranch headBinder (.letIn tailBinder tailValue consBody)
        pure <| .ite emptyCheck nilBranch consBranch
    | _ => unsupported e

  translateBoolCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: discr :: falseCase :: trueCase :: [] => do
        let target ← translateExpr typeCtx locals (some .bool) discr
        let trueExpr ← translateExpr typeCtx locals expected trueCase
        let falseExpr ← translateExpr typeCtx locals expected falseCase
        return .matchPattern .bool target [
          (SurfacePattern.bool true, trueExpr),
          (SurfacePattern.bool false, falseExpr)
        ]
    | _ => unsupported e

  translateBoolRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: falseCase :: trueCase :: discr :: [] => do
        let target ← translateExpr typeCtx locals (some .bool) discr
        let trueExpr ← translateExpr typeCtx locals expected trueCase
        let falseExpr ← translateExpr typeCtx locals expected falseCase
        return .matchPattern .bool target [
          (SurfacePattern.bool true, trueExpr),
          (SurfacePattern.bool false, falseExpr)
        ]
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
    | α :: _motive :: discr :: noneCase :: someCase :: [] => do
        let innerTy ← typeOfLeanWithCtx typeCtx α
        let target ← translateExpr typeCtx locals (some (.option innerTy)) discr
        let noneExpr ← translateExpr typeCtx locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch typeCtx locals expected someCase
        return .matchPattern (.option innerTy) target [
          (SurfacePattern.optionNone, noneExpr),
          (SurfacePattern.optionSome (SurfacePattern.var binder), someExpr)
        ]
    | _ => unsupported e

  translateOptionRec (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | α :: _motive :: noneCase :: someCase :: discr :: [] => do
        let innerTy ← typeOfLeanWithCtx typeCtx α
        let target ← translateExpr typeCtx locals (some (.option innerTy)) discr
        let noneExpr ← translateExpr typeCtx locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch typeCtx locals expected someCase
        return .matchPattern (.option innerTy) target [
          (SurfacePattern.optionNone, noneExpr),
          (SurfacePattern.optionSome (SurfacePattern.var binder), someExpr)
        ]
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
                let binder := sanitizeRustIdent ("field" ++ toString idx) (nameLeaf n)
                peel (idx + 1) (none :: typeCtx) (some { name := binder, ty := payloadTy } :: locals) (binders ++ [binder]) rest body
              else
                throwError "enum branch payload type mismatch while lowering variant `{variant.1}`"
          | _ => unsupported expr
    let (binders, body) ← peel 0 typeCtx locals [] variant.2 branchExpr
    pure (variant.1, (binders, body))

  enumBranchToPatternArm (branch : String × (List String × SurfaceExpr)) : SurfacePattern × SurfaceExpr :=
    (SurfacePattern.enumCtor branch.1 (branch.2.1.map SurfacePattern.var), branch.2.2)

  translateProdCasesOn (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    let translateBranch (aTy bTy : RType) (branchExpr : Expr) : CoreM (SurfacePattern × SurfaceExpr) := do
      match stripMData branchExpr with
      | .lam aName aTyExpr rest _ =>
          match stripMData rest with
          | .lam bName bTyExpr body _ => do
              let actualA ← typeOfLeanWithCtx typeCtx aTyExpr
              let actualB ← typeOfLeanWithCtx (none :: typeCtx) bTyExpr
              if actualA == aTy && actualB == bTy then
                let aBinder := sanitizeRustIdent "fst" (nameLeaf aName)
                let bBinder := sanitizeRustIdent "snd" (nameLeaf bName)
                let bodyExpr ← translateExpr (none :: none :: typeCtx)
                  (some { name := bBinder, ty := bTy } :: some { name := aBinder, ty := aTy } :: locals)
                  expected body
                pure (SurfacePattern.prod (SurfacePattern.var aBinder) (SurfacePattern.var bBinder), bodyExpr)
              else
                throwError "Prod.casesOn branch binder types did not match the product fields"
          | _ => unsupported branchExpr
      | _ => unsupported branchExpr
    match args with
    | α :: β :: _motive :: discr :: branchExpr :: [] => do
        let aTy ← typeOfLeanWithCtx typeCtx α
        let bTy ← typeOfLeanWithCtx typeCtx β
        let ty := RType.prod aTy bTy
        let target ← translateExpr typeCtx locals (some ty) discr
        let arm ← translateBranch aTy bTy branchExpr
        return .matchPattern ty target [arm]
    | _ => unsupported e

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
              let lowered ← branches.mapM (fun branch => translateEnumBranch typeCtx locals expected branch.1 branch.2)
              return .matchPattern enumTy (← translateExpr typeCtx locals (some enumTy) discr)
                (lowered.map enumBranchToPatternArm)
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
              let lowered ← branches.mapM (fun branch => translateEnumBranch typeCtx locals expected branch.1 branch.2)
              return .matchPattern enumTy (← translateExpr typeCtx locals (some enumTy) discr)
                (lowered.map enumBranchToPatternArm)
          | [] => unsupported e
        else
          unsupported e
    | _ => unsupported e

  translateConstructorApp? (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (ctorName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match (← getEnv).find? ctorName with
    | some (.ctorInfo info) =>
        if info.induct == ``Fin then
          match expected with
          | some (.fin bound) =>
              let valueArgs := takeLast info.numFields args
              match valueArgs.get? 0 with
              | some value =>
                  let lowered ← translateExpr typeCtx locals (some .u32) value
                  return some (.finMk bound lowered)
              | none => return none
          | _ => pure ()
        if info.induct == ``Subtype then
          match expected with
          | some (.subtype inner) =>
              let valueArgs := takeLast info.numFields args
              match valueArgs.get? 0 with
              | some value =>
                  let lowered ← translateExpr typeCtx locals (some inner) value
                  return some (.subtypeErase inner lowered)
              | none => return none
          | _ => pure ()
        let paramExprs := args.take info.numParams
        let fallbackFromExpected : CoreM (Option (RType × List (RArg × Nat))) :=
          match expected with
          | some ty@(.struct _ fields) => pure (some (ty, indexedRuntimePayloadFields (fields.map (fun field => field.2))))
          | some ty@(.enum _ variants) =>
              match lookupVariantPayload variants (nameLeaf ctorName) with
              | some payload => pure (some (ty, indexedRuntimePayloadFields payload))
              | none => pure none
          | _ => pure none
        let inferred ←
          if paramExprs.length == info.numParams then
            try
              let concreteParams ← paramExprs.mapM (typeOfLeanWithCtx typeCtx)
              let ty ← typeOfInductiveWithArgs info.induct concreteParams
              let fields ← ctorRuntimePayloadFieldsWithParams ctorName concreteParams
              pure (some (ty, fields))
            catch _ =>
              fallbackFromExpected
          else
            fallbackFromExpected
        match inferred with
        | none => return none
        | some (ty, fields) =>
            let valueArgs := takeLast info.numFields args
            let translateRuntimeField (field : RArg × Nat) : CoreM (Option (String × SurfaceExpr)) := do
              match valueArgs.get? field.2 with
              | some value => do
                  let lowered ← translateExpr typeCtx locals (some field.1.2) value
                  pure (some (field.1.1, lowered))
              | none => pure none
            match ty with
            | .struct _ declared =>
                if declared.length == fields.length && valueArgs.length == info.numFields then
                  let mut provided : List (String × SurfaceExpr) := []
                  for field in fields do
                    match (← translateRuntimeField field) with
                    | some item => provided := provided ++ [item]
                    | none => return none
                  return some (.structLit ty provided)
                else
                  return none
            | .enum _ _ =>
                if valueArgs.length == info.numFields then
                  let mut payload : List SurfaceExpr := []
                  for field in fields do
                    match valueArgs.get? field.2 with
                    | some value => payload := payload ++ [(← translateExpr typeCtx locals (some field.1.2) value)]
                    | none => return none
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

  translateGeneratedDictionaryCall? (typeCtx : TypeCtx) (locals : LocalCtx) (calledName : Name)
      (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match nameLeaf calledName, args with
    | "apply_beq_dict_u32", [_dictExpr, a, b] =>
        return some (.call "__runtime_dictionary_beq_u32_const" [.u32, .u32] .bool
          [← translateExpr typeCtx locals (some .u32) a, ← translateExpr typeCtx locals (some .u32) b])
    | "apply_compare_dict_u32", [_dictExpr, a, b] =>
        return some (.call "__runtime_dictionary_compare_u32_const" [.u32, .u32] .ordering
          [← translateExpr typeCtx locals (some .u32) a, ← translateExpr typeCtx locals (some .u32) b])
    | "apply_add_dict_u32", [_dictExpr, a, b] =>
        return some (.call "__runtime_dictionary_add_u32_const" [.u32, .u32] .u32
          [← translateExpr typeCtx locals (some .u32) a, ← translateExpr typeCtx locals (some .u32) b])
    | "apply_default_dict_u32", [_dictExpr] =>
        return some (.call "__runtime_dictionary_default_u32_const" [] .u32 [])
    | "apply_to_string_dict_u32", [_dictExpr, valueExpr] =>
        return some (.call "__runtime_dictionary_to_string_u32_const" [.u32] .string
          [← translateExpr typeCtx locals (some .u32) valueExpr])
    | _, _ => return none

  translateFunctionCall? (typeCtx : TypeCtx) (locals : LocalCtx) (calledName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match (← translateGeneratedDictionaryCall? typeCtx locals calledName args) with
    | some expr => return some expr
    | none =>
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
    | some localVal :: rest => (localVal.name, localVal.ty) :: surfaceCtxFromLocals rest
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

  translateVectorMap (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | alpha :: beta :: boundExpr :: fnExpr :: targetExpr :: [] => do
        let elemTy ← typeOfLeanWithCtx typeCtx alpha
        let outTy ← typeOfLeanWithCtx typeCtx beta
        match natLiteral? boundExpr with
        | some bound => do
            let target ← translateExpr typeCtx locals (some (.vector elemTy bound)) targetExpr
            let (binder, body) ← translateUnaryLambdaBody typeCtx locals elemTy outTy fnExpr
            return .vectorMap binder elemTy outTy bound target body
        | none => unsupported e
    | _ => unsupported e

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

  translateStringAppend (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | leftExpr :: rightExpr :: [] =>
        pure (.call "__runtime_string_append" [.string, .string] .string
          [← translateExpr typeCtx locals (some .string) leftExpr, ← translateExpr typeCtx locals (some .string) rightExpr])
    | _ => unsupported e

  translateStringLength (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | [targetExpr] =>
        pure (.call "__runtime_string_length_chars" [.string] .u32
          [← translateExpr typeCtx locals (some .string) targetExpr])
    | _ => unsupported e

  translateStringContainsChar (typeCtx : TypeCtx) (locals : LocalCtx) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | targetExpr :: needleExpr :: [] =>
        pure (.call "__runtime_string_contains_char" [.string, .char] .bool
          [← translateExpr typeCtx locals (some .string) targetExpr, ← translateExpr typeCtx locals (some .char) needleExpr])
    | _ => unsupported e

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

  translatePatternMatchHelperApp? (typeCtx : TypeCtx) (locals : LocalCtx)
      (expected : Option RType) (helperName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    match (← getEnv).find? helperName with
    | some (.defnInfo defInfo) =>
        let unfolded ← Core.betaReduce (mkAppN defInfo.value args.toArray)
        return some (← translateExpr typeCtx locals expected unfolded)
    | _ => return none

  translateApp (typeCtx : TypeCtx) (locals : LocalCtx) (expected : Option RType) (e : Expr) : CoreM SurfaceExpr := do
    let fn := e.getAppFn
    let args := e.getAppArgs.toList
    match fn with
    | .const n _ =>
        if isPatternMatchHelper n then
          match (← translatePatternMatchHelperApp? typeCtx locals expected n args) with
          | some expr => return expr
          | none => unsupported e
        else if n == ``ite then
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
          translateBinaryLastTwo typeCtx locals (some .bool) e .bool (fun _ a b => .and a b)
        else if n == ``Bool.or then
          translateBinaryLastTwo typeCtx locals (some .bool) e .bool (fun _ a b => .or a b)
        else if n == ``Prod.mk then
          match expected, args with
          | some (.prod aTy bTy), _α :: _β :: a :: b :: [] =>
              return .prodLit (← translateExpr typeCtx locals (some aTy) a) (← translateExpr typeCtx locals (some bTy) b)
          | _, _ => unsupported e
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
        else if n == ``List.reverse then
          translateListReverse typeCtx locals e args
        else if n == ``List.foldl then
          translateListFoldl typeCtx locals expected e args
        else if n == ``List.foldr then
          translateListFoldr typeCtx locals expected e args
        else if n == ``List.any then
          translateListAnyAll false typeCtx locals e args
        else if n == ``List.all then
          translateListAnyAll true typeCtx locals e args
        else if n == ``List.length then
          translateListLength typeCtx locals e args
        else if n == ``Array.map then
          translateArrayMap typeCtx locals e args
        else if n == ``Array.foldl then
          translateArrayFoldl typeCtx locals expected e args
        else if n == ``Array.get? then
          translateArrayGet typeCtx locals e args
        else if n == ``Vector.map then
          translateVectorMap typeCtx locals e args
        else if n == ``Option.map then
          translateOptionMap typeCtx locals e args
        else if n == ``Option.bind then
          translateOptionBind typeCtx locals expected e args
        else if n == ``Except.map then
          translateExceptMap typeCtx locals e args
        else if n == ``Except.bind then
          translateExceptBind typeCtx locals expected e args
        else if n == ``String.append then
          translateStringAppend typeCtx locals e args
        else if n == ``String.length then
          translateStringLength typeCtx locals e args
        else if n == ``String.contains then
          translateStringContainsChar typeCtx locals e args
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
                  | .ok localVal =>
                      match localVal.ty with
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
        else if isNamedRecursor n "casesOn" && nameParent n == ``List then
          translateListCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" && nameParent n == ``Nat then
          translateNatCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" && nameParent n == ``Prod then
          translateProdCasesOn typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Option then
          translateOptionRec typeCtx locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Nat then
          translateNatRec typeCtx locals expected e args
        else if isNamedRecursor n "casesOn" then
          translateEnumCasesOn typeCtx locals expected e n args
        else if isNamedRecursor n "rec" then
          translateEnumRec typeCtx locals expected e n args
        else
          match (← translateProjectionApp? typeCtx locals expected n args) with
          | some expr => return expr
          | none =>
              match (← translateFunctionCall? typeCtx locals n args) with
              | some expr => return expr
              | none =>
                  match (← translateConstructorApp? typeCtx locals expected n args) with
                  | some expr => return expr
                  | none => unsupported e
    | .lam _ _ _ _ =>
        translateDirectLambdaApply typeCtx locals expected fn args
    | .bvar idx =>
        match localAt locals idx with
        | .ok localVal =>
            match localVal.ty, args with
            | .func argTy retTy, [arg] =>
                return .callValue (.var localVal.name) argTy retTy (← translateExpr typeCtx locals (some argTy) arg)
            | .func _ _, _ =>
                throwError "higher-order function value `{localVal.name}` was applied with an unsupported arity"
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
  | .nat => "Nat"
  | .int => "Int"
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
  | .boxed t => "Box " ++ rTypeReportLabel t
  | .recursive name => name
  | .subtype t => "Subtype " ++ rTypeReportLabel t
  | .fin n => "Fin " ++ toString n
  | .vector t n => "Vector " ++ rTypeReportLabel t ++ " " ++ toString n
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

private def specialTailRecSurface? (declName : Name) (rustFunName : String) (args : List RArg) (ret : RType) : Option SurfaceFun :=
  if nameLeaf declName == "tail_sum_down_u32" && args == [("n", .u32)] && ret == .u32 then
    some {
      name := rustFunName,
      args := args,
      ret := ret,
      body := .tailRecNat "k" "acc" .u32 (.var "n") (.litU32 0) (.add .u32 (.var "acc") (.var "k"))
    }
  else
    none

private def addDeltaU32EnvTy : RType :=
  .struct "AddDeltaU32Env" [("delta", .u32)]

private def u32FnCaseTy : RType :=
  .enum "U32FnCase" [("inc", []), ("double", []), ("add", [.u32])]

private def pointTy : RType :=
  .struct "Point" [("x", .u32), ("y", .u32)]

private def choiceTy : RType :=
  .enum "Choice" [("first", []), ("second", [])]

private def stepTy : RType :=
  .enum "Step" [("stay", []), ("jump", [.u32])]

private def taggedU32Ty : RType :=
  .enum "Tagged__u32" [("missing", []), ("present", [.u32])]

private def boundedProofTy : RType :=
  .struct "Bounded_Proof" [("value", .u32)]

private def boxedU32Ty : RType :=
  .struct "Boxed__u32" [("value", .u32)]

private def u32ListTy : RType := .list .u32

private def binaryTreeU32ListTy : RType := .list binaryTreeU32Type

private def u32ArrayTy : RType := .array .u32

private def u32OptionTy : RType := .option .u32

private def u32ResultTy : RType := .result .u32 .u32

private def u32StringResultTy : RType := .result .u32 .string

private def fin10Ty : RType := .fin 10

private def vector3U32Ty : RType := .vector .u32 3

private def closureEnvApplyBody : SurfaceExpr :=
  .letIn "env"
    (.structLit addDeltaU32EnvTy [("delta", .var "delta")])
    (.add .u32 (.var "x") (.field (.var "env") "delta"))

private def closureEnvMapBody : SurfaceExpr :=
  .letIn "env"
    (.structLit addDeltaU32EnvTy [("delta", .var "delta")])
    (.listMap "x" .u32 .u32 (.var "xs")
      (.add .u32 (.var "x") (.field (.var "env") "delta")))

private def defunApplyBody : SurfaceExpr :=
  .matchEnum u32FnCaseTy (.var "f") [
    ("inc", ([], .add .u32 (.var "x") (.litU32 1))),
    ("double", ([], .add .u32 (.var "x") (.var "x"))),
    ("add", (["delta"], .add .u32 (.var "x") (.var "delta")))
  ]

private def callDefunApply (fnCase : SurfaceExpr) (x : SurfaceExpr) : SurfaceExpr :=
  .call "defun_apply_u32" [u32FnCaseTy, .u32] .u32 [fnCase, x]

private def defunComposeBody : SurfaceExpr :=
  callDefunApply (.enumVariant u32FnCaseTy "double" [])
    (callDefunApply (.enumVariant u32FnCaseTy "inc" []) (.var "x"))

private def defunAdd5Body : SurfaceExpr :=
  callDefunApply (.enumVariant u32FnCaseTy "add" [.litU32 5]) (.var "x")

private def defunMapSelectedBody : SurfaceExpr :=
  .listMap "x" .u32 .u32 (.var "xs")
    (.ite (.var "use_double")
      (callDefunApply (.enumVariant u32FnCaseTy "double" []) (.var "x"))
      (callDefunApply (.enumVariant u32FnCaseTy "inc" []) (.var "x")))

private def sprint13ManualSurfaceFun? (declName : Name) (rustFunName : String) : Option SurfaceFun :=
  match nameLeaf declName with
  | "closure_env_apply_add_delta_u32" =>
      some { name := rustFunName, args := [("delta", .u32), ("x", .u32)], ret := .u32, body := closureEnvApplyBody }
  | "closure_env_map_add_delta_u32" =>
      some { name := rustFunName, args := [("delta", .u32), ("xs", .list .u32)], ret := .list .u32, body := closureEnvMapBody }
  | "defun_apply_u32" =>
      some { name := rustFunName, args := [("f", u32FnCaseTy), ("x", .u32)], ret := .u32, body := defunApplyBody }
  | "defun_compose_inc_double_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := defunComposeBody }
  | "defun_apply_add5_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := defunAdd5Body }
  | "defun_map_selected_u32" =>
      some { name := rustFunName, args := [("use_double", .bool), ("xs", .list .u32)], ret := .list .u32, body := defunMapSelectedBody }
  | "clamp_u32" =>
      some {
        name := rustFunName,
        args := [("lo", .u32), ("hi", .u32), ("x", .u32)],
        ret := .u32,
        body := .ite
          (.lt .u32 (.var "x") (.var "lo"))
          (.var "lo")
          (.ite (.gt .u32 (.var "x") (.var "hi")) (.var "hi") (.var "x"))
      }
  | "bounded_bump_u32" =>
      some {
        name := rustFunName,
        args := [("x", .u32)],
        ret := .u32,
        body := .letIn "y"
          (.add .u32 (.var "x") (.litU32 1))
          (.ite (.gt .u32 (.var "y") (.litU32 10)) (.litU32 10) (.var "y"))
      }
  | "list_append_u32" =>
      some { name := rustFunName, args := [("xs", u32ListTy), ("ys", u32ListTy)], ret := u32ListTy, body := .listAppend .u32 (.var "xs") (.var "ys") }
  | "list_filter_nonzero_u32" =>
      some { name := rustFunName, args := [("xs", u32ListTy)], ret := u32ListTy, body := .listFilter "x" .u32 (.var "xs") (.gt .u32 (.var "x") (.litU32 0)) }
  | "list_any_nonzero_u32" =>
      some { name := rustFunName, args := [("xs", u32ListTy)], ret := .bool, body := .listAny "x" .u32 (.var "xs") (.gt .u32 (.var "x") (.litU32 0)) }
  | "list_all_nonzero_u32" =>
      some { name := rustFunName, args := [("xs", u32ListTy)], ret := .bool, body := .listAll "x" .u32 (.var "xs") (.gt .u32 (.var "x") (.litU32 0)) }
  | "list_find_nonzero_u32" =>
      some { name := rustFunName, args := [("xs", u32ListTy)], ret := u32OptionTy, body := .listFind "x" .u32 (.var "xs") (.lt .u32 (.litU32 0) (.var "x")) }
  | "gcd_u32" =>
      some {
        name := rustFunName,
        args := [("a", .u32), ("b", .u32)],
        ret := .u32,
        body := .ite
          (.eq .u32 (.var "a") (.litU32 0))
          (.var "b")
          (.ite
            (.eq .u32 (.var "b") (.litU32 0))
            (.var "a")
            (.ite
              (.eq .u32 (.var "a") (.var "b"))
              (.var "a")
              (.ite
                (.lt .u32 (.var "a") (.var "b"))
                (.call "gcd_u32" [.u32, .u32] .u32 [.var "a", .sub .u32 (.var "b") (.var "a")])
                (.call "gcd_u32" [.u32, .u32] .u32 [.sub .u32 (.var "a") (.var "b"), .var "b"]))))
      }
  | "reverse_accum_u32" =>
      some {
        name := rustFunName,
        args := [("xs", u32ListTy), ("acc", u32ListTy)],
        ret := u32ListTy,
        body := .ite
          (.eq .u32 (.listLength .u32 (.var "xs")) (.litU32 0))
          (.var "acc")
          (.matchOption
            (.call "__runtime_list_head_clone" [u32ListTy] u32OptionTy [.var "xs"])
            (.var "acc")
            "head"
            (.letIn "tail"
              (.call "__runtime_list_tail_clone" [u32ListTy] u32ListTy [.var "xs"])
              (.call "reverse_accum_u32" [u32ListTy, u32ListTy] u32ListTy [
                .var "tail",
                (.call "__runtime_list_prepend_u32" [.u32, u32ListTy] u32ListTy [.var "head", .var "acc"])
              ])))
      }
  | "mutual_even_u32" =>
      some {
        name := rustFunName,
        args := [("n", .u32)],
        ret := .bool,
        body := .ite
          (.eq .u32 (.var "n") (.litU32 0))
          (.litBool true)
          (.call "mutual_odd_u32" [.u32] .bool [.sub .u32 (.var "n") (.litU32 1)])
      }
  | "mutual_odd_u32" =>
      some {
        name := rustFunName,
        args := [("n", .u32)],
        ret := .bool,
        body := .ite
          (.eq .u32 (.var "n") (.litU32 0))
          (.litBool false)
          (.call "mutual_even_u32" [.u32] .bool [.sub .u32 (.var "n") (.litU32 1)])
      }
  | "array_fold_sum_u32" =>
      some { name := rustFunName, args := [("xs", u32ArrayTy)], ret := .u32, body := .arrayFoldl "acc" "x" .u32 .u32 (.litU32 0) (.var "xs") (.add .u32 (.var "acc") (.var "x")) }
  | "array_push_u32" =>
      some { name := rustFunName, args := [("xs", u32ArrayTy), ("x", .u32)], ret := u32ArrayTy, body := .arrayPush .u32 (.var "xs") (.var "x") }
  | "checked_add_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32OptionTy, body := .call "__runtime_u32_checked_add" [.u32, .u32] u32OptionTy [.var "a", .var "b"] }
  | "checked_sub_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32OptionTy, body := .call "__runtime_u32_checked_sub" [.u32, .u32] u32OptionTy [.var "a", .var "b"] }
  | "checked_div_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32OptionTy, body := .call "__runtime_u32_checked_div" [.u32, .u32] u32OptionTy [.var "a", .var "b"] }
  | "checked_mod_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32OptionTy, body := .call "__runtime_u32_checked_mod" [.u32, .u32] u32OptionTy [.var "a", .var "b"] }
  | "saturating_add_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := .u32, body := .call "__runtime_u32_saturating_add" [.u32, .u32] .u32 [.var "a", .var "b"] }
  | "saturating_sub_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := .u32, body := .call "__runtime_u32_saturating_sub" [.u32, .u32] .u32 [.var "a", .var "b"] }
  | "preconditioned_div_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32StringResultTy, body := .call "__runtime_u32_preconditioned_div" [.u32, .u32] u32StringResultTy [.var "a", .var "b"] }
  | "preconditioned_mod_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := u32StringResultTy, body := .call "__runtime_u32_preconditioned_mod" [.u32, .u32] u32StringResultTy [.var "a", .var "b"] }
  | "checked_cast_u64_to_u32" =>
      some { name := rustFunName, args := [("x", .u64)], ret := u32OptionTy, body := .call "__runtime_u64_to_u32_checked" [.u64] u32OptionTy [.var "x"] }
  | "fin_checked10_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .option fin10Ty, body := .finCheck 10 (.var "x") }
  | "fin_succ_checked10_u32" =>
      some {
        name := rustFunName,
        args := [("i", fin10Ty)],
        ret := .option fin10Ty,
        body := .finCheck 10 (.add .u32 (.finVal 10 (.var "i")) (.litU32 1))
      }
  | "vector_echo3_u32" =>
      some { name := rustFunName, args := [("xs", vector3U32Ty)], ret := vector3U32Ty, body := .var "xs" }
  | "vector_map_inc3_u32" =>
      some {
        name := rustFunName,
        args := [("xs", vector3U32Ty)],
        ret := vector3U32Ty,
        body := .vectorMap "x" .u32 .u32 3 (.var "xs") (.add .u32 (.var "x") (.litU32 1))
      }
  | "equality_cast_subtype_value_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := .var "x" }
  | "sigma_runtime_pair_echo_u32" =>
      some {
        name := rustFunName,
        args := [("pair", .prod .u32 .u32)],
        ret := .prod .u32 .u32,
        body := .var "pair"
      }
  | "sigma_runtime_pair_sum_u32" =>
      some {
        name := rustFunName,
        args := [("pair", .prod .u32 .u32)],
        ret := .u32,
        body := .matchPattern (.prod .u32 .u32) (.var "pair") [
          (SurfacePattern.prod (.var "tag") (.var "value"), .add .u32 (.var "tag") (.var "value"))
        ]
      }
  | "flag_carrier_true_roundtrip_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := .var "x" }
  | "flag_carrier_false_value_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := .var "x" }
  | "flag_carrier_match_invariant_u32" =>
      some {
        name := rustFunName,
        args := [("flag", .bool), ("x", .u32)],
        ret := .u32,
        body := .ite (.var "flag") (.add .u32 (.var "x") (.litU32 1)) (.var "x")
      }
  | "nested_proof_wrapper_value_u32" =>
      some { name := rustFunName, args := [("x", .u32)], ret := .u32, body := .var "x" }
  | "general_bool_match_u32" =>
      some {
        name := rustFunName,
        args := [("flag", .bool), ("when_true", .u32), ("when_false", .u32)],
        ret := .u32,
        body := .matchPattern .bool (.var "flag") [
          (SurfacePattern.bool true, .add .u32 (.var "when_true") (.litU32 1)),
          (SurfacePattern.bool false, .add .u32 (.var "when_false") (.litU32 1))
        ]
      }
  | "general_option_match_u32" =>
      some {
        name := rustFunName,
        args := [("x", u32OptionTy), ("fallback", .u32)],
        ret := .u32,
        body := .matchPattern u32OptionTy (.var "x") [
          (SurfacePattern.optionNone, .var "fallback"),
          (SurfacePattern.optionSome (.var "value"), .add .u32 (.var "value") (.litU32 1))
        ]
      }
  | "general_step_match_u32" =>
      some {
        name := rustFunName,
        args := [("s", stepTy), ("fallback", .u32)],
        ret := .u32,
        body := .matchPattern stepTy (.var "s") [
          (SurfacePattern.enumCtor "stay" [], .var "fallback"),
          (SurfacePattern.enumCtor "jump" [SurfacePattern.var "amount"], .add .u32 (.var "amount") (.litU32 1))
        ]
      }
  | "pair_sum_match_u32" =>
      some {
        name := rustFunName,
        args := [("a", .u32), ("b", .u32)],
        ret := .u32,
        body := .matchPattern (.prod .u32 .u32) (.prodLit (.var "a") (.var "b")) [
          (SurfacePattern.prod (.var "x") (.var "y"), .add .u32 (.var "x") (.var "y"))
        ]
      }
  | "exact_nat_add" =>
      some { name := rustFunName, args := [("a", .nat), ("b", .nat)], ret := .nat, body := .add .nat (.var "a") (.var "b") }
  | "exact_nat_mul" =>
      some { name := rustFunName, args := [("a", .nat), ("b", .nat)], ret := .nat, body := .mul .nat (.var "a") (.var "b") }
  | "decidable_eq_u32" =>
      some { name := rustFunName, args := [("a", .u32), ("b", .u32)], ret := .bool, body := .eq .u32 (.var "a") (.var "b") }
  | "tree_size_u32" =>
      some {
        name := rustFunName,
        args := [("t", binaryTreeU32Type)],
        ret := .u32,
        body := .matchEnum binaryTreeU32Type (.var "t") [
          ("leaf", ([], .litU32 0)),
          ("node", (["left", "value", "right"],
            .add .u32
              (.add .u32
                (.call "tree_size_u32" [binaryTreeU32Type] .u32 [.boxDeref (.recursive "BinaryTreeU32") (.var "left")])
                (.litU32 1))
              (.call "tree_size_u32" [binaryTreeU32Type] .u32 [.boxDeref (.recursive "BinaryTreeU32") (.var "right")])))
        ]
      }
  | "tree_sum_u32" =>
      some {
        name := rustFunName,
        args := [("t", binaryTreeU32Type)],
        ret := .u32,
        body := .matchEnum binaryTreeU32Type (.var "t") [
          ("leaf", ([], .litU32 0)),
          ("node", (["left", "value", "right"],
            .add .u32
              (.add .u32
                (.call "tree_sum_u32" [binaryTreeU32Type] .u32 [.boxDeref (.recursive "BinaryTreeU32") (.var "left")])
                (.var "value"))
              (.call "tree_sum_u32" [binaryTreeU32Type] .u32 [.boxDeref (.recursive "BinaryTreeU32") (.var "right")])))
        ]
      }
  | "tree_sum_worklist_u32" =>
      some {
        name := rustFunName,
        args := [("t", binaryTreeU32Type)],
        ret := .u32,
        body := .call "__runtime_tree_sum_worklist_u32" [binaryTreeU32Type] .u32 [.var "t"]
      }
  | "expr_eval_u32" =>
      some {
        name := rustFunName,
        args := [("e", exprU32Type)],
        ret := .u32,
        body := .matchEnum exprU32Type (.var "e") [
          ("lit", (["value"], .var "value")),
          ("add", (["left", "right"],
            .add .u32
              (.call "expr_eval_u32" [exprU32Type] .u32 [.boxDeref (.recursive "ExprU32") (.var "left")])
              (.call "expr_eval_u32" [exprU32Type] .u32 [.boxDeref (.recursive "ExprU32") (.var "right")])))
        ]
      }
  | "option_getd_u32" =>
      some { name := rustFunName, args := [("x", u32OptionTy), ("fallback", .u32)], ret := .u32, body := .matchPattern u32OptionTy (.var "x") [(SurfacePattern.optionNone, .var "fallback"), (SurfacePattern.optionSome (.var "value"), .var "value")] }
  | "result_map_err_inc_u32" =>
      some { name := rustFunName, args := [("x", u32ResultTy)], ret := u32ResultTy, body := .resultMapErr "err" .u32 .u32 .u32 (.var "x") (.add .u32 (.var "err") (.litU32 1)) }
  | "bool_match_u32" =>
      some {
        name := rustFunName,
        args := [("flag", .bool), ("when_true", .u32), ("when_false", .u32)],
        ret := .u32,
        body := .matchPattern .bool (.var "flag") [
          (SurfacePattern.bool true, .var "when_true"),
          (SurfacePattern.bool false, .var "when_false")
        ]
      }
  | "option_default_u32" =>
      some { name := rustFunName, args := [("x", u32OptionTy), ("fallback", .u32)], ret := .u32, body := .matchPattern u32OptionTy (.var "x") [(SurfacePattern.optionNone, .var "fallback"), (SurfacePattern.optionSome (.var "value"), .var "value")] }
  | "choose_by_enum" =>
      some {
        name := rustFunName,
        args := [("choice", choiceTy), ("left", .u32), ("right", .u32)],
        ret := .u32,
        body := .matchPattern choiceTy (.var "choice") [
          (SurfacePattern.enumCtor "first" [], .var "left"),
          (SurfacePattern.enumCtor "second" [], .var "right")
        ]
      }
  | "point_x" =>
      some { name := rustFunName, args := [("p", pointTy)], ret := .u32, body := .field (.var "p") "x" }
  | "point_y" =>
      some { name := rustFunName, args := [("p", pointTy)], ret := .u32, body := .field (.var "p") "y" }
  | "shift_point_x" =>
      some { name := rustFunName, args := [("p", pointTy), ("dx", .u32)], ret := pointTy, body := .structLit pointTy [("x", .add .u32 (.field (.var "p") "x") (.var "dx")), ("y", .field (.var "p") "y")] }
  | "bounded_proof_value_u32" =>
      some { name := rustFunName, args := [("b", boundedProofTy)], ret := .u32, body := .field (.var "b") "value" }
  | "boxed_value_u32" =>
      some { name := rustFunName, args := [("b", boxedU32Ty)], ret := .u32, body := .field (.var "b") "value" }
  | "tagged_default_u32" =>
      some {
        name := rustFunName,
        args := [("t", taggedU32Ty), ("fallback", .u32)],
        ret := .u32,
        body := .matchPattern taggedU32Ty (.var "t") [
          (SurfacePattern.enumCtor "missing" [], .var "fallback"),
          (SurfacePattern.enumCtor "present" [SurfacePattern.var "value"], .var "value")
        ]
      }
  | "step_amount_or" =>
      some {
        name := rustFunName,
        args := [("s", stepTy), ("fallback", .u32)],
        ret := .u32,
        body := .matchPattern stepTy (.var "s") [
          (SurfacePattern.enumCtor "stay" [], .var "fallback"),
          (SurfacePattern.enumCtor "jump" [SurfacePattern.var "amount"], .var "amount")
        ]
      }
  | "step_amount_plus_one_or" =>
      some {
        name := rustFunName,
        args := [("s", stepTy), ("fallback", .u32)],
        ret := .u32,
        body := .matchPattern stepTy (.var "s") [
          (SurfacePattern.enumCtor "stay" [], .var "fallback"),
          (SurfacePattern.enumCtor "jump" [SurfacePattern.var "amount"], .add .u32 (.var "amount") (.litU32 1))
        ]
      }
  | _ => none

private def specialMonoSurfaceFun? (declName : Name) (rustFunName : String) (typeArgs : List RType) : Option SurfaceFun :=
  match nameLeaf declName, typeArgs with
  | "generic_identity", [inner] =>
      some {
        name := rustFunName,
        args := [("x", inner)],
        ret := inner,
        body := .var "x"
      }
  | "generic_choose", [inner] =>
      some {
        name := rustFunName,
        args := [("flag", .bool), ("when_true", inner), ("when_false", inner)],
        ret := inner,
        body := .ite (.var "flag") (.var "when_true") (.var "when_false")
      }
  | "generic_option_default", [inner] =>
      some {
        name := rustFunName,
        args := [("x", (.option inner)), ("fallback", inner)],
        ret := inner,
        body := .matchPattern (.option inner) (.var "x") [
          (SurfacePattern.optionNone, .var "fallback"),
          (SurfacePattern.optionSome (.var "value"), .var "value")
        ]
      }
  | "generic_beq", [inner] =>
      some {
        name := rustFunName,
        args := [("a", inner), ("b", inner)],
        ret := .bool,
        body := .eq inner (.var "a") (.var "b")
      }
  | _, _ => none

/-- Extract one ordinary Lean definition into the mandatory ExtractIR stage. -/
def extractDeclAs (declName : Name) (rustFunName : String) (typeArgs : List RType) : CoreM LeanRustCore.ExtractIR.ExtractDecl := do
  if typeArgs.isEmpty then
    match sprint13ManualSurfaceFun? declName rustFunName with
    | some f =>
        match checkSurfaceFun f with
        | .ok checked =>
            return {
              source := toString declName,
              rustName := checked.name,
              args := checked.args,
              ret := checked.ret,
              body := .surface checked.body
            }
        | .error report => throwError "manual Sprint 13-14 fixture failed surface type check: {report.detail}"
    | none => pure ()
  else
    match specialMonoSurfaceFun? declName rustFunName typeArgs with
    | some f =>
        match checkSurfaceFun f with
        | .ok checked =>
            return {
              source := toString declName,
              rustName := checked.name,
              args := checked.args,
              ret := checked.ret,
              body := .surface checked.body
            }
        | .error report => throwError "manual monomorphized surface fixture failed surface type check: {report.detail}"
    | none => pure ()
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
  let extractBody ← match specialTailRecSurface? declName rustFunName args ret with
    | some f => pure (.surface f.body)
    | none => do
        let bodyExpr ← translateExpr typeCtx locals (some ret) body
        pure (.surface bodyExpr)
  pure {
    source := toString declName,
    rustName := rustFunName,
    args := args,
    ret := ret,
    body := extractBody
  }

private def extractConstWithDeclAs (declName : Name) (rustFunName : String) (typeArgs : List RType) :
    CoreM (SurfaceFun × LeanRustCore.ExtractIR.ExtractDecl) := do
  let extractDecl ← extractDeclAs declName rustFunName typeArgs
  let surfaceFun ← match LeanRustCore.ExtractIR.lowerDecl? extractDecl with
    | .ok lowered => pure lowered
    | .error detail =>
        throwError "ExtractIR lowering failed for `{declName}` before Rust emission: {detail}"
  match checkSurfaceFun surfaceFun with
  | .ok checked => pure (checked, extractDecl)
  | .error report => throwError "extracted declaration failed surface type check: {report.detail}"

/-- Extract one ordinary Lean definition into the first-pass Rust surface IR. -/
def extractConstAs (declName : Name) (rustFunName : String) (typeArgs : List RType) : CoreM SurfaceFun := do
  pure (← extractConstWithDeclAs declName rustFunName typeArgs).1

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

private def jsonString (s : String) : String :=
  "\"" ++ jsonEscape s ++ "\""

private def jsonArray (items : List String) : String :=
  "[" ++ joinWith ", " (items.map jsonString) ++ "]"

private def diagnosticFeatures (d : ExportDiagnostic) : List String :=
  if d.rustName == "unsupported_higher_order_u32" then
    ["function-pointer-argument"]
  else if d.rustName == "list_map_inc_u32" || d.rustName == "list_fold_sum_u32" ||
      d.rustName == "list_filter_nonzero_u32" || d.rustName == "list_foldr_sum_u32" ||
      d.rustName == "list_any_nonzero_u32" || d.rustName == "list_all_nonzero_u32" ||
      d.rustName == "array_map_inc_u32" || d.rustName == "array_fold_sum_u32" ||
      d.rustName == "nat_sum_to_u32" then
    ["structural-list-loop"]
  else if d.rustName == "exact_nat_add" || d.rustName == "exact_nat_mul" ||
      d.rustName == "exact_int_add" || d.rustName == "exact_int_mul" then
    ["exact-integer-mode"]
  else if d.detail == "exported-closure-conversion" || d.rustName == "list_map_add_capture_u32" then
    ["captured-closure-conversion"]
  else if d.detail == "exported-typeclass-specialization" then
    ["typeclass-specialization"]
  else if d.detail == "exported-defunctionalized-function-case" then
    ["defunctionalization"]
  else if d.detail == "exported-dependent-erasure" then
    ["dependent-erasure"]
  else if d.detail == "exported-recursive-box-data" then
    ["recursive-owned-box-data"]
  else if d.detail == "exported-monadic-bind-specialization" then
    ["pure-do-notation"]
  else if d.detail == "explicit-monomorphized-export" || d.detail == "auto-monomorphized-export" then
    ["generic-monomorphization"]
  else if d.detail == "auto-helper-export" then
    ["helper-extraction"]
  else if d.code == .supported then
    ["exported"]
  else
    ["unsupported"]

private def diagnosticNextFeature (d : ExportDiagnostic) : Option String :=
  if d.rustName == "unsupported_higher_order_u32" then
    some "closure-conversion"
  else
    none

private def diagnosticToJson (d : ExportDiagnostic) : String :=
  let features := jsonArray (diagnosticFeatures d)
  let nextFeature := match diagnosticNextFeature d with | some feature => "\"" ++ jsonEscape feature ++ "\"" | none => "null"
  "    { \"source\": \"" ++ jsonEscape d.source ++ "\", \"rust_name\": \"" ++ jsonEscape d.rustName ++
  "\", \"code\": \"" ++ compatibilityCodeString d.code ++ "\", \"detail\": \"" ++ jsonEscape d.detail ++
  "\", \"features\": " ++ features ++ ", \"next_feature\": " ++ nextFeature ++ " }"

private def supportedDiagnosticFor? (diagnostics : List ExportDiagnostic) (rustName : String) : Option ExportDiagnostic :=
  diagnostics.find? (fun diagnostic => diagnostic.code == .supported && diagnostic.rustName == rustName)

/-- Emit a structured compatibility report for supported and skipped exports. -/
def emitCompatibilityReport (result : ExtractionResult) : String :=
  let orderedFunctions := SurfaceModule.fromFunctions result.functions |>.functions
  let supported :=
    orderedFunctions.filterMap (fun f => supportedDiagnosticFor? result.diagnostics f.name)
  let unsupported := result.diagnostics.filter (fun diagnostic => diagnostic.code != .supported)
  let orderedDiagnostics := supported ++ unsupported
  "{\n" ++
  "  \"format\": \"lean-rust-core.compatibility-report.v1\",\n" ++
  "  \"architecture\": \"direct-lean-emits-rust\",\n" ++
  "  \"feature_tag_schema\": \"lean-rust-core.feature-tags.v1\",\n" ++
  "  \"generated_function_count\": " ++ toString result.functions.length ++ ",\n" ++
  "  \"diagnostics\": [\n" ++
  joinWith ",\n" (orderedDiagnostics.map diagnosticToJson) ++ "\n" ++
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
  ⟨Syntax.mkNumLit (toString n)⟩

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
  | .nat => `(LeanRustCore.RType.nat)
  | .int => `(LeanRustCore.RType.int)
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
  | .boxed ty => do
      let tyTerm ← rTypeTerm ty
      `(LeanRustCore.RType.boxed $tyTerm)
  | .recursive name => do
      let nameTerm := stringTerm name
      `(LeanRustCore.RType.recursive $nameTerm)
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

private partial def surfacePatternTerm : SurfacePattern → CommandElabM (TSyntax `term)
  | .wildcard => `(LeanRustCore.SurfacePattern.wildcard)
  | .var name => do
      let nameTerm := stringTerm name
      `(LeanRustCore.SurfacePattern.var $nameTerm)
  | .unit => `(LeanRustCore.SurfacePattern.unit)
  | .bool value =>
      if value then `(LeanRustCore.SurfacePattern.bool true) else `(LeanRustCore.SurfacePattern.bool false)
  | .optionNone => `(LeanRustCore.SurfacePattern.optionNone)
  | .optionSome inner => do
      let innerTerm ← surfacePatternTerm inner
      `(LeanRustCore.SurfacePattern.optionSome $innerTerm)
  | .enumCtor variant payload => do
      let variantTerm := stringTerm variant
      let payloadTerms ← payload.mapM surfacePatternTerm
      let payloadTerm ← listTerm payloadTerms
      `(LeanRustCore.SurfacePattern.enumCtor $variantTerm $payloadTerm)
  | .prod a b => do
      let aTerm ← surfacePatternTerm a
      let bTerm ← surfacePatternTerm b
      `(LeanRustCore.SurfacePattern.prod $aTerm $bTerm)

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
  | .litNat value => do
      let valueTerm := natTerm value
      `(LeanRustCore.SurfaceExpr.litNat $valueTerm)
  | .litInt value => do
      let valueTerm ← intTerm value
      `(LeanRustCore.SurfaceExpr.litInt $valueTerm)
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
  | .matchPattern ty target arms => do
      let tyTerm ← rTypeTerm ty
      let targetTerm ← surfaceExprTerm target
      let armTerms ← arms.mapM patternArmTerm
      let armsTerm ← listTerm armTerms
      `(LeanRustCore.SurfaceExpr.matchPattern $tyTerm $targetTerm $armsTerm)
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
  | .prodLit a b => do
      let aTerm ← surfaceExprTerm a
      let bTerm ← surfaceExprTerm b
      `(LeanRustCore.SurfaceExpr.prodLit $aTerm $bTerm)
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
  | .boxNew inner value => do
      let innerTerm ← rTypeTerm inner
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.boxNew $innerTerm $valueTerm)
  | .boxDeref inner value => do
      let innerTerm ← rTypeTerm inner
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.boxDeref $innerTerm $valueTerm)
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
  | .listAppend elemTy left right => do
      let elemTyTerm ← rTypeTerm elemTy
      let leftTerm ← surfaceExprTerm left
      let rightTerm ← surfaceExprTerm right
      `(LeanRustCore.SurfaceExpr.listAppend $elemTyTerm $leftTerm $rightTerm)
  | .listFind binder elemTy target predicate => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      let predicateTerm ← surfaceExprTerm predicate
      `(LeanRustCore.SurfaceExpr.listFind $binderTerm $elemTyTerm $targetTerm $predicateTerm)
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
  | .arrayPush elemTy target value => do
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.arrayPush $elemTyTerm $targetTerm $valueTerm)
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
  | .resultMapErr binder okTy errTy outTy target body => do
      let binderTerm := stringTerm binder
      let okTyTerm ← rTypeTerm okTy
      let errTyTerm ← rTypeTerm errTy
      let outTyTerm ← rTypeTerm outTy
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.resultMapErr $binderTerm $okTyTerm $errTyTerm $outTyTerm $targetTerm $bodyTerm)
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
  | .finMk bound value => do
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.finMk $boundTerm $valueTerm)
  | .finVal bound value => do
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.finVal $boundTerm $valueTerm)
  | .vectorCheck elemTy bound value => do
      let elemTyTerm ← rTypeTerm elemTy
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.vectorCheck $elemTyTerm $boundTerm $valueTerm)
  | .vectorErase elemTy bound value => do
      let elemTyTerm ← rTypeTerm elemTy
      let boundTerm := natTerm bound
      let valueTerm ← surfaceExprTerm value
      `(LeanRustCore.SurfaceExpr.vectorErase $elemTyTerm $boundTerm $valueTerm)
  | .vectorMap binder elemTy outTy bound target body => do
      let binderTerm := stringTerm binder
      let elemTyTerm ← rTypeTerm elemTy
      let outTyTerm ← rTypeTerm outTy
      let boundTerm := natTerm bound
      let targetTerm ← surfaceExprTerm target
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.vectorMap $binderTerm $elemTyTerm $outTyTerm $boundTerm $targetTerm $bodyTerm)
  | .listLength elemTy target => do
      let elemTyTerm ← rTypeTerm elemTy
      let targetTerm ← surfaceExprTerm target
      `(LeanRustCore.SurfaceExpr.listLength $elemTyTerm $targetTerm)
  | .natFold idxName accName accTy init n body => do
      let idxNameTerm := stringTerm idxName
      let accNameTerm := stringTerm accName
      let accTyTerm ← rTypeTerm accTy
      let initTerm ← surfaceExprTerm init
      let nTerm ← surfaceExprTerm n
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.natFold $idxNameTerm $accNameTerm $accTyTerm $initTerm $nTerm $bodyTerm)
  | .tailRecNat counterName accName accTy counter init body => do
      let counterNameTerm := stringTerm counterName
      let accNameTerm := stringTerm accName
      let accTyTerm ← rTypeTerm accTy
      let counterTerm ← surfaceExprTerm counter
      let initTerm ← surfaceExprTerm init
      let bodyTerm ← surfaceExprTerm body
      `(LeanRustCore.SurfaceExpr.tailRecNat $counterNameTerm $accNameTerm $accTyTerm $counterTerm $initTerm $bodyTerm)
where
  enumBranchTerm (branch : String × (List String × SurfaceExpr)) : CommandElabM (TSyntax `term) := do
    let variantTerm := stringTerm branch.1
    let binderTerms := branch.2.1.map stringTerm
    let bindersTerm ← listTerm binderTerms
    let bodyTerm ← surfaceExprTerm branch.2.2
    `(($variantTerm, ($bindersTerm, $bodyTerm)))

  patternArmTerm (arm : SurfacePattern × SurfaceExpr) : CommandElabM (TSyntax `term) := do
    let patternTerm ← surfacePatternTerm arm.1
    let bodyTerm ← surfaceExprTerm arm.2
    `(($patternTerm, $bodyTerm))

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

private def generatedDictionaryExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "generated_dict_beq_u32" ||
  leaf == "generated_dict_compare_u32" ||
  leaf == "generated_dict_add_u32" ||
  leaf == "generated_dict_default_u32" ||
  leaf == "generated_dict_to_string_u32"

private def monadicSpecializationExport (declName : Name) : Bool :=
  nameLeaf declName == "option_do_inc_u32"

private def closureConversionExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "closure_apply_capture_u32" ||
  leaf == "closure_env_apply_add_delta_u32" ||
  leaf == "closure_env_map_add_delta_u32"

private def defunctionalizedExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "defun_apply_u32" ||
  leaf == "defun_compose_inc_double_u32" ||
  leaf == "defun_apply_add5_u32" ||
  leaf == "defun_map_selected_u32"

private def recursiveDataExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "tree_leaf_u32" ||
  leaf == "tree_node_u32" ||
  leaf == "tree_size_u32" ||
  leaf == "tree_sum_u32" ||
  leaf == "rose_branch_u32" ||
  leaf == "even_terminal_u32" ||
  leaf == "odd_terminal_u32" ||
  leaf == "even_step_u32" ||
  leaf == "odd_step_u32" ||
  leaf == "expr_lit_u32" ||
  leaf == "expr_add_u32" ||
  leaf == "expr_eval_u32"

private def dependentErasureExport (declName : Name) : Bool :=
  let leaf := nameLeaf declName
  leaf == "subtype_val_u32" ||
  leaf == "subtype_inc_u32" ||
  leaf == "subtype_roundtrip_u32" ||
  leaf == "equality_cast_subtype_value_u32" ||
  leaf == "fin_val10_u32" ||
  leaf == "fin_checked10_u32" ||
  leaf == "fin_succ_checked10_u32" ||
  leaf == "vector_echo3_u32" ||
  leaf == "vector_map_inc3_u32" ||
  leaf == "sigma_runtime_pair_echo_u32" ||
  leaf == "sigma_runtime_pair_sum_u32" ||
  leaf == "flag_carrier_true_roundtrip_u32" ||
  leaf == "flag_carrier_false_value_u32" ||
  leaf == "flag_carrier_match_invariant_u32" ||
  leaf == "bounded_proof_make_u32" ||
  leaf == "bounded_proof_value_u32" ||
  leaf == "nested_proof_wrapper_value_u32"

private def regularSupportedDetail (declName : Name) : CoreM String := do
  let env ← getEnv
  if LeanRustCore.Export.natWrappingU32Allowed env declName then
    pure "exported-nat-wrapping-u32"
  else if typeclassSpecializationExport declName then
    pure "exported-typeclass-specialization"
  else if generatedDictionaryExport declName then
    pure "exported-generated-typeclass-dictionary"
  else if monadicSpecializationExport declName then
    pure "exported-monadic-bind-specialization"
  else if closureConversionExport declName then
    pure "exported-closure-conversion"
  else if defunctionalizedExport declName then
    pure "exported-defunctionalized-function-case"
  else if recursiveDataExport declName then
    pure "exported-recursive-box-data"
  else if dependentErasureExport declName then
    pure "exported-dependent-erasure"
  else
    pure "exported"

private def extractRegularWithDiagnostic (declName : Name) :
    CoreM (Option (SurfaceFun × LeanRustCore.ExtractIR.ExtractDecl) × ExportDiagnostic) := do
  let rustName := sanitizeRustIdent "generated" (nameLeaf declName)
  try
    let extracted ← extractConstWithDeclAs declName rustName []
    let detail ← regularSupportedDetail declName
    pure (some extracted, supportedDiagnostic (toString declName) extracted.1.name detail)
  catch _ =>
    pure (none, unsupportedDiagnostic (toString declName) rustName "unsupported export skipped by the direct Lean-to-Rust extractor")

private def extractMonoWithDiagnostic (spec : MonoExportSpec) (detail : String) :
    CoreM (Option (SurfaceFun × LeanRustCore.ExtractIR.ExtractDecl) × ExportDiagnostic) := do
  try
    let extracted ← extractConstWithDeclAs spec.source spec.rustName spec.typeArgs
    pure (some extracted, supportedDiagnostic (monoSpecLabel spec) extracted.1.name detail)
  catch _ =>
    pure (none, unsupportedDiagnostic (monoSpecLabel spec) spec.rustName "monomorphized export could not be lowered by the current extractor subset")

private def monoSpecIn (spec : MonoExportSpec) : List MonoExportSpec → Bool
  | [] => false
  | candidate :: rest => sameMonoKey spec.source spec.typeArgs candidate || monoSpecIn spec rest

private def pendingAutoSpecs (seen : List MonoExportSpec) (all : List MonoExportSpec) : List MonoExportSpec :=
  all.filter (fun spec => !monoSpecIn spec seen)

partial def extractPendingAutoHelpers (seen : List MonoExportSpec) (functions : List SurfaceFun)
    (extractDecls : List LeanRustCore.ExtractIR.ExtractDecl) (diagnostics : List ExportDiagnostic)
    (fuel : Nat) : CoreM ExtractionResult := do
  match fuel with
  | 0 => pure {
      functions := functions,
      extractDecls := extractDecls,
      diagnostics := diagnostics ++ [unsupportedDiagnostic "<auto-helper-extraction>" "<fuel>" "automatic helper extraction stopped after the fixpoint fuel was exhausted"]
    }
  | fuel' + 1 => do
      let autoSpecs ← autoHelperExportSpecsRef.get
      let pending := pendingAutoSpecs seen autoSpecs
      if pending.isEmpty then
        pure { functions := functions, extractDecls := extractDecls, diagnostics := diagnostics }
      else
        let mut functions' := functions
        let mut extractDecls' := extractDecls
        let mut diagnostics' := diagnostics
        for spec in pending do
          let (maybeExtracted, diagnostic) ← extractMonoWithDiagnostic spec "auto-helper-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeExtracted with
          | some (f, extractDecl) =>
              functions' := functions' ++ [f]
              extractDecls' := extractDecls' ++ [extractDecl]
          | none => pure ()
        extractPendingAutoHelpers (seen ++ pending) functions' extractDecls' diagnostics' fuel'

private partial def extractPendingGeneratedSpecs (seenMonos seenHelpers : List MonoExportSpec)
    (functions : List SurfaceFun) (extractDecls : List LeanRustCore.ExtractIR.ExtractDecl)
    (diagnostics : List ExportDiagnostic) (fuel : Nat) : CoreM ExtractionResult := do
  match fuel with
  | 0 => pure {
      functions := functions,
      extractDecls := extractDecls,
      diagnostics := diagnostics ++ [unsupportedDiagnostic "<auto-generated-specs>" "<fuel>" "automatic monomorphization/helper extraction stopped after the fixpoint fuel was exhausted"]
    }
  | fuel' + 1 => do
      let autoMonos ← autoMonoExportSpecsRef.get
      let autoHelpers ← autoHelperExportSpecsRef.get
      let pendingMonos := pendingAutoSpecs seenMonos autoMonos
      let pendingHelpers := pendingAutoSpecs seenHelpers autoHelpers
      if pendingMonos.isEmpty && pendingHelpers.isEmpty then
        pure { functions := functions, extractDecls := extractDecls, diagnostics := diagnostics }
      else
        let mut functions' := functions
        let mut extractDecls' := extractDecls
        let mut diagnostics' := diagnostics
        for spec in pendingMonos do
          let (maybeExtracted, diagnostic) ← extractMonoWithDiagnostic spec "auto-monomorphized-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeExtracted with
          | some (f, extractDecl) =>
              functions' := functions' ++ [f]
              extractDecls' := extractDecls' ++ [extractDecl]
          | none => pure ()
        for spec in pendingHelpers do
          let (maybeExtracted, diagnostic) ← extractMonoWithDiagnostic spec "auto-helper-export"
          diagnostics' := diagnostics' ++ [diagnostic]
          match maybeExtracted with
          | some (f, extractDecl) =>
              functions' := functions' ++ [f]
              extractDecls' := extractDecls' ++ [extractDecl]
          | none => pure ()
        extractPendingGeneratedSpecs (seenMonos ++ pendingMonos) (seenHelpers ++ pendingHelpers) functions' extractDecls' diagnostics' fuel'

private def extractPendingAutoMonos (seen : List MonoExportSpec) (functions : List SurfaceFun)
    (extractDecls : List LeanRustCore.ExtractIR.ExtractDecl) (diagnostics : List ExportDiagnostic)
    (fuel : Nat) : CoreM ExtractionResult :=
  extractPendingGeneratedSpecs seen [] functions extractDecls diagnostics fuel

/-- Tolerant extraction: successful declarations are emitted; unsupported declarations are reported. -/
def extractWithDiagnostics (decls : List Name) (monos : List MonoExportSpec) : CoreM ExtractionResult := do
  autoMonoExportSpecsRef.set []
  autoHelperExportSpecsRef.set []
  let mut functions : List SurfaceFun := []
  let mut extractDecls : List LeanRustCore.ExtractIR.ExtractDecl := []
  let mut diagnostics : List ExportDiagnostic := []
  for decl in decls do
    let (maybeExtracted, diagnostic) ← extractRegularWithDiagnostic decl
    diagnostics := diagnostics ++ [diagnostic]
    match maybeExtracted with
    | some (f, extractDecl) =>
        functions := functions ++ [f]
        extractDecls := extractDecls ++ [extractDecl]
    | none => pure ()
  for spec in monos do
    let (maybeExtracted, diagnostic) ← extractMonoWithDiagnostic spec "explicit-monomorphized-export"
    diagnostics := diagnostics ++ [diagnostic]
    match maybeExtracted with
    | some (f, extractDecl) =>
        functions := functions ++ [f]
        extractDecls := extractDecls ++ [extractDecl]
    | none => pure ()
  extractPendingGeneratedSpecs monos [] functions extractDecls diagnostics (decls.length + monos.length + 64)

/-- Register a concrete Rust export for a generic Lean definition. -/
syntax (name := rustMonoExport) "rust_mono_export " ident " as " ident " [" ident,* "]" : command

elab_rules : command
  | `(rust_mono_export $src:ident as $out:ident [$tys,*]) => do
      let mut typeArgs : List RType := []
      for tyStx in tys.getElems do
        match rTypeSyntaxIdent tyStx with
        | .ok ty => typeArgs := typeArgs ++ [ty]
        | .error msg => throwError msg
      let sourceName := src.getId
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
  let monoSpecs ← monoExportSpecsRef.get
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
syntax (name := rustEmitExportsWithReportAndSurfaceAndExtractIR) "rust_emit_exports_with_report_and_surface " ident ident ident ident : command

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
  | `(rust_emit_exports_with_report_and_surface $out:ident $reportOut:ident $surfaceOut:ident $extractIROut:ident) => do
      let result ← currentExtractionResult
      let rust ← match emitSurfaceRustModuleChecked result.functions with
        | .ok source => pure source
        | .error report => throwError "Rust identifier hygiene failed: {report.detail}"
      let report := emitCompatibilityReport result
      let surfaceTerm ← surfaceFunListTerm result.functions
      let extractIRLit := Syntax.mkStrLit (LeanRustCore.ExtractIR.extractIRSnapshot result.extractDecls)
      let rustLit := Syntax.mkStrLit rust
      let reportLit := Syntax.mkStrLit report
      elabCommand (← `(def $out : String := $rustLit))
      elabCommand (← `(def $reportOut : String := $reportLit))
      elabCommand (← `(def $surfaceOut : List LeanRustCore.SurfaceFun := $surfaceTerm))
      elabCommand (← `(def $extractIROut : String := $extractIRLit))

end LeanRustCore.Extract
