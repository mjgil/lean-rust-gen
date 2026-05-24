import LeanRustCore.IR
import LeanRustCore.Surface
import LeanRustCore.RustHygiene
import LeanRustCore.EmitRustRuntimeCalls

namespace LeanRustCore

/-- Small dependency-free string join. -/
def joinWith (sep : String) : List String → String
  | [] => ""
  | [x] => x
  | x :: xs => x ++ sep ++ joinWith sep xs

private def concatLists {α : Type} (lists : List (List α)) : List α :=
  lists.foldr (· ++ ·) []

/-- Rust spelling for the current IR type subset. -/
def rustType : RType → String
  | .unit => "()"
  | .bool => "bool"
  | .ordering => "Ordering"
  | .nat => "num_bigint::BigUint"
  | .int => "num_bigint::BigInt"
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
  | .boxed t => "Box<" ++ rustType t ++ ">"
  | .recursive name => rustTypeIdent name
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

private def lookupVariantPayloadLocal (variants : List (String × List RType)) (name : String) : Option (List RType) :=
  match variants with
  | [] => none
  | (candidate, payload) :: rest => if candidate == name then some payload else lookupVariantPayloadLocal rest name

private partial def emitSurfacePattern (ty : RType) : SurfacePattern → String
  | .wildcard => "_"
  | .var name => rustValueIdent "value" name
  | .unit => "()"
  | .bool true => "true"
  | .bool false => "false"
  | .optionNone => "None"
  | .optionSome inner =>
      match ty with
      | .option innerTy => "Some(" ++ emitSurfacePattern innerTy inner ++ ")"
      | _ => "Some(_)"
  | .enumCtor variant payload =>
      match ty with
      | .enum _ variants =>
          let payloadTypes := match lookupVariantPayloadLocal variants variant with | some tys => tys | none => []
          let rendered := (payload.zip payloadTypes).map (fun pair => emitSurfacePattern pair.2 pair.1)
          if rendered.isEmpty then enumPath ty variant else enumPath ty variant ++ "(" ++ joinWith ", " rendered ++ ")"
      | _ => rustVariantIdent variant
  | .prod a b =>
      match ty with
      | .prod aTy bTy => "(" ++ emitSurfacePattern aTy a ++ ", " ++ emitSurfacePattern bTy b ++ ")"
      | _ => "(_, _)"

private def emitInt (n : Int) : String :=
  toString n

private def emitRustStringLiteral (s : String) : String :=
  "String::from(\"" ++ s ++ "\")"

private def emitRustChar (c : Char) : String :=
  "char::from_u32(" ++ toString c.toNat ++ ").unwrap()"

private def emitExactNatLiteral (n : Nat) : String :=
  "num_bigint::BigUint::parse_bytes(b\"" ++ toString n ++ "\", 10).unwrap()"
private def emitExactIntLiteral (n : Int) : String :=
  "num_bigint::BigInt::parse_bytes(b\"" ++ toString n ++ "\", 10).unwrap()"

private partial def emitDefaultValue : RType → String
  | .unit => "()"
  | .bool => "false"
  | .ordering => "Ordering::Eq"
  | .nat => "num_bigint::BigUint::from(0u8)"
  | .int => "num_bigint::BigInt::from(0i8)"
  | .u32 => "0"
  | .u64 => "0"
  | .i32 => "0"
  | .i64 => "0"
  | .char => "char::from_u32(0).unwrap()"
  | .string => "String::new()"
  | .option _ => "None"
  | .list _ => "Vec::new()"
  | .array _ => "Vec::new()"
  | .vector _ _ => "Vec::new()"
  | .boxed inner => "Box::new(" ++ emitDefaultValue inner ++ ")"
  | .recursive name => rustTypeIdent name ++ "::default()"
  | .fin bound => "{ let __lrc_fin: u32 = 0; assert!(__lrc_fin < " ++ toString bound ++ "); __lrc_fin }"
  | .subtype t => emitDefaultValue t
  | .prod a b => "(" ++ emitDefaultValue a ++ ", " ++ emitDefaultValue b ++ ")"
  | .sum a _ => "Err(" ++ emitDefaultValue a ++ ")"
  | .result _ err => "Err(" ++ emitDefaultValue err ++ ")"
  | .struct name fields =>
      let rendered := fields.map (fun field => rustFieldIdent field.1 ++ ": " ++ emitDefaultValue field.2)
      rustTypeIdent name ++ " { " ++ joinWith ", " rendered ++ " }"
  | .enum name variants =>
      match variants with
      | [] => rustTypeIdent name ++ "::default()"
      | (variant, payload) :: _ =>
          let renderedPayload := if payload.isEmpty then "" else "(" ++ joinWith ", " (payload.map emitDefaultValue) ++ ")"
          rustTypeIdent name ++ "::" ++ rustVariantIdent variant ++ renderedPayload
  | .func _ _ => "Default::default()"

/-- Emit a valid Rust expression for the proof-carrying typed subset. -/
def emitExpr {ctx : Type} : {t : RType} → RExpr ctx t → String
  | _, .var name _ => rustValueIdent "value" name
  | _, .litUnit => "()"
  | _, .litBool true => "true"
  | _, .litBool false => "false"
  | _, .litU32 n => toString n
  | _, .litU64 n => toString n
  | _, .litI32 n => emitInt n
  | _, .litI64 n => emitInt n
  | _, .letIn name value body => "{ let " ++ rustValueIdent "value" name ++ " = " ++ emitExpr value ++ "; " ++ emitExpr body ++ " }"
  | _, .ite c a b => "if " ++ emitExpr c ++ " { " ++ emitExpr a ++ " } else { " ++ emitExpr b ++ " }"
  | _, .matchBool c whenTrue whenFalse => "match " ++ emitExpr c ++ " { true => " ++ emitExpr whenTrue ++ ", false => " ++ emitExpr whenFalse ++ " }"
  | _, .matchOption target noneCase someCase => "match " ++ emitExpr target ++ " { None => " ++ emitExpr noneCase ++ ", Some(value) => " ++ emitExpr someCase ++ " }"
  | _, .not a => "(!" ++ emitExpr a ++ ")"
  | _, .and a b => "(" ++ emitExpr a ++ " && " ++ emitExpr b ++ ")"
  | _, .or a b => "(" ++ emitExpr a ++ " || " ++ emitExpr b ++ ")"
  | _, .eqU32 a b => "(" ++ emitExpr a ++ ") == (" ++ emitExpr b ++ ")"
  | _, .ltU32 a b => "(" ++ emitExpr a ++ ") < (" ++ emitExpr b ++ ")"
  | _, .leU32 a b => "(" ++ emitExpr a ++ ") <= (" ++ emitExpr b ++ ")"
  | _, .gtU32 a b => "(" ++ emitExpr a ++ ") > (" ++ emitExpr b ++ ")"
  | _, .geU32 a b => "(" ++ emitExpr a ++ ") >= (" ++ emitExpr b ++ ")"
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
  | .litNat n => emitExactNatLiteral n
  | .litInt n => emitExactIntLiteral n
  | .litU32 n => toString n
  | .litU64 n => toString n
  | .litI32 n => emitInt n
  | .litI64 n => emitInt n
  | .litChar c => emitRustChar c
  | .litString value => emitRustStringLiteral value
  | .letIn name value (.var bodyName) =>
      if bodyName == name then
        emitSurfaceExpr value
      else
        "{ let " ++ rustValueIdent "value" name ++ " = " ++ emitSurfaceExpr value ++ "; " ++ emitSurfaceExpr (.var bodyName) ++ " }"
  | .letIn name value body => "{ let " ++ rustValueIdent "value" name ++ " = " ++ emitSurfaceExpr value ++ "; " ++ emitSurfaceExpr body ++ " }"
  | .ite c a b => "if " ++ emitSurfaceExpr c ++ " { " ++ emitSurfaceExpr a ++ " } else { " ++ emitSurfaceExpr b ++ " }"
  | .matchBool c whenTrue whenFalse => "match " ++ emitSurfaceExpr c ++ " { true => " ++ emitSurfaceExpr whenTrue ++ ", false => " ++ emitSurfaceExpr whenFalse ++ " }"
  | .matchOption target noneCase someName someCase => "match " ++ emitSurfaceExpr target ++ " { None => " ++ emitSurfaceExpr noneCase ++ ", Some(" ++ rustValueIdent "value" someName ++ ") => " ++ emitSurfaceExpr someCase ++ " }"
  | .matchEnum enumTy target branches =>
      let rendered := branches.map (fun branch => emitEnumPattern enumTy branch ++ " => " ++ emitSurfaceExpr branch.2.2)
      "match " ++ emitSurfaceExpr target ++ " { " ++ joinWith ", " rendered ++ " }"
  | .matchPattern scrutTy target arms =>
      let rendered := arms.map (fun arm => emitSurfacePattern scrutTy arm.1 ++ " => " ++ emitSurfaceExpr arm.2)
      "match " ++ emitSurfaceExpr target ++ " { " ++ joinWith ", " rendered ++ " }"
  | .not a => "(!" ++ emitSurfaceExpr a ++ ")"
  | .and a b => "(" ++ emitSurfaceExpr a ++ " && " ++ emitSurfaceExpr b ++ ")"
  | .or a b => "(" ++ emitSurfaceExpr a ++ " || " ++ emitSurfaceExpr b ++ ")"
  | .eq _ a b => "(" ++ emitSurfaceExpr a ++ ") == (" ++ emitSurfaceExpr b ++ ")"
  | .lt _ a b => "(" ++ emitSurfaceExpr a ++ ") < (" ++ emitSurfaceExpr b ++ ")"
  | .le _ a b => "(" ++ emitSurfaceExpr a ++ ") <= (" ++ emitSurfaceExpr b ++ ")"
  | .gt _ a b => "(" ++ emitSurfaceExpr a ++ ") > (" ++ emitSurfaceExpr b ++ ")"
  | .ge _ a b => "(" ++ emitSurfaceExpr a ++ ") >= (" ++ emitSurfaceExpr b ++ ")"
  | .add t a b => emitArithmetic "add" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .sub t a b => emitArithmetic "sub" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .mul t a b => emitArithmetic "mul" t (emitSurfaceExpr a) (emitSurfaceExpr b)
  | .min _ a b => "core::cmp::min(" ++ emitSurfaceExpr a ++ ", " ++ emitSurfaceExpr b ++ ")"
  | .max _ a b => "core::cmp::max(" ++ emitSurfaceExpr a ++ ", " ++ emitSurfaceExpr b ++ ")"
  | .compare _ a b => "if " ++ emitSurfaceExpr a ++ " < " ++ emitSurfaceExpr b ++ " { Ordering::Lt } else if " ++ emitSurfaceExpr a ++ " == " ++ emitSurfaceExpr b ++ " { Ordering::Eq } else { Ordering::Gt }"
  | .optionNone _ => "None"
  | .optionSome a => "Some(" ++ emitSurfaceExpr a ++ ")"
  | .resultOk _ a => "Ok(" ++ emitSurfaceExpr a ++ ")"
  | .resultErr _ e => "Err(" ++ emitSurfaceExpr e ++ ")"
  | .prodLit a b => "(" ++ emitSurfaceExpr a ++ ", " ++ emitSurfaceExpr b ++ ")"
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
      let renderedArgs := args.map emitSurfaceExpr
      match emitRuntimeCall? name renderedArgs with
      | some runtimeCall => runtimeCall
      | none => rustValueIdent "generated" name ++ "(" ++ joinWith ", " renderedArgs ++ ")"
  | .callValue fn _ _ arg =>
      emitSurfaceExpr fn ++ "(" ++ emitSurfaceExpr arg ++ ")"
  | .boxNew _ value =>
      "Box::new(" ++ emitSurfaceExpr value ++ ")"
  | .boxDeref _ value =>
      "*(" ++ emitSurfaceExpr value ++ ")"
  | .closureApply binder _ _ arg body =>
      "{ let " ++ rustValueIdent "value" binder ++ " = " ++ emitSurfaceExpr arg ++ "; " ++ emitSurfaceExpr body ++ " }"
  | .defaultValue ty => emitDefaultValue ty
  | .toStringValue _ value => "(" ++ emitSurfaceExpr value ++ ").to_string()"
  | .reprValue _ value => "format!(\"{:?}\", " ++ emitSurfaceExpr value ++ ")"
  | .listMap binder _ _ target body =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { " ++ outName ++ ".push(" ++ emitSurfaceExpr body ++ "); } " ++ outName ++ " }"
  | .listFilter binder _ target predicate =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if " ++ emitSurfaceExpr predicate ++ " { " ++ outName ++ ".push(" ++ binderName ++ "); } } " ++ outName ++ " }"
  | .listFoldl accName elemName accTy _ init target body =>
      let acc := rustValueIdent "acc" accName
      let elem := rustValueIdent "item" elemName
      "{ let mut " ++ acc ++ " : " ++ rustType accTy ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in " ++ emitSurfaceExpr target ++ " { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .listFoldr elemName accName _ accTy target init body =>
      let elem := rustValueIdent "item" elemName
      let acc := rustValueIdent "acc" accName
      "{ let mut " ++ acc ++ " : " ++ rustType accTy ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in (" ++ emitSurfaceExpr target ++ ").into_iter().rev() { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .listAny binder _ target predicate =>
      let outName := "__lrc_any"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = false; for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if " ++ emitSurfaceExpr predicate ++ " { " ++ outName ++ " = true; break; } } " ++ outName ++ " }"
  | .listAll binder _ target predicate =>
      let outName := "__lrc_all"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = true; for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if !(" ++ emitSurfaceExpr predicate ++ ") { " ++ outName ++ " = false; break; } } " ++ outName ++ " }"
  | .listAppend _ left right =>
      let outName := "__lrc_vec"
      "{ let mut " ++ outName ++ " = " ++ emitSurfaceExpr left ++ "; " ++ outName ++ ".extend(" ++ emitSurfaceExpr right ++ "); " ++ outName ++ " }"
  | .listFind binder _ target predicate =>
      let binderName := rustValueIdent "value" binder
      "{ for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { if " ++ emitSurfaceExpr predicate ++ " { return Some(" ++ binderName ++ "); } } None }"
  | .arrayMap binder _ _ target body =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { " ++ outName ++ ".push(" ++ emitSurfaceExpr body ++ "); } " ++ outName ++ " }"
  | .arrayFoldl accName elemName accTy _ init target body =>
      let acc := rustValueIdent "acc" accName
      let elem := rustValueIdent "item" elemName
      "{ let mut " ++ acc ++ " : " ++ rustType accTy ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ elem ++ " in " ++ emitSurfaceExpr target ++ " { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .arrayPush _ target value =>
      let outName := "__lrc_vec"
      "{ let mut " ++ outName ++ " = " ++ emitSurfaceExpr target ++ "; " ++ outName ++ ".push(" ++ emitSurfaceExpr value ++ "); " ++ outName ++ " }"
  | .optionMap binder _ outTy target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { None => None::<" ++ rustType outTy ++ ">, Some(" ++ name ++ ") => Some(" ++ emitSurfaceExpr body ++ ") }"
  | .optionBind binder _ outTy target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { None => None::<" ++ rustType outTy ++ ">, Some(" ++ name ++ ") => " ++ emitSurfaceExpr body ++ " }"
  | .resultMapOk binder errTy _ _ target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { Err(__lrc_err) => Err::<_, " ++ rustType errTy ++ ">(__lrc_err), Ok(" ++ name ++ ") => Ok(" ++ emitSurfaceExpr body ++ ") }"
  | .resultMapErr binder okTy _ _ target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { Ok(" ++ name ++ ") => Ok::<" ++ rustType okTy ++ ", _>(" ++ name ++ "), Err(" ++ name ++ ") => Err(" ++ emitSurfaceExpr body ++ ") }"
  | .resultBind binder errTy _ _ target body =>
      let name := rustValueIdent "value" binder
      "match " ++ emitSurfaceExpr target ++ " { Err(__lrc_err) => Err::<_, " ++ rustType errTy ++ ">(__lrc_err), Ok(" ++ name ++ ") => " ++ emitSurfaceExpr body ++ " }"
  | .subtypeErase _ value => emitSurfaceExpr value
  | .subtypeVal _ value => emitSurfaceExpr value
  | .finCheck bound value =>
      "if " ++ emitSurfaceExpr value ++ " < " ++ toString bound ++ " { Some(" ++ emitSurfaceExpr value ++ ") } else { None }"
  | .finMk _ value => emitSurfaceExpr value
  | .finVal _ value => emitSurfaceExpr value
  | .vectorCheck elemTy bound value =>
      let vecName := "__lrc_vec"
      "{ let " ++ vecName ++ " = " ++ emitSurfaceExpr value ++ "; if " ++ vecName ++ ".len() == " ++ toString bound ++ " { Some(" ++ vecName ++ ") } else { None::<" ++ rustType (.vector elemTy bound) ++ "> } }"
  | .vectorErase _ _ value => emitSurfaceExpr value
  | .vectorMap binder _ _ _ target body =>
      let outName := "__lrc_out"
      let binderName := rustValueIdent "value" binder
      "{ let mut " ++ outName ++ " = Vec::new(); for " ++ binderName ++ " in " ++ emitSurfaceExpr target ++ " { " ++ outName ++ ".push(" ++ emitSurfaceExpr body ++ "); } " ++ outName ++ " }"
  | .listLength _ target =>
      "(" ++ emitSurfaceExpr target ++ ").len() as u32"
  | .natFold idxName accName accTy init n body =>
      let idx := rustValueIdent "idx" idxName
      let acc := rustValueIdent "acc" accName
      "{ let mut " ++ acc ++ " : " ++ rustType accTy ++ " = " ++ emitSurfaceExpr init ++ "; for " ++ idx ++ " in 0..(" ++ emitSurfaceExpr n ++ ") { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; } " ++ acc ++ " }"
  | .tailRecNat counterName accName accTy counter init body =>
      let counterIdent := rustValueIdent "counter" counterName
      let acc := rustValueIdent "acc" accName
      "{ let mut " ++ counterIdent ++ " = " ++ emitSurfaceExpr counter ++ "; let mut " ++ acc ++ " : " ++ rustType accTy ++ " = " ++ emitSurfaceExpr init ++ "; while " ++ counterIdent ++ " != 0 { " ++ acc ++ " = " ++ emitSurfaceExpr body ++ "; " ++ counterIdent ++ " = (" ++ counterIdent ++ ").wrapping_sub(1); } " ++ acc ++ " }"

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

private partial def collectTypeStructs : RType → List SurfaceStruct
  | .option t => collectTypeStructs t
  | .result ok err => collectTypeStructs ok ++ collectTypeStructs err
  | .list t => collectTypeStructs t
  | .array t => collectTypeStructs t
  | .prod a b => collectTypeStructs a ++ collectTypeStructs b
  | .sum a b => collectTypeStructs a ++ collectTypeStructs b
  | .func a b => collectTypeStructs a ++ collectTypeStructs b
  | .boxed t => collectTypeStructs t
  | .recursive _ => []
  | .subtype t => collectTypeStructs t
  | .fin _ => []
  | .vector t _ => collectTypeStructs t
  | s@(.struct name fields) =>
      { name := name, fields := fields } :: concatLists (fields.map (fun field => collectTypeStructs field.2))
  | .enum _ variants => concatLists (variants.map (fun variant => concatLists (variant.2.map collectTypeStructs)))
  | _ => []

private partial def collectTypeEnums : RType → List SurfaceEnum
  | .ordering => [{ name := "Ordering", variants := [("lt", []), ("eq", []), ("gt", [])] }]
  | .option t => collectTypeEnums t
  | .result ok err => collectTypeEnums ok ++ collectTypeEnums err
  | .list t => collectTypeEnums t
  | .array t => collectTypeEnums t
  | .prod a b => collectTypeEnums a ++ collectTypeEnums b
  | .sum a b => collectTypeEnums a ++ collectTypeEnums b
  | .func a b => collectTypeEnums a ++ collectTypeEnums b
  | .boxed t => collectTypeEnums t
  | .recursive _ => []
  | .subtype t => collectTypeEnums t
  | .fin _ => []
  | .vector t _ => collectTypeEnums t
  | .struct _ fields => concatLists (fields.map (fun field => collectTypeEnums field.2))
  | .enum name variants =>
      { name := name, variants := variants } :: concatLists (variants.map (fun variant => concatLists (variant.2.map collectTypeEnums)))
  | _ => []

partial def collectSurfaceStructs : SurfaceExpr → List SurfaceStruct
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litNat _ => []
  | .litInt _ => []
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
  | .matchEnum ty target branches => collectTypeStructs ty ++ collectSurfaceStructs target ++ concatLists (branches.map (fun branch => collectSurfaceStructs branch.2.2))
  | .matchPattern ty target arms => collectTypeStructs ty ++ collectSurfaceStructs target ++ concatLists (arms.map (fun arm => collectSurfaceStructs arm.2))
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
  | .compare t a b => collectTypeStructs t ++ collectSurfaceStructs a ++ collectSurfaceStructs b
  | .optionNone t => collectTypeStructs t
  | .optionSome a => collectSurfaceStructs a
  | .resultOk t a => collectTypeStructs t ++ collectSurfaceStructs a
  | .resultErr t e => collectTypeStructs t ++ collectSurfaceStructs e
  | .prodLit a b => collectSurfaceStructs a ++ collectSurfaceStructs b
  | .structLit ty fields => collectTypeStructs ty ++ concatLists (fields.map (fun field => collectSurfaceStructs field.2))
  | .field target _ => collectSurfaceStructs target
  | .enumVariant ty _ payload => collectTypeStructs ty ++ concatLists (payload.map collectSurfaceStructs)
  | .call _ argTypes ret args => concatLists (argTypes.map collectTypeStructs) ++ collectTypeStructs ret ++ concatLists (args.map collectSurfaceStructs)
  | .callValue fn argTy retTy arg => collectSurfaceStructs fn ++ collectTypeStructs argTy ++ collectTypeStructs retTy ++ collectSurfaceStructs arg
  | .boxNew inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .boxDeref inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .closureApply _ argTy retTy arg body => collectTypeStructs argTy ++ collectTypeStructs retTy ++ collectSurfaceStructs arg ++ collectSurfaceStructs body
  | .defaultValue ty => collectTypeStructs ty
  | .toStringValue ty value => collectTypeStructs ty ++ collectSurfaceStructs value
  | .reprValue ty value => collectTypeStructs ty ++ collectSurfaceStructs value
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
  | .listAppend elemTy left right =>
      collectTypeStructs elemTy ++ collectSurfaceStructs left ++ collectSurfaceStructs right
  | .listFind _ elemTy target predicate =>
      collectTypeStructs elemTy ++ collectSurfaceStructs target ++ collectSurfaceStructs predicate
  | .arrayMap _ elemTy outTy target body =>
      collectTypeStructs elemTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .arrayFoldl _ _ accTy elemTy init target body =>
      collectTypeStructs accTy ++ collectTypeStructs elemTy ++ collectSurfaceStructs init ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .arrayPush elemTy target value =>
      collectTypeStructs elemTy ++ collectSurfaceStructs target ++ collectSurfaceStructs value
  | .optionMap _ innerTy outTy target body =>
      collectTypeStructs innerTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .optionBind _ innerTy outTy target body =>
      collectTypeStructs innerTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .resultMapOk _ errTy okTy outTy target body =>
      collectTypeStructs errTy ++ collectTypeStructs okTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .resultMapErr _ okTy errTy outErr target body =>
      collectTypeStructs okTy ++ collectTypeStructs errTy ++ collectTypeStructs outErr ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .resultBind _ errTy okTy outTy target body =>
      collectTypeStructs errTy ++ collectTypeStructs okTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .subtypeErase inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .subtypeVal inner value => collectTypeStructs inner ++ collectSurfaceStructs value
  | .finCheck _ value => collectSurfaceStructs value
  | .finMk _ value => collectSurfaceStructs value
  | .finVal _ value => collectSurfaceStructs value
  | .vectorCheck elemTy _ value => collectTypeStructs elemTy ++ collectSurfaceStructs value
  | .vectorErase elemTy _ value => collectTypeStructs elemTy ++ collectSurfaceStructs value
  | .vectorMap _ elemTy outTy _ target body =>
      collectTypeStructs elemTy ++ collectTypeStructs outTy ++ collectSurfaceStructs target ++ collectSurfaceStructs body
  | .listLength elemTy target => collectTypeStructs elemTy ++ collectSurfaceStructs target
  | .natFold _ _ accTy init n body =>
      collectTypeStructs accTy ++ collectSurfaceStructs init ++ collectSurfaceStructs n ++ collectSurfaceStructs body
  | .tailRecNat _ _ accTy counter init body =>
      collectTypeStructs accTy ++ collectSurfaceStructs counter ++ collectSurfaceStructs init ++ collectSurfaceStructs body

partial def collectSurfaceEnums : SurfaceExpr → List SurfaceEnum
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litNat _ => []
  | .litInt _ => []
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
  | .matchEnum ty target branches => collectTypeEnums ty ++ collectSurfaceEnums target ++ concatLists (branches.map (fun branch => collectSurfaceEnums branch.2.2))
  | .matchPattern ty target arms => collectTypeEnums ty ++ collectSurfaceEnums target ++ concatLists (arms.map (fun arm => collectSurfaceEnums arm.2))
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
  | .compare t a b => collectTypeEnums t ++ collectSurfaceEnums a ++ collectSurfaceEnums b
  | .optionNone t => collectTypeEnums t
  | .optionSome a => collectSurfaceEnums a
  | .resultOk t a => collectTypeEnums t ++ collectSurfaceEnums a
  | .resultErr t e => collectTypeEnums t ++ collectSurfaceEnums e
  | .prodLit a b => collectSurfaceEnums a ++ collectSurfaceEnums b
  | .structLit ty fields => collectTypeEnums ty ++ concatLists (fields.map (fun field => collectSurfaceEnums field.2))
  | .field target _ => collectSurfaceEnums target
  | .enumVariant ty _ payload => collectTypeEnums ty ++ concatLists (payload.map collectSurfaceEnums)
  | .call _ argTypes ret args => concatLists (argTypes.map collectTypeEnums) ++ collectTypeEnums ret ++ concatLists (args.map collectSurfaceEnums)
  | .callValue fn argTy retTy arg => collectSurfaceEnums fn ++ collectTypeEnums argTy ++ collectTypeEnums retTy ++ collectSurfaceEnums arg
  | .boxNew inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .boxDeref inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .closureApply _ argTy retTy arg body => collectTypeEnums argTy ++ collectTypeEnums retTy ++ collectSurfaceEnums arg ++ collectSurfaceEnums body
  | .defaultValue ty => collectTypeEnums ty
  | .toStringValue ty value => collectTypeEnums ty ++ collectSurfaceEnums value
  | .reprValue ty value => collectTypeEnums ty ++ collectSurfaceEnums value
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
  | .listAppend elemTy left right =>
      collectTypeEnums elemTy ++ collectSurfaceEnums left ++ collectSurfaceEnums right
  | .listFind _ elemTy target predicate =>
      collectTypeEnums elemTy ++ collectSurfaceEnums target ++ collectSurfaceEnums predicate
  | .arrayMap _ elemTy outTy target body =>
      collectTypeEnums elemTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .arrayFoldl _ _ accTy elemTy init target body =>
      collectTypeEnums accTy ++ collectTypeEnums elemTy ++ collectSurfaceEnums init ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .arrayPush elemTy target value =>
      collectTypeEnums elemTy ++ collectSurfaceEnums target ++ collectSurfaceEnums value
  | .optionMap _ innerTy outTy target body =>
      collectTypeEnums innerTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .optionBind _ innerTy outTy target body =>
      collectTypeEnums innerTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .resultMapOk _ errTy okTy outTy target body =>
      collectTypeEnums errTy ++ collectTypeEnums okTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .resultMapErr _ okTy errTy outErr target body =>
      collectTypeEnums okTy ++ collectTypeEnums errTy ++ collectTypeEnums outErr ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .resultBind _ errTy okTy outTy target body =>
      collectTypeEnums errTy ++ collectTypeEnums okTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .subtypeErase inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .subtypeVal inner value => collectTypeEnums inner ++ collectSurfaceEnums value
  | .finCheck _ value => collectSurfaceEnums value
  | .finMk _ value => collectSurfaceEnums value
  | .finVal _ value => collectSurfaceEnums value
  | .vectorCheck elemTy _ value => collectTypeEnums elemTy ++ collectSurfaceEnums value
  | .vectorErase elemTy _ value => collectTypeEnums elemTy ++ collectSurfaceEnums value
  | .vectorMap _ elemTy outTy _ target body =>
      collectTypeEnums elemTy ++ collectTypeEnums outTy ++ collectSurfaceEnums target ++ collectSurfaceEnums body
  | .listLength elemTy target => collectTypeEnums elemTy ++ collectSurfaceEnums target
  | .natFold _ _ accTy init n body =>
      collectTypeEnums accTy ++ collectSurfaceEnums init ++ collectSurfaceEnums n ++ collectSurfaceEnums body
  | .tailRecNat _ _ accTy counter init body =>
      collectTypeEnums accTy ++ collectSurfaceEnums counter ++ collectSurfaceEnums init ++ collectSurfaceEnums body

partial def collectSurfaceCalls : SurfaceExpr → List String
  | .var _ => []
  | .litUnit => []
  | .litBool _ => []
  | .litNat _ => []
  | .litInt _ => []
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
  | .matchEnum _ target branches => collectSurfaceCalls target ++ concatLists (branches.map (fun branch => collectSurfaceCalls branch.2.2))
  | .matchPattern _ target arms => collectSurfaceCalls target ++ concatLists (arms.map (fun arm => collectSurfaceCalls arm.2))
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
  | .compare _ a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .optionNone _ => []
  | .optionSome a => collectSurfaceCalls a
  | .resultOk _ a => collectSurfaceCalls a
  | .resultErr _ e => collectSurfaceCalls e
  | .prodLit a b => collectSurfaceCalls a ++ collectSurfaceCalls b
  | .structLit _ fields => concatLists (fields.map (fun field => collectSurfaceCalls field.2))
  | .field target _ => collectSurfaceCalls target
  | .enumVariant _ _ payload => concatLists (payload.map collectSurfaceCalls)
  | .call name _ _ args => name :: concatLists (args.map collectSurfaceCalls)
  | .callValue fn _ _ arg => collectSurfaceCalls fn ++ collectSurfaceCalls arg
  | .boxNew _ value => collectSurfaceCalls value
  | .boxDeref _ value => collectSurfaceCalls value
  | .closureApply _ _ _ arg body => collectSurfaceCalls arg ++ collectSurfaceCalls body
  | .defaultValue _ => []
  | .toStringValue _ value => collectSurfaceCalls value
  | .reprValue _ value => collectSurfaceCalls value
  | .listMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .listFilter _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .listFoldl _ _ _ _ init target body => collectSurfaceCalls init ++ collectSurfaceCalls target ++ collectSurfaceCalls body
  | .listFoldr _ _ _ _ target init body => collectSurfaceCalls target ++ collectSurfaceCalls init ++ collectSurfaceCalls body
  | .listAny _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .listAll _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .listAppend _ left right => collectSurfaceCalls left ++ collectSurfaceCalls right
  | .listFind _ _ target predicate => collectSurfaceCalls target ++ collectSurfaceCalls predicate
  | .arrayMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .arrayFoldl _ _ _ _ init target body => collectSurfaceCalls init ++ collectSurfaceCalls target ++ collectSurfaceCalls body
  | .arrayPush _ target value => collectSurfaceCalls target ++ collectSurfaceCalls value
  | .optionMap _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .optionBind _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .resultMapOk _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .resultMapErr _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .resultBind _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .subtypeErase _ value => collectSurfaceCalls value
  | .subtypeVal _ value => collectSurfaceCalls value
  | .finCheck _ value => collectSurfaceCalls value
  | .finMk _ value => collectSurfaceCalls value
  | .finVal _ value => collectSurfaceCalls value
  | .vectorCheck _ _ value => collectSurfaceCalls value
  | .vectorErase _ _ value => collectSurfaceCalls value
  | .vectorMap _ _ _ _ target body => collectSurfaceCalls target ++ collectSurfaceCalls body
  | .listLength _ target => collectSurfaceCalls target
  | .natFold _ _ _ init n body => collectSurfaceCalls init ++ collectSurfaceCalls n ++ collectSurfaceCalls body
  | .tailRecNat _ _ _ counter init body => collectSurfaceCalls counter ++ collectSurfaceCalls init ++ collectSurfaceCalls body

private def collectFunStructs (f : SurfaceFun) : List SurfaceStruct :=
  concatLists (f.args.map (fun arg => collectTypeStructs arg.2)) ++ collectTypeStructs f.ret ++ collectSurfaceStructs f.body

private def collectFunEnums (f : SurfaceFun) : List SurfaceEnum :=
  concatLists (f.args.map (fun arg => collectTypeEnums arg.2)) ++ collectTypeEnums f.ret ++ collectSurfaceEnums f.body

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
  { structs := uniqueStructs (concatLists (ordered.map collectFunStructs)),
    enums := uniqueEnums (concatLists (ordered.map collectFunEnums)),
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
