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

private def nameLeaf : Name → String
  | .anonymous => "_"
  | .str _ s => s
  | .num p n => nameLeaf p ++ Nat.toString n

private def nameParent : Name → Name
  | .anonymous => .anonymous
  | .str p _ => p
  | .num p _ => p

private def sanitizeRustIdent (fallback : String) (s : String) : String :=
  if s == "_" || s == "" then fallback else s

private def localNameAt (locals : List Local) (idx : Nat) : Except String String :=
  match locals.get? idx with
  | some local => Except.ok local.name
  | none => Except.error s!"unbound de-Bruijn variable #{idx} during extraction"

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

private def unsupported (e : Expr) : CoreM α :=
  throwError "unsupported Lean expression in rust_export extraction: {e}"

private def lookupRField (fields : List RArg) (fieldName : String) : Option RType :=
  match fields with
  | [] => none
  | (name, ty) :: rest => if name == fieldName then some ty else lookupRField rest fieldName

mutual
  partial def typeOfLeanM (ty0 : Expr) : CoreM RType := do
    let ty := stripMData ty0
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
            | [inner] => return .option (← typeOfLeanM inner)
            | _ => throwError "unsupported Option type shape in rust_export extraction"
          else if n == ``Except then
            match args with
            | [errTy, okTy] => return .result (← typeOfLeanM okTy) (← typeOfLeanM errTy)
            | _ => throwError "unsupported Except type shape in rust_export extraction"
          else
            match (← getEnv).find? n with
            | some (.inductInfo _) => typeOfInductive n
            | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"
      | _ => throwError "unsupported Lean type in rust_export extraction: {ty}"

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

private partial def firstTypeArg? : List Expr → CoreM (Option RType)
  | [] => pure none
  | x :: xs => do
      try
        return some (← typeOfLeanM x)
      catch _ =>
        firstTypeArg? xs

private def expectedOrTypeArg (expected : Option RType) (args : List Expr) (fallback : RType) : CoreM RType := do
  match expected with
  | some ty => pure ty
  | none =>
      match (← firstTypeArg? args) with
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

private partial def translateExpr (locals : List Local) (expected : Option RType) (e0 : Expr) : CoreM SurfaceExpr := do
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
      match (← translateConstructorApp? locals expected n []) with
      | some expr => return expr
      | none => unsupported e
  | .letE n ty value body _ =>
      let rustName := sanitizeRustIdent "tmp" (nameLeaf n)
      let valueTy ← typeOfLeanM ty
      let valueExpr ← translateExpr locals (some valueTy) value
      let bodyExpr ← translateExpr ({ name := rustName, ty := valueTy } :: locals) expected body
      return .letIn rustName valueExpr bodyExpr
  | .app .. => translateApp locals expected e
  | .mdata _ inner => translateExpr locals expected inner
  | _ => unsupported e
where
  translateBinaryLastTwo (locals : List Local) (expected : Option RType) (e : Expr) (fallback : RType)
      (ctor : RType → SurfaceExpr → SurfaceExpr → SurfaceExpr) : CoreM SurfaceExpr := do
    let args := e.getAppArgs.toList
    let domain ← expectedOrTypeArg expected args fallback
    match lastTwo args with
    | some (a, b) => return ctor domain (← translateExpr locals (some domain) a) (← translateExpr locals (some domain) b)
    | none => unsupported e

  translateBoolCasesOn (locals : List Local) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: discr :: falseCase :: trueCase :: [] =>
        return .matchBool (← translateExpr locals (some .bool) discr)
          (← translateExpr locals expected trueCase)
          (← translateExpr locals expected falseCase)
    | _ => unsupported e

  translateBoolRec (locals : List Local) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _motive :: falseCase :: trueCase :: discr :: [] =>
        return .matchBool (← translateExpr locals (some .bool) discr)
          (← translateExpr locals expected trueCase)
          (← translateExpr locals expected falseCase)
    | _ => unsupported e

  translateOptionSomeBranch (locals : List Local) (expected : Option RType) (someCase : Expr) : CoreM (String × SurfaceExpr) := do
    let someCase := stripMData someCase
    match someCase with
    | .lam n ty body _ =>
        let innerTy ← typeOfLeanM ty
        let binder := sanitizeRustIdent "value" (nameLeaf n)
        let bodyExpr ← translateExpr ({ name := binder, ty := innerTy } :: locals) expected body
        return (binder, bodyExpr)
    | _ => unsupported someCase

  translateOptionCasesOn (locals : List Local) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _α :: _motive :: discr :: noneCase :: someCase :: [] =>
        let target ← translateExpr locals none discr
        let noneExpr ← translateExpr locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch locals expected someCase
        return .matchOption target noneExpr binder someExpr
    | _ => unsupported e

  translateOptionRec (locals : List Local) (expected : Option RType) (e : Expr) (args : List Expr) : CoreM SurfaceExpr := do
    match args with
    | _α :: _motive :: noneCase :: someCase :: discr :: [] =>
        let target ← translateExpr locals none discr
        let noneExpr ← translateExpr locals expected noneCase
        let (binder, someExpr) ← translateOptionSomeBranch locals expected someCase
        return .matchOption target noneExpr binder someExpr
    | _ => unsupported e

  translateEnumCasesOn (locals : List Local) (expected : Option RType) (e : Expr) (recursor : Name) (args : List Expr) : CoreM SurfaceExpr := do
    let inductName := nameParent recursor
    let enumTy ← typeOfInductive inductName
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if variants.all (fun variant => variant.2.isEmpty) && args.length == branchCount + 2 then
          match args with
          | _motive :: discr :: rest =>
              let variantNames := variants.map (fun variant => variant.1)
              let branches := variantNames.zip rest
              return .matchEnum enumTy (← translateExpr locals (some enumTy) discr)
                (← branches.mapM (fun branch => do
                  let branchExpr ← translateExpr locals expected branch.2
                  pure (branch.1, branchExpr)))
          | _ => unsupported e
        else
          unsupported e
    | _ => unsupported e

  translateEnumRec (locals : List Local) (expected : Option RType) (e : Expr) (recursor : Name) (args : List Expr) : CoreM SurfaceExpr := do
    let inductName := nameParent recursor
    let enumTy ← typeOfInductive inductName
    match enumTy with
    | .enum _ variants =>
        let branchCount := variants.length
        if variants.all (fun variant => variant.2.isEmpty) && args.length == branchCount + 2 then
          match args.reverse with
          | discr :: _ =>
              let rest := (args.drop 1).take branchCount
              let variantNames := variants.map (fun variant => variant.1)
              let branches := variantNames.zip rest
              return .matchEnum enumTy (← translateExpr locals (some enumTy) discr)
                (← branches.mapM (fun branch => do
                  let branchExpr ← translateExpr locals expected branch.2
                  pure (branch.1, branchExpr)))
          | [] => unsupported e
        else
          unsupported e
    | _ => unsupported e

  translateConstructorApp? (locals : List Local) (expected : Option RType) (ctorName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
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
                provided := provided ++ [(pair.1.1, (← translateExpr locals (some pair.1.2) pair.2))]
              return some (.structLit ty provided)
            else
              return none
        | .enum _ _ =>
            if valueArgs.length == fields.length then
              let mut payload : List SurfaceExpr := []
              for pair in fields.zip valueArgs do
                payload := payload ++ [(← translateExpr locals (some pair.1.2) pair.2)]
              return some (.enumVariant ty (nameLeaf ctorName) payload)
            else
              return none
        | _ => return none
    | _ => return none

  translateProjectionApp? (locals : List Local) (expected : Option RType) (projName : Name) (args : List Expr) : CoreM (Option SurfaceExpr) := do
    let parent := nameParent projName
    try
      let ty ← typeOfInductive parent
      match ty with
      | .struct _ fields =>
          let fieldName := nameLeaf projName
          match lookupRField fields fieldName, last? args with
          | some fieldTy, some target =>
              let targetExpr ← translateExpr locals (some ty) target
              return some (.field targetExpr fieldName)
          | _, _ => return none
      | _ => return none
    catch _ =>
      return none

  translateApp (locals : List Local) (expected : Option RType) (e : Expr) : CoreM SurfaceExpr := do
    let fn := e.getAppFn
    let args := e.getAppArgs.toList
    match fn with
    | .const n _ =>
        if n == ``ite then
          match args with
          | _ty :: cond :: _dec :: thenExpr :: elseExpr :: [] =>
              return .ite (← translateExpr locals (some .bool) cond) (← translateExpr locals expected thenExpr) (← translateExpr locals expected elseExpr)
          | _ => unsupported e
        else if n == ``Eq then
          let domain ← expectedOrTypeArg none args .u32
          translateBinaryLastTwo locals (some domain) e domain .eq
        else if n == ``LT.lt || n == ``Nat.lt then
          translateBinaryLastTwo locals none e .u32 .lt
        else if n == ``LE.le || n == ``Nat.le then
          translateBinaryLastTwo locals none e .u32 .le
        else if n == ``Nat.add || n == ``HAdd.hAdd then
          translateBinaryLastTwo locals expected e .u32 .add
        else if n == ``Nat.sub || n == ``HSub.hSub then
          translateBinaryLastTwo locals expected e .u32 .sub
        else if n == ``Nat.mul || n == ``HMul.hMul then
          translateBinaryLastTwo locals expected e .u32 .mul
        else if n == ``Bool.not then
          match args with
          | [a] => return .not (← translateExpr locals (some .bool) a)
          | _ => unsupported e
        else if n == ``Bool.and then
          translateBinaryLastTwo locals (some .bool) e .bool .and
        else if n == ``Bool.or then
          translateBinaryLastTwo locals (some .bool) e .bool .or
        else if n == ``Option.none then
          match expected with
          | some (.option inner) => return .optionNone inner
          | _ =>
              match (← firstTypeArg? args) with
              | some inner => return .optionNone inner
              | none => throwError "Option.none extraction needs an expected Option type"
        else if n == ``Option.some then
          let inner ← match expected with
            | some (.option inner) => pure inner
            | _ => expectedOrTypeArg none args .u32
          match lastTwo args with
          | some (_, value) => return .optionSome (← translateExpr locals (some inner) value)
          | none => unsupported e
        else if n == ``Except.ok then
          let (errTy, okTy) ← match expected with
            | some (.result ok err) => pure (err, ok)
            | _ =>
                match args with
                | errExpr :: okExpr :: _ => do
                    let errTy ← typeOfLeanM errExpr
                    let okTy ← typeOfLeanM okExpr
                    pure (errTy, okTy)
                | _ => throwError "Except.ok extraction needs an expected Result type"
          match lastTwo args with
          | some (_, value) => return .resultOk errTy (← translateExpr locals (some okTy) value)
          | none => unsupported e
        else if n == ``Except.error then
          let (errTy, okTy) ← match expected with
            | some (.result ok err) => pure (err, ok)
            | _ =>
                match args with
                | errExpr :: okExpr :: _ => do
                    let errTy ← typeOfLeanM errExpr
                    let okTy ← typeOfLeanM okExpr
                    pure (errTy, okTy)
                | _ => throwError "Except.error extraction needs an expected Result type"
          match lastTwo args with
          | some (_, value) => return .resultErr okTy (← translateExpr locals (some errTy) value)
          | none => unsupported e
        else if isNamedRecursor n "casesOn" && nameParent n == ``Bool then
          translateBoolCasesOn locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Bool then
          translateBoolRec locals expected e args
        else if isNamedRecursor n "casesOn" && nameParent n == ``Option then
          translateOptionCasesOn locals expected e args
        else if isNamedRecursor n "rec" && nameParent n == ``Option then
          translateOptionRec locals expected e args
        else if isNamedRecursor n "casesOn" then
          translateEnumCasesOn locals expected e n args
        else if isNamedRecursor n "rec" then
          translateEnumRec locals expected e n args
        else
          match (← translateProjectionApp? locals expected n args) with
          | some expr => return expr
          | none =>
              match (← translateConstructorApp? locals expected n args) with
              | some expr => return expr
              | none => unsupported e
    | _ => unsupported e

/-- Extract one ordinary Lean definition into the first-pass Rust surface IR. -/
def extractConst (declName : Name) : CoreM SurfaceFun := do
  let info ← getConstInfo declName
  let defInfo ← match info with
    | .defnInfo d => pure d
    | _ => throwError "rust_export extraction only supports ordinary definitions; got {declName}"
  let (typeBinders, retTyExpr) := peelForalls defInfo.type
  let (_valueBinders, body) := peelLambdas defInfo.value
  let mut args : List RArg := []
  let mut idx : Nat := 0
  for binder in typeBinders do
    let (binderName, binderTy) := binder
    let rustName := sanitizeRustIdent s!"arg{idx}" (nameLeaf binderName)
    let rty ← typeOfLeanM binderTy
    args := args ++ [(rustName, rty)]
    idx := idx + 1
  let ret ← typeOfLeanM retTyExpr
  let locals : List Local := args.reverse.map fun arg => { name := arg.1, ty := arg.2 }
  let bodyExpr ← translateExpr locals (some ret) body
  let funName := sanitizeRustIdent "generated" (nameLeaf declName)
  let surfaceFun : SurfaceFun := { name := funName, args := args, ret := ret, body := bodyExpr }
  match checkSurfaceFun surfaceFun with
  | .ok checked => pure checked
  | .error report => throwError "extracted declaration failed surface type check: {report.detail}"

/-- Extract many Lean definitions, preserving declaration order. -/
def extractConsts (decls : List Name) : CoreM (List SurfaceFun) :=
  decls.mapM extractConst

/--
Compile-time command for an explicit declaration list. The tagged `rust_emit_exports`
command below is the default workflow; this helper is retained for tests.
-/
syntax (name := rustEmitDefs) "rust_emit_defs " ident " [" ident,* "]" : command

elab_rules : command
  | `(rust_emit_defs $out:ident [$ids,*]) => do
      let declNames := ids.getElems.toList.map (fun stx => stx.getId)
      let funs ← liftCoreM <| extractConsts declNames
      let rust := emitSurfaceRustModule funs
      let lit := Syntax.mkStrLit rust
      elabCommand (← `(def $out : String := $lit))

/-- Emit Rust for every declaration tagged with `@[rust_export]` that is visible in the current environment. -/
syntax (name := rustEmitExports) "rust_emit_exports " ident : command

elab_rules : command
  | `(rust_emit_exports $out:ident) => do
      let env ← getEnv
      let declNames := LeanRustCore.Export.exportedNames env
      let funs ← liftCoreM <| extractConsts declNames
      let rust := emitSurfaceRustModule funs
      let lit := Syntax.mkStrLit rust
      elabCommand (← `(def $out : String := $lit))

end LeanRustCore.Extract
