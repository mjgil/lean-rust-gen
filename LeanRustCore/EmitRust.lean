import LeanRustCore.IR
import LeanRustCore.Surface

namespace LeanRustCore

/-- Small dependency-free string join. -/
def joinWith (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

/-- Rust spelling for the current IR type subset. -/
def rustType : RType → String
  | .unit => "()"
  | .bool => "bool"
  | .u32 => "u32"
  | .u64 => "u64"
  | .i32 => "i32"
  | .i64 => "i64"
  | .option t => "Option<" ++ rustType t ++ ">"
  | .result ok err => "Result<" ++ rustType ok ++ ", " ++ rustType err ++ ">"
  | .enum name _ => name

def rustVariantName (variant : String) : String :=
  if variant == "first" then "First"
  else if variant == "second" then "Second"
  else if variant == "third" then "Third"
  else if variant == "red" then "Red"
  else if variant == "green" then "Green"
  else if variant == "blue" then "Blue"
  else if variant == "left" then "Left"
  else if variant == "right" then "Right"
  else variant

private def enumPath (ty : RType) (variant : String) : String :=
  match ty with
  | .enum name _ => name ++ "::" ++ rustVariantName variant
  | _ => rustVariantName variant

private def emitInt (n : Int) : String :=
  toString n

private def wrappingMethod : RType → String → Option String
  | .u32, op => some ("wrapping_" ++ op)
  | .u64, op => some ("wrapping_" ++ op)
  | .i32, op => some ("wrapping_" ++ op)
  | .i64, op => some ("wrapping_" ++ op)
  | _, _ => none

private def emitWrapping (op : String) (t : RType) (a b : String) : String :=
  match wrappingMethod t op with
  | some method => "(" ++ a ++ ")." ++ method ++ "(" ++ b ++ ")"
  | none => "(" ++ a ++ " /* unsupported wrapping op */ " ++ b ++ ")"

/-- Emit a valid Rust expression for the proof-carrying typed subset. -/
def emitExpr {ctx : Type} : {t : RType} → RExpr ctx t → String
  | _, .var name _ => name
  | _, .litUnit => "()"
  | _, .litBool true => "true"
  | _, .litBool false => "false"
  | _, .litU32 n => Nat.toString n
  | _, .litU64 n => Nat.toString n
  | _, .litI32 n => emitInt n
  | _, .litI64 n => emitInt n
  | _, .letIn name value body => "{ let " ++ name ++ " = " ++ emitExpr value ++ "; " ++ emitExpr body ++ " }"
  | _, .ite c a b => "if " ++ emitExpr c ++ " { " ++ emitExpr a ++ " } else { " ++ emitExpr b ++ " }"
  | _, .matchBool c whenTrue whenFalse => "match " ++ emitExpr c ++ " { true => " ++ emitExpr whenTrue ++ ", false => " ++ emitExpr whenFalse ++ " }"
  | _, .matchOption target noneCase someCase => "match " ++ emitExpr target ++ " { None => " ++ emitExpr noneCase ++ ", Some(value) => " ++ emitExpr someCase ++ " }"
  | _, .not a => "(!" ++ emitExpr a ++ ")"
  | _, .and a b => "(" ++ emitExpr a ++ " && " ++ emitExpr b ++ ")"
  | _, .or a b => "(" ++ emitExpr a ++ " || " ++ emitExpr b ++ ")"
  | _, .eqU32 a b => emitExpr a ++ " == " ++ emitExpr b
  | _, .ltU32 a b => emitExpr a ++ " < " ++ emitExpr b
  | _, .leU32 a b => emitExpr a ++ " <= " ++ emitExpr b
  | _, .gtU32 a b => emitExpr a ++ " > " ++ emitExpr b
  | _, .geU32 a b => emitExpr a ++ " >= " ++ emitExpr b
  | _, .addU32 a b => "(" ++ emitExpr a ++ ").wrapping_add(" ++ emitExpr b ++ ")"
  | _, .subU32 a b => "(" ++ emitExpr a ++ ").wrapping_sub(" ++ emitExpr b ++ ")"
  | _, .mulU32 a b => "(" ++ emitExpr a ++ ").wrapping_mul(" ++ emitExpr b ++ ")"
  | _, .minU32 a b => "core::cmp::min(" ++ emitExpr a ++ ", " ++ emitExpr b ++ ")"
  | _, .maxU32 a b => "core::cmp::max(" ++ emitExpr a ++ ", " ++ emitExpr b ++ ")"
  | _, .optionNone => "None"
  | _, .optionSome a => "Some(" ++ emitExpr a ++ ")"
  | _, .resultOk a => "Ok(" ++ emitExpr a ++ ")"
  | _, .resultErr e => "Err(" ++ emitExpr e ++ ")"

/-- Emit the extracted first-order surface subset. -/
partial def emitSurfaceExpr : SurfaceExpr → String
  | .var name => name
  | .litUnit => "()"
  | .litBool true => "true"
  | .litBool false => "false"
  | .litU32 n => Nat.toString n
  | .litU64 n => Nat.toString n
  | .litI32 n => emitInt n
  | .litI64 n => emitInt n
  | .letIn name value body => "{ let " ++ name ++ " = " ++ emitSurfaceExpr value ++ "; " ++ emitSurfaceExpr body ++ " }"
  | .ite c a b => "if " ++ emitSurfaceExpr c ++ " { " ++ emitSurfaceExpr a ++ " } else { " ++ emitSurfaceExpr b ++ " }"
  | .matchBool c whenTrue whenFalse => "match " ++ emitSurfaceExpr c ++ " { true => " ++ emitSurfaceExpr whenTrue ++ ", false => " ++ emitSurfaceExpr whenFalse ++ " }"
  | .matchOption target noneCase someName someCase => "match " ++ emitSurfaceExpr target ++ " { None => " ++ emitSurfaceExpr noneCase ++ ", Some(" ++ someName ++ ") => " ++ emitSurfaceExpr someCase ++ " }"
  | .matchEnum enumTy target branches =>
      let rendered := branches.map (fun branch => enumPath enumTy branch.1 ++ " => " ++ emitSurfaceExpr branch.2)
      "match " ++ emitSurfaceExpr target ++ " { " ++ joinWith ", " rendered ++ " }"
  | .not a => "(!" ++ emitSurfaceExpr a ++ ")"
  | .and a b => "(" ++ emitSurfaceExpr a ++ " && " ++ emitSurfaceExpr b ++ ")"
  | .or a b => "(" ++ emitSurfaceExpr a ++ " || " ++ emitSurfaceExpr b ++ ")"
  | .eq _ a b => emitSurfaceExpr a ++ " == " ++ emitSurfaceExpr b
  | .lt _ a b => emitSurfaceExpr a ++ " < " ++ emitSurfaceExpr b
  | .le _ a b => emitSurfaceExpr a ++ " <= " ++ emitSurfaceExpr b
  | .gt _ a b => emitSurfaceExpr a ++ " > " ++ emitSurfaceExpr b
  | .ge _ a b => emitSurfaceExpr a ++ " >= " ++ emitSurfaceExpr b
  | .add t a b => emitWrapping "add" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .sub t a b => emitWrapping "sub" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .mul t a b => emitWrapping "mul" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .min _ a b => "core::cmp::min(" ++ emitSurfaceExpr a ++ ", " ++ emitSurfaceExpr b ++ ")"
  | .max _ a b => "core::cmp::max(" ++ emitSurfaceExpr a ++ ", " ++ emitSurfaceExpr b ++ ")"
  | .optionNone _ => "None"
  | .optionSome a => "Some(" ++ emitSurfaceExpr a ++ ")"
  | .resultOk _ a => "Ok(" ++ emitSurfaceExpr a ++ ")"
  | .resultErr _ e => "Err(" ++ emitSurfaceExpr e ++ ")"
  | .enumVariant ty variant => enumPath ty variant

/-- Emit one Rust function argument. -/
def emitArg (arg : RArg) : String :=
  arg.1 ++ ": " ++ rustType arg.2

/-- Emit a safe Rust function from proof-carrying typed IR. -/
def emitFun (f : RFun) : String :=
  "pub fn " ++ f.name ++ "(" ++ joinWith ", " (f.args.map emitArg) ++ ") -> " ++
    rustType f.ret ++ " {\n    " ++ emitExpr f.body ++ "\n}\n"

/-- Emit a safe Rust function from extracted surface IR. -/
def emitSurfaceFun (f : SurfaceFun) : String :=
  "pub fn " ++ f.name ++ "(" ++ joinWith ", " (f.args.map emitArg) ++ ") -> " ++
    rustType f.ret ++ " {\n    " ++ emitSurfaceExpr f.body ++ "\n}\n"

private def collectTypeEnums : RType → List RType
  | .option t => collectTypeEnums t
  | .result ok err => collectTypeEnums ok ++ collectTypeEnums err
  | e@(.enum _ _) => [e]
  | _ => []

partial def collectSurfaceEnums : SurfaceExpr → List RType
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litU32 _ => []
  | .litU64 _ => []
  | .litI32 _ => []
  | .litI64 _ => []
  | .letIn _ value body => collectSurfaceEnums value ++ collectSurfaceEnums body
  | .ite c a b => collectSurfaceEnums c ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .matchBool c a b => collectSurfaceEnums c ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .matchOption target noneCase _ someCase => collectSurfaceEnums target ++ collectSurfaceEnums noneCase ++ collectSurfaceEnums someCase
  | .matchEnum ty target branches => collectTypeEnums ty ++ collectSurfaceEnums target ++ branches.bind (fun branch => collectSurfaceEnums branch.2)
  | .not a => collectSurfaceEnums a
  | .and a b => collectSurfaceEnums a ++ collectSurfaceEnums b
  | .or a b => collectSurfaceEnums a ++ collectSurfaceEnums b
  | .eq t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .lt t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .le t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .gt t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .ge t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .add t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .sub t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .mul t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .min t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .max t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .optionNone t => collectTypeEnums t
  | .optionSome a => collectSurfaceEnums a
  | .resultOk t a => collectTypeEnums t ++ collectSurfaceEnums a
  | .resultErr t e => collectTypeEnums t ++ collectSurfaceEnums e
  | .enumVariant ty _ => collectTypeEnums ty

private def collectFunEnums (f : SurfaceFun) : List RType :=
  f.args.bind (fun arg => collectTypeEnums arg.2) ++ collectTypeEnums f.ret ++ collectSurfaceEnums f.body

private def hasEnumNamed (name : String) : List RType → Bool
  | [] => false
  | (.enum candidate _) :: rest => candidate == name || hasEnumNamed name rest
  | _ :: rest => hasEnumNamed name rest

private def uniqueEnums : List RType → List RType
  | [] => []
  | e@(.enum name _) :: rest =>
      let tail := uniqueEnums rest
      if hasEnumNamed name tail then tail else e :: tail
  | _ :: rest => uniqueEnums rest

private def emitEnum : RType → String
  | .enum name variants =>
      "#[derive(Clone, Copy, Debug, PartialEq, Eq)]\n" ++
      "pub enum " ++ name ++ " { " ++ joinWith ", " (variants.map rustVariantName) ++ " }\n"
  | _ => ""

private def emitEnums (fns : List SurfaceFun) : String :=
  let enums := uniqueEnums (fns.bind collectFunEnums)
  if enums.isEmpty then "" else joinWith "\n" (enums.map emitEnum) ++ "\n"

/-- Emit a whole generated module from proof-carrying functions. -/
def emitRustModule (fns : List RFun) : String :=
  "// Generated by LeanRustCore. Do not edit by hand.\n" ++
  "// The checked-in rust/src/generated.rs is a fallback snapshot; scripts/gen.sh regenerates it.\n\n" ++
  joinWith "\n" (fns.map emitFun)

/-- Emit a whole generated module from extracted Lean declarations. -/
def emitSurfaceRustModule (fns : List SurfaceFun) : String :=
  "// Generated by LeanRustCore from elaborated Lean declarations. Do not edit by hand.\n" ++
  "// The checked-in rust/src/generated.rs is a fallback snapshot; scripts/gen.sh regenerates it.\n\n" ++
  emitEnums fns ++
  joinWith "\n" (fns.map emitSurfaceFun)

end LeanRustCore
