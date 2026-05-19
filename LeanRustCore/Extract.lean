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

private def sanitizeRustIdent (fallback : String) (s : String) : String :=
  if s == "_" || s == "" then fallback else s

private def localNameAt (locals : List Local) (idx : Nat) : Except String String :=
  match locals.get? idx with
  | some local => Except.ok local.name
  | none => Except.error s!"unbound de-Bruijn variable #{idx} during extraction"

private partial def stripMData : Expr → Expr
  | .mdata _ inner => stripMData inner
  | other => other

private def typeOfLean (ty : Expr) : Except String RType :=
  let ty := stripMData ty
  if ty.isConstOf ``Nat then
    Except.ok .u32
  else if ty.isConstOf ``Bool then
    Except.ok .bool
  else
    Except.error "unsupported Lean type in rust_export extraction"

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

private def unsupported (e : Expr) : CoreM α :=
  throwError "unsupported Lean expression in rust_export extraction: {e}"

private partial def translateExpr (locals : List Local) (e0 : Expr) : CoreM SurfaceExpr := do
  let e := stripMData e0
  if let some b := boolLiteral? e then
    return .litBool b
  if let some n := natLiteral? e then
    return .litU32 n
  match e with
  | .bvar idx =>
      match localNameAt locals idx with
      | .ok name => return .var name
      | .error msg => throwError msg
  | .letE n _ty value body _ =>
      let rustName := sanitizeRustIdent "tmp" (nameLeaf n)
      let valueExpr ← translateExpr locals value
      let valueTy ← match typeOfLean _ty with
        | .ok ty => pure ty
        | .error msg => throwError msg
      let bodyExpr ← translateExpr ({ name := rustName, ty := valueTy } :: locals) body
      return .letIn rustName valueExpr bodyExpr
  | .app .. => translateApp locals e
  | .mdata _ inner => translateExpr locals inner
  | _ => unsupported e
where
  translateBinaryLastTwo (locals : List Local) (e : Expr) (ctor : SurfaceExpr → SurfaceExpr → SurfaceExpr) : CoreM SurfaceExpr := do
    match lastTwo (e.getAppArgs.toList) with
    | some (a, b) => return ctor (← translateExpr locals a) (← translateExpr locals b)
    | none => unsupported e

  translateApp (locals : List Local) (e : Expr) : CoreM SurfaceExpr := do
    let fn := e.getAppFn
    let args := e.getAppArgs.toList
    match fn with
    | .const n _ =>
        if n == ``ite then
          match args with
          | _ty :: cond :: _dec :: thenExpr :: elseExpr :: [] =>
              return .ite (← translateExpr locals cond) (← translateExpr locals thenExpr) (← translateExpr locals elseExpr)
          | _ => unsupported e
        else if n == ``Eq then
          translateBinaryLastTwo locals e .eqU32
        else if n == ``LT.lt || n == ``Nat.lt then
          translateBinaryLastTwo locals e .ltU32
        else if n == ``LE.le || n == ``Nat.le then
          translateBinaryLastTwo locals e .leU32
        else if n == ``Nat.add || n == ``HAdd.hAdd then
          translateBinaryLastTwo locals e .addU32
        else if n == ``Nat.sub || n == ``HSub.hSub then
          translateBinaryLastTwo locals e .subU32
        else if n == ``Nat.mul || n == ``HMul.hMul then
          translateBinaryLastTwo locals e .mulU32
        else if n == ``Bool.not then
          match args with
          | [a] => return .not (← translateExpr locals a)
          | _ => unsupported e
        else if n == ``Bool.and then
          translateBinaryLastTwo locals e .and
        else if n == ``Bool.or then
          translateBinaryLastTwo locals e .or
        else
          unsupported e
    | _ => unsupported e

/-- Extract one ordinary Lean definition into the first-pass Rust surface IR. -/
def extractConst (declName : Name) : CoreM SurfaceFun := do
  let info ← getConstInfo declName
  let defInfo ← match info with
    | .defnInfo d => pure d
    | _ => throwError "rust_export extraction only supports ordinary definitions; got {declName}"
  let (typeBinders, retTyExpr) := peelForalls defInfo.type
  let (valueBinders, body) := peelLambdas defInfo.value
  if typeBinders.length != valueBinders.length then
    throwError "type/value binder mismatch while extracting {declName}"
  let mut args : List RArg := []
  let mut idx : Nat := 0
  for binder in typeBinders do
    let (binderName, binderTy) := binder
    let rustName := sanitizeRustIdent s!"arg{idx}" (nameLeaf binderName)
    let rty ← match typeOfLean binderTy with
      | .ok ty => pure ty
      | .error msg => throwError msg
    args := args ++ [(rustName, rty)]
    idx := idx + 1
  let ret ← match typeOfLean retTyExpr with
    | .ok ty => pure ty
    | .error msg => throwError msg
  let locals : List Local := args.reverse.map fun arg => { name := arg.1, ty := arg.2 }
  let bodyExpr ← translateExpr locals body
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

Example:

```lean
rust_emit_defs generatedRust [My.Namespace.foo, My.Namespace.bar]
```

The command inspects the elaborated constant bodies, lowers the supported subset
to `SurfaceFun`, checks the extracted function types, and defines the named
constant as the emitted Rust module text.
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
