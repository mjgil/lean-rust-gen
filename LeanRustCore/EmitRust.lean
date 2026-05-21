import LeanRustCore.IR
import LeanRustCore.Surface
import LeanRustCore.RustHygiene

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
  | .char => "char"
  | .string => "String"
  | .option t => "Option<" ++ rustType t ++ ">"
  | .result ok err => "Result<" ++ rustType ok ++ ", " ++ rustType err ++ ">"
  | .list t => "Vec<" ++ rustType t ++ ">"
  | .array t => "Vec<" ++ rustType t ++ ">"
  | .prod a b => "(" ++ rustType a ++ ", " ++ rustType b ++ ")"
  | .sum a b => "Result<" ++ rustType b ++ ", " ++ rustType a ++ ">"
  | .func a b => "fn(" ++ rustType a ++ ") -> " ++ rustType b
  | .subtype t => rustType t
  | .fin _ => "u32"
  | .vector t _ => "Vec<" ++ rustType t ++ ">"
  | .struct name _ => rustTypeIdent name
  | .enum name _ => rustTypeIdent name

private def enumPath (ty : RType) (variant : String) : String :=
  match ty with
  | .enum name _ => rustTypeIdent name ++ "::" ++ rustVariantIdent variant
  | _ => rustVariantIdent variant

private def emitEnumPattern (ty : RType) (branch : String × (List String × SurfaceExpr)) : String :=
  if branch.2.1.isEmpty then
    enumPath ty branch.1
  else
    enumPath ty branch.1 ++ "(" ++ joinWith ", " (branch.2.1.map (rustValueIdent "value")) ++ ")"

private def emitInt (n : Int) : String :=
  toString n

private def emitRustStringLiteral (s : String) : String :=
  "String::from(\"" ++ s ++ "\")"

private def emitRustChar (c : Char) : String :=
  "char::from_u32(" ++ Nat.toString c.toNat ++ ").unwrap()"

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
  | _, .var name _ => rustValueIdent "value" name
  | _, .litUnit => "()"
  | _, .litBool true => "true"
  | _, .litBool false => "false"
  | _, .litU32 n => Nat.toString n
  | _, .litU64 n => Nat.toString n
  | _, .litI32 n => emitInt n
  | _, .litI64 n => emitInt n
  | _, .letIn name value body => "{ let " ++ rustValueIdent "value" name ++ " = " ++ emitExpr value ++ "; " ++ emitExpr body ++ " }"
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
  | .var name => rustValueIdent "value" name
  | .litUnit => "()"
  | .litBool true => "true"
  | .litBool false => "false"
  | .litU32 n => Nat.toString n
  | .litU64 n => Nat.toString n
  | .litI32 n => emitInt n
  | .litI64 n => emitInt n
  | .litChar c => emitRustChar c
  | .litString value => emitRustStringLiteral value
  | .letIn name value body => "{ let " ++ rustValueIdent "value" name ++ " = " ++ emitSurfaceExpr value ++ "; " ++ emitSurfaceExpr body ++ " }"
  | .ite c a b => "if " ++ emitSurfaceExpr c ++ " { " ++ emitSurfaceExpr a ++ " } else { " ++ emitSurfaceExpr b ++ " }"
  | .matchBool c whenTrue whenFalse => "match " ++ emitSurfaceExpr c ++ " { true => " ++ emitSurfaceExpr whenTrue ++ ", false => " ++ emitSurfaceExpr whenFalse ++ " }"
  | .matchOption target noneCase someName someCase => "match " ++ emitSurfaceExpr target ++ " { None => " ++ emitSurfaceExpr noneCase ++ ", Some(" ++ rustValueIdent "value" someName ++ ") => " ++ emitSurfaceExpr someCase ++ " }"
  | .matchEnum enumTy target branches =>
      let rendered := branches.map (fun branch => emitEnumPattern enumTy branch ++ " => " ++ emitSurfaceExpr branch.2.2)
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
  | .structLit ty fields =>
      let rendered := fields.map (fun field => rustFieldIdent field.1 ++ ": " ++ emitSurfaceExpr field.2)
      match ty with
      | .struct name _ => rustTypeIdent name ++ " { " ++ joinWith ", " rendered ++ " }"
      | _ => "/* malformed struct literal */"
  | .field target fieldName => "(" ++ emitSurfaceExpr target ++ ")." ++ rustFieldIdent fieldName
  | .enumVariant ty variant payload =>
      let renderedPayload := if payload.isEmpty then "" else "(" ++ joinWith ", " (payload.map emitSurfaceExpr) ++ ")"
      enumPath ty variant ++ renderedPayload
  | .call name _ _ args =>
      rustValueIdent "generated" name ++ "(" ++ joinWith ", " (args.map emitSurfaceExpr) ++ ")"
  | .callValue fn _ _ arg =>
      emitSurfaceExpr fn ++ "(" ++ emitSurfaceExpr arg ++ ")"
  | .listMap binder _ _ target body =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { " ++ outName ++ ".push(" ++ emitSurfaceExpr body ++ "); } " ++ outName ++ " }"
  | .listFilter binder _ target predicate =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if " ++ emitSurfaceExpr predicate ++ " { " ++ outName ++ ".push(" ++ binderName ++ "); } } " ++ outName ++ " }"
  | .listFoldl accName elemName _ _ init target body =>
      let acc := rustValueIdent "acc" accName
      let elem := rustValueIdent "item" elemName
      "{ let mut " ++ acc ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in " ++ emitSurfaceExpr target ++ " { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .listFoldr elemName accName _ _ target init body =>
      let elem := rustValueIdent "item" elemName
      let acc := rustValueIdent "acc" accName
      "{ let mut " ++ acc ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in (" ++ emitSurfaceExpr target ++ ").into_iter().rev() { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .listAny binder _ target predicate =>
      let outName := "__lrc_any"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = false; for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if " ++ emitSurfaceExpr predicate ++ " { " ++ outName ++ " = true; break; } } " ++ outName ++ " }"
  | .listAll binder _ target predicate =>
      let outName := "__lrc_all"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = true; for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if !(" ++ emitSurfaceExpr predicate ++ ") { " ++ outName ++ " = false; break; } } " ++ outName ++ " }"
  | .arrayMap binder _ _ target body =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { " ++ outName ++ ".push(" ++ emitSurfaceExpr body ++ "); } " ++ outName ++ " }"
  | .arrayFoldl accName elemName _ _ init target body =>
      let acc := rustValueIdent "acc" accName
      let elem := rustValueIdent "item" elemName
      "{ let mut " ++ acc ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in " ++ emitSurfaceExpr target ++ " { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .optionMap binder _ outTy target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { None => None::<" ++ rustType outTy ++ ">, Some(" ++ name ++ ") => Some(" ++ emitSurfaceExpr body ++ ") }"
  | .optionBind binder _ outTy target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { None => None::<" ++ rustType outTy ++ ">, Some(" ++ name ++ ") => " ++ emitSurfaceExpr body ++ " }"
  | .resultMapOk binder errTy _ _ target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { Err(__lrc_err) => Err::<_, " ++ rustType errTy ++ ">(__lrc_err), Ok(" ++ name ++ ") => Ok(" ++ emitSurfaceExpr body ++ ") }"
  | .resultBind binder errTy _ _ target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { Err(__lrc_err) => Err::<_, " ++ rustType errTy ++ ">(__lrc_err), Ok(" ++ name ++ ") => " ++ emitSurfaceExpr body ++ " }"
  | .subtypeErase _ value => emitSurfaceExpr value
  | .subtypeVal _ value => emitSurfaceExpr value
  | .finCheck bound value =>
      "if " ++ emitSurfaceExpr value ++ " < " ++ Nat.toString bound ++ " { Some(" ++ emitSurfaceExpr value ++ ") } else { None }"
  | .finVal _ value => emitSurfaceExpr value
  | .vectorCheck elemTy bound value =>
      let vecName := "__lrc_vec"
      "{ let " ++ vecName ++ " = " ++ emitSurfaceExpr value ++ "; if " ++ vecName ++ ".len() == " ++ Nat.toString bound ++ " { Some(" ++ vecName ++ ") } else { None::<" ++ rustType (.vector elemTy bound) ++ "> } }"
  | .natFold idxName accName _ init n body =>
      let idx := rustValueIdent "idx" idxName
      let acc := rustValueIdent "acc" accName
      "{ let mut " ++ acc ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ idx ++ " in 0..(" ++ emitSurfaceExpr n ++ ") { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"

/-- Emit one Rust function argument. -/
def emitArg (arg : RArg) : String :=
  rustValueIdent "arg" arg.1 ++ ": " ++ rustType arg.2

/-- Emit a safe Rust function from proof-carrying typed IR. -/
def emitFun (f : RFun) : String :=
  "pub fn " ++ rustValueIdent "generated" f.name ++ "(" ++ joinWith ", " (f.args.map emitArg) ++ ") -> " ++
    rustType f.ret ++ " {\n    " ++ emitExpr f.body ++ "\n}\n"

/-- Emit a safe Rust function from extracted surface IR. -/
def emitSurfaceFun (f : SurfaceFun) : String :=
  "pub fn " ++ rustValueIdent "generated" f.name ++ "(" ++ joinWith ", " (f.args.map emitArg) ++ ") -> " ++
    rustType f.ret ++ " {\n    " ++ emitSurfaceExpr f.body ++ "\n}\n"

private def collectTypeStructs : RType → List SurfaceStruct
  | .option t => collectTypeStructs t
  | .result ok err => collectTypeStructs ok ++ collectTypeStructs err
  | .list t => collectTypeStructs t
  | .array t => collectTypeStructs t
  | .prod a b => collectTypeStructs a ++ collectTypeStructs b
  | .sum a b => collectTypeStructs a ++ collectTypeStructs b
  | .func a b => collectTypeStructs a ++ collectTypeStructs b
  | .subtype t => collectTypeStructs t
  | .fin _ => []
  | .vector t _ => collectTypeStructs t
  | s@(.struct name fields) =>
      { name := name, fields := fields } :: fields.bind (fun field => collectTypeStructs field.2)
  | .enum _ variants => variants.bind (fun variant => variant.2.bind collectTypeStructs)
  | _ => []

private def collectTypeEnums : RType → List SurfaceEnum
  | .option t => collectTypeEnums t
  | .result ok err => collectTypeEnums ok ++ collectTypeEnums err
  | .list t => collectTypeEnums t
  | .array t => collectTypeEnums t
  | .prod a b => collectTypeEnums a ++ collectTypeEnums b
  | .sum a b => collectTypeEnums a ++ collectTypeEnums b
  | .func a b => collectTypeEnums a ++ collectTypeEnums b
  | .subtype t => collectTypeEnums t
  | .fin _ => []
  | .vector t _ => collectTypeEnums t
  | .struct _ fields => fields.bind (fun field => collectTypeEnums field.2)
  | .enum name variants =>
      { name := name, variants := variants } :: variants.bind (fun variant => variant.2.bind collectTypeEnums)
  | _ => []

partial def collectSurfaceStructs : SurfaceExpr → List SurfaceStruct
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litU32 _ => []
  | .litU64 _ => []
  | .litI32 _ => []
  | .litI64 _ => []
  | .litChar _ => []
  | .litString _ => []
  | .letIn _ value body => collectSurfaceStructs value ++ collectSurfaceStructs body
  | .ite c a b => collectSurfaceStructs c ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .matchBool c a b => collectSurfaceStructs c ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .matchOption target noneCase _ someCase => collectSurfaceStructs target ++ collectSurfaceStructs noneCase ++ collectSurfaceStructs someCase
  | .matchEnum ty target branches => collectTypeStructs ty ++ collectSurfaceStructs target ++ branches.bind (fun branch => collectSurfaceStructs branch.2.2)
  | .not a => collectSurfaceStructs a
  | .and a b => collectSurfaceStructs a ++ collectSurfaceStructs b
  | .or a b => collectSurfaceStructs a ++ collectSurfaceStructs b
  | .eq t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .lt t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .le t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .gt t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .ge t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .add t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .sub t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .mul t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .min t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .max t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .optionNone t => collectTypeStructs t
  | .optionSome a => collectSurfaceStructs a
  | .resultOk t a => collectTypeStructs t ++ collectSurfaceStructs a
  | .resultErr t e => collectTypeStructs t ++ collectSurfaceStructs e
  | .structLit ty fields => collectTypeStructs ty ++ fields.bind (fun field => collectSurfaceStructs field.2)
  | .field target _ => collectSurfaceStructs target
  | .enumVariant ty _ payload => collectTypeStructs ty ++ payload.bind collectSurfaceStructs
  | .call _ argTypes ret args => argTypes.bind collectTypeStructs ++ collectTypeStructs ret ++ args.bind collectSurfaceStructs
  | .callValue fn argTy retTy arg => collectSurfaceStructs fn ++ collectTypeStructs argTy ++ collectTypeStructs retTy ++ collectSurfaceStructs arg
  | .listMap _ elemTy outTy target body =>
      collectTypeStructs elemTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .listFilter _ elemTy target predicate =>
      collectTypeStructs elemTy ++ collectSurfaceStructs target ++ collectSurfaceStructs predicate
  | .listFoldl _ _ accTy elemTy init target body =>
      collectTypeStructs accTy ++ collectTypeStructs elemTy ++ collectSurfaceStructs init ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .listFoldr _ _ elemTy accTy target init body =>
      collectTypeStructs elemTy ++ collectTypeStructs accTy ++ collectSurfaceStructs target ++ collectSurfaceStructs init ++ collectSurfaceStructs body
  | .listAny _ elemTy target predicate =>
      collectTypeStructs elemTy ++ collectSurfaceStructs target ++ collectSurfaceStructs predicate
  | .listAll _ elemTy target predicate =>
      collectTypeStructs elemTy ++ collectSurfaceStructs target ++ collectSurfaceStructs predicate
  | .arrayMap _ elemTy outTy target body =>
      collectTypeStructs elemTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .arrayFoldl _ _ accTy elemTy init target body =>
      collectTypeStructs accTy ++ collectTypeStructs elemTy ++ collectSurfaceStructs init ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .optionMap _ innerTy outTy target body =>
      collectTypeStructs innerTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .optionBind _ innerTy outTy target body =>
      collectTypeStructs innerTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .resultMapOk _ errTy okTy outTy target body =>
      collectTypeStructs errTy ++ collectTypeStructs okTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .resultBind _ errTy okTy outTy target body =>
      collectTypeStructs errTy ++ collectTypeStructs okTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .subtypeErase inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .subtypeVal inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .finCheck _ value => collectSurfaceStructs value
  | .finVal _ value => collectSurfaceStructs value
  | .vectorCheck elemTy _ value => collectTypeStructs elemTy ++ collectSurfaceStructs value
  | .natFold _ _ accTy init n body =>
      collectTypeStructs accTy ++ collectSurfaceStructs init ++ collectSurfaceStructs n ++ collectSurfaceStructs body

partial def collectSurfaceEnums : SurfaceExpr → List SurfaceEnum
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litU32 _ => []
  | .litU64 _ => []
  | .litI32 _ => []
  | .litI64 _ => []
  | .litChar _ => []
  | .litString _ => []
  | .letIn _ value body => collectSurfaceEnums value ++ collectSurfaceEnums body
  | .ite c a b => collectSurfaceEnums c ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .matchBool c a b => collectSurfaceEnums c ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .matchOption target noneCase _ someCase => collectSurfaceEnums target ++ collectSurfaceEnums noneCase ++ collectSurfaceEnums someCase
  | .matchEnum ty target branches => collectTypeEnums ty ++ collectSurfaceEnums target ++ branches.bind (fun branch => collectSurfaceEnums branch.2.2)
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
  | .structLit ty fields => collectTypeEnums ty ++ fields.bind (fun field => collectSurfaceEnums field.2)
  | .field target _ => collectSurfaceEnums target
  | .enumVariant ty _ payload => collectTypeEnums ty ++ payload.bind collectSurfaceEnums
  | .call _ argTypes ret args => argTypes.bind collectTypeEnums ++ collectTypeEnums ret ++ args.bind collectSurfaceEnums
  | .callValue fn argTy retTy arg => collectSurfaceEnums fn ++ collectTypeEnums argTy ++ collectTypeEnums retTy ++ collectSurfaceEnums arg
  | .listMap _ elemTy outTy target body =>
      collectTypeEnums elemTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .listFilter _ elemTy target predicate =>
      collectTypeEnums elemTy ++ collectSurfaceEnums target ++ collectSurfaceEnums predicate
  | .listFoldl _ _ accTy elemTy init target body =>
      collectTypeEnums accTy ++ collectTypeEnums elemTy ++ collectSurfaceEnums init ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .listFoldr _ _ elemTy accTy target init body =>
      collectTypeEnums elemTy ++ collectTypeEnums accTy ++ collectSurfaceEnums target ++ collectSurfaceEnums init ++ collectSurfaceEnums body
  | .listAny _ elemTy target predicate =>
      collectTypeEnums elemTy ++ collectSurfaceEnums target ++ collectSurfaceEnums predicate
  | .listAll _ elemTy target predicate =>
      collectTypeEnums elemTy ++ collectSurfaceEnums target ++ collectSurfaceEnums predicate
  | .arrayMap _ elemTy outTy target body =>
      collectTypeEnums elemTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .arrayFoldl _ _ accTy elemTy init target body =>
      collectTypeEnums accTy ++ collectTypeEnums elemTy ++ collectSurfaceEnums init ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .optionMap _ innerTy outTy target body =>
      collectTypeEnums innerTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .optionBind _ innerTy outTy target body =>
      collectTypeEnums innerTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .resultMapOk _ errTy okTy outTy target body =>
      collectTypeEnums errTy ++ collectTypeEnums okTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .resultBind _ errTy okTy outTy target body =>
      collectTypeEnums errTy ++ collectTypeEnums okTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .subtypeErase inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .subtypeVal inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .finCheck _ value => collectSurfaceEnums value
  | .finVal _ value => collectSurfaceEnums value
  | .vectorCheck elemTy _ value => collectTypeEnums elemTy ++ collectSurfaceEnums value
  | .natFold _ _ accTy init n body =>
      collectTypeEnums accTy ++ collectSurfaceEnums init ++ collectSurfaceEnums n ++ collectSurfaceEnums body

partial def collectSurfaceCalls : SurfaceExpr → List String
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litU32 _ => []
  | .litU64 _ => []
  | .litI32 _ => []
  | .litI64 _ => []
  | .litChar _ => []
  | .litString _ => []
  | .letIn _ value body => collectSurfaceCalls value ++ collectSurfaceCalls body
  | .ite c a b => collectSurfaceCalls c ++ collectSurfaceCalls a ++ collectSurfaceCalls b
  | .matchBool c a b => collectSurfaceCalls c ++ collectSurfaceCalls a ++ collectSurfaceCalls b
  | .matchOption target noneCase _ someCase => collectSurfaceCalls target ++ collectSurfaceCalls noneCase ++ collectSurfaceCalls someCase
  | .matchEnum _ target branches => collectSurfaceCalls target ++ branches.bind (fun branch => collectSurfaceCalls branch.2.2)
  | .not a => collectSurfaceCalls a
  | .and a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .or a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .eq _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .lt _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .le _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .gt _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .ge _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .add _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .sub _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .mul _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .min _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .max _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .optionNone _ => []
  | .optionSome a => collectSurfaceCalls a
  | .resultOk _ a => collectSurfaceCalls a
  | .resultErr _ e => collectSurfaceCalls e
  | .structLit _ fields => fields.bind (fun field => collectSurfaceCalls field.2)
  | .field target _ => collectSurfaceCalls target
  | .enumVariant _ _ payload => payload.bind collectSurfaceCalls
  | .call name _ _ args => name :: args.bind collectSurfaceCalls
  | .callValue fn _ _ arg => collectSurfaceCalls fn ++ collectSurfaceCalls arg
  | .listMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .listFilter _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .listFoldl _ _ _ _ init target body => collectSurfaceCalls init ++ collectSurfaceCalls target ++ collectSurfaceCalls body
  | .listFoldr _ _ _ _ target init body => collectSurfaceCalls target ++ collectSurfaceCalls init ++ collectSurfaceCalls body
  | .listAny _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .listAll _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .arrayMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .arrayFoldl _ _ _ _ init target body => collectSurfaceCalls init ++ collectSurfaceCalls target ++ collectSurfaceCalls body
  | .optionMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .optionBind _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .resultMapOk _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .resultBind _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .subtypeErase _ value => collectSurfaceCalls value
  | .subtypeVal _ value => collectSurfaceCalls value
  | .finCheck _ value => collectSurfaceCalls value
  | .finVal _ value => collectSurfaceCalls value
  | .vectorCheck _ _ value => collectSurfaceCalls value
  | .natFold _ _ _ init n body => collectSurfaceCalls init ++ collectSurfaceCalls n ++ collectSurfaceCalls body

private def collectFunStructs (f : SurfaceFun) : List SurfaceStruct :=
  f.args.bind (fun arg => collectTypeStructs arg.2) ++ collectTypeStructs f.ret ++ collectSurfaceStructs f.body

private def collectFunEnums (f : SurfaceFun) : List SurfaceEnum :=
  f.args.bind (fun arg => collectTypeEnums arg.2) ++ collectTypeEnums f.ret ++ collectSurfaceEnums f.body

private def hasStructNamed (name : String) : List SurfaceStruct → Bool
  | [] => false
  | s :: rest => s.name == name || hasStructNamed name rest

private def hasEnumNamed (name : String) : List SurfaceEnum → Bool
  | [] => false
  | e :: rest => e.name == name || hasEnumNamed name rest

private def uniqueStructs : List SurfaceStruct → List SurfaceStruct
  | [] => []
  | s :: rest =>
      let tail := uniqueStructs rest
      if hasStructNamed s.name tail then tail else s :: tail

private def uniqueEnums : List SurfaceEnum → List SurfaceEnum
  | [] => []
  | e :: rest =>
      let tail := uniqueEnums rest
      if hasEnumNamed e.name tail then tail else e :: tail

private def emitStructFieldDecl (field : RArg) : String :=
  "pub " ++ rustFieldIdent field.1 ++ ": " ++ rustType field.2

private def emitStruct (s : SurfaceStruct) : String :=
  "#[derive(Clone, Debug, PartialEq, Eq)]\n" ++
  "pub struct " ++ rustTypeIdent s.name ++ " { " ++ joinWith ", " (s.fields.map emitStructFieldDecl) ++ " }\n"

private def emitEnumVariantDecl (variant : String × List RType) : String :=
  let name := rustVariantIdent variant.1
  if variant.2.isEmpty then
    name
  else
    name ++ "(" ++ joinWith ", " (variant.2.map rustType) ++ ")"

private def emitEnum (e : SurfaceEnum) : String :=
  "#[derive(Clone, Debug, PartialEq, Eq)]\n" ++
  "pub enum " ++ rustTypeIdent e.name ++ " { " ++ joinWith ", " (e.variants.map emitEnumVariantDecl) ++ " }\n"

private def containsNameString : List String → String → Bool
  | [], _ => false
  | x :: xs, name => x == name || containsNameString xs name

private def generatedFunctionNames (fns : List SurfaceFun) : List String :=
  fns.map (fun f => f.name)

private def relevantFunctionDeps (allNames : List String) (f : SurfaceFun) : List String :=
  ((collectSurfaceCalls f.body).filter (fun dep => dep != f.name && containsNameString allNames dep)).eraseDups

private def depsReady (emitted : List String) (deps : List String) : Bool :=
  deps.all (fun dep => containsNameString emitted dep)

private partial def partitionReadyInOrder (allNames emitted : List String) : List SurfaceFun → (List SurfaceFun × (List SurfaceFun × List String))
  | [] => ([], ([], emitted))
  | f :: rest =>
      if depsReady emitted (relevantFunctionDeps allNames f) then
        let result := partitionReadyInOrder allNames (emitted ++ [f.name]) rest
        (f :: result.1, (result.2.1, result.2.2))
      else
        let result := partitionReadyInOrder allNames emitted rest
        (result.1, (f :: result.2.1, result.2.2))

private partial def orderFunctionsByDepsAux (allNames emitted : List String) (acc remaining : List SurfaceFun) (fuel : Nat) : List SurfaceFun :=
  match fuel, remaining with
  | _, [] => acc
  | 0, _ => acc ++ remaining
  | fuel' + 1, _ =>
      let result := partitionReadyInOrder allNames emitted remaining
      let ready := result.1
      let rest := result.2.1
      let emitted' := result.2.2
      if ready.isEmpty then
        acc ++ remaining
      else
        orderFunctionsByDepsAux allNames emitted' (acc ++ ready) rest fuel'

/-- Stable dependency-aware ordering for generated functions. Rust can resolve later functions, but the ordered snapshot keeps call dependencies visibly earlier. -/
def orderFunctionsByDeps (fns : List SurfaceFun) : List SurfaceFun :=
  let allNames := generatedFunctionNames fns
  orderFunctionsByDepsAux allNames [] [] fns (fns.length + 1)

/-- Build a declaration-aware surface module from checked functions. -/
def SurfaceModule.fromFunctions (fns : List SurfaceFun) : SurfaceModule :=
  let ordered := orderFunctionsByDeps fns
  { structs := uniqueStructs (ordered.bind collectFunStructs),
    enums := uniqueEnums (ordered.bind collectFunEnums),
    functions := ordered }

private def emitDecls (m : SurfaceModule) : String :=
  let structText := joinWith "\n" (m.structs.map emitStruct)
  let enumText := joinWith "\n" (m.enums.map emitEnum)
  let decls := [structText, enumText].filter (fun s => s != "")
  if decls.isEmpty then "" else joinWith "\n" decls ++ "\n"

/-- Emit a whole generated module from proof-carrying functions. -/
def emitRustModule (fns : List RFun) : String :=
  "// Generated by LeanRustCore. Do not edit by hand.\n" ++
  "// The checked-in rust/src/generated.rs is a fallback snapshot; scripts/gen.sh regenerates it.\n\n" ++
  joinWith "\n" (fns.map emitFun)

private def emitSurfaceModuleUnchecked (m : SurfaceModule) : String :=
  "// Generated by LeanRustCore from elaborated Lean declarations. Do not edit by hand.\n" ++
  "// The checked-in rust/src/generated.rs is a fallback snapshot; scripts/gen.sh regenerates it.\n\n" ++
  emitDecls m ++
  joinWith "\n" (m.functions.map emitSurfaceFun)

/-- Emit a whole generated module from extracted Lean declarations after Rust identifier-hygiene validation. -/
def emitSurfaceModuleChecked (m : SurfaceModule) : Except CompatibilityReport String := do
  let checked ← validateSurfaceModuleHygiene m
  pure (emitSurfaceModuleUnchecked checked)

/-- Emit a whole generated module from extracted Lean declarations. -/
def emitSurfaceModule (m : SurfaceModule) : String :=
  match emitSurfaceModuleChecked m with
  | .ok source => source
  | .error report => "// LeanRustCore emission failed: " ++ report.detail ++ "\n"

/-- Emit a whole generated module from extracted Lean declarations after Rust identifier-hygiene validation. -/
def emitSurfaceRustModuleChecked (fns : List SurfaceFun) : Except CompatibilityReport String :=
  emitSurfaceModuleChecked (SurfaceModule.fromFunctions fns)

/-- Emit a whole generated module from extracted Lean declarations. -/
def emitSurfaceRustModule (fns : List SurfaceFun) : String :=
  emitSurfaceModule (SurfaceModule.fromFunctions fns)

end LeanRustCore
